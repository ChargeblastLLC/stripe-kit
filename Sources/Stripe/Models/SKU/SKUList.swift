//
//  SKUList.swift
//  Stripe
//
//  Created by Andrew Edwards on 8/22/17.
//
//

/**
 SKU List
 https://stripe.com/docs/api/curl#list_skus
 */

public struct SKUList: List, StripeModelProtocol {
    public var object: String?
    public var hasMore: Bool?
    public var totalCount: Int?
    public var url: String?
    public var items: [StripeSKU]?
    
    enum CodingKeys: String, CodingKey {
        case object
        case hasMore = "has_more"
        case totalCount = "total_count"
        case url
        case items = "data"
    }
}
