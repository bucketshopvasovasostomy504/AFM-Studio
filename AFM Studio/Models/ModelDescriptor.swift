import Foundation

enum ModelLane: String, Codable, CaseIterable, Identifiable, Sendable {
    case appleSystem
    case privateCloud
    case localMLX
    case coreAI
    case server

    var id: String { rawValue }

    var title: String {
        switch self {
        case .appleSystem:
            "Apple"
        case .privateCloud:
            "Private Cloud"
        case .localMLX:
            "Local MLX"
        case .coreAI:
            "Core AI"
        case .server:
            "Server Providers"
        }
    }
}

enum ModelAvailabilityState: String, Codable, Equatable, Sendable {
    case available
    case unavailable
    case requiresSetup
    case experimental
}

struct ModelCapabilitySet: Codable, Equatable, Sendable {
    var text: Bool
    var reasoning: Bool
    var toolCalling: Bool
    var guidedGeneration: Bool
    var vision: Bool

    static let textOnly = ModelCapabilitySet(
        text: true,
        reasoning: false,
        toolCalling: false,
        guidedGeneration: false,
        vision: false
    )
}

struct ModelDescriptor: Identifiable, Codable, Equatable, Sendable {
    var id: String
    var displayName: String
    var lane: ModelLane
    var modelID: String
    var capabilities: ModelCapabilitySet
    var availability: ModelAvailabilityState
    var statusLine: String
    var isBuiltIn: Bool

    var canSend: Bool {
        availability == .available || availability == .experimental
    }
}
