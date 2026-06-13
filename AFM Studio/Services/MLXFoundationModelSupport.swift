import Foundation

#if canImport(MLXFoundationModels)
import MLXFoundationModels
#elseif canImport(MLXLanguageModel)
import MLXLanguageModel
#endif

enum MLXFoundationModelSupport {
    static let gemma4E2BModelID = "mlx-community/gemma-4-e2b-it-4bit"

    static var isCompiledIn: Bool {
        #if canImport(MLXFoundationModels) || canImport(MLXLanguageModel)
        true
        #else
        false
        #endif
    }

    static var statusLine: String {
        if isCompiledIn {
            return "MLX Foundation Models package linked"
        }
        return "Waiting for Apple's MLX Foundation Models package"
    }
}
