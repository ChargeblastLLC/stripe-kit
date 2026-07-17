//
//  Dispute.swift
//  Stripe
//
//  Created by Andrew Edwards on 7/11/17.
//
//

import Foundation

/// The [Dispute Object](https://stripe.com/docs/api/disputes/object)
public struct Dispute: Codable {
    /// Unique identifier for the object.
    public var id: String
    /// Disputed amount. Usually the amount of the charge, but can differ (usually because of currency fluctuation or because only part of the order is disputed).
    public var amount: Int?
    /// ID of the charge that was disputed.
    @Expandable<Charge> public var charge: String?
    /// Three-letter ISO currency code, in lowercase. Must be a supported currency.
    public var currency: Currency?
    /// Evidence provided to respond to a dispute. Updating any field in the hash will submit all fields in the hash for review.
    public var evidence: DisputeEvidence?
    /// Set of key-value pairs that you can attach to an object. This can be useful for storing additional information about the object in a structured format.
    public var metadata: [String: String]?
    /// ID of the PaymentIntent that was disputed.
    @Expandable<PaymentIntent> public var paymentIntent: String?
    /// Reason given by cardholder for dispute. Possible values are `bank_cannot_process`, `check_returned`, `credit_not_processed`, `customer_initiated`, `debit_not_authorized`, `duplicate`, `fraudulent`, `general`, `incorrect_account_details`, `insufficient_funds`, `product_not_received`, `product_unacceptable`, `subscription_canceled`, or `unrecognized`. Read more about [dispute reasons](https://stripe.com/docs/disputes/categories).
    public var reason: DisputeReason?
    /// Current status of dispute. Possible values are `warning_needs_response`, `warning_under_review`, `warning_closed`, `needs_response`, `under_review`, `charge_refunded`, `won`, or `lost`.
    public var status: DisputeStatus?
    /// String representing the object’s type. Objects of the same type share the same value.
    public var object: String
    /// List of zero, one, or two balance transactions that show funds withdrawn and reinstated to your Stripe account as a result of this dispute.
    public var balanceTransactions: [BalanceTransaction]?
    /// Time at which the object was created. Measured in seconds since the Unix epoch.
    public var created: Date
    /// Information about the evidence submission.
    public var evidenceDetails: DisputeEvidenceDetails?
    /// If true, it is still possible to refund the disputed payment. Once the payment has been fully refunded, no further funds will be withdrawn from your Stripe account as a result of this dispute.
    public var isChargeRefundable: Bool?
    /// Has the value `true` if the object exists in live mode or the value `false` if the object exists in test mode.
    public var livemode: Bool?
    /// Additional dispute details specific to the payment method type.
    public var paymentMethodDetails: DisputePaymentMethodDetails?
    
    public init(id: String,
                amount: Int? = nil,
                charge: String? = nil,
                currency: Currency? = nil,
                evidence: DisputeEvidence? = nil,
                metadata: [String : String]? = nil,
                paymentIntent: String? = nil,
                reason: DisputeReason? = nil,
                status: DisputeStatus? = nil,
                object: String,
                balanceTransactions: [BalanceTransaction]? = nil,
                created: Date,
                evidenceDetails: DisputeEvidenceDetails? = nil,
                isChargeRefundable: Bool? = nil,
                livemode: Bool? = nil,
                paymentMethodDetails: DisputePaymentMethodDetails? = nil) {
        self.id = id
        self.amount = amount
        self._charge = Expandable(id: charge)
        self.currency = currency
        self.evidence = evidence
        self.metadata = metadata
        self._paymentIntent = Expandable(id: paymentIntent)
        self.reason = reason
        self.status = status
        self.object = object
        self.balanceTransactions = balanceTransactions
        self.created = created
        self.evidenceDetails = evidenceDetails
        self.isChargeRefundable = isChargeRefundable
        self.livemode = livemode
        self.paymentMethodDetails = paymentMethodDetails
    }
}

public struct DisputeEvidenceDetails: Codable {
    /// Date by which evidence must be submitted in order to successfully challenge dispute.
    /// Stripe may return `0` when no deadline applies — that is normalized to `nil`.
    public var dueBy: Date?
    /// Whether evidence has been staged for this dispute.
    public var hasEvidence: Bool?
    /// Whether the last evidence submission was submitted past the due date. Defaults to `false` if no evidence submissions have occurred. If `true`, then delivery of the latest evidence is not guaranteed.
    public var pastDue: Bool?
    /// The number of times evidence has been submitted. Typically, you may only submit evidence once.
    public var submissionCount: Int?
    
    public init(dueBy: Date? = nil,
                hasEvidence: Bool? = nil,
                pastDue: Bool? = nil,
                submissionCount: Int? = nil) {
        self.dueBy = Self.normalizedDueBy(dueBy)
        self.hasEvidence = hasEvidence
        self.pastDue = pastDue
        self.submissionCount = submissionCount
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // Decode as epoch seconds so `due_by: 0` can be treated as "no deadline"
        // (JSONDecoder's `.secondsSince1970` would otherwise yield 1970-01-01).
        if let epoch = try container.decodeIfPresent(Double.self, forKey: .dueBy), epoch > 0 {
            dueBy = Date(timeIntervalSince1970: epoch)
        } else {
            dueBy = nil
        }
        hasEvidence = try container.decodeIfPresent(Bool.self, forKey: .hasEvidence)
        pastDue = try container.decodeIfPresent(Bool.self, forKey: .pastDue)
        submissionCount = try container.decodeIfPresent(Int.self, forKey: .submissionCount)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if let dueBy {
            try container.encode(dueBy.timeIntervalSince1970, forKey: .dueBy)
        }
        try container.encodeIfPresent(hasEvidence, forKey: .hasEvidence)
        try container.encodeIfPresent(pastDue, forKey: .pastDue)
        try container.encodeIfPresent(submissionCount, forKey: .submissionCount)
    }

