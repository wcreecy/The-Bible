import Foundation
import AudioToolbox

public enum TimerSound: String, CaseIterable, Identifiable {
    case bell
    case chime
    case glass
    case horn
    case piano
    case pop
    case synth

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .bell: return "Bell"
        case .chime: return "Chime"
        case .glass: return "Glass"
        case .horn: return "Horn"
        case .piano: return "Piano"
        case .pop: return "Pop"
        case .synth: return "Synth"
        }
    }

    public var systemSoundID: SystemSoundID {
        switch self {
        case .bell: return 1005
        case .chime: return 1007
        case .glass: return 1022
        case .horn: return 1013
        case .piano: return 1030
        case .pop: return 1057
        case .synth: return 1070
        }
    }

    public static var `default`: TimerSound { .bell }
}
