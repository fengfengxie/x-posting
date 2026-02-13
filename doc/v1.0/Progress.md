# Progress

## Phase 1: Foundation (Completed)
- [x] Set up Swift package targets (`XPostingCore`, `XPostingApp`, tests).
- [x] Implement baseline menubar app with popover and composer window.
- [x] Add local draft and settings persistence primitives.

## Phase 2: Core Workflow (Completed)
- [x] Implement character limit analysis and thread segmentation preview.
- [x] Implement DeepSeek polish service with tone presets.
- [x] Add output language options for polishing (`auto` / `en` / `cn`).
- [x] Add clipboard and single-image draft attachment flow.

## Phase 3: X Integration (Completed)
- [x] Implement OAuth 1.0a signing (HMAC-SHA1) and credential storage.
- [x] Implement X publish service for post/thread flow.
- [x] Implement publish failure handling that keeps draft content and supports manual copy.

## Phase 4: Quality and Tooling (Completed)
- [x] Add unit tests for character limits, draft persistence, OAuth 1.0a signer, and credential service.
- [x] Wire `script/build.sh` and `script/test.sh` to real commands.
- [x] Update v1.0 docs from templates to current MVP spec.

## Notes
- Date: 2026-02-13
- Current publish integration includes single image upload path and thread posting logic.
- Migrated from OAuth 2.0 PKCE to OAuth 1.0a: user pastes 4 keys from X Developer Portal, no browser redirect needed, tokens never expire.
- Bugfix: DeepSeek API key is now directly editable/pastable in settings and saved in app settings (no Keychain fetch path for DeepSeek key).
- Bugfix: X API settings inputs now use stable local edit state to prevent typing loss in Settings window, and settings window explicitly activates app focus on appear.
- Bugfix: Settings moved from SwiftUI `Settings` scene to a dedicated window scene opened via `openWindow(id:)`, ensuring keyboard focus is captured instead of leaking to background terminal.
- UX: Menubar `Open Composer` and `Settings` controls are now clearly styled as clickable buttons, and a `Quit` button was added to the menubar panel.
- UI polish: Menubar quick draft editor now applies inner padding so typed text no longer visually collides with the editor border.
- UX: Menubar quick draft now supports direct image attach/remove operations with attached-file visibility, so users can publish image posts without opening the full composer.
