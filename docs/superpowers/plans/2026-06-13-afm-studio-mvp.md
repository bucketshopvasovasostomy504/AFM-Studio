# AFM Studio MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the first working AFM Studio app with a Perspective-style chat workspace, Apple system and Private Cloud Compute model selection, an MLXFoundationModels validation path for Gemma 4 E2B, local comparison, and local benchmarks.

**Architecture:** Keep app UI, model registry, session creation, chat state, comparison, and benchmarks in focused Swift files under the file-system synchronized `AFM Studio/` group. Route all real generation through FoundationModels `LanguageModelSession`; MLX support starts through Apple's `MLXFoundationModels` package and stays disabled with a clear status if the package cannot be added in this environment. Server providers and Core AI providers are follow-up plans after the MVP path is verified.

**Tech Stack:** SwiftUI, SwiftData, FoundationModels, Observation, Xcode 27 beta, Swift Concurrency, optional MLXFoundationModels package after dependency validation.

---

## Scope Check

This plan implements the MVP from `docs/superpowers/specs/2026-06-13-afm-studio-design.md`.

Included:

- App shell and Perspective-style chat layout.
- SwiftData persistence models.
- Model registry for Apple system, PCC, and a gated MLX Gemma 4 E2B descriptor.
- FoundationModels session factory and streaming chat runner.
- PCC availability and quota formatting.
- Compare mode across selected descriptors.
- Benchmark mode with repeatable local suites.
- Xcode beta build verification.

Deferred into separate plans:

- OpenAI-compatible server provider executor.
- Core AI provider integration.
- Custom MLX executor fallback.
- Full model download manager UI beyond status, model ID, and load feedback.

## File Structure

Create these files:

- `AFM Studio/AFMStudioApp.swift` - app entry point and SwiftData container.
- `AFM Studio/ContentView.swift` - root view host only.
- `AFM Studio/Models/ModelDescriptor.swift` - stable model metadata and UI status types.
- `AFM Studio/Models/PersistenceModels.swift` - SwiftData records for conversations, messages, runs, benchmark suites, and benchmark results.
- `AFM Studio/Models/GenerationSettings.swift` - temperature, max tokens, reasoning level, and comparison settings.
- `AFM Studio/Services/ModelRegistry.swift` - descriptor list and availability refresh.
- `AFM Studio/Services/SessionFactory.swift` - descriptor to `LanguageModelSession` conversion.
- `AFM Studio/Services/ChatStore.swift` - active conversation state, send, retry, and streaming updates.
- `AFM Studio/Services/ComparisonRunner.swift` - multi-model prompt fanout.
- `AFM Studio/Services/BenchmarkRunner.swift` - prompt suite execution and result aggregation.
- `AFM Studio/Services/FoundationModelStatusFormatting.swift` - availability, quota, and error text.
- `AFM Studio/Views/AFMStudioView.swift` - split layout and tab/sidebar routing.
- `AFM Studio/Views/Chat/ChatWorkspaceView.swift` - conversation list, detail, and composer composition.
- `AFM Studio/Views/Chat/ConversationListView.swift` - sidebar list.
- `AFM Studio/Views/Chat/ChatTranscriptView.swift` - message stream.
- `AFM Studio/Views/Chat/ComposerView.swift` - prompt input and send controls.
- `AFM Studio/Views/Models/ModelPickerView.swift` - grouped model picker and add/manage entry.
- `AFM Studio/Views/Compare/CompareView.swift` - comparison prompt and results.
- `AFM Studio/Views/Benchmarks/BenchmarkView.swift` - benchmark suite runner and result list.
- `AFM Studio/Views/Settings/ModelSettingsView.swift` - quota and local MLX status.

Modify these files:

- `AFM Studio/ContentView.swift` - replace starter app and hello-world view with root view host.
- `AFM Studio.xcodeproj/project.pbxproj` - only if adding the MLXFoundationModels package requires explicit project package entries.

Do not stage or commit:

- `AFM Studio.xcodeproj/xcuserdata/mikedoise.xcuserdatad/xcschemes/xcschememanagement.plist`

## Task 1: Baseline Project Cleanup

**Files:**
- Create: `AFM Studio/AFMStudioApp.swift`
- Modify: `AFM Studio/ContentView.swift`

- [ ] **Step 1: Replace the starter app file with a root host**

Update `AFM Studio/ContentView.swift`:

```swift
import SwiftUI

struct ContentView: View {
    var body: some View {
        AFMStudioView()
    }
}

#Preview {
    ContentView()
        .modelContainer(AFMMockData.previewContainer)
}
```

- [ ] **Step 2: Add the app entry point**

Create `AFM Studio/AFMStudioApp.swift`:

```swift
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
```

- [ ] **Step 3: Add a temporary root view so the project builds**

Create `AFM Studio/Views/AFMStudioView.swift`:

```swift
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

#Preview {
    AFMStudioView()
}
```

- [ ] **Step 4: Add temporary SwiftData schema shims**

Create `AFM Studio/Models/PersistenceModels.swift`:

```swift
import Foundation
import SwiftData

enum AFMStudioSchema {
    static let models: [any PersistentModel.Type] = []
}

enum AFMMockData {
    @MainActor
    static var previewContainer: ModelContainer {
        try! ModelContainer(for: Schema(AFMMockData.emptySchema), configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    private static let emptySchema: [any PersistentModel.Type] = []
}
```

