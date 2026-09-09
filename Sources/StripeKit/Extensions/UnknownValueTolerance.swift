import Foundation

public struct StripeDecodingReport {
    public enum Outcome {
        case unknownValueDecodedAsNil
        case unknownValueRawPreserved
        case recordDropped
    }

    public let typeName: String
    public let rawValue: String?
    public let codingPath: String
    public let outcome: Outcome
    public let underlyingError: Error?

    init(typeName: String,
         rawValue: String? = nil,
         codingPath: [CodingKey],
         outcome: Outcome,
         underlyingError: Error? = nil) {
        self.typeName = typeName
        self.rawValue = rawValue
        self.codingPath = codingPath.map(\.stringValue).joined(separator: ".")
        self.outcome = outcome
        self.underlyingError = underlyingError
    }
}

public enum StripeDecodingDiagnostics {
    private static let lock = NSLock()
    private static var _handler: ((StripeDecodingReport) -> Void)?

    public static var handler: ((StripeDecodingReport) -> Void)? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _handler
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _handler = newValue
        }
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
        } catch DecodingError.dataCorrupted(let context) {
            guard let raw = try? decode(String.self, forKey: key) else {
                throw DecodingError.dataCorrupted(context)
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

    public init(wrappedValue: [Element]?) {
        self.wrappedValue = wrappedValue
    }

    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        var elements: [Element] = []
        elements.reserveCapacity(container.count ?? 0)

        while !container.isAtEnd {
            let element = try container.decode(LossyElement<Element>.self)

            if let value = element.value {
                elements.append(value)
                continue
            }

            StripeDecodingDiagnostics.report(
                StripeDecodingReport(typeName: String(describing: Element.self),
                                     codingPath: container.codingPath,
                                     outcome: .recordDropped,
                                     underlyingError: element.failure)
            )
        }

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
