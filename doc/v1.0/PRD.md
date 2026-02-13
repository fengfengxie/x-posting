# Product Requirements Document

## Overview
X Posting is a distraction-resistant macOS menubar app for drafting, polishing, and publishing X posts without opening the X app/feed.

## Goals
- Let users draft and publish X posts from a menubar workflow.
- Improve draft quality via DeepSeek polishing.
- Handle X character constraints with clear preview and auto thread splitting.
- Keep failure flow safe: draft content is never lost.

## Non-Goals
- Cloud sync or multi-device collaboration.
- Multi-image/video/GIF publishing.
- Social analytics and scheduling.

## Target Users
- Builders who share project progress frequently on X.
- Users who want to avoid feed distraction while posting.

## User Stories
- As a user, I can draft quickly from the menubar.
- As a user, I can polish language with selectable tone.
- As a user, I can choose target output language for polishing: auto / English / Chinese.
- As a user, I can preview thread splits before publishing.
- As a user, I can publish directly to X and keep draft content if publish fails.

## Requirements
- macOS 14+ menubar app with optional full composer window.
- Local draft persistence.
- DeepSeek API integration with user-provided API key.
- Polish presets: concise / professional / casual.
- Output language option: auto / en / cn.
- X OAuth 1.0a account connection (user-provided API keys).
- Publish via X API with text and one image.
- Character limit analysis and auto thread split.
- On publish failure: show error, keep draft content, offer copy action.

## Success Metrics
- Draft-to-publish flow can be completed without opening X app.
- 100% of failed publishes preserve draft text and image selection.
- Character limit preview matches publish segments from app output.

## Risks
- X API access policy/permission changes.
- Media upload compatibility differences across API versions.
- Weighted character counting may drift from future X rules.

## Open Questions
- Whether to add queued retry mode in a later version.
