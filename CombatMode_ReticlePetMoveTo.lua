--[[ CombatMode_ReticlePetMoveTo.lua — pet-move session bridge for Combat Mode ]]

local ADDON = ...
local Bridge = _G.CombatMode_ReticlePetMoveTo

local GetTime = GetTime
local IsMouselooking = IsMouselooking

local TICK = 0.1
local STOP_TARGET_GRACE = Bridge.STOP_TARGET_GRACE
local CONFIRM_END_DELAY = Bridge.CONFIRM_END_DELAY

local frame
local tick = 0
local confirmEndTimer

local function getCM()
  return Bridge:GetCM()
end

local function cancelConfirmEndTimer()
  if confirmEndTimer then
    confirmEndTimer:Cancel()
    confirmEndTimer = nil
  end
end

local function withinGracePeriod()
  local t = Bridge.activeTimestamp
  return type(t) == "number" and (GetTime() - t) < STOP_TARGET_GRACE
end

local function relockCursor()
  local cm = getCM()
  if cm and cm.LockFreeLook and not IsMouselooking() then
    cm.LockFreeLook()
  end
end

local function endSession()
  if not Bridge.activeTimestamp then
    return
  end
  Bridge.activeTimestamp = nil
  cancelConfirmEndTimer()
  relockCursor()
  frame:Hide()
end

local function scheduleConfirmEnd()
  cancelConfirmEndTimer()
  local sessionStart = Bridge.activeTimestamp
  confirmEndTimer = C_Timer.NewTimer(CONFIRM_END_DELAY, function()
    confirmEndTimer = nil
    if Bridge.activeTimestamp == sessionStart then
      endSession()
    end
  end)
end

function Bridge:Activate()
  self.activeTimestamp = GetTime()
  frame:Show()
end

-- Internal cleanup only — the macro no longer calls this because
-- SpellStopTargeting() cannot dismiss /petmoveto targeting.
function Bridge:Cancel()
  endSession()
end

frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("GLOBAL_MOUSE_DOWN")
frame:Hide()

frame:SetScript("OnEvent", function(_, event, arg1)
  if event == "ADDON_LOADED" and arg1 == ADDON then
    -- ESC fires SpellStopTargeting even during /petmoveto; use it as a signal.
    hooksecurefunc("SpellStopTargeting", function()
      if not Bridge:IsActive() or withinGracePeriod() then
        return
      end
      endSession()
    end)
    frame:UnregisterEvent("ADDON_LOADED")
    return
  end

  if event ~= "GLOBAL_MOUSE_DOWN" or not Bridge:IsActive() then
    return
  end

  if arg1 == "LeftButton" then
    -- LMB confirms placement. Delay so the ground click completes before re-lock.
    scheduleConfirmEnd()
  elseif arg1 == "RightButton" then
    -- RMB cancels targeting immediately at the C level.
    endSession()
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
