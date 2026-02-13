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
- Bugfix: Menubar `Attach Image` now reliably reopens Finder on repeated clicks by forcing a fresh importer presentation state transition.
- Bugfix: Replaced SwiftUI `.fileImporter` with direct `NSOpenPanel` for image attach in both menubar and composer views, fixing repeated-click unresponsiveness in MenuBarExtra context. Image data is now copied into app support on attach, resolving security-scoped URL access failures during publish.
- UX refactor: Removed the independent composer window and removed `Open Composer`; compose/polish/publish/image actions now stay menubar-first.
- Polish simplification: Removed tone/output-mode branching and switched to a single minimal-edit prompt that preserves authenticity and only fixes necessary typos/grammar/syntax.
- UX polish: Menubar primary actions now emphasize separation between writing and posting: `Publish` appears first with a green prominent style, `Polish` was renamed to `Fix Text` with a blue prominent style, and the unused `Copy` button was removed.
- UX polish: Kept `Publish` as the primary green action, moved `Fix Text` down before `Attach Image`, and aligned `Fix Text` styling to the same bordered secondary style as image actions.
- UX polish: Added a leading icon to `Fix Text` (`wand.and.stars`) to match the icon+text button pattern used by `Attach Image`.
- UX polish: Added a menubar `Homepage` button (next to `Settings`) that opens `https://x.com/_feng_xie` for quick post-check access.
- UX polish: Repositioned `Homepage` to the panel header (top-right, same row as `Quick Draft`) for faster access and less footer clutter.
- Bugfix: Deferred Keychain credential reads until needed (e.g., Settings open / publish flow) instead of loading at app bootstrap, so startup no longer triggers immediate Keychain prompts.
- UX polish: After a successful `Fix Text`, status now shows a clickable `Revert` link that restores the exact pre-polish draft and then hides itself.
- UX polish: Publish success feedback now includes an inline `Open Post` hyperlink action using the returned post ID, enabling one-click verification after posting.
- Docs: Rewrote README for public repo readiness (motivation, features, getting started, project structure, tech stack). Updated GitHub repo description.
