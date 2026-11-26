import Foundation

/// Option of an event casting attribute (selection format / target gender).
public struct DivoEventAttributeOption: Equatable {
    public let id: String
    public let title: String

    public init(id: String, title: String) {
        self.id = id
        self.title = title
    }
}

/// How the casting takes place. Ids match the backend `selectionFormat` values.
public enum DivoEventSelectionFormat {
    public static var options: [DivoEventAttributeOption] {
        [
            DivoEventAttributeOption(id: "open_call", title: DivoStrings.selectionFormatOpenCall),
            DivoEventAttributeOption(id: "go_see_invite_only", title: DivoStrings.selectionFormatGoSee),
            DivoEventAttributeOption(id: "online_self_tape", title: DivoStrings.selectionFormatOnlineSelfTape),
            DivoEventAttributeOption(id: "client_casting", title: DivoStrings.selectionFormatClientCasting),
            DivoEventAttributeOption(id: "agency_casting", title: DivoStrings.selectionFormatAgencyCasting)
        ]
    }

    public static func title(for id: String?) -> String? {
        guard let id, !id.isEmpty else { return nil }
        return options.first(where: { $0.id == id })?.title
    }
}

/// Target gender of the casting. Ids match the backend `targetGender` values.
public enum DivoEventTargetGender {
    public static var options: [DivoEventAttributeOption] {
        [
            DivoEventAttributeOption(id: "female", title: DivoStrings.targetGenderFemale),
            DivoEventAttributeOption(id: "male", title: DivoStrings.targetGenderMale),
            DivoEventAttributeOption(id: "non_binary", title: DivoStrings.targetGenderNonBinary),
            DivoEventAttributeOption(id: "transgender_female", title: DivoStrings.targetGenderTransgenderFemale),
            DivoEventAttributeOption(id: "transgender_male", title: DivoStrings.targetGenderTransgenderMale),
            DivoEventAttributeOption(id: "custom", title: DivoStrings.targetGenderCustom),
            DivoEventAttributeOption(id: "other", title: DivoStrings.targetGenderOther)
        ]
    }

    public static func title(for id: String?) -> String? {
        guard let id, !id.isEmpty else { return nil }
        return options.first(where: { $0.id == id })?.title
    }
}