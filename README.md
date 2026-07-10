# MLX-SwiftUI

Native iOS chat app that runs a local LLM experience with SwiftUI, Apple MLX, MLX Swift LM, and Hugging Face model loading, with a hosted fallback for iOS Simulator builds.

## Overview

MLX-SwiftUI is a compact AI chat application built to demonstrate practical local language model integration on iOS. On physical devices, the app loads Qwen3 0.6B 4-bit through MLX/Hugging Face. On iOS Simulator, it skips local MLX model loading and uses Hugging Face Inference Providers through a hosted API fallback.

## Features

- On-device chat interface built with SwiftUI.
- Qwen3 0.6B 4-bit model loading through MLX and Hugging Face.
- Simulator-only Hugging Face API fallback using `openai/gpt-oss-120b:cerebras` that avoids local model downloads.
- Async model initialization and prompt handling.
- Loading, ready, error, and retry UI states.
- Clean chat composer with user and assistant message bubbles.
- Local-first interaction flow on physical devices.

## Project Structure

```text
MLX-SwiftUI
├── MLX_SwiftUIApp.swift
├── ContentView.swift
└── ChatViewModel.swift
```

## Tech Stack

- Swift
- SwiftUI
- Observation framework
- MLX Swift LM
- MLX Hugging Face integration
- Hugging Face Swift
- Tokenizers

## Architecture

- `MLX_SwiftUIApp` defines the app entry point and launches the main SwiftUI scene.
- `ContentView` manages the visible UI states, chat layout, message bubbles, loading view, error view, and composer.
- `ChatViewModel` selects the chat backend, handles model/API initialization, prompt submission, response updates, and chat state.


## Getting Started

1. Open `MLX-SwiftUI.xcodeproj` in Xcode.
2. Allow Swift Package Manager to resolve dependencies.
3. For simulator fallback support, copy `Secrets.example.xcconfig` to `Secrets.xcconfig`.
4. Add a Hugging Face token with Inference Providers permission:

   ```xcconfig
   HF_TOKEN = hf_your_token_here
   ```

5. Build and run the app on an iPhone, iPad, or simulator.
6. On physical devices, the model may need to download on first launch. Later launches reuse the cached model.
7. On simulator, the app does not download the local MLX model. It calls the hosted Hugging Face fallback instead.

## Future Improvements

- Streaming responses.
- Chat history persistence.
- Model selection.
- Better error handling.
- Performance optimization.
