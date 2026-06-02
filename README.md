# CombatMode: Pet Move To

A World of Warcraft addon for Hunters using [CombatMode](https://www.curseforge.com/wow/addons/combat-mode). Hooks CombatMode's `ShouldFreeLookBeOff` and auto-installs a macro that unlocks the cursor for `/petmoveto` ground placement.

## Features

- **One-key pet move**: bind the auto-installed `CM Pet Move` macro to any key
- **CombatMode integration**: hooks `ShouldFreeLookBeOff` so the cursor stays free during pet placement
- **Automatic cursor re-lock**: after confirming (LMB) or cancelling (RMB/Esc), CombatMode re-engages mouselook
- **Grace period**: prevents accidental double-activation within 0.35s

## Installation

Install from [CurseForge](https://www.curseforge.com/wow/addons/combatmode-petmoveto) or copy the addon folder to your WoW `Interface/AddOns/` directory.

Requires: [CombatMode](https://www.curseforge.com/wow/addons/combat-mode)

## Usage

1. `/cmpet` — show addon status (hook + macro)
2. `/cmpet install` — reinstall the macro
3. `/cmpet macro` — print the macro text
4. `/cmpet e2e` — run in-game integration tests (dev builds)

Bind any key to the `CM Pet Move` macro in WoW's keybinding UI.

## Development

### Prerequisites

- [d3mlabs/dev](https://github.com/d3mlabs/dev) CLI
- Lua 5.1 (provisioned automatically by `dev up`)
- LuaRocks (provisioned automatically by `dev up`)

### Setup

```bash
dev up          # provisions Lua 5.1, installs LuaUnit, runs bin/up
```

Or manually:

```bash
brew install luajit luarocks
luarocks init --lua-version 5.1
luarocks install luaunit --tree lua_modules
```

### Testing

```bash
dev test        # or: ./bin/test
```

Runs all `test/unit/*_test.lua` files with LuaJIT. Tests use a WoW API stub environment (`test/helpers/wow_env.lua`) — no game client required.

#### E2E tests

In the WoW game client:

```
/cmpet e2e
```

Runs integration tests against real WoW APIs and prints results to chat.

### Packaging

```bash
dev package     # or: ./bin/package
```

Reads version from `.toc`, assembles `dist/CombatMode_PetMoveTo-<version>.zip`.

### Releasing

```bash
dev release     # or: ./bin/release
```

1. Bumps `## Version:` in `.toc`, commits + tags
2. Pushes main + tag
3. Runs `bin/package`
4. Creates GitHub release with zip attached
5. Uploads to CurseForge (if `CF_API_KEY` and `CF_PROJECT_ID` are set)

### Project structure

```
CombatMode_PetMoveTo/
  CombatMode_PetMoveTo.toc     # WoW addon manifest
  src/
    Config.lua                  # Public API, DI wiring, slash commands
    PetMoveToCommand.lua        # Single command state machine
    PetMoveToService.lua        # Command lifecycle, event handling, cursor mgmt
    AddonService.lua            # Macro installation, addon status
  test/
    unit/                       # LuaUnit tests (run outside WoW)
    e2e/                        # In-game tests (run via /cmpet e2e)
    helpers/
      wow_env.lua               # WoW API stubs for unit testing
      spy.lua                   # Lightweight call-tracking utility
  bin/
    up                          # Project-specific setup (luarocks init)
    test                        # Unit test runner
    package                     # Assemble release zip
    release                     # Tag + package + publish
  lib/
    wow_curseforge_integration.rb  # Custom dev Integration for CurseForge
  dev.yml                       # dev CLI configuration
  dependencies.rb               # Dependency declarations
  .github/workflows/ci.yml     # GitHub Actions CI
```

## License

MIT
