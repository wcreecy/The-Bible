import SwiftUI
import UIKit

enum AppIconChoice: String, CaseIterable, Identifiable {
    case defaultIcon
    case clouds = "AppIconClouds"
    case bible = "AppIconBible"
    case blue = "AppIconBlue"
    case green = "AppIconGreen"
    case orangeStripe = "AppIconOrangeStripe"
    case orange = "AppIconOrange"
    case red = "AppIconRed"
    case risingSun = "AppIconRisingSun"
    case pink = "AppIconPink"
    case water = "AppIconWater"
    case stainedGlass = "AppIconStainedGlass"
    case stars = "AppIconStars"

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .defaultIcon: "Default"
        case .clouds: "Clouds"
        case .bible: "Bible"
        case .blue: "Blue"
        case .green: "Green"
        case .orangeStripe: "Orange Stripe"
        case .orange: "Orange"
        case .red: "Red"
        case .risingSun: "Rising Sun"
        case .pink: "Pink"
        case .water: "Water"
        case .stainedGlass: "Stained Glass"
        case .stars: "Stars"
        }
    }

    var alternateIconName: String? {
        self == .defaultIcon ? nil : rawValue
    }

    var previewAssetName: String {
        self == .defaultIcon ? "AppIconDefaultPreview" : "\(rawValue)Preview"
    }

    static var current: AppIconChoice {
        guard let alternateIconName = UIApplication.shared.alternateIconName else {
            return .defaultIcon
        }
        return AppIconChoice(rawValue: alternateIconName) ?? .defaultIcon
    }
}
