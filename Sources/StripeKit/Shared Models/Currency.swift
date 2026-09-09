//
//  Currency.swift
//  Stripe
//
//  Created by Anthony Castelli on 4/14/17.
//
//

public enum Currency: RawRepresentable, Codable, Hashable, CaseIterable, Sendable {
    case usd
    case aed
    case afn
    case all
    case amd
    case ang
    case aoa
    case ars
    case aud
    case awg
    case azn
    case bam
    case bbd
    case bdt
    case bgn
    case bif
    case bmd
    case bnd
    case bob
    case brl
    case bsd
    case bwp
    case byn
    case bzd
    case cad
    case cdf
    case chf
    case clp
    case cny
    case cop
    case crc
    case cve
    case czk
    case djf
    case dkk
    case dop
    case dzd
    case egp
    case etb
    case eur
    case fjd
    case fkp
    case gbp
    case gel
    case gip
    case gmd
    case gnf
    case gtq
    case gyd
    case hkd
    case hnl
    case hrk
    case htg
    case huf
    case idr
    case ils
    case inr
    case isk
    case jmd
    case jpy
    case kes
    case kgs
    case khr
    case kmf
    case krw
    case kyd
    case kwd
    case kzt
    case lak
    case lbp
    case lkr
    case lrd
    case lsl
    case mad
    case mdl
    case mga
    case mkd
    case mmk
    case mnt
    case mop
    case mro
    case mur
    case mvr
    case mwk
    case mxn
    case myr
    case mzn
    case nad
    case ngn
    case nio
    case nok
    case npr
    case nzd
    case omr
    case pab
    case pen
    case pgk
    case php
    case pkr
    case pln
    case pyg
    case qar
    case ron
    case rsd
    case rub
    case rwf
    case sar
    case sbd
    case scr
    case sek
    case sgd
    case shp
    case sll
    case sos
    case srd
    case std
    case szl
    case thb
    case tjs
    case top
    case `try`
    case ttd
    case twd
    case tzs
    case uah
    case ugx
    case uyu
    case uzs
    case vnd
    case vuv
    case wst
    case xaf
    case xcd
    case xof
    case xpf
    case yer
    case zar
    case zmw
    case xcg
    case unrecognized(String)

    public static let allCases: [Currency] = [
        .usd, .aed, .afn, .all, .amd, .ang, .aoa, .ars,
        .aud, .awg, .azn, .bam, .bbd, .bdt, .bgn, .bif,
        .bmd, .bnd, .bob, .brl, .bsd, .bwp, .byn, .bzd,
        .cad, .cdf, .chf, .clp, .cny, .cop, .crc, .cve,
        .czk, .djf, .dkk, .dop, .dzd, .egp, .etb, .eur,
        .fjd, .fkp, .gbp, .gel, .gip, .gmd, .gnf, .gtq,
        .gyd, .hkd, .hnl, .hrk, .htg, .huf, .idr, .ils,
        .inr, .isk, .jmd, .jpy, .kes, .kgs, .khr, .kmf,
        .krw, .kyd, .kwd, .kzt, .lak, .lbp, .lkr, .lrd,
        .lsl, .mad, .mdl, .mga, .mkd, .mmk, .mnt, .mop,
        .mro, .mur, .mvr, .mwk, .mxn, .myr, .mzn, .nad,
        .ngn, .nio, .nok, .npr, .nzd, .omr, .pab, .pen,
        .pgk, .php, .pkr, .pln, .pyg, .qar, .ron, .rsd,
        .rub, .rwf, .sar, .sbd, .scr, .sek, .sgd, .shp,
        .sll, .sos, .srd, .std, .szl, .thb, .tjs, .top,
        .`try`, .ttd, .twd, .tzs, .uah, .ugx, .uyu, .uzs,
        .vnd, .vuv, .wst, .xaf, .xcd, .xof, .xpf, .yer,
        .zar, .zmw, .xcg
    ]

