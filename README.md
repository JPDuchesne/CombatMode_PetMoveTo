# CombatMode: Reticle Pet Move To

Companion addon for [Combat Mode](https://github.com/djsmithdev/combatmode) + hunter `/petmoveto`.

On login it **automatically**:

1. Installs the Combat Mode **custom condition** (unlocks cursor for ground spells + pet move)
2. Creates/updates the **`CM Pet Move`** character macro

You only need to **bind `` ` ``** (or any key) to that macro.

## How it works

When you press the macro, the addon signals Combat Mode to **unlock the cursor** so you can aim the pet-move ring with your mouse. LMB confirms placement. CM re-locks the cursor automatically when the session ends.

## Install

Copy this folder to:

`World of Warcraft/_retail_/Interface/AddOns/CombatMode_ReticlePetMoveTo`

Requires **Combat Mode** enabled. `/reload` then `/cmpet install`.

## Slash commands

| Command | Action |
|---------|--------|
| `/cmpet` | Status |
| `/cmpet install` | Reinstall condition + macro |
| `/cmpet macro` | Print macro text |
| `/cmpet condition` | Print CM custom condition |

## Flow

- `` ` `` → cursor unlocks, pet-move ring appears
- **LMB** → place pet → CM re-locks cursor
- `` ` `` again or **Esc** → cancel → CM re-locks cursor

## Session lifecycle

The macro calls `CombatMode_ReticlePetMoveTo:Activate()` and `CombatMode_ReticlePetMoveTo:Cancel()`. The addon owns session state; CM owns cursor state.

- **Start**: `Activate()` sets a timestamp and shows the session frame (OnUpdate begins). CM's custom condition sees `WantsCursorUnlock()` return true and unlocks the cursor.
- **End**: `SpellStopTargeting` hook clears the timestamp and hides the frame. CM's condition returns false on its next frame and re-locks the cursor.
- **Timeout**: 30s safety net via OnUpdate.
- **Idle**: frame is hidden — zero CPU cost.

## Manual setup

**Macro** `CM Pet Move`:

```lua
/run if CombatMode_ReticlePetMoveTo:IsActive() then CombatMode_ReticlePetMoveTo:Cancel() return end
/petpassive
/petmoveto
/run CombatMode_ReticlePetMoveTo:Activate()
```

**Combat Mode custom condition** (auto-installed):

```lua
if SpellIsTargeting() then return true end
if CombatMode_ReticlePetMoveTo:WantsCursorUnlock() then return true end
return false
```
