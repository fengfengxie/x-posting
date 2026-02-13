# Plan

## Guiding Principles
- Keep posting flow fast and distraction-light.
- Preserve user content on all error paths.
- Keep integrations modular for API evolution.

## Technical Framework / Stack
- Swift 6
- SwiftUI + MenuBarExtra for UI
- AppKit utilities (clipboard)
- URLSession for network calls
- Keychain for secret/token storage
- Swift Package Manager build and test

## Data Model Plan
- `Draft`: text, image path, timestamps.
- `AppSettings`: DeepSeek and X configuration, default polish options.
- `PolishRequest` + `PolishResponse`.
- `PostSegment` + `PublishPlan` + `PublishResult`.
- `OAuthConfiguration` + `OAuthToken`.

## UI / UX Plan
- Menubar popover for quick draft + polish/publish/copy.
- Full composer window for long edits, thread preview, and image attach.
- Settings page for DeepSeek and X API credentials.
- Failure UX: show error banner and keep content unchanged.

## Implementation Phases
1. Foundation
- Package scaffolding.
- Core models and stores.
- Menubar + composer skeleton.

2. Core workflow
- Character limit analysis and split preview.
- DeepSeek polish with tone and output language controls.
- Local persistence and clipboard flow.

3. X integration
- OAuth PKCE flow.
- Publish single post/thread with optional single image.
- Failure handling and status reporting.

4. Hardening
- Unit tests for core logic.
- Build/test scripts wired.
- Documentation refresh.

## Definition of Done
- App builds via `script/build.sh`.
- Tests pass via `script/test.sh`.
- Draft/polish/preview/publish flows are wired.
- Docs (`PRD.md`, `Plan.md`, `Progress.md`) reflect implemented MVP.

## Notes
- Character counting is a configurable approximation and can be swapped if exact rules change.
- OAuth callback can be handled either by app URL callback or manual callback URL completion in MVP.
