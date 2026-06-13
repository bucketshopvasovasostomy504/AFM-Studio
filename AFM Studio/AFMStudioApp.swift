import SwiftData
import SwiftUI

@main
struct AFMStudioApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: AFMStudioSchema.models)
    }
}
