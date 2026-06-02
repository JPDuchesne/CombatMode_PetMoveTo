--[[ Config.lua — public API, dependency wiring, slash commands ]]

local ADDON, ns = ...

---@class CombatMode_PetMoveTo
local API = {}
_G.CombatMode_PetMoveTo = API

---Start a new pet-move command. Called from the macro.
function API:Activate()  ns.petMoveToService:Activate()                    end

---Cancel the pending command (if any).
function API:Cancel()    ns.petMoveToService:Cancel()                      end

---Whether the addon is actively managing a pet-move command.
---@return boolean
function API:IsActive()  return ns.petMoveToService:HasPendingCommand()    end

---@param msg string
local function printMsg(msg)
  print("|cff33ff99PetMoveTo|r: " .. msg)
end

---Install the macro and print user-facing feedback.
---@return boolean ok
local function installMacroWithFeedback()
  local ok, err = pcall(ns.addonService.InstallMacro, ns.addonService)

  if ok then
    printMsg("Installed |cff00ff00" .. ns.addonService.MACRO_NAME .. "|r macro.")
    printMsg("Bind |cff00ff00` |r (or any key) to macro |cff00ff00" .. ns.addonService.MACRO_NAME .. "|r.")
  else
    ---@cast err AddonError
    printMsg("|cffff5050" .. err.message .. "|r")
  end

  return ok
end

---Print addon status to chat.
local function showStatus()
  local status = ns.addonService:GetStatus()

  printMsg(
    (status.hooked and "|cff00ff00CM hook: installed|r" or "|cffffcc00CM hook: not installed|r")
      .. " | "
      .. (status.macroInstalled and ("|cff00ff00Macro: " .. status.macroName .. " #" .. status.macroIndex .. "|r") or "|cffffcc00Macro: missing|r")
  )
  printMsg("Run |cff00ff00/cmpet install|r to reinstall macro. Bind |cff00ff00` |r to the macro.")
end

SLASH_COMBATMODE_PETMOVETO1 = "/cmpet"
SlashCmdList["COMBATMODE_PETMOVETO"] = function(msg)
  msg = strtrim(msg or ""):lower()
  if msg == "install" or msg == "setup" then
    installMacroWithFeedback()
  elseif msg == "macro" then
    printMsg(ns.addonService.MACRO_TEXT:gsub("\n", " "))
  else
    showStatus()
  end
end

-- Dependency wiring: construct services on ADDON_LOADED with DI
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(_, _, addon)
  if addon ~= ADDON then return end

  ns.addonService = ns.AddonService:New()

  local cm = LibStub("AceAddon-3.0"):GetAddon("CombatMode")
  local service = ns.PetMoveToService:New(cm)
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

  installMacroWithFeedback()
  frame:UnregisterEvent("ADDON_LOADED")
end)
