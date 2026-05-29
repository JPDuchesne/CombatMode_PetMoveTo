# CM Pet Move Bridge

Companion addon for [Combat Mode](https://github.com/djsmithdev/combatmode) + hunter `/petmoveto`.

On login it **automatically**:

1. Installs the Combat Mode **custom condition** (ground spells + optional pet-move cursor unlock)
2. Creates/updates the **`CM Pet Move`** character macro

You only need to **bind `` ` ``** (or any key) to that macro.

## Default behavior

**Reticle stays locked** while you aim the pet-move ring. During the ring, LMB is temporarily bound to **Camera Or Select Or Move** (ground confirm) instead of your CM click-cast macro.

| Mode | `` ` `` | While aiming | LMB |
|------|--------|--------------|-----|
| **Default** | Start ring | Reticle **locked** | Places pet (not your click-cast macro) |
| `/cpmb unlock` (on) | Start ring | Cursor **unlocked** | Places pet |

This fixes "cursor unlocks before I confirm" when you want to aim with the CM crosshair, not a free mouse.

## Install

Copy this folder to:

`World of Warcraft/_retail_/Interface/AddOns/CMPetMoveCMBridge`

Requires **Combat Mode** enabled. `/reload` then `/cpmb install`.

## Slash commands

| Command | Action |
|---------|--------|
| `/cpmb` | Status |
| `/cpmb install` | Reinstall condition + macro |
| `/cpmb unlock` | Toggle free-cursor during pet move (default **off**) |
| `/cpmb macro` | Print macro text |
| `/cpmb condition` | Print CM custom condition |

## Flow (default)

- `` ` `` → ring up, **reticle stays locked**, LMB freed from click-cast
- **LMB** → place pet → click-cast restored
- `` ` `` again or **Esc** → cancel

## Session lifecycle

The macro calls `CMPetMoveCMBridge:Activate()` and `CMPetMoveCMBridge:Cancel()` — the addon owns all session state internally.

- **Start**: `Activate()` sets a timestamp and shows the session frame (OnUpdate begins).
- **End**: `SpellStopTargeting` hook detects confirm/cancel and hides the frame (OnUpdate stops).
- **LMB fallback**: 0.5s timer in case `SpellStopTargeting` does not fire on `/petmoveto` confirm (it's not a spell).
- **Timeout**: 30s safety net via OnUpdate.
- **Idle**: frame is hidden — zero CPU cost.

## Manual setup

**Macro** `CM Pet Move`:

```lua
/run if CMPetMoveCMBridge:IsActive() then CMPetMoveCMBridge:Cancel() return end
/petpassive
/petmoveto
/run CMPetMoveCMBridge:Activate()
```

**Combat Mode custom condition** (auto-installed):

```lua
if SpellIsTargeting() then return true end
if CMPetMoveCMBridge:WantsCursorUnlock() then return true end
return false
```

With default settings, `WantsCursorUnlock()` is false during pet move — only traps/other ground spells unlock via `SpellIsTargeting()`.
