--[[ CombatMode_ReticlePetMoveTo.lua — pet-move session bridge for Combat Mode ]]

local ADDON = ...
local Bridge = _G.CombatMode_ReticlePetMoveTo

local GetTime = GetTime

local TICK = 0.1
local STOP_TARGET_GRACE = Bridge.STOP_TARGET_GRACE

local frame
local tick = 0

local function withinGracePeriod()
  local t = Bridge.activeTimestamp
  return type(t) == "number" and (GetTime() - t) < STOP_TARGET_GRACE
end

local function endSession()
  if not Bridge.activeTimestamp then
    return
  end
  Bridge.activeTimestamp = nil
  frame:Hide()
end

function Bridge:Activate()
  self.activeTimestamp = GetTime()
  frame:Show()
end

function Bridge:Cancel()
  endSession()
  SpellStopTargeting()
end

frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:Hide()

frame:SetScript("OnEvent", function(_, event, arg1)
  if event == "ADDON_LOADED" and arg1 == ADDON then
    hooksecurefunc("SpellStopTargeting", function()
      if not Bridge:IsActive() or withinGracePeriod() then
        return
      end
      endSession()
    end)
    frame:UnregisterEvent("ADDON_LOADED")
  end
end)

-- OnUpdate only fires while the frame is shown (active session).
-- Force-ends on timeout as a safety net.
frame:SetScript("OnUpdate", function(_, elapsed)
  tick = tick + elapsed
  if tick < TICK then
    return
  end
  tick = 0

  if not Bridge:IsActive() then
    endSession()
  end
end)
