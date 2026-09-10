import Foundation

// Decodes a Stripe enum value this package does not map as `nil` rather than throwing, so one
// unrecognised value cannot abort the page around it.
//
// Stripe adds enum values without warning. The synthesized `Codable` conformance of a
// `String`-backed enum throws `DecodingError.dataCorrupted` on anything it does not know, and
// because the failure surfaces while decoding a list response it takes the whole page with it,
// not just the record that carried the value.
//
// The deliberate leniencies, and their limits:
//
// - When decoding an enum value, only `dataCorrupted` is caught, and only when the value really
//   is a string. A `typeMismatch` there means Stripe changed a field's type, which is a schema
//   break rather than a new value, and it still throws.
// - At the page level the rule is deliberately wider: `LossyList` drops a record that fails for
//   any reason, so a schema break confined to some records costs those records, not the page.
// - That width applies ONLY to a list that IS the response, which is a page a caller iterates.
//   The same list type nested inside another object is a relation the caller reads whole
//   (`Customer.subscriptions`, `Subscription.items`), and silently shortening one changes what
//   the caller decides rather than costing it a page, so a nested list rejects the whole object
//   instead. Composed, that is the behaviour worth having: a bad item fails its subscription,
//   and the page around that subscription drops just that record and keeps going.
// - A page that loses every record still throws. Returning an empty page would read as success
//   to a caller that stops paginating on an empty result, turning a loud failure into a silently
//   truncated sync.
// - `Currency` keeps its raw value through an `unrecognized(String)` case. Every other enum
//   discards the unmapped string, which is safe because a nil enum already means "not one we act
//   on", while a nil currency would let a caller substitute a default and relabel money.
// - The two `decodeIfPresent` overloads are deliberately `internal`. They are more constrained
//   than the stdlib's, so a `public` one would win overload resolution inside an importing
//   module's own synthesized conformances and make that module's unrelated enums silently
//   lenient too. The `LossyList` container plumbing below stays `public`, because the wrapper is
//   applied to public properties and is constrained to a type this package owns.
//
// Skipping a record is data loss, so a consumer must install `StripeDecodingDiagnostics.handler`
// and report what it hears. The handler is `nil` by default and the reports are dropped until one
// is installed.

private struct LossyListIndexKey: CodingKey {
    private let index: Int

    var intValue: Int? { index }
    var stringValue: String { "Index \(index)" }

    init(_ index: Int) { self.index = index }
    init?(intValue: Int) { index = intValue }
    init?(stringValue: String) { nil }
}

public struct StripeDecodingReport: Sendable {
    public enum Outcome: Sendable, Equatable {
        case unknownValueDecodedAsNil
        case unknownValueRawPreserved
        case recordDropped
    }

    public let typeName: String
    public let rawValue: String?
    public let codingPath: String
    public let outcome: Outcome
    public let failureDescription: String?
    /// Which `DecodingError` case a dropped record failed on, as a stable token
    /// (`typeMismatch`, `keyNotFound`, `valueNotFound`, `dataCorrupted`), `unknown` for a case
    /// this package does not know yet, or `nonDecodingError` when the record failed on something
    /// that never became a `DecodingError` at all.
    ///
    /// Separate from `failureDescription` because that one is `String(describing:)` of the error,
    /// whose text differs between Darwin Foundation and swift-corelibs-foundation. A consumer that
    /// parsed it to group failures worked on macOS and produced one group per record on Linux.
    public let failureKind: String?
    /// The coding path of the value that actually failed, which names the FIELD rather than the
    /// record: `["data", "Index 3", "id"]`. The keyed segments are what a consumer wants to group
    /// on, and the integer-indexed ones are what it wants to drop, so both are kept separate here
    /// rather than pre-joined.
    public let failureCodingPath: [String]
    /// The positions in `failureCodingPath` that are array indices rather than keys, so a consumer
    /// can drop them without guessing from the text.
    public let failureCodingPathIndices: Set<Int>

    init(typeName: String,
         rawValue: String? = nil,
         codingPath: [CodingKey],
         outcome: Outcome,
         underlyingError: Error? = nil) {
        self.typeName = typeName
        self.rawValue = rawValue
        self.codingPath = codingPath.map(\.stringValue).joined(separator: ".")
        self.outcome = outcome
        self.failureDescription = underlyingError.map { String(describing: $0) }

        if let underlyingError {
            let decoding = underlyingError as? DecodingError

            // A record can fail on something that is not a DecodingError at all: JSONDecoder
            // converts its internal JSONError at the outermost decode boundary, and this catch
            // sits inside that boundary, so an integer that overflows Int arrives raw. Falling
            // back to the record's own path keeps the grouping key non-empty, and the kind says
            // which of the two situations produced it.
            self.failureKind = decoding.map(Self.kind) ?? "nonDecodingError"

            let failurePath = decoding.map(Self.failurePath) ?? codingPath
            self.failureCodingPath = failurePath.map(\.stringValue)
            self.failureCodingPathIndices = Set(
                failurePath.enumerated()
                    .filter { $0.element.intValue != nil }
                    .map(\.offset)
            )
        } else {
            self.failureKind = nil
            self.failureCodingPath = []
            self.failureCodingPathIndices = []
        }
    }

    private static func kind(_ error: DecodingError) -> String {
        switch error {
        case .typeMismatch: return "typeMismatch"
        case .valueNotFound: return "valueNotFound"
        case .keyNotFound: return "keyNotFound"
        case .dataCorrupted: return "dataCorrupted"
        @unknown default: return "unknown"
        }
    }

