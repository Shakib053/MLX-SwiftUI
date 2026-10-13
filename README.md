# MLX-SwiftUI

Native iOS chat app that runs a local LLM experience with SwiftUI, Apple MLX, and Apple Foundation Models as an on-device fallback.

## Overview

MLX-SwiftUI is a compact AI chat application built to demonstrate practical local language model integration on iOS. On physical devices, the app can load Qwen3 0.6B 4-bit, Gemma 3 1B 4-bit, or Llama 3.2 1B 4-bit through MLX. When a local model cannot be used, the app falls back to Apple Foundation Models when they are available.

## Features

- On-device chat interface built with SwiftUI.
- Qwen3 0.6B 4-bit model loading through MLX.
- Gemma 3 1B QAT 4-bit and Llama 3.2 1B 4-bit model downloads.
- Persistent model selection with up to two locally cached models.
- Apple Foundation Models fallback that keeps chat processing on device.
- Async model initialization and prompt handling.
- Loading, ready, error, and retry UI states.
- Clean chat composer with user and assistant message bubbles.
- Local-first interaction flow on physical devices.

## Project Structure

```text
MLX-SwiftUI
├── App
│   ├── MLXSwiftUIApp.swift
│   ├── ContentView.swift
│   ├── MainTabView.swift
│   ├── AppState.swift
│   └── AppTab.swift
├── Core
│   └── Models
├── Features
│   ├── Chats
│   ├── Models
│   ├── Onboarding
│   └── Settings
└── Shared
    └── UI
```

## Tech Stack

- Swift
- SwiftUI
- Observation framework
- MLX Swift LM for local model downloads and inference
- Tokenizers

## Architecture

- `MLXSwiftUIApp` defines the app entry point and launches the main SwiftUI scene.
- `ContentView` owns application state, appearance, and onboarding presentation.
- `MainTabView` owns type-safe navigation between Chats, Models, and Settings.
- Each folder under `Features` owns its screens, state, and feature-specific components.
- `ChatViewModel` selects the chat backend and coordinates model initialization, prompts, streaming responses, and chat state.
- `Core/Models` contains application-wide domain models, while `Shared/UI` contains presentation primitives used by multiple features.


## Getting Started

1. Open `MLX-SwiftUI.xcodeproj` in Xcode.
2. Allow Swift Package Manager to resolve dependencies.
3. Build and run the app on an iPhone, iPad, or simulator.
4. On physical devices, the model may need to download on first launch. Later launches reuse the cached model.
5. On simulator, the app uses Apple Foundation Models when they are available; it does not call a hosted chat provider.

## Future Improvements

- Streaming responses.
- Chat history persistence.
- Additional model families and configurable model limits.
- Better error handling.
- Performance optimization.

## Localization

The app uses Apple's native String Catalogs. `MLX-SwiftUI/Localizable.xcstrings` contains app text, and `MLX-SwiftUI/InfoPlist.xcstrings` contains the camera permission description. English is the source language. Additional languages can be added in Xcode's catalog editor; no localization package or custom language manager is required.

To add a language, open each catalog in Xcode, click **+** in the language sidebar, select the language, and enter its translations. Build in Xcode to update extracted strings. For command-line extraction, use `xcodebuild -exportLocalizations -project MLX-SwiftUI.xcodeproj -localizationPath /tmp/MLX-SwiftUI-localizations -exportLanguage en CODE_SIGNING_ALLOWED=NO`. Test using **Product > Scheme > Edit Scheme > Run > Options > App Language**, including the double-length and right-to-left pseudolanguages for layout checks. The app uses the user's system or per-app language preference when translations are available.

Keep literal SwiftUI labels such as `Text("Settings")` as they are. Use `LocalizedStringKey` for reusable view parameters containing interface labels, and `String(localized: "…")` when app code needs a translated `String`, including status messages and errors. Preserve interpolation so translations can reorder values, and use catalog plural variants for counts. Picker tags, persistence identifiers, model names, and AI prompt instructions remain stable; user content and generated responses are not translated by the catalog. Existing saved conversation titles and task content retain their stored text.
