--[[ Init.lua — addon entry point: bootstraps services and wires the public API.

Loaded last in the .toc. All other source files must precede this one so that
class definitions (PetMoveToCommand, PetMoveToService, AddonService) are
available on the addon namespace when this file executes.
]]

local ADDON, ns = ...

-- Public API — the global table that macros call into.
---@class CombatMode_PetMoveTo
local API = {}
_G.CombatMode_PetMoveTo = API

---Start a new pet-move command. Called from the macro.
function API:Activate()  ns.petMoveToService:Activate()              end

---Cancel the pending command (if any).
function API:Cancel()    ns.petMoveToService:Cancel()                end

---Whether the addon is actively managing a pet-move command.
---@return boolean
function API:IsActive()  return ns.petMoveToService:HasPendingCommand() end

-- Slash command registration (handler delegates to AddonService)
SLASH_COMBATMODE_PETMOVETO1 = "/cmpet"
SlashCmdList["COMBATMODE_PETMOVETO"] = function(msg)
  ns.addonService:HandleSlashCommand(msg)
end

-- Bootstrap: construct services and wire dependencies on ADDON_LOADED.
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(_, _, addon)
  if addon ~= ADDON then return end

  ns.addonService = ns.AddonService:New()

  local cm = LibStub("AceAddon-3.0"):GetAddon("CombatMode")
  local service = ns.PetMoveToService:New(cm)
  ns.petMoveToService = service

  -- Integration: override CM's cursor-unlock decision while pet-move is active.
  -- Must be after ns.petMoveToService assignment since the closure calls
  -- API:IsActive() → ns.petMoveToService:HasPendingCommand().
  if cm.ShouldFreeLookBeOff then
    local original = cm.ShouldFreeLookBeOff
    cm.ShouldFreeLookBeOff = function(...)
      if API:IsActive() then return true end
      return original(...)
    end
    service.hooked = true
  end

  ns.addonService:InstallMacroWithFeedback()
  frame:UnregisterEvent("ADDON_LOADED")
end)