    /// Stripe sends `due_by: 0` when evidence is not accepted / no deadline — treat as nil.
    public static func normalizedDueBy(_ date: Date?) -> Date? {
        guard let date, date.timeIntervalSince1970 > 0 else { return nil }
        return date
    }

    private enum CodingKeys: String, CodingKey {
        case dueBy
        case hasEvidence
        case pastDue
        case submissionCount
    }
}

/// Additional dispute information specific to the payment method type.
/// See [payment_method_details](https://docs.stripe.com/api/disputes/object#dispute_object-payment_method_details).
public struct DisputePaymentMethodDetails: Codable {
    /// Card-specific dispute details.
    public var card: DisputePaymentMethodDetailsCard?
    /// Amazon Pay specific dispute details.
    public var amazonPay: DisputePaymentMethodDetailsAmazonPay?
    /// Klarna specific dispute details.
    public var klarna: DisputePaymentMethodDetailsKlarna?
    /// PayPal specific dispute details.
    public var paypal: DisputePaymentMethodDetailsPaypal?
    /// Payment method type.
    public var type: DisputePaymentMethodDetailsType?
    
    public init(card: DisputePaymentMethodDetailsCard? = nil,
                amazonPay: DisputePaymentMethodDetailsAmazonPay? = nil,
                klarna: DisputePaymentMethodDetailsKlarna? = nil,
                paypal: DisputePaymentMethodDetailsPaypal? = nil,
                type: DisputePaymentMethodDetailsType? = nil) {
        self.card = card
        self.amazonPay = amazonPay
        self.klarna = klarna
        self.paypal = paypal
        self.type = type
    }
}

public struct DisputePaymentMethodDetailsCard: Codable {
    /// Card brand. Can be `amex`, `cartes_bancaires`, `diners`, `discover`, `eftpos_au`, `jcb`, `link`, `mastercard`, `unionpay`, `visa` or `unknown`.
    public var brand: String?
    /// The type of dispute opened. Possible values are `block`, `chargeback`, `compliance`, `inquiry`, or `resolution`.
    public var caseType: DisputeCardCaseType?
    /// The card network’s specific dispute reason code.
    public var networkReasonCode: String?
    
    public init(brand: String? = nil,
                caseType: DisputeCardCaseType? = nil,
                networkReasonCode: String? = nil) {
        self.brand = brand
        self.caseType = caseType
        self.networkReasonCode = networkReasonCode
    }
}

/// Card dispute case type (`payment_method_details.card.case_type`).
public enum DisputeCardCaseType: String, Codable {
    /// A dispute opened by a cardholder that the card network blocked before it could become a chargeback.
    case block
    /// The action taken by a cardholder’s bank to debit a business’s account in response to a dispute from the cardholder.
    case chargeback
    /// An action taken by the card network when they believe the merchant does not conform to network rules.
    case compliance
    /// A pre-dispute request from a card issuer (also called retrievals / RFIs). May escalate to a chargeback.
    case inquiry
    /// A dispute opened by a cardholder that was resolved (refunded) before it could become a chargeback.
    case resolution
}

public struct DisputePaymentMethodDetailsAmazonPay: Codable {
    /// The Amazon Pay dispute type, `chargeback` or `claim`.
    public var disputeType: String?
    
    public init(disputeType: String? = nil) {
        self.disputeType = disputeType
    }
}

public struct DisputePaymentMethodDetailsKlarna: Codable {
    /// Chargeback loss reason mapped by Stripe from Klarna’s chargeback loss reason.
    public var chargebackLossReasonCode: String?
    /// The reason for the dispute as defined by Klarna.
    public var reasonCode: String?
    
    public init(chargebackLossReasonCode: String? = nil,
                reasonCode: String? = nil) {
        self.chargebackLossReasonCode = chargebackLossReasonCode
        self.reasonCode = reasonCode
    }
}

public struct DisputePaymentMethodDetailsPaypal: Codable {
    /// The ID of the dispute in PayPal.
    public var caseId: String?
    /// The reason for the dispute as defined by PayPal.
    public var reasonCode: String?
    
    public init(caseId: String? = nil,
                reasonCode: String? = nil) {
        self.caseId = caseId
        self.reasonCode = reasonCode
    }
}

public enum DisputePaymentMethodDetailsType: String, Codable {
    case card
    case amazonPay = "amazon_pay"
    case klarna
    case paypal
}

public enum DisputeReason: String, Codable {
    case bankCannotProcess = "bank_cannot_process"
    case checkReturned = "check_returned"
    case creditNotProcessed = "credit_not_processed"
    case customerInitiated = "customer_initiated"
    case debitNotAuthorized = "debit_not_authorized"
    case duplicate
    case fraudulent
    case general
    case incorrectAccountDetails = "incorrect_account_details"
    case insufficientFunds = "insufficient_funds"
    case productNotReceived = "product_not_received"
    case productUnacceptable = "product_unacceptable"
    case subscriptionCanceled = "subscription_canceled"
    case unrecognized
    case noncompliant = "noncompliant"
}

public enum DisputeStatus: String, Codable {
    case warningNeedsResponse = "warning_needs_response"
    case warningUnderReview = "warning_under_review"
    case warningClosed = "warning_closed"
    case needsResponse = "needs_response"
    case underReview = "under_review"
    case chargeRefunded = "charge_refunded"
    case won
    case lost
    case protected
    case prevented
}

public struct DisputeList: Codable {
    public var object: String
    public var hasMore: Bool?
    public var url: String?
    public var data: [Dispute]?
}
