import Foundation

private struct LossyListIndexKey: CodingKey {
    let intValue: Int?
    var stringValue: String { "Index \(intValue ?? -1)" }

    init(_ index: Int) { intValue = index }
    init?(intValue: Int) { self.intValue = intValue }
    init?(stringValue: String) { nil }
}

public struct StripeDecodingReport: Sendable {
    public enum Outcome: Sendable {
        case unknownValueDecodedAsNil
        case unknownValueRawPreserved
        case recordDropped
    }

    public let typeName: String
    public let rawValue: String?
    public let codingPath: String
    public let outcome: Outcome
    public let failureDescription: String?

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
    public func decodeIfPresent<T>(_ type: T.Type, forKey key: Key) throws -> T?
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
    public func decodeIfPresent<T>(_ type: [T].Type, forKey key: Key) throws -> [T]?
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
        var firstFailure: Error?
        var dropped = 0
        elements.reserveCapacity(container.count ?? 0)

        while !container.isAtEnd {
            let index = container.currentIndex
            let element = try container.decode(LossyElement<Element>.self)

            if let value = element.value {
                elements.append(value)
                continue
            }

            dropped += 1
            if firstFailure == nil {
                firstFailure = element.failure
            }

            StripeDecodingDiagnostics.report(
                StripeDecodingReport(typeName: String(describing: Element.self),
                                     codingPath: container.codingPath + [LossyListIndexKey(index)],
                                     outcome: .recordDropped,
                                     underlyingError: element.failure)
            )
        }

        if elements.isEmpty, let failure = firstFailure {
            throw failure
        }

        droppedCount = dropped
        wrappedValue = elements
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
