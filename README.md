# MLX-SwiftUI

Native iOS chat app that runs a local LLM experience with SwiftUI, Apple MLX, MLX Swift LM, and Hugging Face model loading.

## Overview

MLX-SwiftUI is a compact on-device AI chat application built to demonstrate practical local language model integration on iOS. The app loads Qwen3 0.6B 4-bit through MLX/Hugging Face, creates a chat session, and provides a polished SwiftUI interface for sending prompts and reading responses.

## Features

- On-device chat interface built with SwiftUI.
- Qwen3 0.6B 4-bit model loading through MLX and Hugging Face.
- Async model initialization and prompt handling.
- Loading, ready, error, and retry UI states.
- Clean chat composer with user and assistant message bubbles.
- Local-first interaction flow without relying on a hosted API.

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
- `ChatViewModel` handles model loading, session creation, prompt submission, response updates, and chat state.


## Getting Started

1. Open `MLX-SwiftUI.xcodeproj` in Xcode.
2. Allow Swift Package Manager to resolve dependencies.
3. Build and run the app on an iPhone or iPad simulator/device.
4. On first launch, the model may need to download. Later launches reuse the cached model.

## Future Improvements

- Fallback for simulators and model download failure.
- Streaming responses.
- Chat history persistence.
- Model selection.
- Better error handling.
- Performance optimization.
