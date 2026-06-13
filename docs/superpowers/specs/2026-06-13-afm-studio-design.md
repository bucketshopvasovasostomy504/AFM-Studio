# AFM Studio Design

Date: 2026-06-13
Status: Design direction approved; written spec awaiting user review

## Goal

AFM Studio is an open-source multiplatform Mac and iOS app for trying, comparing, and benchmarking models exposed through Apple's Foundation Models framework in the 27 releases. The app provides a Perspective Intelligence-inspired chat interface, model picker, model management, quota visibility, benchmark runs, and side-by-side comparison.

The app uses a single multiplatform Xcode target and builds against Xcode beta:

`/Applications/Xcode-beta.app/Contents/Developer`

## Product Scope

AFM Studio supports these model lanes as first-class Foundation Models models:

1. Apple system model via `SystemLanguageModel`.
2. Private Cloud Compute via `PrivateCloudComputeLanguageModel`.
3. Local MLX models via Apple's open-source `MLXFoundationModels` package and `MLXLanguageModel`.
4. Future Core AI models via Apple's open-source Core AI Foundation Models provider package when the package/API is available.
5. Future server providers through Foundation Models custom `LanguageModel` / `LanguageModelExecutor` implementations, including OpenAI-compatible APIs.

All user-facing chat, comparison, benchmarking, and usage surfaces route through `LanguageModelSession`. The app does not build or expose a separate non-AFM provider router.

## Non-Goals

- No standalone OpenAI, Ollama, or MLX chat client outside Foundation Models.
- No custom MLX executor in v1 unless `MLXFoundationModels` cannot support the selected Gemma path.
- No marketing-style landing page. The first screen is the usable chat workspace.
- No image-heavy design exploration for the first spec. The UI direction is text-only and based on Perspective Intelligence's chat behavior.

## References

- Foundation Models: https://developer.apple.com/documentation/foundationmodels
- Private Cloud Compute with Foundation Models: https://developer.apple.com/documentation/foundationmodels/adding-server-side-intelligence-with-private-cloud-compute
- WWDC26 "What is new in Foundation Models": https://developer.apple.com/videos/play/wwdc2026/241/
- WWDC26 "Bring an LLM provider to the Foundation Models framework": https://developer.apple.com/videos/play/wwdc2026/339/
- MLX Swift LM: https://github.com/ml-explore/mlx-swift-lm
- Core AI Models: https://github.com/apple/coreai-models
- Gemma 4: https://deepmind.google/models/gemma/gemma-4/

## Architecture

AFM Studio uses a small set of boundaries:

- `ModelRegistry` lists all available and configured models.
- `ModelDescriptor` stores stable app metadata: id, display name, provider lane, capabilities, availability, quota source, and default generation settings.
- `SessionFactory` converts a selected descriptor into a `LanguageModelSession`.
- `ChatStore` owns conversations, messages, selected model, transcript snapshots, and run metadata.
- `BenchmarkRunner` runs repeatable prompts against one selected model or a comparison set.
- `ComparisonRunner` sends the same prompt to multiple selected descriptors and captures output, latency, usage, reasoning availability, and errors.
- `CredentialStore` stores server-provider API keys in Keychain when server providers are implemented.

The important invariant is that UI code does not know whether a response came from system, PCC, MLX, Core AI, or a server provider. It observes a session run and rendered result metadata.

## Model Lanes

### Apple System

The system model is always listed when the OS supports Foundation Models. Availability is read from `SystemLanguageModel.availability`. The UI shows unavailable reasons plainly and disables send only for the affected model.

### Private Cloud Compute

PCC uses `PrivateCloudComputeLanguageModel`. The registry surfaces availability, quota status, limit reached state, reset date, and Apple's limit increase suggestion when available.

PCC exposes reasoning level controls backed by `ContextOptions.reasoningLevel` with `light`, `moderate`, and `deep`. Reasoning controls are shown only for models that advertise reasoning capability or are known PCC descriptors.

### MLX

MLX support uses Apple's provider package:

```swift
import FoundationModels
import MLXFoundationModels

let model = MLXLanguageModel(modelID: descriptor.modelID)
let session = LanguageModelSession(model: model)
```

The app constructs `MLXLanguageModel` with the selected descriptor's concrete model ID. The first local model target is Gemma 4 E2B Instruct. The initial descriptor uses a small quantized MLX community variant as the default candidate. The implementation must validate the final model ID during implementation because model repository names can change.

MLX model management tracks:

- model ID
- local download/cache state
- load state
- quantization label when known
- estimated disk size when known
- last run latency and token throughput
- runtime errors such as missing model files, unsupported architecture, out-of-memory, or tokenizer/template failure

If `MLXFoundationModels` cannot run the chosen Gemma 4 E2B variant, v1 keeps the MLX lane and swaps the default model to the smallest working Gemma 4-compatible MLX model. A custom executor is reserved as a follow-up, not the first implementation path.

