# Bot Creator Shared Engine

The core bot execution engine for the Bot Creator ecosystem. This library provides the BDFD transpiler, interaction handling, and runtime variable resolution used by both the Bot Creator App and the CLI Runner.

## Features

- **BDFD Transpiler**: High-performance Lexer, Parser, and Transpiler for BDFD scripts.
- **Bot Engine**: Centralized orchestration for bot sessions, events, and workflows.
- **Generic Storage**: Abstract `BotDataStore` interface allowing for any database backend.
- **Rich Metadata**: Automated extraction of Discord metadata (Guild, Channel, Member, User) into runtime variables.
- **Action System**: Extensible action handler architecture for custom bot functionality.

## Usage

Add this package to your `pubspec.yaml`:

```yaml
dependencies:
  bot_creator_shared:
    git:
      url: git@github.com:ketsuna-org/bot-creator-shared.git
```

## Internal Architecture

- `lib/engine`: Core BotEngine and session management.
- `lib/utils/bdfd_*`: Lexing, parsing, and transpilation logic.
- `lib/actions`: Handlers for Discord interactions and bot actions.
- `lib/bot`: Data models and storage interfaces.

---
© 2026 Bot-Creator. All rights reserved.
