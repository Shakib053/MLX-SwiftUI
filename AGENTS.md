# AGENTS.md

Instructions for Codex and other coding agents working in this repository.

## Project Snapshot

This is a native iOS SwiftUI app for local-first LLM chat using Apple MLX, MLX Swift LM, Hugging Face model loading, and a simulator-only hosted fallback. The main app target lives under `MLX-SwiftUI/`; the widget extension lives under `MLX_SwiftUIWidget/`.

Important areas:

- `MLX-SwiftUI/App`: app entry point, root state, tabs, and top-level navigation.
- `MLX-SwiftUI/Core`: shared domain and MLX model loading.
- `MLX-SwiftUI/Features/Chats`: chat domain, persistence, safety, backend selection, and UI.
- `MLX-SwiftUI/Features/Models`: model catalog, model detail, and model selection UI.
- `MLX-SwiftUI/Features/Settings`: settings, licenses, feedback, and appearance controls.
- `MLX-SwiftUI/Shared`: reusable UI primitives and shared widget data.
- `MLX_SwiftUIWidget`: WidgetKit surfaces that should stay in sync with shared data contracts.

## Karpathy-Inspired Execution

Apply the four principles from the `karpathy-guidelines` skill. Use judgment for trivial, obvious changes; apply the full process for ambiguous, risky, or multi-step work.

### Think Before Coding

- Read the relevant code before proposing an implementation.
- State material assumptions. If multiple interpretations would change behavior, present them or ask before choosing.
- Surface meaningful tradeoffs and propose the simplest sound approach. Push back when the requested approach adds unnecessary complexity.
- Stop and ask when essential context is missing. Do not hide confusion behind a plausible guess.

### Simplicity First

- Write the minimum code that solves the requested problem.
- Do not add unrequested features, speculative configuration, or flexibility for hypothetical future uses.
- Do not add an abstraction for one call site. Prefer direct, readable code until repeated use establishes a need.
- Handle realistic failure modes at system boundaries. Do not add defensive branches for impossible states.
- If an implementation is much larger or more complicated than the behavior requires, simplify it before finishing.

### Surgical Changes

- Every changed line must trace directly to the request or be necessary to keep the requested change correct.
- Do not reformat, rewrite comments, or improve adjacent code that is unrelated to the task.
- Match the surrounding naming, formatting, and architecture, even when a different style is personally preferable.
- Remove imports, variables, functions, and files made unused by the current change. Report pre-existing dead code; do not delete it unless asked.

### Goal-Driven Execution

- Define observable success criteria before implementation. For bugs, reproduce the issue first when practical.
- For multi-step work, state a short plan where every step names its verification check.
- Work in small loops: make one coherent change, verify it, then continue.
- Do not claim completion until the relevant success criteria have been checked. State any checks that could not be run.

## Repo Rules

- Preserve existing architecture. Put feature-specific state and components inside the relevant `Features/*` folder.
- Use `Core` only for app-wide models and services. Use `Shared` only for reusable UI/data used across multiple areas.
- Keep SwiftUI views decomposed by responsibility, not by arbitrary size limits.
- Do not introduce new dependencies unless the task clearly requires one.
- Do not commit secrets. `Secrets.xcconfig` is local-only; use `Secrets.example.xcconfig` for documented placeholders.
- Avoid broad refactors while fixing narrow bugs.
- Respect user changes in the working tree. Never revert unrelated modifications.

## Swift And SwiftUI Conventions

- Prefer value types, `let`, small structs, and explicit access control where helpful.
- Use Swift concurrency idiomatically: `async`/`await`, `Task`, `MainActor`, and cancellation-aware code.
- Keep UI state on the main actor. Do not mutate observed UI state from background work.
- Use `@Observable`/Observation patterns consistently with the existing app.
- Keep view modifiers readable. Extract repeated visual language into `Shared/UI` only when reused.
- Prefer SF Symbols for iconography.
- Keep text, colors, spacing, and controls consistent with the existing design system.
- Handle loading, empty, error, retry, and disabled states for user-facing async workflows.
- For widgets, keep timelines lightweight and avoid sharing app-only assumptions with extension code.

## MLX And Chat Behavior

- Treat model loading as expensive and failure-prone. Preserve clear loading, ready, error, and retry states.
- Keep simulator behavior separate from physical-device MLX behavior.
- Do not accidentally trigger local MLX model downloads on simulator paths.
- Keep Hugging Face token handling behind configuration. Never hardcode tokens.
- Make chat backend behavior testable by keeping domain logic separate from SwiftUI rendering.
- Be careful with streaming, cancellation, and repeated sends. A user should not be able to corrupt chat state by tapping quickly.
- Preserve local-first behavior on physical devices.

## Editing Checklist

Before editing:

1. Read the relevant files.
2. State assumptions and success criteria; resolve ambiguity that would change behavior.
3. Identify the smallest change that meets those criteria.
4. Check whether the change touches app state, async work, persistence, widgets, or secrets.

While editing:

1. Keep changes scoped to the request.
2. Match existing naming and formatting.
3. Prefer explicit branch handling over implicit fallthrough in user-facing state machines.
4. Add comments only when they explain non-obvious reasoning.
5. Remove only code made unused by the current change.

After editing:

1. Run the narrowest check that proves each success criterion, then build the affected target when feasible.
2. Inspect failures carefully; fix the root cause, not the symptom.
3. Report the criteria verified and any verification that could not be run.

## Build And Verification

Primary build command:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project MLX-SwiftUI.xcodeproj -scheme MLX-SwiftUI -destination 'generic/platform=iOS' -configuration Debug -derivedDataPath /tmp/MLX-SwiftUI-device-derived CODE_SIGNING_ALLOWED=NO build
```

The project expects a local `Secrets.xcconfig`. For builds that do not exercise the hosted fallback, a temporary placeholder is sufficient; do not commit it. For simulator fallback testing, use a valid `HF_TOKEN` as described in `README.md`.

Simulator build command, matching CI:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project MLX-SwiftUI.xcodeproj -scheme MLX-SwiftUI -configuration Debug -destination 'generic/platform=iOS Simulator' -skipMacroValidation CODE_SIGNING_ALLOWED=NO clean build
```

For focused compiler output:

```sh
set -o pipefail
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project MLX-SwiftUI.xcodeproj -scheme MLX-SwiftUI -destination 'generic/platform=iOS' -configuration Debug -derivedDataPath /tmp/MLX-SwiftUI-device-derived CODE_SIGNING_ALLOWED=NO build 2>&1 | rg -C 5 'error:|fatal error:|BUILD (SUCCEEDED|FAILED)'
```

Use simulator builds when checking the hosted fallback. In `DEBUG` simulator builds, the normal and hosted-only download scenarios use the hosted backend; the other simulated scenarios can exercise local-load states. Use physical-device generic builds when checking MLX/device compatibility.

## Common Pitfalls

- SwiftUI state updates from background tasks.
- Async tasks continuing after a view model or user action has moved on.
- Model downloads or MLX paths running in simulator unexpectedly.
- Widget extension code depending on APIs unavailable to extensions.
- Secrets, local config, or derived data entering source control.
- Creating shared abstractions before two real call sites exist.

## Review Guidance

When reviewing changes, lead with bugs and regressions:

- Correctness: state flow, async cancellation, persistence, and model loading.
- Platform behavior: simulator vs device, app target vs widget extension.
- User experience: loading/error states, disabled controls, accessibility labels, and layout on compact screens.
- Security: token handling and accidental secret exposure.
- Maintainability: unnecessary abstraction, duplicated state, or unclear ownership.

Summaries are secondary. Findings should be concrete and tied to files and lines.
