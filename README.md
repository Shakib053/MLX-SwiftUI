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
