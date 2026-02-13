# Repository Guidelines

## Standard Task Workflow

For tasks of implementing new features:

- Read PRD.md, Plan.md, Progress.md before coding.
- Summarize current project state before implementation.
- Carry out the implementation; build and test if possible.
- Update Progress.md after changes.
- Commit with a clear, concise message.

For tasks of bug fixing:

- Summarize the bug, reason, and solution before implementation.
- Carry out the implementation to fix the bug; build and test afterwards.
- Update Progress.md after changes.
- Commit with a clear, concise message.

For tasks of reboot from a new Codex session:

- Read PRD.md, Plan.md, Progress.md.
- Assume this is a continuation of an existing project.
- Summarize your understanding of the current state and propose the next concrete step without writing code yet.

## Project Structure & Module Organization
- Root folders: `src/`, `script/`, `doc/`.
- Docs live in `doc/vX.Y/`: PRD.md, Plan.md, Progress.md.

## Build, Test, and Development Commands
- Build: `script/build.sh`
- Test: `script/test.sh`

## Coding Style & Naming Conventions
- Follow language and framework conventions used in the repo.
- Keep files organized under `src/`.

## Testing Guidelines
- Add tests when reasonable; document how to run them.

## Commit & Pull Request Guidelines
- Commit messages are short, imperative, and scoped.
- PRs should include a brief summary and testing notes.

## Security & Configuration Tips
- Do not commit secrets or personal credentials.
