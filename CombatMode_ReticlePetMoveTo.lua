--[[ CombatMode_ReticlePetMoveTo.lua — pet-move session + LMB override bridge for Combat Mode ]]

local ADDON = ...
local Bridge = _G.CombatMode_ReticlePetMoveTo

local GetTime = GetTime
local SetMouselookOverrideBinding = SetMouselookOverrideBinding

local LMB_BINDING_KEYS = { "button1", "shiftbutton1", "ctrlbutton1", "altbutton1" }
local TICK = 0.1
local STOP_TARGET_GRACE = Bridge.STOP_TARGET_GRACE
local CONFIRM_END_DELAY = Bridge.CONFIRM_END_DELAY
local GROUND_CLICK_BINDING = Bridge.GROUND_CLICK_BINDING

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

local function applyPetMoveLmbBinding()
  local addon = getCM()
  if not addon then
    return
  end
  local loc = addon.GetBindingsLocation and addon.GetBindingsLocation() or "char"
  local bindings = addon.DB[loc] and addon.DB[loc].bindings
  if not bindings then
    return
  end
  for _, name in ipairs(LMB_BINDING_KEYS) do
    local settings = bindings[name]
    if settings and settings.enabled and settings.key then
      -- nil clears CM's click-cast override, letting the raw click confirm ground targeting.
      SetMouselookOverrideBinding(settings.key, GROUND_CLICK_BINDING)
    end
  end
end

local function restoreLmbOverrides()
  local addon = getCM()
  if not addon or not addon.OverrideDefaultButtons then
    return
  end
  addon.OverrideDefaultButtons()
end

local function endSession()
  if not Bridge.activeTimestamp then
    return
  end
  Bridge.activeTimestamp = nil
  cancelConfirmEndTimer()
  restoreLmbOverrides()
  frame:Hide()
end

local function onSessionStart()
  cancelConfirmEndTimer()
  applyPetMoveLmbBinding()
end

local function scheduleConfirmEnd()
  cancelConfirmEndTimer()
  local sessionStart = Bridge.activeTimestamp
  confirmEndTimer = C_Timer.NewTimer(CONFIRM_END_DELAY, function()
    confirmEndTimer = nil
    -- Only end the session this timer belongs to; a new Activate() resets activeTimestamp.
    if Bridge.activeTimestamp == sessionStart then
      endSession()
    end
  end)
end

function Bridge:Activate()
  self.activeTimestamp = GetTime()
  frame:Show()
  onSessionStart()
end

function Bridge:Cancel()
  endSession()
  SpellStopTargeting()
end

frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("GLOBAL_MOUSE_DOWN")
frame:Hide()

frame:SetScript("OnEvent", function(_, event, arg1)
  if event == "ADDON_LOADED" and arg1 == ADDON then
    local cm = getCM()
    if cm and cm.OverrideDefaultButtons then
      hooksecurefunc(cm, "OverrideDefaultButtons", function()
        if Bridge:IsActive() then
          applyPetMoveLmbBinding()
        end
      end)
    end
    hooksecurefunc("SpellStopTargeting", function()
      if not Bridge:IsActive() or withinGracePeriod() then
        return
      end
      endSession()
    end)
    frame:UnregisterEvent("ADDON_LOADED")
    return
  end

  -- Safety net: schedule session end on LMB in case SpellStopTargeting does not fire on confirm.
  -- /petmoveto is not a spell (SpellIsTargeting() is false), so confirm behavior is unverified.
  if event == "GLOBAL_MOUSE_DOWN" and arg1 == "LeftButton" and Bridge:IsActive() and not withinGracePeriod() then
    scheduleConfirmEnd()
  end
end)

-- OnUpdate only fires while the frame is shown (active session).
-- Re-applies LMB binding defensively and force-ends on timeout.
frame:SetScript("OnUpdate", function(_, elapsed)
  tick = tick + elapsed
  if tick < TICK then
    return
  end
  tick = 0

  if not Bridge:IsActive() then
    endSession()
    return
  end

  applyPetMoveLmbBinding()
end)
