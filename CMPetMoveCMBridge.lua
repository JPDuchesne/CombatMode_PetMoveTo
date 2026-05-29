--[[ CMPetMoveCMBridge.lua — pet-move session + LMB override bridge for Combat Mode ]]

local ADDON = ...
local Bridge = _G.CMPetMoveCMBridge

local GetTime = GetTime
local IsMouselooking = IsMouselooking
local SetMouselookOverrideBinding = SetMouselookOverrideBinding

local LMB_BINDING_KEYS = { "button1", "shiftbutton1", "ctrlbutton1", "altbutton1" }
local TICK = 0.1
local TIMEOUT = Bridge.TIMEOUT
local STOP_TARGET_GRACE = Bridge.STOP_TARGET_GRACE
local CONFIRM_END_DELAY = Bridge.CONFIRM_END_DELAY
local GROUND_CLICK_BINDING = Bridge.GROUND_CLICK_BINDING

local frame
local wasActive = false
local wasLocked = false
local didUnlockCursor = false
local tick = 0
local confirmEndTimer

local function getCM()
  return Bridge:GetCM()
end

local function getGlobal()
  local addon = getCM()
  if not addon or not addon.DB or not addon.DB.global then
    return nil
  end
  return addon.DB.global
end

local function cancelConfirmEndTimer()
  if confirmEndTimer then
    confirmEndTimer:Cancel()
    confirmEndTimer = nil
  end
end

local function petMoveTimestamp()
  local global = getGlobal()
  if not global then
    return nil
  end
  local t = global.petMoveActive
  if type(t) ~= "number" then
    return nil
  end
  if GetTime() - t > TIMEOUT then
    global.petMoveActive = nil
    return nil
  end
  return t
end

local function isActive()
  return petMoveTimestamp() ~= nil
end

local function withinGracePeriod()
  local t = petMoveTimestamp()
  return t ~= nil and (GetTime() - t) < STOP_TARGET_GRACE
end

local function clearSessionFlags()
  local global = getGlobal()
  if not global then
    return
  end
  global.petMoveActive = nil
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
      -- While mouselook is locked, nil still routes LMB to CM click-cast (e.g. a macro).
      -- Explicit ground-click binding places the pet without unlocking the reticle.
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

local function maybeRelock()
  if not didUnlockCursor then
    return
  end
  local addon = getCM()
  if not addon or not addon.LockFreeLook or not addon.ShouldFreeLookBeOff then
    return
  end
  if not addon.ShouldFreeLookBeOff() and not IsMouselooking() then
    addon.LockFreeLook()
  end
end

local function onSessionEnd()
  cancelConfirmEndTimer()
  restoreLmbOverrides()
  maybeRelock()
  wasLocked = false
  didUnlockCursor = false
end

local function endSession()
  if not isActive() then
    cancelConfirmEndTimer()
    return
  end
  clearSessionFlags()
  if wasActive then
    onSessionEnd()
    wasActive = false
  end
end

local function scheduleConfirmEnd()
  cancelConfirmEndTimer()
  confirmEndTimer = C_Timer.NewTimer(CONFIRM_END_DELAY, function()
    confirmEndTimer = nil
    if isActive() then
      endSession()
    end
  end)
end

local function onSessionStart()
  local addon = getCM()
  if not addon then
    return
  end
  cancelConfirmEndTimer()
  wasLocked = IsMouselooking()
  didUnlockCursor = false
  applyPetMoveLmbBinding()
  if wasLocked and addon.UnlockFreeLook and Bridge:ShouldUnlockCursorDuringPetMove() then
    addon.UnlockFreeLook()
    didUnlockCursor = true
  end
end

frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("GLOBAL_MOUSE_DOWN")

frame:SetScript("OnEvent", function(_, event, arg1)
  if event == "ADDON_LOADED" and arg1 == ADDON then
    local cm = getCM()
    if cm and cm.OverrideDefaultButtons then
      hooksecurefunc(cm, "OverrideDefaultButtons", function()
        if isActive() then
          applyPetMoveLmbBinding()
        end
      end)
    end
    hooksecurefunc("SpellStopTargeting", function()
      if not isActive() or withinGracePeriod() then
        return
      end
      endSession()
    end)
    return
  end

  if event == "GLOBAL_MOUSE_DOWN" and arg1 == "LeftButton" and isActive() and not withinGracePeriod() then
    -- Do NOT endSession immediately — that restores click-cast before the ground click lands.
    scheduleConfirmEnd()
  end
end)

frame:SetScript("OnUpdate", function(_, elapsed)
  tick = tick + elapsed
  if tick < TICK then
    return
  end
  tick = 0

  local active = isActive()
  if active then
    applyPetMoveLmbBinding()
  end

  if active and not wasActive then
    onSessionStart()
  elseif not active and wasActive then
    onSessionEnd()
  end

  wasActive = active
end)