    public init(rawValue: String) {
        switch rawValue {
        case "usd": self = .usd
        case "aed": self = .aed
        case "afn": self = .afn
        case "all": self = .all
        case "amd": self = .amd
        case "ang": self = .ang
        case "aoa": self = .aoa
        case "ars": self = .ars
        case "aud": self = .aud
        case "awg": self = .awg
        case "azn": self = .azn
        case "bam": self = .bam
        case "bbd": self = .bbd
        case "bdt": self = .bdt
        case "bgn": self = .bgn
        case "bif": self = .bif
        case "bmd": self = .bmd
        case "bnd": self = .bnd
        case "bob": self = .bob
        case "brl": self = .brl
        case "bsd": self = .bsd
        case "bwp": self = .bwp
        case "byn": self = .byn
        case "bzd": self = .bzd
        case "cad": self = .cad
        case "cdf": self = .cdf
        case "chf": self = .chf
        case "clp": self = .clp
        case "cny": self = .cny
        case "cop": self = .cop
        case "crc": self = .crc
        case "cve": self = .cve
        case "czk": self = .czk
        case "djf": self = .djf
        case "dkk": self = .dkk
        case "dop": self = .dop
        case "dzd": self = .dzd
        case "egp": self = .egp
        case "etb": self = .etb
        case "eur": self = .eur
        case "fjd": self = .fjd
        case "fkp": self = .fkp
        case "gbp": self = .gbp
        case "gel": self = .gel
        case "gip": self = .gip
        case "gmd": self = .gmd
        case "gnf": self = .gnf
        case "gtq": self = .gtq
        case "gyd": self = .gyd
        case "hkd": self = .hkd
        case "hnl": self = .hnl
        case "hrk": self = .hrk
        case "htg": self = .htg
        case "huf": self = .huf
        case "idr": self = .idr
        case "ils": self = .ils
        case "inr": self = .inr
        case "isk": self = .isk
        case "jmd": self = .jmd
        case "jpy": self = .jpy
        case "kes": self = .kes
        case "kgs": self = .kgs
        case "khr": self = .khr
        case "kmf": self = .kmf
        case "krw": self = .krw
        case "kyd": self = .kyd
        case "kwd": self = .kwd
        case "kzt": self = .kzt
        case "lak": self = .lak
        case "lbp": self = .lbp
        case "lkr": self = .lkr
        case "lrd": self = .lrd
        case "lsl": self = .lsl
        case "mad": self = .mad
        case "mdl": self = .mdl
        case "mga": self = .mga
        case "mkd": self = .mkd
        case "mmk": self = .mmk
        case "mnt": self = .mnt
        case "mop": self = .mop
        case "mro": self = .mro
        case "mur": self = .mur
        case "mvr": self = .mvr
        case "mwk": self = .mwk
        case "mxn": self = .mxn
        case "myr": self = .myr
        case "mzn": self = .mzn
        case "nad": self = .nad
        case "ngn": self = .ngn
        case "nio": self = .nio
        case "nok": self = .nok
        case "npr": self = .npr
        case "nzd": self = .nzd
        case "omr": self = .omr
        case "pab": self = .pab
        case "pen": self = .pen
        case "pgk": self = .pgk
        case "php": self = .php
        case "pkr": self = .pkr
        case "pln": self = .pln
        case "pyg": self = .pyg
        case "qar": self = .qar
        case "ron": self = .ron
        case "rsd": self = .rsd
        case "rub": self = .rub
        case "rwf": self = .rwf
        case "sar": self = .sar
        case "sbd": self = .sbd
        case "scr": self = .scr
        case "sek": self = .sek
        case "sgd": self = .sgd
        case "shp": self = .shp
        case "sll": self = .sll
        case "sos": self = .sos
        case "srd": self = .srd
        case "std": self = .std
        case "szl": self = .szl
        case "thb": self = .thb
        case "tjs": self = .tjs
        case "top": self = .top
        case "try": self = .`try`
        case "ttd": self = .ttd
        case "twd": self = .twd
        case "tzs": self = .tzs
        case "uah": self = .uah
        case "ugx": self = .ugx
        case "uyu": self = .uyu
        case "uzs": self = .uzs
        case "vnd": self = .vnd
        case "vuv": self = .vuv
        case "wst": self = .wst
        case "xaf": self = .xaf
        case "xcd": self = .xcd
        case "xof": self = .xof
        case "xpf": self = .xpf
        case "yer": self = .yer
        case "zar": self = .zar
        case "zmw": self = .zmw
        case "xcg": self = .xcg
        default: self = .unrecognized(rawValue)
        }
    }

