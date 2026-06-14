# AFM Studio

[![GitHub stars](https://img.shields.io/github/stars/Techopolis/AFM-Studio?style=social)](https://github.com/Techopolis/AFM-Studio/stargazers)
[![GitHub forks](https://img.shields.io/github/forks/Techopolis/AFM-Studio?style=social)](https://github.com/Techopolis/AFM-Studio/forks)
[![GitHub issues](https://img.shields.io/github/issues/Techopolis/AFM-Studio)](https://github.com/Techopolis/AFM-Studio/issues)
[![GitHub pull requests](https://img.shields.io/github/issues-pr/Techopolis/AFM-Studio)](https://github.com/Techopolis/AFM-Studio/pulls)
[![Last commit](https://img.shields.io/github/last-commit/Techopolis/AFM-Studio)](https://github.com/Techopolis/AFM-Studio/commits/main)
![Platforms](https://img.shields.io/badge/platform-macOS%20%7C%20iOS-lightgrey)
![Xcode](https://img.shields.io/badge/Xcode-27%20beta-blue)

AFM Studio is an open-source Mac and iOS app for trying, comparing, and benchmarking language models through Apple's Foundation Models framework.

The project is built for the OS 27 / Xcode 27 beta cycle. It focuses on the Apple Foundation Models path first: system models, Private Cloud Compute, and Core AI model bundles loaded through the Foundation Models provider support. MLX support is intentionally not wired into the app right now; it can return when Apple ships a Foundation Models-ready MLX language model package.

## What It Does

- Chat with models through `LanguageModelSession`.
- Select Apple system, Private Cloud Compute, and Core AI-backed models from one model registry.
- Add local Core AI model bundles from disk.
- Compare one prompt across multiple selected models.
- Run local benchmark suites and save results with SwiftData.
- Inspect Private Cloud Compute availability and quota status where supported.
- Parse model output channels so assistant text, final output, and thinking/reasoning traces do not render as raw protocol tags.
- Use a native SwiftUI interface with a macOS Settings scene, iOS Settings tab, SF Symbols, and VoiceOver-friendly row labels.

## Current Model Support

AFM Studio currently routes generation through Foundation Models sessions:

- `SystemLanguageModel.default`
- `PrivateCloudComputeLanguageModel` on supported OS 27 platforms
- `CoreAILanguageModel(resourcesAt:variant:kvCacheStrategy:)` when the Apple `coreai-models` package is linked

The built-in Core AI catalog includes:

- Gemma 4 E2B Core AI bundle from the community CoreAI model zoo
- Gemma 4 E4B Core AI bundle from the community CoreAI model zoo
- Gemma 3 4B Instruct from Apple's `coreai-models`
- Gemma 3 12B Instruct from Apple's `coreai-models`
- GPT-OSS 20B from Apple's `coreai-models`

Large model artifacts are not committed to this repository. Local exports belong under `CoreAIModelExports/`, which is ignored by Git.

## Requirements

- macOS with Xcode 27 beta installed at:

  ```bash
  /Applications/Xcode-beta.app/Contents/Developer
  ```

- Apple OS 27 SDKs for building the app.
- SwiftUI, SwiftData, FoundationModels, and the Apple `coreai-models` Swift package dependency.
- An Apple Developer Program team for entitlement-backed Foundation Models features. Private Cloud Compute access has additional Apple eligibility requirements.
- Optional for local model export: `uv`, expected by `scripts/export-coreai-models.sh`.

## Private Cloud Compute Entitlement

Private Cloud Compute is separate from Foundation Models adapter/provider work. AFM Studio's PCC path uses Apple's built-in `PrivateCloudComputeLanguageModel` and the managed entitlement `com.apple.developer.private-cloud-compute`.

Apple documents PCC setup in [Adding server-side intelligence with Private Cloud Compute](https://developer.apple.com/documentation/foundationmodels/adding-server-side-intelligence-with-private-cloud-compute) and documents the entitlement at [com.apple.developer.private-cloud-compute](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.private-cloud-compute). Request access from Apple's [Private Cloud Compute](https://developer.apple.com/private-cloud-compute/) page using the [Get the entitlement](https://developer.apple.com/contact/request/private-cloud-compute/) flow.

As of the OS 27 beta documentation, Apple lists these access requirements:

- Enrollment in the App Store Small Business Program.
- Fewer than 2 million first-time App Store downloads across your apps.
- The Private Cloud Compute entitlement assigned to your Apple Developer account.

To enable it for your own builds:

1. Sign in to the Apple Developer account that owns your app identifier.
2. Confirm the team meets Apple's PCC eligibility requirements on the [Private Cloud Compute](https://developer.apple.com/private-cloud-compute/) page.
3. Request the Private Cloud Compute entitlement with Apple's [Get the entitlement](https://developer.apple.com/contact/request/private-cloud-compute/) flow.
4. After approval, open `AFM Studio.xcodeproj` in Xcode 27 beta.
5. Select the `AFM Studio` app target, then open `Signing & Capabilities`.
6. Choose your development team and a bundle identifier that has the approved Private Cloud Compute entitlement.
7. Let Xcode create or update the app entitlements file and provisioning profile. The entitlement file should contain Apple's PCC key, `com.apple.developer.private-cloud-compute`, set to `true`.
8. Do not request or add adapter/provider entitlements just to use PCC. Those are for custom Foundation Models provider work, not `PrivateCloudComputeLanguageModel`.
9. Build and run on a supported OS 27 Mac or device, then refresh the model registry in AFM Studio. The Private Cloud Compute row should report availability and quota through `PrivateCloudComputeLanguageModel.availability` and `quotaUsage`.

Do not commit personal provisioning profiles, signing certificates, or Xcode user state. Commit only project and entitlement-file changes that are required for the shared open-source target.

## Getting Started

From the repository root, build with the beta toolchain:

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
/Applications/Xcode-beta.app/Contents/Developer/usr/bin/xcodebuild \
  -project "AFM Studio.xcodeproj" \
  -scheme "AFM Studio" \
  -destination 'platform=macOS' \
  -derivedDataPath /private/tmp/AFMStudioDerivedData \
  build
```

For a generic iOS device compile check:

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
/Applications/Xcode-beta.app/Contents/Developer/usr/bin/xcodebuild \
  -project "AFM Studio.xcodeproj" \
  -scheme "AFM Studio" \
  -destination 'generic/platform=iOS' \
  -derivedDataPath /private/tmp/AFMStudioDerivedData-iOS \
  CODE_SIGNING_ALLOWED=NO \
  build
```

The iOS Simulator path can be limited by the beta SDK and Apple's Core AI package availability. Prefer macOS and generic iOS device builds for repository verification until the simulator SDK includes the needed Core AI framework surface.

## Local Core AI Models

AFM Studio can detect installed Core AI model bundles from app Application Support:

```text
~/Library/Containers/online.techopolis.afmstudio/Data/Library/Application Support/AFM Studio/CoreAIModels/
```

To export Apple's supported Core AI presets locally, first make sure the `coreai-models` package checkout exists under the derived data path, then run:

```bash
bash scripts/export-coreai-models.sh gemma3-4b
bash scripts/export-coreai-models.sh gemma3-12b
bash scripts/export-coreai-models.sh gpt-oss-20b
```

Or export all three:

```bash
bash scripts/export-coreai-models.sh all
```

To install exported bundles into the macOS app container for local testing:

```bash
bash scripts/install-coreai-models-local.sh all
```

The install script currently supports:

- `gemma3-4b`
- `gemma3-12b`
- `gpt-oss-20b`
- `all`

## Project Layout

```text
AFM Studio/
  AFMStudioApp.swift                 App entry point and scenes
  ContentView.swift                  Root host
  Models/                            SwiftData records and model metadata
  Services/                          Registry, session factory, stores, Core AI support
  Views/                             SwiftUI chat, models, compare, benchmarks, settings
scripts/
  export-coreai-models.sh            Local Apple Core AI export helper
  install-coreai-models-local.sh     Local app-container install helper
docs/superpowers/
  specs/                             Design notes
  plans/                             Implementation plans
```

## Development Notes

- Keep generation routed through `LanguageModelSession`.
- Keep provider-specific setup isolated behind services such as `SessionFactory`, `ModelRegistry`, and `CoreAILanguageModelSupport`.
- Do not commit exported model bundles, derived data, or local app-container artifacts.
- Prefer native SwiftUI controls and SF Symbols.
- Keep VoiceOver behavior explicit on custom rows, cards, and icon-heavy controls.
- Use Xcode beta for verification unless a task explicitly targets the stable Xcode install.

## Verification

Before opening a pull request, run:

```bash
git diff --check

DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
/Applications/Xcode-beta.app/Contents/Developer/usr/bin/xcodebuild \
  -project "AFM Studio.xcodeproj" \
  -scheme "AFM Studio" \
  -destination 'platform=macOS' \
  -derivedDataPath /private/tmp/AFMStudioDerivedData \
  build

DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
/Applications/Xcode-beta.app/Contents/Developer/usr/bin/xcodebuild \
  -project "AFM Studio.xcodeproj" \
  -scheme "AFM Studio" \
  -destination 'generic/platform=iOS' \
  -derivedDataPath /private/tmp/AFMStudioDerivedData-iOS \
  CODE_SIGNING_ALLOWED=NO \
  build
```

## Roadmap

- Improve Core AI bundle download and installation flows.
- Add richer benchmark metrics, including throughput when APIs expose enough timing data.
- Add quota and usage views for supported Foundation Models providers.
- Revisit MLX when Apple provides a Foundation Models-compatible MLX language model package.
- Add server-provider support only through Foundation Models provider interfaces.

## Contributors

Thanks to everyone who has contributed to AFM Studio.

[![Contributors](https://contrib.rocks/image?repo=Techopolis/AFM-Studio)](https://github.com/Techopolis/AFM-Studio/graphs/contributors)

Made with [contrib.rocks](https://contrib.rocks).

## License

AFM Studio is intended to be open source. Add a `LICENSE` file before public release so contributors and users know the exact terms.
