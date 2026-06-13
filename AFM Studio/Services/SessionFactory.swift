import Foundation
import FoundationModels

#if canImport(MLXFoundationModels)
import MLXFoundationModels
#elseif canImport(MLXLanguageModel)
import MLXLanguageModel
#endif

enum SessionFactoryError: LocalizedError {
    case unsupportedModel(String)
    case unavailable(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedModel(let modelID):
            "Unsupported model: \(modelID)"
        case .unavailable(let message):
            message
        }
    }
}

enum SessionFactory {
    static func makeSession(for descriptor: ModelDescriptor) throws -> LanguageModelSession {
        switch descriptor.id {
        case BuiltInModelID.appleSystem:
            return LanguageModelSession(model: SystemLanguageModel.default)
        case BuiltInModelID.privateCloud:
            if #available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *) {
                return LanguageModelSession(model: PrivateCloudComputeLanguageModel())
            }
            throw SessionFactoryError.unavailable("Private Cloud Compute requires OS 27.")
        case BuiltInModelID.gemma4E2B:
            #if canImport(MLXFoundationModels) || canImport(MLXLanguageModel)
            let model = MLXLanguageModel(modelID: descriptor.modelID)
            return LanguageModelSession(model: model)
            #else
            throw SessionFactoryError.unavailable("MLX Foundation Models support is not linked in this build.")
            #endif
        default:
            throw SessionFactoryError.unsupportedModel(descriptor.id)
        }
    }
}