- [ ] **Step 5: Build with Xcode beta**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer /Applications/Xcode-beta.app/Contents/Developer/usr/bin/xcodebuild -project "AFM Studio.xcodeproj" -scheme "AFM Studio" -destination 'platform=macOS' build
```

Expected: build succeeds or fails only because the shared scheme is not visible from CLI. If the scheme is not visible, open the project once in Xcode beta and share the scheme, then rerun the command.

- [ ] **Step 6: Commit**

```bash
git add "AFM Studio/AFMStudioApp.swift" "AFM Studio/ContentView.swift" "AFM Studio/Views/AFMStudioView.swift" "AFM Studio/Models/PersistenceModels.swift"
git commit -m "Build AFM Studio app shell"
```

## Task 2: Persistence and Core Domain Types

**Files:**
- Modify: `AFM Studio/Models/PersistenceModels.swift`
- Create: `AFM Studio/Models/ModelDescriptor.swift`
- Create: `AFM Studio/Models/GenerationSettings.swift`

- [ ] **Step 1: Define model descriptors**

Create `AFM Studio/Models/ModelDescriptor.swift`:

```swift
import Foundation

enum ModelLane: String, Codable, CaseIterable, Identifiable {
    case appleSystem
    case privateCloud
    case localMLX
    case coreAI
    case server

    var id: String { rawValue }

    var title: String {
        switch self {
        case .appleSystem: "Apple"
        case .privateCloud: "Private Cloud"
        case .localMLX: "Local MLX"
        case .coreAI: "Core AI"
        case .server: "Server Providers"
        }
    }
}

enum ModelAvailabilityState: String, Codable, Equatable {
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

    static let textOnly = ModelCapabilitySet(text: true, reasoning: false, toolCalling: false, guidedGeneration: false, vision: false)
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
```

- [ ] **Step 2: Define generation settings**

Create `AFM Studio/Models/GenerationSettings.swift`:

```swift
import Foundation

enum ReasoningLevelSetting: String, Codable, CaseIterable, Identifiable, Sendable {
    case automatic
    case light
    case moderate
    case deep

    var id: String { rawValue }

