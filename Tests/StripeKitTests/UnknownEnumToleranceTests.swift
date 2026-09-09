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

    // Production path: DecodingError(dataCorrupted) at data.Index N.paymentMethodDetails.type
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

    // Production path: DecodingError(dataCorrupted) at data.Index N.paymentMethodDetails.card.brand (SOL-7 "elo")
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

    // Production path: DecodingError(dataCorrupted) at data.Index N.paymentMethodDetails.cardPresent.receipt.accountType
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

    // Currency is money, so the raw value must survive onto the record, not decode to nil.
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

    // A record that fails for a NON-enum reason must not abort the rest of the page either.
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
        XCTAssertNotNil(dropped.underlyingError, "a dropped record must carry why it was dropped")
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
}
