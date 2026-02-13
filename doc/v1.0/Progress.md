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
- [x] Implement OAuth PKCE request + token exchange service.
- [x] Implement X publish service for post/thread flow.
- [x] Implement publish failure handling that keeps draft content and supports manual copy.

## Phase 4: Quality and Tooling (Completed)
- [x] Add unit tests for character limits, draft persistence, and OAuth helper logic.
- [x] Wire `script/build.sh` and `script/test.sh` to real commands.
- [x] Update v1.0 docs from templates to current MVP spec.

## Notes
- Date: 2026-02-13
- Current publish integration includes single image upload path and thread posting logic.
- OAuth completion currently supports callback URL handling and manual callback URL entry for MVP reliability.
- Bugfix: DeepSeek API key is now directly editable/pastable in settings and saved in app settings (no Keychain fetch path for DeepSeek key).
