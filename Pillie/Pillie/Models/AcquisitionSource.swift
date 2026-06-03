//
//  AcquisitionSource.swift
//  Pillie
//

import Foundation

enum AcquisitionSource: String, CaseIterable, Hashable, Identifiable {
    case tiktok
    case instagram
    case appStoreSearch
    case friendOrWordOfMouth
    case reddit
    case other

    static let allCases: [AcquisitionSource] = [
        .tiktok,
        .instagram,
        .appStoreSearch,
        .reddit,
        .other
    ]

    var id: String { rawValue }

    var title: String {
        switch self {
        case .tiktok: return "TikTok"
        case .instagram: return "Instagram"
        case .appStoreSearch: return "App Store search"
        case .friendOrWordOfMouth: return "Friend or word of mouth"
        case .reddit: return "Reddit"
        case .other: return "Other"
        }
    }
}