    var title: String {
        switch self {
        case .automatic: "Automatic"
        case .light: "Light"
        case .moderate: "Moderate"
        case .deep: "Deep"
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
```

- [ ] **Step 3: Replace the temporary persistence shim**

Update `AFM Studio/Models/PersistenceModels.swift`:

```swift
import Foundation
import SwiftData

@Model
final class ConversationRecord {
    var id: UUID
    var title: String
    var selectedModelID: String
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \MessageRecord.conversation)
    var messages: [MessageRecord]

    init(id: UUID = UUID(), title: String = "New Chat", selectedModelID: String = BuiltInModelID.appleSystem, createdAt: Date = .now, updatedAt: Date = .now, messages: [MessageRecord] = []) {
        self.id = id
        self.title = title
        self.selectedModelID = selectedModelID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.messages = messages
    }
}

@Model
final class MessageRecord {
    var id: UUID
    var role: MessageRole
    var content: String
    var createdAt: Date
    var conversation: ConversationRecord?

    @Relationship(deleteRule: .cascade, inverse: \RunRecord.message)
    var runs: [RunRecord]

    init(id: UUID = UUID(), role: MessageRole, content: String, createdAt: Date = .now, conversation: ConversationRecord? = nil, runs: [RunRecord] = []) {
        self.id = id
        self.role = role
        self.content = content
        self.createdAt = createdAt
        self.conversation = conversation
        self.runs = runs
    }
}

@Model
final class RunRecord {
    var id: UUID
    var modelID: String
    var startedAt: Date
    var completedAt: Date?
    var duration: TimeInterval?
    var inputTokens: Int?
    var outputTokens: Int?
    var errorCategory: String?
    var message: MessageRecord?

    init(id: UUID = UUID(), modelID: String, startedAt: Date = .now, completedAt: Date? = nil, duration: TimeInterval? = nil, inputTokens: Int? = nil, outputTokens: Int? = nil, errorCategory: String? = nil, message: MessageRecord? = nil) {
        self.id = id
        self.modelID = modelID
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.duration = duration
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.errorCategory = errorCategory
        self.message = message
    }
}

@Model
final class BenchmarkSuiteRecord {
    var id: UUID
    var name: String
    var prompts: [String]

    init(id: UUID = UUID(), name: String, prompts: [String]) {
        self.id = id
        self.name = name
        self.prompts = prompts
    }
}

@Model
final class BenchmarkResultRecord {
    var id: UUID
    var suiteName: String
    var prompt: String
    var modelID: String
    var output: String
    var duration: TimeInterval
    var outputTokens: Int?
    var errorCategory: String?
    var createdAt: Date

    init(id: UUID = UUID(), suiteName: String, prompt: String, modelID: String, output: String, duration: TimeInterval, outputTokens: Int? = nil, errorCategory: String? = nil, createdAt: Date = .now) {
        self.id = id
        self.suiteName = suiteName
        self.prompt = prompt
        self.modelID = modelID
        self.output = output
        self.duration = duration
        self.outputTokens = outputTokens
        self.errorCategory = errorCategory
        self.createdAt = createdAt
    }
}

@Model
final class UserModelRecord {
    var id: UUID
    var descriptorID: String
    var displayName: String
    var laneRawValue: String
    var modelID: String

    init(id: UUID = UUID(), descriptorID: String, displayName: String, laneRawValue: String, modelID: String) {
        self.id = id
        self.descriptorID = descriptorID
        self.displayName = displayName
        self.laneRawValue = laneRawValue
        self.modelID = modelID
    }
}

enum MessageRole: String, Codable {
    case user
    case assistant
    case system
}

enum BuiltInModelID {
    static let appleSystem = "apple.system.default"
    static let privateCloud = "apple.private-cloud.default"
    static let gemma4E2B = "mlx.gemma-4-e2b-it"
}

enum AFMStudioSchema {
    static let models: [any PersistentModel.Type] = [
        ConversationRecord.self,
        MessageRecord.self,
        RunRecord.self,
        BenchmarkSuiteRecord.self,
        BenchmarkResultRecord.self,
        UserModelRecord.self
    ]
}

enum AFMMockData {
    @MainActor
    static var previewContainer: ModelContainer {
        try! ModelContainer(for: Schema(AFMStudioSchema.models), configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }
}
```

- [ ] **Step 4: Build**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer /Applications/Xcode-beta.app/Contents/Developer/usr/bin/xcodebuild -project "AFM Studio.xcodeproj" -scheme "AFM Studio" -destination 'platform=macOS' build
```

Expected: build succeeds.

- [ ] **Step 5: Commit**

```bash
git add "AFM Studio/Models"
git commit -m "Add AFM Studio domain models"
```

## Task 3: Model Registry and Status Formatting

**Files:**
- Create: `AFM Studio/Services/ModelRegistry.swift`
- Create: `AFM Studio/Services/FoundationModelStatusFormatting.swift`

- [ ] **Step 1: Add status formatting**

Create `AFM Studio/Services/FoundationModelStatusFormatting.swift`:

```swift
import Foundation
import FoundationModels

enum FoundationModelStatusFormatting {
    static func systemAvailabilityText(_ availability: SystemLanguageModel.Availability) -> (ModelAvailabilityState, String) {
        switch availability {
        case .available:
            return (.available, "Ready")
        case .unavailable(let reason):
            return (.unavailable, "Unavailable: \(String(describing: reason))")
        @unknown default:
            return (.unavailable, "Unavailable")
        }
    }

    @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
    static func privateCloudAvailabilityText(_ availability: PrivateCloudComputeLanguageModel.Availability) -> (ModelAvailabilityState, String) {
        switch availability {
        case .available:
            return (.available, "Ready")
        case .unavailable(let reason):
            return (.unavailable, "Unavailable: \(String(describing: reason))")
        @unknown default:
            return (.unavailable, "Unavailable")
        }
    }

    @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
    static func privateCloudQuotaText(_ quotaUsage: PrivateCloudComputeLanguageModel.QuotaUsage) -> String {
        if quotaUsage.isLimitReached {
            if let resetDate = quotaUsage.resetDate {
                return "Quota reached until \(resetDate.formatted(date: .abbreviated, time: .shortened))"
            }
            return "Quota reached"
        }

        switch quotaUsage.status {
        case .belowLimit(let belowLimit):
            return belowLimit.isApproachingLimit ? "Quota approaching daily limit" : "Quota available"
        case .limitReached:
            return "Quota reached"
        @unknown default:
            return "Quota status unknown"
        }
    }
}
```

- [ ] **Step 2: Add registry**

Create `AFM Studio/Services/ModelRegistry.swift`:

```swift
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

    func refresh() {
        var next: [ModelDescriptor] = []
        next.append(systemDescriptor())

        if #available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *) {
            next.append(privateCloudDescriptor())
        }

        next.append(mlxGemmaDescriptor())
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
            capabilities: ModelCapabilitySet(text: true, reasoning: true, toolCalling: false, guidedGeneration: true, vision: false),
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
            modelID: "mlx-community/gemma-4-e2b-it-4bit",
            capabilities: .textOnly,
            availability: .requiresSetup,
            statusLine: "MLXFoundationModels package validation required",
            isBuiltIn: true
        )
    }
}
```

- [ ] **Step 3: Build**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer /Applications/Xcode-beta.app/Contents/Developer/usr/bin/xcodebuild -project "AFM Studio.xcodeproj" -scheme "AFM Studio" -destination 'platform=macOS' build
```

Expected: build succeeds.

- [ ] **Step 4: Commit**

```bash
git add "AFM Studio/Services/ModelRegistry.swift" "AFM Studio/Services/FoundationModelStatusFormatting.swift"
git commit -m "Add Foundation Models registry"
```

## Task 4: Session Factory and Chat Runner

**Files:**
- Create: `AFM Studio/Services/SessionFactory.swift`
- Create: `AFM Studio/Services/ChatStore.swift`

- [ ] **Step 1: Add session factory**

Create `AFM Studio/Services/SessionFactory.swift`:

```swift
import Foundation
import FoundationModels

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
            throw SessionFactoryError.unavailable("MLXFoundationModels has not been validated in this build.")
        default:
            throw SessionFactoryError.unsupportedModel(descriptor.id)
        }
    }
}
```

- [ ] **Step 2: Add chat store**

Create `AFM Studio/Services/ChatStore.swift`:

```swift
import Foundation
import FoundationModels
import Observation
import SwiftData

@MainActor
@Observable
final class ChatStore {
    var activeConversation: ConversationRecord?
    var isGenerating = false
    var errorMessage: String?

