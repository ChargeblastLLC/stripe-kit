//
//  TaxID.swift
//  Stripe
//
//  Created by Andrew Edwards on 5/11/19.
//

import Foundation

/// The [Tax ID Object](https://stripe.com/docs/api/customer_tax_ids/object) .
public struct TaxID: Codable {
    /// Unique identifier for the object.
    public var id: String
    /// Two-letter ISO code representing the country of the tax ID.
    public var country: String?
    /// ID of the customer.
    @Expandable<Customer> public var customer: String?
    /// Type of the tax ID.
    public var type: TaxIDType?
    /// Value of the tax ID.
    public var value: String?
    /// String representing the object’s type. Objects of the same type share the same value.
    public var object: String
    /// Time at which the object was created. Measured in seconds since the Unix epoch.
    public var created: Date
    /// Has the value true if the object exists in live mode or the value false if the object exists in test mode.
    public var livemode: Bool?
    /// Tax ID verification information.
    public var verification: TaxIDVerififcation?
    
    public init(id: String,
                country: String? = nil,
                customer: String? = nil,
                type: TaxIDType? = nil,
                value: String? = nil,
                object: String,
                created: Date,
                livemode: Bool? = nil,
                verification: TaxIDVerififcation? = nil) {
        self.id = id
        self.country = country
        self._customer = Expandable(id: customer)
        self.type = type
        self.value = value
        self.object = object
        self.created = created
        self.livemode = livemode
        self.verification = verification
    }
}

public enum TaxIDType: String, Codable {
    case aeTrn = "ae_trn"
    case auAbn = "au_abn"
    case auArn = "au_arn"
    case bgUic = "bg_uic"
    case brCnpj = "br_cnpj"
    case brCpf = "br_cpf"
    case caBn = "ca_bn"
    case caGstHst = "ca_gst_hst"
    case caPstBc = "ca_pst_bc"
    case caPstMb = "ca_pst_mb"
    case caPstSk = "ca_pst_sk"
    case caQst = "ca_qst"
    case chVat = "ch_vat"
    case clTin = "cl_tin"
    case egTin = "eg_tin"
    case esCif = "es_cif"
    case euOssVat = "eu_oss_vat"
    case euVat = "eu_vat"
    case gbVat = "gb_vat"
    case geVat = "ge_vat"
    case hkBr = "hk_br"
    case huTin = "hu_tin"
    case idNpwp = "id_npwp"
    case ilVat = "il_vat"
    case inGst = "in_gst"
    case isVat = "is_vat"
    case jpCn = "jp_cn"
    case jpRn = "jp_rn"
    case jpTrn = "jp_trn"
    case kePin = "ke_pin"
    case krBrn = "kr_brn"
    case liUid = "li_uid"
    case mxRfc = "mx_rfc"
    case myFrp = "my_frp"
    case myItn = "my_itn"
    case mySst = "my_sst"
    case noVat = "no_vat"
    case nzGst = "nz_gst"
    case phTin = "ph_tin"
    case ruInn = "ru_inn"
    case ruKpp = "ru_kpp"
    case saVat = "sa_vat"
    case sgGst = "sg_gst"
    case sgUen = "sg_uen"
    case siTin = "si_tin"
    case thVat = "th_vat"
    case trTin = "tr_tin"
    case twVat = "tw_vat"
    case uaVat = "ua_vat"
    case usEin = "us_ein"
    case zaVat = "za_vat"
    case ngTin = "ng_tin"
    case vnTin = "vn_tin"
    case rsPib = "rs_pib"
    case coNit = "co_nit"
    case arCuit = "ar_cuit"
    case crTin = "cr_tin"
    case kzBin = "kz_bin"
    case cnTin = "cn_tin"
    case doRcn = "do_rcn"
    case roTin = "ro_tin"
    case ecRuc = "ec_ruc"
    case veRif = "ve_rif"
    case adNrt = "ad_nrt"
    case bhVat = "bh_vat"
    case boTin = "bo_tin"
    case chUid = "ch_uid"
    case deStn = "de_stn"
    case noVoec = "no_voec"
    case omVat = "om_vat"
    case peRuc = "pe_ruc"
    case svNit = "sv_nit"
    case uyRuc = "uy_ruc"
    case uzVat = "uz_vat"
    case ugTin = "ug_tin"
    case mkVat = "mk_vat"
    case mdVat = "md_vat"
    case maVat = "ma_vat"
    case khTin = "kh_tin"
    case hrOib = "hr_oib"
    case aoTin = "ao_tin"
    case alTin = "al_tin"
    case unknown
}

public struct TaxIDVerififcation: Codable {
    /// Verification status, one of `pending`, `unavailable`, `unverified`, or `verified`.
    public var status: TaxIDVerififcationStatus?
    /// Verified address.
    public var verifiedAddress: String?
    /// Verified name.
    public var verifiedName: String?
    
    public init(status: TaxIDVerififcationStatus? = nil,
                verifiedAddress: String? = nil,
                verifiedName: String? = nil) {
        self.status = status
        self.verifiedAddress = verifiedAddress
        self.verifiedName = verifiedName
    }
}

public enum TaxIDVerififcationStatus: String, Codable {
    case pending
    case unavailable
    case unverified
    case verified
}

public struct TaxIDList: Codable {
    public var object: String
    public var url: String?
    public var hasMore: Bool?
    public var data: [TaxID]?
    
    public init(object: String,
                url: String? = nil,
                hasMore: Bool? = nil,
                data: [TaxID]? = nil) {
        self.object = object
        self.url = url
        self.hasMore = hasMore
        self.data = data
    }
}
