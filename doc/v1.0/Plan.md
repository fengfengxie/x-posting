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
- Keychain for X OAuth 1.0a credential storage
- UserDefaults-backed settings storage for DeepSeek configuration and API key
- Swift Package Manager build and test

## Data Model Plan
- `Draft`: text, timestamps.
- `AppSettings`: DeepSeek and X configuration.
- `PolishRequest` + `PolishResponse`.
- `PostSegment` + `PublishPlan` + `PublishResult`.
- `XCredentials` (OAuth 1.0a API key + access token pairs).

## UI / UX Plan
- Menubar popover for quick draft + polish/publish/copy.
- Menubar includes draft, live count, polish, and publish controls without opening a second compose surface.
- Settings page for DeepSeek and X API credentials.
- Failure UX: show error banner and keep content unchanged.

## Implementation Phases
1. Foundation
- Package scaffolding.
- Core models and stores.
- Menubar-first app skeleton.

2. Core workflow
- Character limit analysis and split preview.
- DeepSeek polish with single minimal-edit behavior.
- Local persistence and clipboard flow.

3. X integration
- OAuth 1.0a signing (user pastes 4 keys from X Developer Portal).
- Publish single post/thread with text only.
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
- OAuth 1.0a uses HMAC-SHA1 request signing; tokens never expire and no browser redirect is needed.
