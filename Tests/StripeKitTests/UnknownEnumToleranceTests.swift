import XCTest
@testable import StripeKit

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
    }

    func testUnknownEnumValueIsReportedWithItsRawValueAndPath() throws {
        var reports: [StripeDecodingReport] = []
        StripeDecodingDiagnostics.handler = { reports.append($0) }
        defer { StripeDecodingDiagnostics.handler = nil }

        _ = try decodePage(middleRecord: """
        {
          "id": "ch_middle",
          "object": "charge",
          "created": 1757404801,
          "currency": "xbt",
          "payment_method_details": { "type": "some_future_method" }
        }
        """)

        let typeReport = try XCTUnwrap(reports.first { $0.typeName == "ChargePaymentMethodDetailsType" })
        XCTAssertEqual(typeReport.rawValue, "some_future_method")
        XCTAssertEqual(typeReport.codingPath, "data.Index 1.paymentMethodDetails.type")
        guard case .unknownValueDecodedAsNil = typeReport.outcome else {
            return XCTFail("expected the payment method type to decode as nil")
        }

        let currencyReport = try XCTUnwrap(reports.first { $0.typeName == "Currency" })
        XCTAssertEqual(currencyReport.rawValue, "xbt")
        guard case .unknownValueRawPreserved = currencyReport.outcome else {
            return XCTFail("expected the currency raw value to be preserved")
        }
    }

    func testDroppedRecordIsReportedRatherThanSilentlyLost() throws {
        var reports: [StripeDecodingReport] = []
        StripeDecodingDiagnostics.handler = { reports.append($0) }
        defer { StripeDecodingDiagnostics.handler = nil }

        _ = try decodePage(middleRecord: """
        { "id": 12345, "object": "charge", "created": 1757404801 }
        """)

        let dropped = try XCTUnwrap(reports.first { report in
            if case .recordDropped = report.outcome { return true }
            return false
        })
        XCTAssertEqual(dropped.typeName, "Charge")
        XCTAssertEqual(dropped.codingPath, "data.Index 1",
                       "the report must name which record was dropped, not only the array")
        XCTAssertNotNil(dropped.failureDescription, "a dropped record must carry why it was dropped")
    }

    func testPageWithNoUnknownValuesReportsNothing() throws {
        var reports: [StripeDecodingReport] = []
        StripeDecodingDiagnostics.handler = { reports.append($0) }
        defer { StripeDecodingDiagnostics.handler = nil }

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
        XCTAssertTrue(reports.isEmpty, "a healthy page must stay silent")
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
                             "a total loss must not be reported as an empty but successful page")
    }

    func testGenuinelyEmptyPageIsNotTreatedAsATotalLoss() throws {
        let json = #"{"object":"list","has_more":false,"data":[]}"#.data(using: .utf8)!
        let list = try stripeDecoder().decode(ChargeList.self, from: json)
        XCTAssertEqual(try XCTUnwrap(list.data).count, 0)
    }

    func testSurvivingRecordKeepsAPageWithOtherTotalFailures() throws {
        let list = try decodePage(middleRecord: #"{ "id": 99, "object": "charge", "created": 1 }"#)
        XCTAssertEqual(try XCTUnwrap(list.data).count, 2, "one good record is enough to keep the page")
    }

    func testUnknownValueInAnEnumArrayDropsOnlyThatValue() throws {
        let json = #"{"payment_method_types":["card","some_future_method","link"]}"#
            .data(using: .utf8)!

        let settings = try stripeDecoder().decode(SubscriptionPaymentSettings.self, from: json)
        XCTAssertEqual(settings.paymentMethodTypes, [.card, .link],
                       "only the unmapped entry is dropped, the order of the rest is kept")
    }

    func testUnknownValueInAnEnumArrayIsReportedWithItsIndex() throws {
        var reports: [StripeDecodingReport] = []
        StripeDecodingDiagnostics.handler = { reports.append($0) }
        defer { StripeDecodingDiagnostics.handler = nil }

        let json = #"{"payment_method_types":["card","some_future_method"]}"#.data(using: .utf8)!
        _ = try stripeDecoder().decode(SubscriptionPaymentSettings.self, from: json)

        let report = try XCTUnwrap(reports.first { $0.typeName == "PaymentMethodType" })
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
}