### Core AI

Core AI support is included as an architecture slot, not a v1 blocker. The app will add `CoreAILanguageModel` descriptors once Apple's open-source package is available and builds in this project.

### Server Providers

Server providers are represented as custom Foundation Models `LanguageModel` implementations. An OpenAI-compatible provider translates Foundation Models transcript, tools, schema, generation options, context options, and metadata into provider requests inside a `LanguageModelExecutor`.

Server provider responses must stream back through `LanguageModelExecutorGenerationChannel`, including text, reasoning when available, tool calls when supported, metadata, and token usage. Server providers are not allowed to bypass `LanguageModelSession`.

## UI Design

The UI follows Perspective Intelligence's chat shape:

- conversation list/sidebar on wide screens
- chat detail as the main surface
- compact title/model picker in the conversation header
- message stream with user and assistant turns
- composer anchored at the bottom
- add/model management entry from the model picker
- settings for provider configuration, quota, and local model cache

The first screen opens to the working chat workspace. It does not show a hero page.

The model picker groups models by lane:

- Apple
- Private Cloud
- Local MLX
- Core AI
- Server Providers

Each row shows name, availability, capability chips, and one small status line only when useful, such as quota approaching, local model not downloaded, or key missing.

## Chat Flow

Sending a message creates a run record with:

- conversation id
- model descriptor id
- prompt text
- generation options
- context options
- timestamp

`SessionFactory` creates a `LanguageModelSession` for the selected descriptor. Streaming updates append snapshots to the active assistant message. At completion, the run stores content, duration, usage, metadata, and any reported reasoning or tool-call details.

Failures are stored as message-level run errors, not modal-only errors. The user can switch model and retry from the failed message.

## Compare Flow

Comparison mode lets the user select two or more model descriptors and send one prompt to all selected models. Results appear side by side on macOS and stacked on iPhone.

Each result shows:

- model name
- output
- duration
- usage when available
- quota or rate-limit failure when relevant
- benchmark tags if the prompt came from a suite

Comparison runs reuse the same runner primitives as chat so they do not fork behavior.

## Benchmark Flow

Benchmarking starts with local prompt suites stored in the app bundle or app data. A suite contains prompts, optional tags, and expected measurement fields. V1 measures:

- time to first token when streaming data exposes it
- total duration
- output token count when reported
- input token count when reported
- tokens per second when possible
- error category

Benchmarks are local-first. No leaderboard or remote telemetry is included in v1.

## Data Persistence

Use SwiftData for:

- conversations
- messages
- run metadata
- model descriptors added by users
- benchmark suites and results
- local model cache metadata

Secrets such as server-provider API keys use Keychain. The app never stores plaintext API keys in conversation records, benchmark results, or logs.

## Error Handling

Errors are mapped into user-facing categories:

- unavailable model
- missing entitlement
- PCC quota reached
- rate limited
- network failure
- local model missing
- local model load failed
- unsupported capability
- context too large
- generation refused or blocked
- unknown provider error

The UI shows a short explanation and a direct recovery action when available: switch model, open model settings, download local model, retry, or show Apple's quota suggestion.

## Testing Strategy

Implementation should include focused tests for:

- model registry grouping and availability mapping
- descriptor to `LanguageModelSession` factory behavior
- PCC quota status formatting
- benchmark result aggregation
- comparison result ordering and error preservation
- server provider request mapping once server providers are added

Manual verification uses Xcode beta. Builds and simulator/device checks should set:

`DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer`

MLX verification must prove at least one prompt can run through:

`MLXLanguageModel -> LanguageModelSession -> AFM Studio chat renderer`

before the MLX lane is marked working.

## Implementation Order

1. Establish app shell and Perspective-style chat layout.
2. Add model registry with Apple system and PCC descriptors.
3. Add `LanguageModelSession` chat streaming.
4. Add MLXFoundationModels package and Gemma 4 E2B descriptor.
5. Implement MLX model status and first prompt verification.
6. Add compare mode using the same run pipeline.
7. Add benchmark suites and result storage.
8. Add server custom provider support through Foundation Models executor APIs.
9. Add Core AI provider support when the package/API is available.

## Acceptance Criteria

- The project remains a single multiplatform target for macOS and iOS.
- Builds use Xcode beta 27.
- The first screen is a usable chat workspace.
- The chat UI includes a Perspective-style model picker.
- System and PCC models can be selected where available.
- PCC quota status is visible when PCC is available.
- MLXFoundationModels is the first implementation path for local MLX models.
- Gemma 4 E2B Instruct is the first MLX target, with fallback to the smallest working Gemma 4-compatible MLX variant if the exact target cannot run.
- Compare mode can run one prompt across multiple selected models.
- Benchmark mode records repeatable local results.
- Server providers, when added, route through Foundation Models `LanguageModel` and `LanguageModelExecutor`.
