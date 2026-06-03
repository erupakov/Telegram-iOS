import Foundation

public enum Role {
    case model
    case newFace
    case agency
    case fan

    public init(apiRole: String?) {
        switch apiRole {
        case "agency_employee": self = .agency
        case "new_face":        self = .newFace
        case "fan":             self = .fan
        default:                self = .model
        }
    }

    public var title: String {
        switch self {
        case .model: DivoStrings.roleModel
        case .newFace: DivoStrings.roleNewFace
        case .agency: DivoStrings.roleAgency
        case .fan: DivoStrings.roleFan
        }
    }
}