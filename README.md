# X Posting

A lightweight macOS menubar app for drafting, polishing, and publishing posts to X (Twitter) — without ever opening your feed.

## Why

Posting on X means opening X, and opening X means doomscrolling. X Posting keeps you focused: draft from the menubar, polish with AI, hit publish, and get back to work.

## Features

- **Menubar-first workflow** — draft, polish, attach images, and publish directly from the macOS menu bar. No separate windows needed.
- **AI text polish** — one-click grammar and typo fixes powered by DeepSeek, with instant revert if you prefer the original.
- **Thread auto-split** — live character count with automatic thread segmentation when your post exceeds the limit.
- **Single image attachment** — attach one image per post via Finder or clipboard.
- **Safe failure handling** — publish errors never lose your draft; content stays in the editor with a copy fallback.
- **OAuth 1.0a** — paste your X API keys once; tokens never expire, no browser redirect needed.

## Requirements

- macOS 14+
- Swift 6 / Xcode 16+
- [X Developer](https://developer.x.com/) API keys (OAuth 1.0a — API key, API secret, access token, access token secret)
- [DeepSeek](https://platform.deepseek.com/) API key (for text polish)

## Getting Started

```bash
# Clone
git clone https://github.com/fengfengxie/x-posting.git
cd x-posting

# Build
script/build.sh

# Run
swift run x-posting

# Test
script/test.sh
```

On first launch, open **Settings** from the menubar panel and enter your X API credentials and DeepSeek API key.

## Project Structure

```
src/
├── XPostingCore/          # Core logic (models, services, stores)
│   ├── Models.swift
│   ├── DraftStore.swift
│   ├── AppSettingsStore.swift
│   ├── SecureCredentialStore.swift
│   ├── CharacterLimitService.swift
│   ├── DeepSeekPolishService.swift
│   ├── OAuth1Signer.swift
│   ├── XAuthService.swift
│   ├── XPublishService.swift
│   └── HTTPClient.swift
├── XPostingApp/           # SwiftUI app & views
│   ├── XPostingApp.swift
│   ├── ComposerViewModel.swift
│   └── Views/
│       ├── MenuBarContentView.swift
│       └── SettingsView.swift
└── XPostingCoreTests/     # Unit tests
```

## Tech Stack

- **Swift 6** with strict concurrency
- **SwiftUI** + `MenuBarExtra`
- **Swift Package Manager** for build and dependency management
- **Keychain** for secure X credential storage
- **UserDefaults** for app settings and draft persistence

## License

[MIT](LICENSE)
