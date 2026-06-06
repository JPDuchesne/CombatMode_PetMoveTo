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

function TestAddonService:test_install_creates_per_character_macro()
  self.service:InstallMacro()
  local _, perChar = GetNumMacros()
  lu.assertEquals(perChar, 1)
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

function TestAddonService:test_install_wow_api_error_throws()
  local original = CreateMacro
  CreateMacro = function() return 0 end
  local ok, err = pcall(self.service.InstallMacro, self.service)
  CreateMacro = original
  lu.assertFalse(ok)
  lu.assertEquals(err.type, "wow_api")
  lu.assertEquals(err.api, "CreateMacro")
end

-- Macro content

function TestAddonService:test_macro_text_contains_petpassive()
  lu.assertStrContains(self.ns.AddonService.MACRO_TEXT, "/petpassive")
end

function TestAddonService:test_macro_text_contains_petmoveto()
  lu.assertStrContains(self.ns.AddonService.MACRO_TEXT, "/petmoveto")
end

function TestAddonService:test_macro_text_contains_activate()
  lu.assertStrContains(self.ns.AddonService.MACRO_TEXT, "CombatMode_PetMoveTo:Activate()")
end

-- HandleSlashCommand

function TestAddonService:test_slash_install_creates_macro()
  self.service:HandleSlashCommand("install")
  local idx = GetMacroIndexByName(self.ns.AddonService.MACRO_NAME)
  lu.assertTrue(idx > 0)
end

function TestAddonService:test_slash_setup_creates_macro()
  self.service:HandleSlashCommand("setup")
  local idx = GetMacroIndexByName(self.ns.AddonService.MACRO_NAME)
  lu.assertTrue(idx > 0)
end

function TestAddonService:test_slash_macro_prints_macro_text()
  self.service:HandleSlashCommand("macro")
  local log = WoWAPI.GetPrintLog()
  lu.assertTrue(#log > 0)
  lu.assertStrContains(log[#log], "/petmoveto")
end

function TestAddonService:test_slash_empty_shows_status()
  self.service:HandleSlashCommand("")
  local log = WoWAPI.GetPrintLog()
  lu.assertTrue(#log >= 2)
  lu.assertStrContains(log[#log - 1], "CM hook")
  lu.assertStrContains(log[#log], "/cmpet install")
end

-- InstallMacroWithFeedback

function TestAddonService:test_install_with_feedback_prints_success()
  local ok = self.service:InstallMacroWithFeedback()
  lu.assertTrue(ok)
  local log = WoWAPI.GetPrintLog()
  lu.assertTrue(#log >= 2)
  lu.assertStrContains(log[#log - 1], self.ns.AddonService.MACRO_NAME)
  lu.assertStrContains(log[#log], "Bind")
end

function TestAddonService:test_install_with_feedback_prints_error()
  WoWAPI.SetCombatLockdown(true)
  local ok = self.service:InstallMacroWithFeedback()
  lu.assertFalse(ok)
  local log = WoWAPI.GetPrintLog()
  lu.assertTrue(#log > 0)
  lu.assertStrContains(log[#log], "combat")
end

-- ShowStatus

function TestAddonService:test_show_status_reports_missing_macro()
  self.service:ShowStatus()
  local log = WoWAPI.GetPrintLog()
  lu.assertStrContains(log[#log - 1], "missing")
end

function TestAddonService:test_show_status_reports_installed_macro()
  self.service:InstallMacro()
  WoWAPI.GetPrintLog() -- clear install noise by noting position
  self.service:ShowStatus()
  local log = WoWAPI.GetPrintLog()
  lu.assertStrContains(log[#log - 1], self.ns.AddonService.MACRO_NAME)
end

os.exit(lu.LuaUnit.run())