    private let registry: ModelRegistry

    init(registry: ModelRegistry) {
        self.registry = registry
    }

    func ensureConversation(in context: ModelContext) -> ConversationRecord {
        if let activeConversation {
            return activeConversation
        }

        let conversation = ConversationRecord(selectedModelID: BuiltInModelID.appleSystem)
        context.insert(conversation)
        activeConversation = conversation
        return conversation
    }

    func send(_ prompt: String, in context: ModelContext) async {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false, isGenerating == false else {
            return
        }

        let conversation = ensureConversation(in: context)
        let descriptor = registry.descriptor(for: conversation.selectedModelID) ?? registry.descriptors.first
        guard let descriptor else {
            errorMessage = "No model is available."
            return
        }

        let userMessage = MessageRecord(role: .user, content: trimmed, conversation: conversation)
        let assistantMessage = MessageRecord(role: .assistant, content: "", conversation: conversation)
        conversation.messages.append(userMessage)
        conversation.messages.append(assistantMessage)
        conversation.updatedAt = .now

        isGenerating = true
        errorMessage = nil
        let startedAt = Date()
        let run = RunRecord(modelID: descriptor.id, startedAt: startedAt, message: assistantMessage)
        assistantMessage.runs.append(run)

        do {
            let session = try SessionFactory.makeSession(for: descriptor)
            let stream = session.streamResponse(to: trimmed)
            for try await snapshot in stream {
                assistantMessage.content = snapshot.content
            }
            let completedAt = Date()
            run.completedAt = completedAt
            run.duration = completedAt.timeIntervalSince(startedAt)
        } catch {
            assistantMessage.content = "Generation failed."
            run.errorCategory = String(describing: type(of: error))
            errorMessage = error.localizedDescription
        }

        isGenerating = false
    }
}
```

- [ ] **Step 3: Build**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer /Applications/Xcode-beta.app/Contents/Developer/usr/bin/xcodebuild -project "AFM Studio.xcodeproj" -scheme "AFM Studio" -destination 'platform=macOS' build
```

Expected: build succeeds.

- [ ] **Step 4: Commit**

```bash
git add "AFM Studio/Services/SessionFactory.swift" "AFM Studio/Services/ChatStore.swift"
git commit -m "Add chat session runner"
```

## Task 5: Perspective-Style Chat UI

**Files:**
- Modify: `AFM Studio/Views/AFMStudioView.swift`
- Create: `AFM Studio/Views/Chat/ChatWorkspaceView.swift`
- Create: `AFM Studio/Views/Chat/ConversationListView.swift`
- Create: `AFM Studio/Views/Chat/ChatTranscriptView.swift`
- Create: `AFM Studio/Views/Chat/ComposerView.swift`
- Create: `AFM Studio/Views/Models/ModelPickerView.swift`

- [ ] **Step 1: Keep root focused on the chat tab**

Update `AFM Studio/Views/AFMStudioView.swift`:

```swift
import SwiftData
import SwiftUI

struct AFMStudioView: View {
    @State private var registry = ModelRegistry()
    @State private var chatStore: ChatStore?

    var body: some View {
        TabView {
            ChatWorkspaceView(registry: registry, chatStore: resolvedChatStore)
                .tabItem {
                    Label("Chat", systemImage: "bubble.left.and.bubble.right")
                }
        }
    }

    private var resolvedChatStore: ChatStore {
        if let chatStore {
            return chatStore
        }
        let store = ChatStore(registry: registry)
        chatStore = store
        return store
    }
}

#Preview {
    AFMStudioView()
        .modelContainer(AFMMockData.previewContainer)
}
```

- [ ] **Step 2: Add workspace composition**

Create `AFM Studio/Views/Chat/ChatWorkspaceView.swift`:

```swift
import SwiftData
import SwiftUI

struct ChatWorkspaceView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ConversationRecord.updatedAt, order: .reverse) private var conversations: [ConversationRecord]

    let registry: ModelRegistry
    let chatStore: ChatStore

    var body: some View {
        NavigationSplitView {
            ConversationListView(conversations: conversations, selection: chatStore.activeConversation) { conversation in
                chatStore.activeConversation = conversation
            } newChat: {
                let conversation = ConversationRecord(selectedModelID: BuiltInModelID.appleSystem)
                modelContext.insert(conversation)
                chatStore.activeConversation = conversation
            }
            .navigationTitle("AFM Studio")
        } detail: {
            VStack(spacing: 0) {
                header
                Divider()
                ChatTranscriptView(conversation: chatStore.activeConversation)
                ComposerView(isGenerating: chatStore.isGenerating) { prompt in
                    Task {
                        await chatStore.send(prompt, in: modelContext)
                    }
                }
            }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(chatStore.activeConversation?.title ?? "New Chat")
                    .font(.headline)
                Text(chatStore.activeConversation?.selectedModelID ?? BuiltInModelID.appleSystem)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            ModelPickerView(registry: registry, selectedModelID: bindingForSelectedModel)
                .frame(maxWidth: 280)
        }
        .padding()
    }

    private var bindingForSelectedModel: Binding<String> {
        Binding {
            chatStore.activeConversation?.selectedModelID ?? BuiltInModelID.appleSystem
        } set: { newValue in
            let conversation = chatStore.ensureConversation(in: modelContext)
            conversation.selectedModelID = newValue
            conversation.updatedAt = .now
        }
    }
}
```

- [ ] **Step 3: Add conversation list**

Create `AFM Studio/Views/Chat/ConversationListView.swift`:

```swift
import SwiftUI

struct ConversationListView: View {
    let conversations: [ConversationRecord]
    let selection: ConversationRecord?
    let select: (ConversationRecord) -> Void
    let newChat: () -> Void

    var body: some View {
        List(selection: selectedID) {
            ForEach(conversations) { conversation in
                Button {
                    select(conversation)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(conversation.title)
                            .font(.body)
                            .lineLimit(1)
                        Text(conversation.updatedAt, style: .relative)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
                .tag(conversation.id)
            }
        }
        .toolbar {
            Button {
                newChat()
            } label: {
                Label("New Chat", systemImage: "square.and.pencil")
            }
        }
    }

    private var selectedID: Binding<UUID?> {
        Binding {
            selection?.id
        } set: { _ in }
    }
}
```

- [ ] **Step 4: Add transcript**

Create `AFM Studio/Views/Chat/ChatTranscriptView.swift`:

```swift
import SwiftUI

struct ChatTranscriptView: View {
    let conversation: ConversationRecord?

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                if let conversation, conversation.messages.isEmpty == false {
                    ForEach(conversation.messages.sorted { $0.createdAt < $1.createdAt }) { message in
                        messageRow(message)
                    }
                } else {
                    ContentUnavailableView("Start a chat", systemImage: "text.bubble", description: Text("Pick a model and send a prompt."))
                        .padding(.top, 80)
                }
            }
            .padding()
        }
    }

    private func messageRow(_ message: MessageRecord) -> some View {
        HStack {
            if message.role == .user {
                Spacer(minLength: 48)
            }

            Text(message.content.isEmpty ? "Thinking" : message.content)
                .textSelection(.enabled)
                .padding(12)
                .background(message.role == .user ? Color.accentColor.opacity(0.14) : Color.secondary.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            if message.role != .user {
                Spacer(minLength: 48)
            }
        }
    }
}
```

- [ ] **Step 5: Add composer**

Create `AFM Studio/Views/Chat/ComposerView.swift`:

```swift
import SwiftUI

struct ComposerView: View {
    let isGenerating: Bool
    let send: (String) -> Void

    @State private var text = ""

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField("Message", text: $text, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...6)
            Button {
                let prompt = text
                text = ""
                send(prompt)
            } label: {
                Label("Send", systemImage: "paperplane.fill")
            }
            .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isGenerating)
        }
        .padding()
    }
}
```

- [ ] **Step 6: Add model picker**

Create `AFM Studio/Views/Models/ModelPickerView.swift`:

```swift
import SwiftUI

struct ModelPickerView: View {
    let registry: ModelRegistry
    @Binding var selectedModelID: String

    var body: some View {
        Picker("Model", selection: $selectedModelID) {
            ForEach(registry.groupedDescriptors(), id: \.lane) { group in
                Section(group.lane.title) {
                    ForEach(group.descriptors) { descriptor in
                        Text(descriptor.displayName)
                            .tag(descriptor.id)
                    }
                }
            }
        }
        .pickerStyle(.menu)
        .accessibilityLabel("Model")
    }
}
```

- [ ] **Step 7: Build**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer /Applications/Xcode-beta.app/Contents/Developer/usr/bin/xcodebuild -project "AFM Studio.xcodeproj" -scheme "AFM Studio" -destination 'platform=macOS' build
```

Expected: build succeeds.

- [ ] **Step 8: Commit**

```bash
git add "AFM Studio/Views"
git commit -m "Add chat workspace UI"
```

## Task 6: MLXFoundationModels Dependency Gate

**Files:**
- Modify: `AFM Studio/Services/SessionFactory.swift`
- Modify: `AFM Studio/Services/ModelRegistry.swift`
- Modify: `AFM Studio.xcodeproj/project.pbxproj` if the package is resolvable

- [ ] **Step 1: Verify the package product**

Run these searches before editing project dependencies:

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer /Applications/Xcode-beta.app/Contents/Developer/usr/bin/xcodebuild -version
```

Expected:

```text
Xcode 27.0
```

Then search current public package sources:

```bash
curl -L --max-time 20 https://raw.githubusercontent.com/ml-explore/mlx-swift-lm/main/Package.swift
curl -L --max-time 20 https://raw.githubusercontent.com/apple/coreai-models/main/swift/Package.swift
```

Expected: inspect the command output for a product named `MLXFoundationModels`, `MLXLanguageModel`, or a FoundationModels integration target. Continue to Step 2 only if a package source exposes that product. Continue to Step 4 if neither package source exposes that product.

- [ ] **Step 2: If `MLXFoundationModels` is resolvable, add the package**

Use Xcode beta package dependency UI or project-file editing to add the package URL that defines `MLXFoundationModels`. Link the `MLXFoundationModels` product to the `AFM Studio` target.

After adding it, run:

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer /Applications/Xcode-beta.app/Contents/Developer/usr/bin/xcodebuild -resolvePackageDependencies -project "AFM Studio.xcodeproj" -scheme "AFM Studio"
```

Expected: package dependency resolution succeeds and writes `AFM Studio.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`.

- [ ] **Step 3: Add conditional MLX session creation**

If the package is linked, update the top of `AFM Studio/Services/SessionFactory.swift`:

```swift
import Foundation
import FoundationModels
import MLXFoundationModels
```

Replace the Gemma case:

```swift
case BuiltInModelID.gemma4E2B:
    let model = MLXLanguageModel(modelID: descriptor.modelID)
    return LanguageModelSession(model: model)
```

- [ ] **Step 4: If the package is not resolvable, keep the gated error**

If neither package source exposes `MLXFoundationModels`, leave `SessionFactory` with:

```swift
case BuiltInModelID.gemma4E2B:
    throw SessionFactoryError.unavailable("MLXFoundationModels has not been validated in this build.")
```

Update the MLX descriptor status line in `AFM Studio/Services/ModelRegistry.swift`:

```swift
statusLine: "Waiting for Apple's MLXFoundationModels package"
```

- [ ] **Step 5: Build**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer /Applications/Xcode-beta.app/Contents/Developer/usr/bin/xcodebuild -project "AFM Studio.xcodeproj" -scheme "AFM Studio" -destination 'platform=macOS' build
```

Expected: build succeeds. If the MLX package was added, `SessionFactory.swift` compiles with `import MLXFoundationModels`.

- [ ] **Step 6: Commit**

For package-resolved path:

```bash
git add "AFM Studio/Services/SessionFactory.swift" "AFM Studio/Services/ModelRegistry.swift" "AFM Studio.xcodeproj/project.pbxproj" "AFM Studio.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"
git commit -m "Add MLX Foundation Models gate"
```

For gated path:

```bash
git add "AFM Studio/Services/ModelRegistry.swift"
git commit -m "Gate MLX provider until package validation"
```

## Task 7: Compare Mode

**Files:**
- Create: `AFM Studio/Services/ComparisonRunner.swift`
- Create: `AFM Studio/Views/Compare/CompareView.swift`
- Modify: `AFM Studio/Views/AFMStudioView.swift`

- [ ] **Step 1: Add comparison runner**

Create `AFM Studio/Services/ComparisonRunner.swift`:

```swift
import Foundation
import FoundationModels
import Observation

struct ComparisonResult: Identifiable, Sendable {
    var id = UUID()
    var descriptor: ModelDescriptor
    var output: String
    var duration: TimeInterval?
    var errorMessage: String?
}

@MainActor
@Observable
final class ComparisonRunner {
    var results: [ComparisonResult] = []
    var isRunning = false

    func run(prompt: String, descriptors: [ModelDescriptor]) async {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false, descriptors.isEmpty == false else {
            return
        }

        isRunning = true
        results = []

        for descriptor in descriptors {
            let start = Date()
            do {
                let session = try SessionFactory.makeSession(for: descriptor)
                let response = try await session.respond(to: trimmed)
                results.append(ComparisonResult(descriptor: descriptor, output: response.content, duration: Date().timeIntervalSince(start), errorMessage: nil))
            } catch {
                results.append(ComparisonResult(descriptor: descriptor, output: "", duration: Date().timeIntervalSince(start), errorMessage: error.localizedDescription))
            }
        }

        isRunning = false
    }
}
```

- [ ] **Step 2: Add comparison view**

Create `AFM Studio/Views/Compare/CompareView.swift`:

```swift
import SwiftUI

struct CompareView: View {
    let registry: ModelRegistry
    @State private var runner = ComparisonRunner()
    @State private var prompt = ""
    @State private var selectedIDs = Set<String>([BuiltInModelID.appleSystem, BuiltInModelID.privateCloud])

    var body: some View {
        VStack(spacing: 12) {
            TextField("Prompt", text: $prompt, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...6)
            modelChecks
            Button {
                Task {
                    await runner.run(prompt: prompt, descriptors: selectedDescriptors)
                }
            } label: {
                Label("Compare", systemImage: "rectangle.split.3x1")
            }
            .disabled(prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || runner.isRunning)
            resultGrid
        }
        .padding()
        .navigationTitle("Compare")
    }

    private var modelChecks: some View {
        VStack(alignment: .leading) {
            ForEach(registry.descriptors) { descriptor in
                Toggle(descriptor.displayName, isOn: Binding {
                    selectedIDs.contains(descriptor.id)
                } set: { isOn in
                    if isOn {
                        selectedIDs.insert(descriptor.id)
                    } else {
                        selectedIDs.remove(descriptor.id)
                    }
                })
            }
        }
    }

    private var selectedDescriptors: [ModelDescriptor] {
        registry.descriptors.filter { selectedIDs.contains($0.id) }
    }

    private var resultGrid: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 12)], spacing: 12) {
                ForEach(runner.results) { result in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(result.descriptor.displayName)
                            .font(.headline)
                        if let duration = result.duration {
                            Text(duration.formatted(.number.precision(.fractionLength(2))) + "s")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text(result.errorMessage ?? result.output)
                            .textSelection(.enabled)
                            .foregroundStyle(result.errorMessage == nil ? .primary : .red)
                    }
                    .padding()
                    .background(.quaternary)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }
}
```

- [ ] **Step 3: Add compare tab to root**

Update `AFM Studio/Views/AFMStudioView.swift`:

```swift
import SwiftData
import SwiftUI

struct AFMStudioView: View {
    @State private var registry = ModelRegistry()
    @State private var chatStore: ChatStore?

    var body: some View {
        TabView {
            ChatWorkspaceView(registry: registry, chatStore: resolvedChatStore)
                .tabItem {
                    Label("Chat", systemImage: "bubble.left.and.bubble.right")
                }
            NavigationStack {
                CompareView(registry: registry)
            }
            .tabItem {
                Label("Compare", systemImage: "rectangle.split.3x1")
            }
        }
    }

    private var resolvedChatStore: ChatStore {
        if let chatStore {
            return chatStore
        }
        let store = ChatStore(registry: registry)
        chatStore = store
        return store
    }
}

#Preview {
    AFMStudioView()
        .modelContainer(AFMMockData.previewContainer)
}
```

- [ ] **Step 4: Build and commit**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer /Applications/Xcode-beta.app/Contents/Developer/usr/bin/xcodebuild -project "AFM Studio.xcodeproj" -scheme "AFM Studio" -destination 'platform=macOS' build
```

Expected: build succeeds.

Commit:

```bash
git add "AFM Studio/Services/ComparisonRunner.swift" "AFM Studio/Views/Compare/CompareView.swift" "AFM Studio/Views/AFMStudioView.swift"
git commit -m "Add model comparison mode"
```

## Task 8: Benchmark Mode

**Files:**
- Create: `AFM Studio/Services/BenchmarkRunner.swift`
- Create: `AFM Studio/Views/Benchmarks/BenchmarkView.swift`
- Modify: `AFM Studio/Views/AFMStudioView.swift`

- [ ] **Step 1: Add benchmark runner**

Create `AFM Studio/Services/BenchmarkRunner.swift`:

```swift
import Foundation
import FoundationModels
import Observation

struct BenchmarkSuite: Identifiable, Sendable {
    var id: String
    var name: String
    var prompts: [String]

