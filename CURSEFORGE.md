# CombatMode: Pet Move To

Companion addon for [Combat Mode](https://www.curseforge.com/wow/addons/combat-mode) that makes `/petmoveto` work seamlessly with cursor-lock.

## The problem

Combat Mode locks your cursor for action-combat gameplay. But `/petmoveto` needs a free cursor to place the green targeting ring on the ground.

You can't add `/petmoveto` to Combat Mode's "cast at cursor" reticle system either — WoW's engine doesn't treat it as a spell, so the normal reticle-targeting flow doesn't apply. Without this addon, you have to manually unlock your cursor, place the command, then re-lock it.

## What this addon does

Press one key and it all happens automatically:

1. **Unlocks your cursor** so you can aim the pet-move ring
2. **LMB** — places your pet, cursor re-locks after a short delay
3. **RMB / Esc** — cancels, cursor re-locks immediately

No more fumbling with cursor toggles mid-combat.

## Setup

1. Install [Combat Mode](https://www.curseforge.com/wow/addons/combat-mode) (required dependency)
2. Install this addon
3. `/reload` — the addon auto-creates a macro called **CM Pet Move**
4. Open **Esc → Macros**, find **CM Pet Move**, and bind it to any key (`` ` `` works great)

That's it. Press your keybind whenever you want to reposition your pet.

## Slash commands

| Command | What it does |
|---------|-------------|
| `/cmpet` | Show addon status |
| `/cmpet install` | Reinstall the macro (after updates) |
| `/cmpet macro` | Print the macro text |

## Works with

Any class that has a pet supporting `/petmoveto`:

- **Hunter** — all specs with active pets
- **Warlock** — demons
- **Death Knight** — ghoul (Unholy)

## How it works

The addon hooks Combat Mode's `ShouldFreeLookBeOff` function. When you activate the macro, the hook tells Combat Mode to release the cursor. Once you confirm (LMB) or cancel (RMB/Esc), the addon explicitly re-locks the cursor.

The macro runs three commands in sequence:
```
/petpassive
/petmoveto
/run CombatMode_PetMoveTo:Activate()
```
