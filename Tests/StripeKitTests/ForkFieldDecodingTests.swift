import Foundation
import XCTest
@testable import StripeKit

final class ForkFieldDecodingTests: XCTestCase {

    private func stripeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }

    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try stripeDecoder().decode(type, from: Data(json.utf8))
    }

    func testChargeCardDetailsDecodeIssuerFields() throws {
        let card = try decode(ChargePaymentMethodDetailsCard.self, """
        {
            "brand": "visa",
            "iin": "424242",
            "issuer": "JPMORGAN CHASE BANK N.A. - DEBIT",
            "authorization_code": "A1B2C3",
            "network_transaction_id": "583012345678901"
        }
        """)

        XCTAssertEqual(card.iin, "424242")
        XCTAssertEqual(card.issuer, "JPMORGAN CHASE BANK N.A. - DEBIT")
        XCTAssertEqual(card.authorizationCode, "A1B2C3")
        XCTAssertEqual(card.networkTransactionId, "583012345678901")
    }

    func testRefundDestinationDetailsDecodeEveryCardReferenceField() throws {
        let details = try decode(RefundDestinationDetails.self, """
        {
            "type": "card",
            "card": {
                "reference": "74537604221004010015426",
                "reference_status": "available",
                "reference_type": "acquirer_reference_number",
                "type": "refund"
            }
        }
        """)

        XCTAssertEqual(details.type, "card")
        XCTAssertEqual(details.card?.reference, "74537604221004010015426")
        XCTAssertEqual(details.card?.referenceStatus, "available")
        XCTAssertEqual(details.card?.referenceType, "acquirer_reference_number")
        XCTAssertEqual(details.card?.type, "refund")
    }

    func testDisputePaymentMethodDetailsDecodeCardCaseType() throws {
        let details = try decode(DisputePaymentMethodDetails.self, """
        {
            "type": "card",
            "card": {
                "brand": "visa",
                "case_type": "inquiry",
                "network_reason_code": "10.4"
            }
        }
        """)

        XCTAssertEqual(details.card?.brand, "visa")
        XCTAssertEqual(details.card?.caseType, .inquiry)
        XCTAssertEqual(details.card?.networkReasonCode, "10.4")
    }

    func testDisputeEvidenceDueByZeroDecodesAsNil() throws {
        let details = try decode(DisputeEvidenceDetails.self, """
        {"due_by": 0, "has_evidence": false, "past_due": false, "submission_count": 0}
        """)

        XCTAssertNil(details.dueBy)
        XCTAssertEqual(details.submissionCount, 0)
    }

    func testDisputeEvidenceDueByEpochDecodesAsDate() throws {
        let details = try decode(DisputeEvidenceDetails.self, """
        {"due_by": 1793318400, "has_evidence": true, "past_due": false, "submission_count": 1}
        """)

        XCTAssertEqual(details.dueBy, Date(timeIntervalSince1970: 1793318400))
    }

    func testProductWithoutCreatedDecodes() throws {
        let product = try decode(Product.self, """
        {"id": "prod_123", "object": "product", "name": "Alerts"}
        """)

        XCTAssertEqual(product.id, "prod_123")
        XCTAssertNil(product.created)
    }

    func testInvoiceWithoutCreatedDecodes() throws {
        let invoice = try decode(Invoice.self, """
        {"id": "in_123", "object": "invoice"}
        """)

        XCTAssertEqual(invoice.id, "in_123")
        XCTAssertNil(invoice.created)
    }

    func testRefundDecodesDestinationDetailsUnderItsJSONKey() throws {
        let refund = try decode(Refund.self, """
        {
            "id": "re_123",
            "object": "refund",
            "created": 1692942318,
            "destination_details": {
                "type": "card",
                "card": {
                    "reference": "74537604221004010015426",
                    "reference_status": "available",
                    "reference_type": "acquirer_reference_number",
                    "type": "refund"
                }
            }
        }
        """)

        XCTAssertEqual(refund.destinationDetails?.card?.reference, "74537604221004010015426")
        XCTAssertEqual(refund.destinationDetails?.card?.referenceStatus, "available")
    }

    func testDisputeDecodesPaymentMethodAndEvidenceDetailsUnderTheirJSONKeys() throws {
        let dispute = try decode(Dispute.self, """
        {
            "id": "dp_123",
            "object": "dispute",
            "created": 1692942318,
            "evidence_details": {"due_by": 0, "has_evidence": false, "past_due": false, "submission_count": 0},
            "payment_method_details": {
                "type": "card",
                "card": {"brand": "visa", "case_type": "chargeback", "network_reason_code": "13.1"}
            }
        }
        """)

        XCTAssertEqual(dispute.paymentMethodDetails?.card?.caseType, .chargeback)
        XCTAssertEqual(dispute.paymentMethodDetails?.card?.networkReasonCode, "13.1")
        XCTAssertNotNil(dispute.evidenceDetails)
        XCTAssertNil(dispute.evidenceDetails?.dueBy)
    }

    func testEventRoutesAnEarlyFraudWarningToItsCase() throws {
        let event = try decode(Event.self, """
        {
            "id": "evt_123",
            "object": "event",
            "type": "radar.early_fraud_warning.created",
            "data": {
                "object": {
                    "id": "issfr_123",
                    "object": "radar.early_fraud_warning",
                    "created": 1692942318,
                    "charge": "ch_123",
                    "fraud_type": "unauthorized_use_of_card"
                }
            }
        }
        """)

        XCTAssertEqual(event.type, .radarEarlyFraudWarningCreated)
        guard case .earlyFraudWarning(let warning) = event.data?.object else {
            return XCTFail("expected .earlyFraudWarning, got \(String(describing: event.data?.object))")
        }
        XCTAssertEqual(warning.charge, "ch_123")
    }
}
