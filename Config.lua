--[[ Config.lua — public API, dependency wiring, macro installer, slash commands ]]

local ADDON, ns = ...

local API = {}
_G.CombatMode_ReticlePetMoveTo = API

API.MACRO_NAME = "CM Pet Move"
API.MACRO_ICON = "Ability_Hunter_MastersCall"
API.MACRO_TEXT = table.concat({
  "/petpassive",
  "/petmoveto",
  "/run CombatMode_ReticlePetMoveTo:Activate()",
}, "\n")

-- Public API: thin delegations to the service (constructed on ADDON_LOADED)
function API:Activate()  ns.petMoveToService:Activate()                    end
function API:Cancel()    ns.petMoveToService:Cancel()                      end
function API:IsActive()  return ns.petMoveToService:HasPendingCommand()    end

function API:Print(msg)
  print("|cff33ff99ReticlePetMoveTo|r: " .. msg)
end

function API:InstallMacro()
  if InCombatLockdown() then
    return false, "cannot update macros in combat."
  end

  local macroIndex = GetMacroIndexByName(self.MACRO_NAME)
  if macroIndex > 0 then
    EditMacro(macroIndex, self.MACRO_NAME, self.MACRO_ICON, self.MACRO_TEXT)
    return true, "updated macro |cff00ff00" .. self.MACRO_NAME .. "|r (#" .. macroIndex .. ")."
  end

  local _, perCharCount = GetNumMacros()
  if perCharCount >= 18 then
    return false, "character macro limit reached (18). Delete one macro and run |cff00ff00/cmpet install|r."
  end

  macroIndex = CreateMacro(self.MACRO_NAME, self.MACRO_ICON, self.MACRO_TEXT, true)
  if not macroIndex or macroIndex == 0 then
    return false, "failed to create macro."
  end

  return true, "created macro |cff00ff00" .. self.MACRO_NAME .. "|r (#" .. macroIndex .. ")."
end

function API:InstallAll(silent)
  local okMacro, msgMacro = self:InstallMacro()

  if not silent then
    if okMacro then
      self:Print(msgMacro)
    else
      self:Print("|cffff5050" .. msgMacro .. "|r")
    end
    if okMacro then
      self:Print("Bind |cff00ff00` |r (or any key) to macro |cff00ff00" .. self.MACRO_NAME .. "|r.")
    end
  end

  return okMacro
end

function API:TryAutoInstall()
  if InCombatLockdown() then
    self.pendingInstall = true
    return
  end

  self.pendingInstall = false
  local okMacro = self:InstallMacro()

  if not CombatMode_ReticlePetMoveToDB then
    CombatMode_ReticlePetMoveToDB = {}
  end

  if okMacro and not CombatMode_ReticlePetMoveToDB.greeted then
    CombatMode_ReticlePetMoveToDB.greeted = true
    self:Print("Installed |cff00ff00" .. self.MACRO_NAME .. "|r macro.")
    self:Print("Bind |cff00ff00` |r to that macro. Use |cff00ff00/cmpet|r for help.")
  end
end

function API:ShowStatus()
  local macroIndex = GetMacroIndexByName(self.MACRO_NAME)
  local hooked = ns.petMoveToService and ns.petMoveToService.hooked

  self:Print(
    (hooked and "|cff00ff00CM hook: installed|r" or "|cffffcc00CM hook: not installed|r")
      .. " | "
      .. (macroIndex > 0 and ("|cff00ff00Macro: " .. self.MACRO_NAME .. " #" .. macroIndex .. "|r") or "|cffffcc00Macro: missing|r")
  )
  self:Print("Run |cff00ff00/cmpet install|r to reinstall macro. Bind |cff00ff00` |r to the macro.")
end

SLASH_COMBATMODE_RETICLEPETMOVETO1 = "/cmpet"
SlashCmdList["COMBATMODE_RETICLEPETMOVETO"] = function(msg)
  msg = strtrim(msg or ""):lower()
  if msg == "install" or msg == "setup" then
    API:InstallAll(false)
  elseif msg == "macro" then
    API:Print(API.MACRO_TEXT:gsub("\n", " "))
  else
    API:ShowStatus()
  end
end

-- Dependency wiring: construct service on ADDON_LOADED with CM injected
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(_, _, addon)
  if addon ~= ADDON then return end

  local cm = LibStub("AceAddon-3.0"):GetAddon("CombatMode", true)
  local service = ns.PetMoveToService:New(cm)
  service:Setup()
  ns.petMoveToService = service

  -- Hook CM's cursor-lock decision — integration code, not service logic.
  -- Must be after ns.petMoveToService assignment: the closure calls
  -- API:IsActive() → ns.petMoveToService:HasPendingCommand().
  if cm.ShouldFreeLookBeOff then
    local original = cm.ShouldFreeLookBeOff
    cm.ShouldFreeLookBeOff = function(...)
      if API:IsActive() then return true end
      return original(...)
    end
    service.hooked = true
  end

  API:TryAutoInstall()
  frame:UnregisterEvent("ADDON_LOADED")
end)

-- Deferred install for combat lockdown
local installFrame = CreateFrame("Frame")
installFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
installFrame:SetScript("OnEvent", function()
  if API.pendingInstall then
    API:TryAutoInstall()
  end
end)
