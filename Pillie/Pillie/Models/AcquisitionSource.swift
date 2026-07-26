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
        case .tiktok: return PillieLocalization.string("onboarding.acquisition.tiktok")
        case .instagram: return PillieLocalization.string("onboarding.acquisition.instagram")
        case .appStoreSearch: return PillieLocalization.string("onboarding.acquisition.app_store")
        case .friendOrWordOfMouth: return PillieLocalization.string("onboarding.acquisition.friend")
        case .reddit: return PillieLocalization.string("onboarding.acquisition.reddit")
        case .other: return PillieLocalization.string("onboarding.acquisition.other")
        }
    }
}
