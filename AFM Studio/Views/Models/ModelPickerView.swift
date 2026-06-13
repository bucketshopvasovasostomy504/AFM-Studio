import SwiftUI

struct ModelPickerView: View {
    let conversation: ConversationRecord
    let registry: ModelRegistry

    private var selection: Binding<String> {
        Binding {
            conversation.selectedModelID
        } set: { newValue in
            conversation.selectedModelID = newValue
            conversation.updatedAt = .now
        }
    }

    var body: some View {
        Picker("Model", selection: selection) {
            ForEach(registry.groupedDescriptors(), id: \.lane.rawValue) { group in
                Section(group.lane.title) {
                    ForEach(group.descriptors) { descriptor in
                        Text(descriptor.displayName)
                            .tag(descriptor.id)
                    }
                }
            }
        }
        .pickerStyle(.menu)
    }
}
