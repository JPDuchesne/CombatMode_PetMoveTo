local WoWAPI = require("test.helpers.wow_api")
local lu = require("luaunit")

-- Load AddonService in isolation (depends only on WoW API stubs)
local function loadAddonService()
  local ns = {}
  loadfile("src/AddonService.lua")("CombatMode_PetMoveTo", ns)
  return ns
end

TestAddonService = {}

function TestAddonService:setUp()
  WoWAPI.Reset()
  self.ns = loadAddonService()
  self.service = self.ns.AddonService:New()
end

-- InstallMacro — happy path

function TestAddonService:test_install_creates_macro()
  self.service:InstallMacro()
  local idx = GetMacroIndexByName(self.ns.AddonService.MACRO_NAME)
  lu.assertTrue(idx > 0)
end

function TestAddonService:test_install_uses_correct_name_and_icon()
  self.service:InstallMacro()
  local idx = GetMacroIndexByName(self.ns.AddonService.MACRO_NAME)
  lu.assertTrue(idx > 0)
end

function TestAddonService:test_install_updates_existing_macro()
  self.service:InstallMacro()
  local idx1 = GetMacroIndexByName(self.ns.AddonService.MACRO_NAME)

  self.service:InstallMacro()
  local idx2 = GetMacroIndexByName(self.ns.AddonService.MACRO_NAME)
  lu.assertEquals(idx1, idx2)
end

-- InstallMacro — error cases

function TestAddonService:test_install_in_combat_throws()
  WoWAPI.SetCombatLockdown(true)
  local ok, err = pcall(self.service.InstallMacro, self.service)
  lu.assertFalse(ok)
  lu.assertEquals(err.type, "combat_lockdown")
end

function TestAddonService:test_install_at_macro_limit_throws()
  -- Fill up to 18 per-character macros
  for i = 1, 18 do
    CreateMacro("Macro" .. i, "INV_Misc_QuestionMark", "/say hi", true)
  end
  local ok, err = pcall(self.service.InstallMacro, self.service)
  lu.assertFalse(ok)
  lu.assertEquals(err.type, "macro_limit")
end

-- GetStatus

function TestAddonService:test_status_without_macro()
  local status = self.service:GetStatus()
  lu.assertFalse(status.macroInstalled)
  lu.assertEquals(status.macroIndex, 0)
  lu.assertEquals(status.macroName, self.ns.AddonService.MACRO_NAME)
end

function TestAddonService:test_status_with_macro()
  self.service:InstallMacro()
  local status = self.service:GetStatus()
  lu.assertTrue(status.macroInstalled)
  lu.assertTrue(status.macroIndex > 0)
end

function TestAddonService:test_status_reports_hook_state()
  local status = self.service:GetStatus()
  -- No petMoveToService in this isolated ns, so hooked should be falsy
  lu.assertNil(status.hooked)
end

-- Macro content

function TestAddonService:test_macro_text_contains_petmoveto()
  lu.assertStrContains(self.ns.AddonService.MACRO_TEXT, "/petmoveto")
end

function TestAddonService:test_macro_text_contains_activate()
  lu.assertStrContains(self.ns.AddonService.MACRO_TEXT, "CombatMode_PetMoveTo:Activate()")
end

os.exit(lu.LuaUnit.run())
