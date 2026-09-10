import Foundation
import XCTest
@testable import StripeKit

private final class ReportCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [StripeDecodingReport] = []

    var all: [StripeDecodingReport] {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }

    static func installed() -> ReportCollector {
        let collector = ReportCollector()
        StripeDecodingDiagnostics.handler = { [collector] report in
            collector.lock.lock()
            defer { collector.lock.unlock() }
            collector.storage.append(report)
        }
        return collector
    }

    func uninstall() {
        StripeDecodingDiagnostics.handler = nil
    }
}

final class UnknownEnumToleranceTests: XCTestCase {

    private func stripeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }

    private func chargePage(middleRecord: String) -> Data {
        """
        {
          "object": "list",
          "has_more": false,
          "url": "/v1/charges",
          "data": [
            {
              "id": "ch_first",
              "object": "charge",
              "created": 1757404800,
              "currency": "usd",
              "payment_method_details": { "type": "card", "card": { "brand": "visa", "last4": "4242" } }
            },
            \(middleRecord),
            {
              "id": "ch_last",
              "object": "charge",
              "created": 1757404802,
              "currency": "usd",
              "payment_method_details": { "type": "card", "card": { "brand": "amex", "last4": "0005" } }
            }
          ]
        }
        """.data(using: .utf8)!
    }

    private func decodePage(middleRecord: String) throws -> ChargeList {
        try stripeDecoder().decode(ChargeList.self, from: chargePage(middleRecord: middleRecord))
    }

    func testUnknownPaymentMethodTypeDoesNotAbortThePage() throws {
        let list = try decodePage(middleRecord: """
        {
          "id": "ch_middle",
          "object": "charge",
          "created": 1757404801,
          "currency": "usd",
          "payment_method_details": { "type": "some_future_method" }
        }
        """)

        let data = try XCTUnwrap(list.data)
        XCTAssertEqual(data.map(\.id), ["ch_first", "ch_middle", "ch_last"],
                       "every record in the page must survive one unknown enum value")
        XCTAssertNil(data[1].paymentMethodDetails?.type,
                     "an unrecognised payment method type decodes as nil rather than throwing")
        XCTAssertEqual(data[0].paymentMethodDetails?.type, .card,
                       "the records around the poisoned one keep their decoded values")
        XCTAssertEqual(data[2].paymentMethodDetails?.card?.brand, .amex)
    }

    func testUnknownCardBrandDoesNotAbortThePage() throws {
        let list = try decodePage(middleRecord: """
        {
          "id": "ch_middle",
          "object": "charge",
          "created": 1757404801,
          "currency": "usd",
          "payment_method_details": { "type": "card", "card": { "brand": "elo", "last4": "1234" } }
        }
        """)

        let data = try XCTUnwrap(list.data)
        XCTAssertEqual(data.count, 3)
        XCTAssertEqual(data[1].paymentMethodDetails?.type, .card,
                       "sibling fields on the same record still decode")
        XCTAssertEqual(data[1].paymentMethodDetails?.card?.last4, "1234")
        XCTAssertNil(data[1].paymentMethodDetails?.card?.brand)
    }

    func testUnknownCardPresentReceiptAccountTypeDoesNotAbortThePage() throws {
        let list = try decodePage(middleRecord: """
        {
          "id": "ch_middle",
          "object": "charge",
          "created": 1757404801,
          "currency": "usd",
          "payment_method_details": {
            "type": "card_present",
            "card_present": { "receipt": { "account_type": "some_future_account" } }
          }
        }
        """)

        let data = try XCTUnwrap(list.data)
        XCTAssertEqual(data.count, 3)
        XCTAssertNil(data[1].paymentMethodDetails?.cardPresent?.receipt?.accountType)
    }

    func testUnknownCurrencyPreservesItsRawValue() throws {
        let list = try decodePage(middleRecord: """
        {
          "id": "ch_middle",
          "object": "charge",
          "created": 1757404801,
          "currency": "xbt",
          "payment_method_details": { "type": "card" }
        }
        """)

        let data = try XCTUnwrap(list.data)
        XCTAssertEqual(data.count, 3)
        XCTAssertEqual(data[1].currency?.rawValue, "xbt",
                       "an unmapped currency keeps its raw code so the charge is never relabelled")
        XCTAssertEqual(data[0].currency, .usd, "known currencies are unaffected")
    }

    func testKnownCurrencyRoundTripsUnchanged() throws {
        XCTAssertEqual(Currency.usd.rawValue, "usd")
        XCTAssertEqual(Currency(rawValue: "eur"), .eur)

        let encoded = try JSONEncoder().encode(["currency": Currency.brl])
        XCTAssertEqual(String(data: encoded, encoding: .utf8), #"{"currency":"brl"}"#,
                       "the encoded shape is unchanged, so already-persisted rows keep decoding")
    }

    func testEveryKnownCurrencyRoundTripsThroughItsRawValue() {
        XCTAssertEqual(Currency.allCases.count, 139)

        for currency in Currency.allCases {
            let raw = currency.rawValue
            XCTAssertFalse(raw.isEmpty, "\(currency) has an empty raw value")
            XCTAssertEqual(Currency(rawValue: raw), currency,
                           "\(currency) does not survive a rawValue round trip")
            XCTAssertEqual(String(describing: currency), raw,
                           "\(currency) raw value drifted from its case name, which was the ISO code")

            if case .unrecognized = currency {
                XCTFail("allCases must not contain the unrecognized case")
            }
        }

        XCTAssertEqual(Currency.allCases.map(\.rawValue).count,
                       Set(Currency.allCases.map(\.rawValue)).count,
                       "raw values must be unique")
        XCTAssertEqual(Currency.try.rawValue, "try", "the backticked case keeps its ISO code")
    }

    func testUnrecognizedCurrencyEncodesBackToTheOriginalCode() throws {
        let currency = Currency(rawValue: "xbt")
        XCTAssertEqual(currency, .unrecognized("xbt"))

        let encoded = try JSONEncoder().encode(["currency": currency])
        XCTAssertEqual(String(data: encoded, encoding: .utf8), #"{"currency":"xbt"}"#,
                       "an unmapped code re-encodes verbatim, so a round trip is lossless")
    }

    func testStructurallyBrokenRecordDoesNotAbortThePage() throws {
        let list = try decodePage(middleRecord: """
        {
          "id": 12345,
          "object": "charge",
          "created": 1757404801
        }
        """)

        let data = try XCTUnwrap(list.data)
        XCTAssertEqual(data.map(\.id), ["ch_first", "ch_last"],
                       "the undecodable record is dropped, the healthy ones are kept")
        XCTAssertEqual(list.$data, 1, "the drop must be counted, or a run reports clean while short")
    }

    func testUnknownEnumValueIsReportedWithItsRawValueAndPath() throws {
        let collector = ReportCollector.installed()
        defer { collector.uninstall() }

        _ = try decodePage(middleRecord: """
        {
          "id": "ch_middle",
          "object": "charge",
          "created": 1757404801,
          "currency": "xbt",
          "payment_method_details": { "type": "some_future_method" }
        }
        """)

        let typeReport = try XCTUnwrap(collector.all.first { $0.typeName == "ChargePaymentMethodDetailsType" })
        XCTAssertEqual(typeReport.rawValue, "some_future_method")
        XCTAssertEqual(typeReport.codingPath, "data.Index 1.paymentMethodDetails.type")
        XCTAssertEqual(typeReport.outcome, .unknownValueDecodedAsNil)

        let currencyReport = try XCTUnwrap(collector.all.first { $0.typeName == "Currency" })
        XCTAssertEqual(currencyReport.rawValue, "xbt")
        XCTAssertEqual(currencyReport.outcome, .unknownValueRawPreserved)
    }

    func testDroppedRecordIsReportedRatherThanSilentlyLost() throws {
        let collector = ReportCollector.installed()
        defer { collector.uninstall() }

        _ = try decodePage(middleRecord: """
        { "id": 12345, "object": "charge", "created": 1757404801 }
        """)

        let dropped = try XCTUnwrap(collector.all.first { $0.outcome == .recordDropped })
        XCTAssertEqual(dropped.typeName, "Charge")
        XCTAssertEqual(dropped.codingPath, "data.Index 1",
                       "the report must name which record was dropped, not only the array")
        XCTAssertNotNil(dropped.failureDescription, "a dropped record must carry why it was dropped")
    }

    func testPageWithNoUnknownValuesReportsNothing() throws {
        let collector = ReportCollector.installed()
        defer { collector.uninstall() }

        let list = try decodePage(middleRecord: """
        {
          "id": "ch_middle",
          "object": "charge",
          "created": 1757404801,
          "currency": "eur",
          "payment_method_details": { "type": "paypal" }
        }
        """)

        XCTAssertEqual(try XCTUnwrap(list.data).count, 3)
        XCTAssertEqual(list.$data, 0, "a healthy page drops nothing")
        XCTAssertTrue(collector.all.isEmpty, "a healthy page must stay silent")
    }

    func testAbsentPageDataStaysAbsentThroughARoundTrip() throws {
        let json = #"{"object":"list","has_more":false}"#.data(using: .utf8)!
        let list = try stripeDecoder().decode(ChargeList.self, from: json)
        XCTAssertNil(list.data)

        let reencoded = try JSONEncoder().encode(list)
        let asObject = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: reencoded) as? [String: Any]
        )
        XCTAssertFalse(asObject.keys.contains("data"),
                       "a nil page array is omitted, not encoded as null")
    }

    func testPageWhereEveryRecordFailsStaysLoud() {
        let json = """
        {
          "object": "list",
          "has_more": true,
          "data": [
            { "id": 1, "object": "charge", "created": 1757404800 },
            { "id": 2, "object": "charge", "created": 1757404801 }
          ]
        }
        """.data(using: .utf8)!

        XCTAssertThrowsError(try stripeDecoder().decode(ChargeList.self, from: json),
                             "a total loss must not be reported as an empty but successful page") { error in
            guard let decoding = error as? DecodingError,
                  case .typeMismatch(_, let context) = decoding else {
                return XCTFail("expected the failing element's own DecodingError, got \(error)")
            }
            XCTAssertEqual(context.codingPath.first?.stringValue, "data")
            XCTAssertEqual(context.codingPath.dropFirst().first?.intValue, 0,
                           "the rethrown error must still name which record failed")
            XCTAssertEqual(context.codingPath.last?.stringValue, "id",
                           "and which field on it")
        }
    }

    func testGenuinelyEmptyPageIsNotTreatedAsATotalLoss() throws {
        let json = #"{"object":"list","has_more":false,"data":[]}"#.data(using: .utf8)!
        let list = try stripeDecoder().decode(ChargeList.self, from: json)
        XCTAssertEqual(try XCTUnwrap(list.data).count, 0)
    }

    func testSurvivingRecordKeepsAPageWithOtherTotalFailures() throws {
        let list = try decodePage(middleRecord: #"{ "id": 99, "object": "charge", "created": 1 }"#)
        XCTAssertEqual(try XCTUnwrap(list.data).count, 2, "one good record is enough to keep the page")
        XCTAssertEqual(list.$data, 1, "the dropped record is counted even though the page survived")
    }

    func testUnknownValueInAnEnumArrayDropsOnlyThatValue() throws {
        let json = #"{"payment_method_types":["card","some_future_method","link"]}"#
            .data(using: .utf8)!

        let settings = try stripeDecoder().decode(SubscriptionPaymentSettings.self, from: json)
        XCTAssertEqual(settings.paymentMethodTypes, [.card, .link],
                       "only the unmapped entry is dropped, the order of the rest is kept")
    }

    func testUnknownValueInAnEnumArrayIsReportedWithItsIndex() throws {
        let collector = ReportCollector.installed()
        defer { collector.uninstall() }

        let json = #"{"payment_method_types":["card","some_future_method"]}"#.data(using: .utf8)!
        _ = try stripeDecoder().decode(SubscriptionPaymentSettings.self, from: json)

        let report = try XCTUnwrap(collector.all.first { $0.typeName == "PaymentMethodType" })
        XCTAssertEqual(report.rawValue, "some_future_method")
        XCTAssertEqual(report.codingPath, "paymentMethodTypes.Index 1")
    }

    func testUnknownCheckoutTaxIdTypeDoesNotDropTheRecord() throws {
        let json = """
        {
          "email": "buyer@example.com",
          "tax_ids": [{ "type": "some_future_tax_id", "value": "123" }]
        }
        """.data(using: .utf8)!

        let details = try stripeDecoder().decode(SessionCustomerDetails.self, from: json)
        let taxIds = try XCTUnwrap(details.taxIds)
        XCTAssertEqual(taxIds.count, 1, "the tax id row survives an unmapped type")
        XCTAssertNil(taxIds[0].type)
        XCTAssertEqual(taxIds[0].value, "123")
    }

    func testUnknownCurrencyInAnEnumArrayIsReported() throws {
        let collector = ReportCollector.installed()
        defer { collector.uninstall() }

        let json = #"{"id":"US","object":"country_spec","supported_payment_currencies":["usd","xbt","eur"]}"#
            .data(using: .utf8)!
        let spec = try stripeDecoder().decode(CountrySpec.self, from: json)

        XCTAssertEqual(spec.supportedPaymentCurrencies,
                       [.usd, .unrecognized("xbt"), .eur],
                       "an array element keeps its raw value exactly as a scalar property does")

        let report = try XCTUnwrap(collector.all.first { $0.typeName == "Currency" })
        XCTAssertEqual(report.rawValue, "xbt")
        XCTAssertEqual(report.codingPath, "supportedPaymentCurrencies.Index 1")
        XCTAssertEqual(report.outcome, .unknownValueRawPreserved,
                       "an array element must report the same outcome as a scalar property")
    }

    func testEmbeddedListRejectsABadRecordRatherThanShorteningItself() throws {
        let json = """
        {
          "id": "cus_1",
          "object": "customer",
          "subscriptions": {
            "object": "list",
            "data": [
              { "id": 12345, "object": "subscription" },
              { "id": "sub_ok", "object": "subscription", "created": 1, "automatic_tax": {} }
            ]
          }
        }
        """.data(using: .utf8)!

        XCTAssertThrowsError(try stripeDecoder().decode(Customer.self, from: json)) { error in
            XCTAssertTrue(error is DecodingError,
                          "a relation the caller reads whole must not silently lose a member")
        }
    }

    func testEmbeddedListReportsNothingWhenItRejects() throws {
        let collector = ReportCollector.installed()
        defer { collector.uninstall() }

        let json = """
        {
          "id": "cus_1", "object": "customer",
          "subscriptions": { "object": "list", "data": [{ "id": 12345, "object": "subscription" }] }
        }
        """.data(using: .utf8)!

        _ = try? stripeDecoder().decode(Customer.self, from: json)
        XCTAssertTrue(collector.all.isEmpty,
                      "a rejected list dropped nothing, so it must not report a drop")
    }

    func testPageKeepsGoingWhenAnEmbeddedListRejectsOneRecord() throws {
        let json = """
        {
          "object": "list",
          "data": [
            { "id": "sub_bad", "object": "subscription", "created": 1, "automatic_tax": {},
              "items": { "object": "list", "data": [
                { "id": 1, "object": "subscription_item", "created": 1 },
                { "id": "si_ok", "object": "subscription_item", "created": 1 }
              ] } },
            { "id": "sub_ok", "object": "subscription", "created": 1, "automatic_tax": {} }
          ]
        }
        """.data(using: .utf8)!

        let list = try stripeDecoder().decode(SubscriptionList.self, from: json)
        XCTAssertEqual(try XCTUnwrap(list.data).map(\.id), ["sub_ok"],
                       "the embedded list has a survivor, so only strictness can reject it, "
                           + "and the page drops just that record")
        XCTAssertEqual(list.$data, 1)
    }

    func testPageResponseIsRecognisedByItsCodingPathDepth() {
        XCTAssertTrue(LossyList<Charge>.isPageResponse([LossyListProbeKey("data")]))
        XCTAssertFalse(LossyList<Charge>.isPageResponse([
            LossyListProbeKey("subscriptions"), LossyListProbeKey("data"),
        ]))
        XCTAssertFalse(LossyList<Charge>.isPageResponse([]))
    }

    func testADroppedRecordCarriesTheFailureKindAndTheFieldThatFailed() throws {
        let collector = ReportCollector.installed()
        defer { collector.uninstall() }

        _ = try decodePage(middleRecord: #"{ "id": 12345, "object": "charge", "created": 1 }"#)

        let dropped = try XCTUnwrap(collector.all.first { $0.outcome == .recordDropped })
        XCTAssertEqual(dropped.failureKind, "typeMismatch",
                       "a stable token, not a rendering that differs between Foundations")
        XCTAssertEqual(dropped.failureCodingPath.last, "id",
                       "the path names the field that failed, which the record path cannot")
        XCTAssertTrue(dropped.failureCodingPath.contains("data"))
    }

    func testTheFailurePathMarksWhichSegmentsAreRecordIndices() throws {
        let collector = ReportCollector.installed()
        defer { collector.uninstall() }

        _ = try decodePage(middleRecord: #"{ "id": 12345, "object": "charge", "created": 1 }"#)

        let dropped = try XCTUnwrap(collector.all.first { $0.outcome == .recordDropped })
        let keyed = dropped.failureCodingPath.enumerated()
            .filter { !dropped.failureCodingPathIndices.contains($0.offset) }
            .map(\.element)

        XCTAssertEqual(keyed, ["data", "id"],
                       "dropping the marked positions leaves the shape of the failure, which is "
                       + "what two records broken the same way must share")
        XCTAssertFalse(dropped.failureCodingPathIndices.isEmpty,
                       "and the record index must be marked rather than left for a consumer to "
                       + "guess out of the text")
    }

    func testAKeyNotFoundDropNamesTheMissingKey() throws {
        let collector = ReportCollector.installed()
        defer { collector.uninstall() }

        _ = try decodePage(middleRecord: #"{ "id": "ch_middle", "object": "charge" }"#)

        let dropped = try XCTUnwrap(collector.all.first { $0.outcome == .recordDropped })
        XCTAssertEqual(dropped.failureKind, "keyNotFound")
        XCTAssertEqual(dropped.failureCodingPath.last, "created")
    }

    func testAnUnmappedEnumValueCarriesNoFailureStructure() throws {
        let collector = ReportCollector.installed()
        defer { collector.uninstall() }

        _ = try decodePage(middleRecord: """
        { "id": "ch_middle", "object": "charge", "created": 1, "currency": "usd",
          "payment_method_details": { "type": "some_future_method" } }
        """)

        let report = try XCTUnwrap(collector.all.first { $0.outcome == .unknownValueDecodedAsNil })
        XCTAssertNil(report.failureKind, "nothing failed, so there is no failure to describe")
        XCTAssertTrue(report.failureCodingPath.isEmpty)
    }

    func testAValueNotFoundDropNamesTheFieldThatWasNull() throws {
        let collector = ReportCollector.installed()
        defer { collector.uninstall() }

        _ = try decodePage(middleRecord: #"{ "id": null, "object": "charge", "created": 1 }"#)

        let dropped = try XCTUnwrap(collector.all.first { $0.outcome == .recordDropped })
        XCTAssertEqual(dropped.failureKind, "valueNotFound")
        XCTAssertEqual(dropped.failureCodingPath.last, "id")
    }
}

private struct LossyListProbeKey: CodingKey {
    var stringValue: String
    var intValue: Int? { nil }

    init(_ stringValue: String) { self.stringValue = stringValue }
    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { nil }
}
