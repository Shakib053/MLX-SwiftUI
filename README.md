# MLX-SwiftUI

Native iOS AI app for chatting and working with text, images, and documents using SwiftUI, Apple MLX, and Apple Foundation Models.

## Overview

MLX-SwiftUI is a local-first AI workspace for iOS. It offers chat alongside focused tools for summarizing, rewriting, extracting details, reading text from images, and analyzing documents. On physical devices, it can use Apple Foundation Models when available or download an MLX model from its catalog.

## Features

- **Chat:** Stream responses, continue saved conversations, regenerate a response, and switch between available models.
- **Task workspace:** Summarize or rewrite text, extract dates and action items, read text from photos, and analyze imported documents. Save useful results for later.
- **History:** Search saved conversations and task results; rename, pin, or delete conversations.
- **Model catalog:** Choose from Qwen 3 0.6B, Gemma 3 1B, and Llama 3.2 1B 4-bit MLX models on physical devices. Track downloads and retry failed loads.
- **On-device options:** Use Apple Foundation Models when available, or select a downloaded MLX model as the default for new chats.
- **Personalization:** Choose system, light, or dark appearance and toggle haptic feedback.

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
│   ├── Home
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
- `MainTabView` owns type-safe navigation between Home, Models, History, and Settings.
- Each folder under `Features` owns its screens, state, and feature-specific components.
- `ChatViewModel` selects the chat backend and coordinates model initialization, prompts, streaming responses, and chat state.
- `Core/Models` contains application-wide domain models, while `Shared/UI` contains presentation primitives used by multiple features.


## Getting Started

1. Open `MLX-SwiftUI.xcodeproj` in Xcode.
2. Allow Swift Package Manager to resolve dependencies.
3. Build and run the app on an iPhone, iPad, or simulator.
4. On physical devices, the model may need to download on first launch. Later launches reuse the cached model.
5. On simulator, the app uses Apple Foundation Models when they are available; it does not call a hosted chat provider.

## Localization

The app uses Apple's native String Catalogs. `MLX-SwiftUI/Localizable.xcstrings` contains app text, and `MLX-SwiftUI/InfoPlist.xcstrings` contains the camera permission description. English is the source language. Additional languages can be added in Xcode's catalog editor; no localization package or custom language manager is required.

To add a language, open each catalog in Xcode, click **+** in the language sidebar, select the language, and enter its translations. Build in Xcode to update extracted strings. For command-line extraction, use `xcodebuild -exportLocalizations -project MLX-SwiftUI.xcodeproj -localizationPath /tmp/MLX-SwiftUI-localizations -exportLanguage en CODE_SIGNING_ALLOWED=NO`. Test using **Product > Scheme > Edit Scheme > Run > Options > App Language**, including the double-length and right-to-left pseudolanguages for layout checks. The app uses the user's system or per-app language preference when translations are available.

Keep literal SwiftUI labels such as `Text("Settings")` as they are. Use `LocalizedStringKey` for reusable view parameters containing interface labels, and `String(localized: "…")` when app code needs a translated `String`, including status messages and errors. Preserve interpolation so translations can reorder values, and use catalog plural variants for counts. Picker tags, persistence identifiers, model names, and AI prompt instructions remain stable; user content and generated responses are not translated by the catalog. Existing saved conversation titles and task content retain their stored text.
