import Foundation
import SwiftData

enum AFMStudioSchema {
    static let models: [any PersistentModel.Type] = []
}

enum AFMMockData {
    @MainActor
    static var previewContainer: ModelContainer {
        try! ModelContainer(
            for: Schema(emptySchema),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private static let emptySchema: [any PersistentModel.Type] = []
}
