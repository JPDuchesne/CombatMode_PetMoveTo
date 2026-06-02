--[[ AddonService.lua — macro installation, addon status ]]

local _, ns = ...

---@alias AddonErrorType "combat_lockdown"|"macro_limit"|"wow_api"

---@class AddonError
---@field type AddonErrorType
---@field message string User-facing error description
---@field api string? WoW API that failed (wow_api errors only)
---@field macroName string? Macro name involved (wow_api errors only)
---@field returnValue any? Value returned by the WoW API (wow_api errors only)

---@class AddonStatus
---@field hooked boolean Whether the cursor-lock integration hook is active
---@field macroInstalled boolean Whether the CM Pet Move macro exists
---@field macroIndex number WoW macro index (0 if not found)
---@field macroName string Macro name

---@class AddonService
local AddonService = {}
AddonService.__index = AddonService

AddonService.MACRO_NAME = "CM Pet Move"
AddonService.MACRO_ICON = "Ability_Hunter_MastersCall"
AddonService.MACRO_TEXT = table.concat({
  "/petpassive",
  "/petmoveto",
  "/run CombatMode_PetMoveTo:Activate()",
}, "\n")

---@return AddonService
function AddonService:New()
  return setmetatable({}, self)
end

---Install or update the CM Pet Move macro.
---Throws AddonError on failure.
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

---Query current addon status (hook + macro).
---@return AddonStatus
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
