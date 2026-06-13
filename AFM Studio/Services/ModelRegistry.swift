import Foundation
import FoundationModels
import Observation

@MainActor
@Observable
final class ModelRegistry {
    private(set) var descriptors: [ModelDescriptor] = []

    init() {
        refresh()
    }

    func refresh(userModels: [UserModelRecord] = []) {
        var next: [ModelDescriptor] = []
        next.append(systemDescriptor())

        if #available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *) {
            next.append(privateCloudDescriptor())
        }

        next.append(mlxGemmaDescriptor())
        next.append(contentsOf: userModels.map(userDescriptor))
        descriptors = next
    }

    func descriptor(for id: String) -> ModelDescriptor? {
        descriptors.first { $0.id == id }
    }

    func groupedDescriptors() -> [(lane: ModelLane, descriptors: [ModelDescriptor])] {
        ModelLane.allCases.compactMap { lane in
            let values = descriptors.filter { $0.lane == lane }
            return values.isEmpty ? nil : (lane, values)
        }
    }

    private func systemDescriptor() -> ModelDescriptor {
        let model = SystemLanguageModel.default
        let status = FoundationModelStatusFormatting.systemAvailabilityText(model.availability)
        return ModelDescriptor(
            id: BuiltInModelID.appleSystem,
            displayName: "Apple System Model",
            lane: .appleSystem,
            modelID: "SystemLanguageModel.default",
            capabilities: .textOnly,
            availability: status.0,
            statusLine: status.1,
            isBuiltIn: true
        )
    }

    @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
    private func privateCloudDescriptor() -> ModelDescriptor {
        let model = PrivateCloudComputeLanguageModel()
        let availability = FoundationModelStatusFormatting.privateCloudAvailabilityText(model.availability)
        let quota = FoundationModelStatusFormatting.privateCloudQuotaText(model.quotaUsage)
        return ModelDescriptor(
            id: BuiltInModelID.privateCloud,
            displayName: "Private Cloud Compute",
            lane: .privateCloud,
            modelID: "PrivateCloudComputeLanguageModel.default",
            capabilities: ModelCapabilitySet(
                text: true,
                reasoning: true,
                toolCalling: false,
                guidedGeneration: true,
                vision: false
            ),
            availability: availability.0,
            statusLine: availability.0 == .available ? quota : availability.1,
            isBuiltIn: true
        )
    }

    private func mlxGemmaDescriptor() -> ModelDescriptor {
        ModelDescriptor(
            id: BuiltInModelID.gemma4E2B,
            displayName: "Gemma 4 E2B Instruct",
            lane: .localMLX,
            modelID: MLXFoundationModelSupport.gemma4E2BModelID,
            capabilities: .textOnly,
            availability: MLXFoundationModelSupport.isCompiledIn ? .experimental : .requiresSetup,
            statusLine: MLXFoundationModelSupport.statusLine,
            isBuiltIn: true
        )
    }

    private func userDescriptor(for record: UserModelRecord) -> ModelDescriptor {
        let lane = ModelLane(rawValue: record.laneRawValue) ?? .localMLX
        let statusLine: String
        switch lane {
        case .localMLX:
            statusLine = MLXFoundationModelSupport.statusLine
        case .server:
            statusLine = "Waiting for AFM provider configuration"
        case .coreAI:
            statusLine = "Waiting for Core AI model support"
        case .appleSystem, .privateCloud:
            statusLine = "Custom descriptor"
        }

        return ModelDescriptor(
            id: record.descriptorID,
            displayName: record.displayName,
            lane: lane,
            modelID: record.modelID,
            capabilities: .textOnly,
            availability: .requiresSetup,
            statusLine: statusLine,
            isBuiltIn: false
        )
    }
}