    public var rawValue: String {
        switch self {
        case .usd: return "usd"
        case .aed: return "aed"
        case .afn: return "afn"
        case .all: return "all"
        case .amd: return "amd"
        case .ang: return "ang"
        case .aoa: return "aoa"
        case .ars: return "ars"
        case .aud: return "aud"
        case .awg: return "awg"
        case .azn: return "azn"
        case .bam: return "bam"
        case .bbd: return "bbd"
        case .bdt: return "bdt"
        case .bgn: return "bgn"
        case .bif: return "bif"
        case .bmd: return "bmd"
        case .bnd: return "bnd"
        case .bob: return "bob"
        case .brl: return "brl"
        case .bsd: return "bsd"
        case .bwp: return "bwp"
        case .byn: return "byn"
        case .bzd: return "bzd"
        case .cad: return "cad"
        case .cdf: return "cdf"
        case .chf: return "chf"
        case .clp: return "clp"
        case .cny: return "cny"
        case .cop: return "cop"
        case .crc: return "crc"
        case .cve: return "cve"
        case .czk: return "czk"
        case .djf: return "djf"
        case .dkk: return "dkk"
        case .dop: return "dop"
        case .dzd: return "dzd"
        case .egp: return "egp"
        case .etb: return "etb"
        case .eur: return "eur"
        case .fjd: return "fjd"
        case .fkp: return "fkp"
        case .gbp: return "gbp"
        case .gel: return "gel"
        case .gip: return "gip"
        case .gmd: return "gmd"
        case .gnf: return "gnf"
        case .gtq: return "gtq"
        case .gyd: return "gyd"
        case .hkd: return "hkd"
        case .hnl: return "hnl"
        case .hrk: return "hrk"
        case .htg: return "htg"
        case .huf: return "huf"
        case .idr: return "idr"
        case .ils: return "ils"
        case .inr: return "inr"
        case .isk: return "isk"
        case .jmd: return "jmd"
        case .jpy: return "jpy"
        case .kes: return "kes"
        case .kgs: return "kgs"
        case .khr: return "khr"
        case .kmf: return "kmf"
        case .krw: return "krw"
        case .kyd: return "kyd"
        case .kwd: return "kwd"
        case .kzt: return "kzt"
        case .lak: return "lak"
        case .lbp: return "lbp"
        case .lkr: return "lkr"
        case .lrd: return "lrd"
        case .lsl: return "lsl"
        case .mad: return "mad"
        case .mdl: return "mdl"
        case .mga: return "mga"
        case .mkd: return "mkd"
        case .mmk: return "mmk"
        case .mnt: return "mnt"
        case .mop: return "mop"
        case .mro: return "mro"
        case .mur: return "mur"
        case .mvr: return "mvr"
        case .mwk: return "mwk"
        case .mxn: return "mxn"
        case .myr: return "myr"
        case .mzn: return "mzn"
        case .nad: return "nad"
        case .ngn: return "ngn"
        case .nio: return "nio"
        case .nok: return "nok"
        case .npr: return "npr"
        case .nzd: return "nzd"
        case .omr: return "omr"
        case .pab: return "pab"
        case .pen: return "pen"
        case .pgk: return "pgk"
        case .php: return "php"
        case .pkr: return "pkr"
        case .pln: return "pln"
        case .pyg: return "pyg"
        case .qar: return "qar"
        case .ron: return "ron"
        case .rsd: return "rsd"
        case .rub: return "rub"
        case .rwf: return "rwf"
        case .sar: return "sar"
        case .sbd: return "sbd"
        case .scr: return "scr"
        case .sek: return "sek"
        case .sgd: return "sgd"
        case .shp: return "shp"
        case .sll: return "sll"
        case .sos: return "sos"
        case .srd: return "srd"
        case .std: return "std"
        case .szl: return "szl"
        case .thb: return "thb"
        case .tjs: return "tjs"
        case .top: return "top"
        case .`try`: return "try"
        case .ttd: return "ttd"
        case .twd: return "twd"
        case .tzs: return "tzs"
        case .uah: return "uah"
        case .ugx: return "ugx"
        case .uyu: return "uyu"
        case .uzs: return "uzs"
        case .vnd: return "vnd"
        case .vuv: return "vuv"
        case .wst: return "wst"
        case .xaf: return "xaf"
        case .xcd: return "xcd"
        case .xof: return "xof"
        case .xpf: return "xpf"
        case .yer: return "yer"
        case .zar: return "zar"
        case .zmw: return "zmw"
        case .xcg: return "xcg"
        case .unrecognized(let value): return value
        }
    }

    public init(from decoder: Decoder) throws {
        let rawValue = try decoder.singleValueContainer().decode(String.self)
        self.init(rawValue: rawValue)

        if case .unrecognized = self {
            StripeDecodingDiagnostics.report(
                StripeDecodingReport(typeName: "Currency",
                                     rawValue: rawValue,
                                     codingPath: decoder.codingPath,
                                     outcome: .unknownValueRawPreserved)
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}
