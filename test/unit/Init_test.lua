local WoWAPI = require("test.helpers.wow_api")
local spy = require("test.helpers.spy")
local lu = require("luaunit")

local ADDON_NAME = "CombatMode_PetMoveTo"

-- Load the full addon via .toc and fire ADDON_LOADED to bootstrap.
local function bootAddon(cmOverrides)
  local cm = {
    LockFreeLook = spy.new(),
    ShouldFreeLookBeOff = function() return false end,
  }
  if cmOverrides then
    for k, v in pairs(cmOverrides) do cm[k] = v end
  end
  WoWAPI.RegisterAddon("CombatMode", cm)

  local ns = WoWAPI.loadAddon(ADDON_NAME .. ".toc")
  WoWAPI.FireEvent("ADDON_LOADED", ADDON_NAME)

  return ns, cm
end

TestInit = {}

function TestInit:setUp()
  WoWAPI.Reset()
end

-- Bootstrap wiring

function TestInit:test_addon_loaded_creates_addon_service()
  local ns = bootAddon()
  lu.assertNotNil(ns.addonService)
end

function TestInit:test_addon_loaded_creates_pet_move_to_service()
  local ns = bootAddon()
  lu.assertNotNil(ns.petMoveToService)
end

function TestInit:test_addon_loaded_installs_macro()
  bootAddon()
  local idx = GetMacroIndexByName("CM Pet Move")
  lu.assertTrue(idx > 0)
end

function TestInit:test_addon_loaded_ignores_other_addons()
  local cm = { LockFreeLook = spy.new(), ShouldFreeLookBeOff = function() return false end }
  WoWAPI.RegisterAddon("CombatMode", cm)
  local ns = WoWAPI.loadAddon(ADDON_NAME .. ".toc")
  WoWAPI.FireEvent("ADDON_LOADED", "SomeOtherAddon")
  lu.assertNil(ns.addonService)
end

-- CM integration hook

function TestInit:test_hooks_should_free_look_be_off()
  local ns, cm = bootAddon()
  lu.assertTrue(ns.petMoveToService.hooked)
  -- When not active, CM's original behavior is preserved
  lu.assertFalse(cm.ShouldFreeLookBeOff())
end

function TestInit:test_hook_returns_true_when_active()
  local _, cm = bootAddon()
  _G.CombatMode_PetMoveTo:Activate()
  lu.assertTrue(cm.ShouldFreeLookBeOff())
end

function TestInit:test_hook_falls_through_when_not_active()
  local _, cm = bootAddon({ ShouldFreeLookBeOff = function() return true end })
  -- Not active, so falls through to the original which returns true
  lu.assertTrue(cm.ShouldFreeLookBeOff())
end

function TestInit:test_no_hook_without_should_free_look_be_off()
  WoWAPI.RegisterAddon("CombatMode", { LockFreeLook = spy.new() })
  local ns = WoWAPI.loadAddon(ADDON_NAME .. ".toc")
  WoWAPI.FireEvent("ADDON_LOADED", ADDON_NAME)
  lu.assertNil(ns.petMoveToService.hooked)
end

-- Public API

function TestInit:test_global_api_exists()
  bootAddon()
  lu.assertNotNil(_G.CombatMode_PetMoveTo)
end

function TestInit:test_api_activate_starts_command()
  bootAddon()
  _G.CombatMode_PetMoveTo:Activate()
  lu.assertTrue(_G.CombatMode_PetMoveTo:IsActive())
end

function TestInit:test_api_cancel_clears_command()
  bootAddon()
  _G.CombatMode_PetMoveTo:Activate()
  _G.CombatMode_PetMoveTo:Cancel()
  lu.assertFalse(_G.CombatMode_PetMoveTo:IsActive())
end

function TestInit:test_api_is_active_false_when_idle()
  bootAddon()
  lu.assertFalse(_G.CombatMode_PetMoveTo:IsActive())
end

-- Slash command registration

function TestInit:test_slash_command_is_registered()
  bootAddon()
  lu.assertNotNil(SlashCmdList["COMBATMODE_PETMOVETO"])
end

function TestInit:test_slash_command_delegates_to_addon_service()
  bootAddon()
  SlashCmdList["COMBATMODE_PETMOVETO"]("")
  local log = WoWAPI.GetPrintLog()
  -- ShowStatus prints at least 2 lines (status + help)
  local statusLines = 0
  for _, msg in ipairs(log) do
    if msg:find("CM hook") or msg:find("/cmpet install") then
      statusLines = statusLines + 1
    end
  end
  lu.assertTrue(statusLines >= 2)
end

os.exit(lu.LuaUnit.run())
