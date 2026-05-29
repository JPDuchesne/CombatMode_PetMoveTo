# CM Pet Move Bridge

Companion addon for [Combat Mode](https://github.com/djsmithdev/combatmode) + hunter `/petmoveto`.

On login it **automatically**:

1. Installs the Combat Mode **custom condition** (ground spells + optional pet-move cursor unlock)
2. Creates/updates the **`CM Pet Move`** character macro

You only need to **bind `` ` ``** (or any key) to that macro.

## Default behavior (v1.3+)

**Reticle stays locked** while you aim the pet-move ring. During the ring, LMB is temporarily bound to **Camera Or Select Or Move** (ground confirm) instead of your CM click-cast macro.

| Mode | `` ` `` | While aiming | LMB |
|------|--------|--------------|-----|
| **Default** | Start ring | Reticle **locked** | Places pet (not your click-cast macro) |
| `/cpmb unlock` (on) | Start ring | Cursor **unlocked** | Places pet |

This fixes “cursor unlocks before I confirm” when you want to aim with the CM crosshair, not a free mouse.

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

## Timing / LMB confirm

- **Do not** end the pet-move session on LMB press — that restored click-cast before the ground click registered (the main “works sometimes” bug).
- LMB override stays cleared until `SpellStopTargeting` (confirm/cancel) or a **0.5s** fallback after LMB.
- **0.35s grace** after `` ` `` ignores spurious cancel events when the ring starts.

## Flow (default)

- `` ` `` → ring up, **reticle stays locked**, LMB freed from click-cast
- **LMB** → place pet → click-cast restored
- `` ` `` again or **Esc** → cancel

## Manual setup

**Macro** `CM Pet Move`:

```lua
/run local g=CM.DB.global if g.petMoveActive then g.petMoveActive=nil SpellStopTargeting()return end
/petpassive
/petmoveto
/run CM.DB.global.petMoveActive=GetTime()
```

**Combat Mode custom condition** (auto-installed):

```lua
if SpellIsTargeting() then return true end
if CMPetMoveCMBridge:WantsCursorUnlock() then return true end
return false
```

With default settings, `WantsCursorUnlock()` is false during pet move — only traps/other ground spells unlock via `SpellIsTargeting()`.