    /// The path to the value that failed.
    ///
    /// `keyNotFound` is the odd one: its context path names the CONTAINER the key was missing
    /// from, and the key itself rides the associated value, so it has to be appended or the path
    /// stops one segment short of the thing that actually went wrong.
    private static func failurePath(_ error: DecodingError) -> [CodingKey] {
        switch error {
        case .typeMismatch(_, let context): return context.codingPath
        case .valueNotFound(_, let context): return context.codingPath
        case .keyNotFound(let key, let context): return context.codingPath + [key]
        case .dataCorrupted(let context): return context.codingPath
        @unknown default: return []
        }
    }
}

private final class StripeDecodingHandlerBox: @unchecked Sendable {
    private let lock = NSLock()
    private var handler: (@Sendable (StripeDecodingReport) -> Void)?

    var current: (@Sendable (StripeDecodingReport) -> Void)? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return handler
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            handler = newValue
        }
    }
}

private let stripeDecodingHandlerBox = StripeDecodingHandlerBox()

public enum StripeDecodingDiagnostics {
    public static var handler: (@Sendable (StripeDecodingReport) -> Void)? {
        get { stripeDecodingHandlerBox.current }
        set { stripeDecodingHandlerBox.current = newValue }
    }

    static func report(_ report: StripeDecodingReport) {
        handler?(report)
    }
}

extension KeyedDecodingContainer {
    func decodeIfPresent<T>(_ type: T.Type, forKey key: Key) throws -> T?
    where T: RawRepresentable & Decodable, T.RawValue == String {
        guard contains(key), try !decodeNil(forKey: key) else { return nil }

        do {
            return try decode(T.self, forKey: key)
        } catch let error as DecodingError {
            guard case .dataCorrupted = error,
                  let raw = try? decode(String.self, forKey: key) else {
                throw error
            }

            StripeDecodingDiagnostics.report(
                StripeDecodingReport(typeName: String(describing: T.self),
                                     rawValue: raw,
                                     codingPath: codingPath + [key],
                                     outcome: .unknownValueDecodedAsNil)
            )
            return nil
        }
    }
}

extension KeyedDecodingContainer {
    func decodeIfPresent<T>(_ type: [T].Type, forKey key: Key) throws -> [T]?
    where T: RawRepresentable & Decodable, T.RawValue == String {
        guard contains(key), try !decodeNil(forKey: key) else { return nil }

        var nested = try nestedUnkeyedContainer(forKey: key)
        var values: [T] = []
        values.reserveCapacity(nested.count ?? 0)

        while !nested.isAtEnd {
            let index = nested.currentIndex
            let element = try nested.superDecoder()

            do {
                values.append(try T(from: element))
                continue
            } catch let error as DecodingError {
                guard case .dataCorrupted = error,
                      let raw = try? element.singleValueContainer().decode(String.self) else {
                    throw error
                }

                StripeDecodingDiagnostics.report(
                    StripeDecodingReport(typeName: String(describing: T.self),
                                         rawValue: raw,
                                         codingPath: nested.codingPath + [LossyListIndexKey(index)],
                                         outcome: .unknownValueDecodedAsNil)
                )
            }
        }

        return values
    }
}

private struct LossyElement<Wrapped: Decodable>: Decodable {
    let value: Wrapped?
    let failure: Error?

    init(from decoder: Decoder) throws {
        do {
            value = try Wrapped(from: decoder)
            failure = nil
        } catch {
            value = nil
            failure = error
        }
    }
}

@propertyWrapper
public struct LossyList<Element: Codable>: Codable {
    public var wrappedValue: [Element]?
    public private(set) var droppedCount = 0

    public var projectedValue: Int { droppedCount }

    public init(wrappedValue: [Element]?) {
        self.wrappedValue = wrappedValue
    }

    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        var elements: [Element] = []
        var failures: [(index: Int, error: Error?)] = []
        elements.reserveCapacity(container.count ?? 0)

        while !container.isAtEnd {
            let index = container.currentIndex
            let element = try container.decode(LossyElement<Element>.self)

            if let value = element.value {
                elements.append(value)
                continue
            }

            failures.append((index, element.failure))
        }

        if let failure = Self.rejection(failures: failures,
                                        survivors: elements.count,
                                        codingPath: decoder.codingPath) {
            throw failure
        }

        for failure in failures {
            StripeDecodingDiagnostics.report(
                StripeDecodingReport(typeName: String(describing: Element.self),
                                     codingPath: container.codingPath
                                         + [LossyListIndexKey(failure.index)],
                                     outcome: .recordDropped,
                                     underlyingError: failure.error)
            )
        }

        droppedCount = failures.count
        wrappedValue = elements
    }

    static func rejection(failures: [(index: Int, error: Error?)],
                          survivors: Int,
                          codingPath: [CodingKey]) -> Error? {
        guard let first = failures.first?.error else { return nil }
        if survivors == 0 { return first }
        return isPageResponse(codingPath) ? nil : first
    }

    static func isPageResponse(_ codingPath: [CodingKey]) -> Bool {
        codingPath.count == 1
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(wrappedValue)
    }
}

extension KeyedDecodingContainer {
    public func decode<Element>(_ type: LossyList<Element>.Type,
                                forKey key: Key) throws -> LossyList<Element> {
        guard contains(key), try !decodeNil(forKey: key) else {
            return LossyList(wrappedValue: nil)
        }
        return try LossyList<Element>(from: superDecoder(forKey: key))
    }
}

extension KeyedEncodingContainer {
    public mutating func encode<Element>(_ value: LossyList<Element>,
                                         forKey key: Key) throws {
        try encodeIfPresent(value.wrappedValue, forKey: key)
    }
}
