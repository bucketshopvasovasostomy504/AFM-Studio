import Foundation

enum ReasoningLevelSetting: String, Codable, CaseIterable, Identifiable, Sendable {
    case automatic
    case light
    case moderate
    case deep

    var id: String { rawValue }

    var title: String {
        switch self {
        case .automatic:
            "Automatic"
        case .light:
            "Light"
        case .moderate:
            "Moderate"
        case .deep:
            "Deep"
        }
    }
}

struct GenerationSettings: Codable, Equatable, Sendable {
    var temperature: Double?
    var maximumResponseTokens: Int?
    var reasoningLevel: ReasoningLevelSetting

    static let `default` = GenerationSettings(
        temperature: nil,
        maximumResponseTokens: nil,
        reasoningLevel: .automatic
    )
}