    static let starter = BenchmarkSuite(
        id: "starter",
        name: "Starter",
        prompts: [
            "Summarize what Foundation Models are in two sentences.",
            "Write a SwiftUI button that says Run.",
            "List three differences between local and cloud model execution."
        ]
    )
}

@MainActor
@Observable
final class BenchmarkRunner {
    var results: [BenchmarkResultRecord] = []
    var isRunning = false

    func run(suite: BenchmarkSuite, descriptor: ModelDescriptor) async {
        isRunning = true
        results = []

        for prompt in suite.prompts {
            let start = Date()
            do {
                let session = try SessionFactory.makeSession(for: descriptor)
                let response = try await session.respond(to: prompt)
                results.append(BenchmarkResultRecord(suiteName: suite.name, prompt: prompt, modelID: descriptor.id, output: response.content, duration: Date().timeIntervalSince(start), outputTokens: nil, errorCategory: nil))
            } catch {
                results.append(BenchmarkResultRecord(suiteName: suite.name, prompt: prompt, modelID: descriptor.id, output: "", duration: Date().timeIntervalSince(start), outputTokens: nil, errorCategory: String(describing: type(of: error))))
            }
        }

        isRunning = false
    }
}
```

- [ ] **Step 2: Add benchmark view**

Create `AFM Studio/Views/Benchmarks/BenchmarkView.swift`:

```swift
import SwiftUI

struct BenchmarkView: View {
    let registry: ModelRegistry
    @State private var runner = BenchmarkRunner()
    @State private var selectedModelID = BuiltInModelID.appleSystem
    private let suite = BenchmarkSuite.starter

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Model", selection: $selectedModelID) {
                ForEach(registry.descriptors) { descriptor in
                    Text(descriptor.displayName).tag(descriptor.id)
                }
            }
            Button {
                Task {
                    if let descriptor = registry.descriptor(for: selectedModelID) {
                        await runner.run(suite: suite, descriptor: descriptor)
                    }
                }
            } label: {
                Label("Run Benchmark", systemImage: "speedometer")
            }
            .disabled(runner.isRunning)
            List(runner.results) { result in
                VStack(alignment: .leading, spacing: 6) {
                    Text(result.prompt)
                        .font(.headline)
                    Text(result.errorCategory ?? result.output)
                        .lineLimit(4)
                    Text(result.duration.formatted(.number.precision(.fractionLength(2))) + "s")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .navigationTitle("Benchmarks")
    }
}
```

- [ ] **Step 3: Add benchmarks tab**

Update the `TabView` in `AFM Studio/Views/AFMStudioView.swift`:

```swift
TabView {
    ChatWorkspaceView(registry: registry, chatStore: resolvedChatStore)
        .tabItem {
            Label("Chat", systemImage: "bubble.left.and.bubble.right")
        }
    NavigationStack {
        CompareView(registry: registry)
    }
    .tabItem {
        Label("Compare", systemImage: "rectangle.split.3x1")
    }
    NavigationStack {
        BenchmarkView(registry: registry)
    }
    .tabItem {
        Label("Benchmarks", systemImage: "speedometer")
    }
}
```

- [ ] **Step 4: Build and commit**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer /Applications/Xcode-beta.app/Contents/Developer/usr/bin/xcodebuild -project "AFM Studio.xcodeproj" -scheme "AFM Studio" -destination 'platform=macOS' build
```

Expected: build succeeds.

Commit:

```bash
git add "AFM Studio/Services/BenchmarkRunner.swift" "AFM Studio/Views/Benchmarks/BenchmarkView.swift" "AFM Studio/Views/AFMStudioView.swift"
git commit -m "Add local benchmark mode"
```

## Task 9: Settings and Model Status Surface

**Files:**
- Create: `AFM Studio/Views/Settings/ModelSettingsView.swift`
- Modify: `AFM Studio/Views/AFMStudioView.swift`

- [ ] **Step 1: Add model settings view**

Create `AFM Studio/Views/Settings/ModelSettingsView.swift`:

```swift
import SwiftUI

struct ModelSettingsView: View {
    let registry: ModelRegistry

    var body: some View {
        List {
            ForEach(registry.groupedDescriptors(), id: \.lane) { group in
                Section(group.lane.title) {
                    ForEach(group.descriptors) { descriptor in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(descriptor.displayName)
                                .font(.headline)
                            Text(descriptor.statusLine)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(descriptor.modelID)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Models")
        .toolbar {
            Button {
                registry.refresh()
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
        }
    }
}
```

- [ ] **Step 2: Add models tab**

Update the `TabView` in `AFM Studio/Views/AFMStudioView.swift`:

```swift
TabView {
    ChatWorkspaceView(registry: registry, chatStore: resolvedChatStore)
        .tabItem {
            Label("Chat", systemImage: "bubble.left.and.bubble.right")
        }
    NavigationStack {
        CompareView(registry: registry)
    }
    .tabItem {
        Label("Compare", systemImage: "rectangle.split.3x1")
    }
    NavigationStack {
        BenchmarkView(registry: registry)
    }
    .tabItem {
        Label("Benchmarks", systemImage: "speedometer")
    }
    NavigationStack {
        ModelSettingsView(registry: registry)
    }
    .tabItem {
        Label("Models", systemImage: "square.stack.3d.up")
    }
}
```

- [ ] **Step 3: Build and commit**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer /Applications/Xcode-beta.app/Contents/Developer/usr/bin/xcodebuild -project "AFM Studio.xcodeproj" -scheme "AFM Studio" -destination 'platform=macOS' build
```

Expected: build succeeds.

Commit:

```bash
git add "AFM Studio/Views/Settings/ModelSettingsView.swift" "AFM Studio/Views/AFMStudioView.swift"
git commit -m "Add model status settings"
```

## Task 10: Manual Verification Pass

**Files:**
- Modify only files needed to fix verification failures from this task.

- [ ] **Step 1: Build macOS with Xcode beta**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer /Applications/Xcode-beta.app/Contents/Developer/usr/bin/xcodebuild -project "AFM Studio.xcodeproj" -scheme "AFM Studio" -destination 'platform=macOS' build
```

Expected: build succeeds.

- [ ] **Step 2: Build iOS simulator with Xcode beta**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer /Applications/Xcode-beta.app/Contents/Developer/usr/bin/xcodebuild -project "AFM Studio.xcodeproj" -scheme "AFM Studio" -destination 'generic/platform=iOS Simulator' build
```

Expected: build succeeds.

- [ ] **Step 3: Run macOS app**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer /Applications/Xcode-beta.app/Contents/Developer/usr/bin/xcodebuild -project "AFM Studio.xcodeproj" -scheme "AFM Studio" -destination 'platform=macOS' -derivedDataPath /tmp/AFMStudioDerivedData build
```

Expected: build succeeds and creates:

```text
/tmp/AFMStudioDerivedData/Build/Products/Debug/AFM Studio.app
```

Then run:

```bash
open "/tmp/AFMStudioDerivedData/Build/Products/Debug/AFM Studio.app"
```

Expected: app launches to a chat workspace with tabs for Chat, Compare, Benchmarks, and Models.

- [ ] **Step 4: Verify UI flows**

Manual checks:

- Chat tab shows model picker and composer.
- Models tab lists Apple System Model, Private Cloud Compute on OS 27, and Gemma 4 E2B Instruct.
- Gemma row status states package validation or working state.
- Compare tab allows at least two selected models and records errors inline.
- Benchmarks tab runs the starter suite and records each result row.

- [ ] **Step 5: Commit verification fixes**

If code changes were required:

```bash
git add "AFM Studio"
git commit -m "Polish AFM Studio MVP verification"
```

If no code changes were required, do not create an empty commit.

## Completion Criteria

- macOS build passes with Xcode beta.
- iOS simulator build passes with Xcode beta.
- App launches on macOS.
- Chat workspace is the first usable screen.
- System and PCC descriptors appear where supported.
- PCC status includes quota text on OS 27.
- Gemma 4 E2B appears in the Local MLX lane with working or gated package status.
- Compare and Benchmark routes use the same `SessionFactory` path as chat.
- No non-AFM provider router is introduced.
