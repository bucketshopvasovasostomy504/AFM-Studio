import SwiftUI

struct AFMStudioView: View {
    var body: some View {
        NavigationSplitView {
            Text("Chats")
                .navigationTitle("AFM Studio")
        } detail: {
            Text("Select or start a chat")
                .foregroundStyle(.secondary)
        }
    }
}
