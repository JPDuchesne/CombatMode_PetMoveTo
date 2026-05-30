--[[ AddonService.lua — macro installation, addon status ]]

local _, ns = ...

local AddonService = {}
AddonService.__index = AddonService

AddonService.MACRO_NAME = "CM Pet Move"
AddonService.MACRO_ICON = "Ability_Hunter_MastersCall"
AddonService.MACRO_TEXT = table.concat({
  "/petpassive",
  "/petmoveto",
  "/run CombatMode_ReticlePetMoveTo:Activate()",
}, "\n")

function AddonService:New()
  return setmetatable({}, self)
end

function AddonService:InstallMacro()
  if InCombatLockdown() then
    error({ type = "combat_lockdown", message = "cannot update macros in combat." }, 0)
  end

  local macroIndex = GetMacroIndexByName(self.MACRO_NAME)
  if macroIndex > 0 then
    EditMacro(macroIndex, self.MACRO_NAME, self.MACRO_ICON, self.MACRO_TEXT)
    return
  end

  local _, perCharCount = GetNumMacros()
  if perCharCount >= 18 then
    error({ type = "macro_limit", message = "character macro limit reached (18). Delete one macro and run /cmpet install." }, 0)
  end

  macroIndex = CreateMacro(self.MACRO_NAME, self.MACRO_ICON, self.MACRO_TEXT, true)
  if not macroIndex or macroIndex == 0 then
    error({
      type = "wow_api",
      message = "failed to create macro.",
      api = "CreateMacro",
      macroName = self.MACRO_NAME,
      returnValue = macroIndex,
    }, 0)
  end
end

function AddonService:GetStatus()
  local macroIndex = GetMacroIndexByName(self.MACRO_NAME)
  local hooked = ns.petMoveToService and ns.petMoveToService.hooked

  return {
    hooked = hooked,
    macroInstalled = macroIndex > 0,
    macroIndex = macroIndex,
    macroName = self.MACRO_NAME,
  }
end

ns.AddonService = AddonService
