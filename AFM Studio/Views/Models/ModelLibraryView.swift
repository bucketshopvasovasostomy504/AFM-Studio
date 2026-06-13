import SwiftData
import SwiftUI

struct ModelLibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \UserModelRecord.displayName) private var userModels: [UserModelRecord]

    let registry: ModelRegistry

    @State private var isAddingModel = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(registry.groupedDescriptors(), id: \.lane.rawValue) { group in
                    Section(group.lane.title) {
                        ForEach(group.descriptors) { descriptor in
                            ModelDescriptorRow(descriptor: descriptor)
                        }
                    }
                }
            }
            .navigationTitle("Models")
            .toolbar {
                ToolbarItemGroup {
                    Button("Refresh") {
                        registry.refresh(userModels: userModels)
                    }
                    Button("Add Model") {
                        isAddingModel = true
                    }
                }
            }
            .sheet(isPresented: $isAddingModel) {
                AddModelSheet()
            }
            .onAppear {
                registry.refresh(userModels: userModels)
            }
            .onChange(of: userModels.count) { _, _ in
                registry.refresh(userModels: userModels)
            }
        }
    }
}

private struct ModelDescriptorRow: View {
    let descriptor: ModelDescriptor

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(descriptor.displayName)
                    .font(.headline)
                Spacer()
                Text(descriptor.availability.rawValue)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(statusColor)
            }

            Text(descriptor.modelID)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)

            Text(descriptor.statusLine)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private var statusColor: Color {
        switch descriptor.availability {
        case .available:
            .green
        case .experimental:
            .blue
        case .requiresSetup:
            .orange
        case .unavailable:
            .red
        }
    }
}

private struct AddModelSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var displayName = ""
    @State private var modelID = ""
    @State private var lane: ModelLane = .localMLX

    private var canAdd: Bool {
        displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            && modelID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Model") {
                    TextField("Display Name", text: $displayName)
                    TextField("Model ID", text: $modelID)
                    Picker("Lane", selection: $lane) {
                        Text("Local MLX").tag(ModelLane.localMLX)
                        Text("Core AI").tag(ModelLane.coreAI)
                        Text("Server Provider").tag(ModelLane.server)
                    }
                }

                Section("Status") {
                    Text("Added models are saved in the library and appear in the picker. Generation stays disabled until the matching AFM provider is implemented.")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Add Model")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addModel()
                    }
                    .disabled(canAdd == false)
                }
            }
        }
        #if os(macOS)
        .frame(width: 460, height: 300)
        #endif
    }

    private func addModel() {
        let record = UserModelRecord(
            descriptorID: "user.\(UUID().uuidString)",
            displayName: displayName.trimmingCharacters(in: .whitespacesAndNewlines),
            laneRawValue: lane.rawValue,
            modelID: modelID.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        modelContext.insert(record)
        try? modelContext.save()
        dismiss()
    }
}
