--[[ Config.lua — bundled CM custom condition + pet-move macro installer ]]

local Bridge = {}
_G.CombatMode_ReticlePetMoveTo = Bridge

Bridge.TIMEOUT = 30
Bridge.STOP_TARGET_GRACE = 0.35
Bridge.CONFIRM_END_DELAY = 0.5
Bridge.GROUND_CLICK_BINDING = "CAMERAORSELECTORMOVE"
Bridge.CONDITION_VERSION = 3

Bridge.MACRO_NAME = "CM Pet Move"
Bridge.MACRO_ICON = "Ability_Hunter_MastersCall"
Bridge.MACRO_TEXT = table.concat({
  "/run if CombatMode_ReticlePetMoveTo:IsActive() then CombatMode_ReticlePetMoveTo:Cancel() return end",
  "/petpassive",
  "/petmoveto",
  "/run CombatMode_ReticlePetMoveTo:Activate()",
}, "\n")

Bridge.CONDITION_BODY = table.concat({
  "if SpellIsTargeting() then return true end",
  "if CombatMode_ReticlePetMoveTo:WantsCursorUnlock() then return true end",
  "return false",
}, "\n")

function Bridge:GetCM()
  return LibStub("AceAddon-3.0"):GetAddon("CombatMode", true)
end

function Bridge:ShouldUnlockCursorDuringPetMove()
  return CombatMode_ReticlePetMoveToDB and CombatMode_ReticlePetMoveToDB.unlockCursor == true
end

function Bridge:IsActive()
  local t = self.activeTimestamp
  if type(t) ~= "number" then
    return false
  end
  if GetTime() - t > self.TIMEOUT then
    self.activeTimestamp = nil
    return false
  end
  return true
end

function Bridge:WantsCursorUnlock()
  if not self:ShouldUnlockCursorDuringPetMove() then
    return false
  end
  return self:IsActive()
end

function Bridge:ConditionNeedsUpdate(current, global)
  if not current:find("CombatMode_ReticlePetMoveTo:WantsCursorUnlock", 1, true) then
    return true
  end
  if current:find("petMoveActive", 1, true) then
    return true
  end
  return (global.cpmbConditionVersion or 0) < self.CONDITION_VERSION
end

function Bridge:InstallCMCondition()
  local cm = self:GetCM()
  if not cm or not cm.DB or not cm.DB.global then
    return false, "Combat Mode is not loaded."
  end

  local global = cm.DB.global
  local current = global.customCondition or ""

  if not self:ConditionNeedsUpdate(current, global) then
    return true, "Combat Mode custom condition already installed."
  end

  -- Preserve unrelated user conditions; detect ours (old or new name) via WantsCursorUnlock.
  if current:match("%S") and not current:find("petMoveActive", 1, true) and not current:find("WantsCursorUnlock", 1, true) then
    global.customCondition = "if CombatMode_ReticlePetMoveTo:WantsCursorUnlock() then return true end\n" .. current
  else
    global.customCondition = self.CONDITION_BODY
  end

  global.cpmbConditionVersion = self.CONDITION_VERSION
  return true, "installed Combat Mode custom condition."
end

function Bridge:InstallMacro()
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

function Bridge:Print(msg)
  print("|cff33ccffCM_ReticlePetMoveTo:|r " .. msg)
end

function Bridge:InstallAll(silent)
  local okCM, msgCM = self:InstallCMCondition()
  local okMacro, msgMacro = self:InstallMacro()

  if not silent then
    if okCM then
      self:Print(msgCM)
    else
      self:Print("|cffff5050" .. msgCM .. "|r")
    end
    if okMacro then
      self:Print(msgMacro)
    else
      self:Print("|cffff5050" .. msgMacro .. "|r")
    end
    if okCM and okMacro then
      self:Print("Bind |cff00ff00` |r (or any key) to macro |cff00ff00" .. self.MACRO_NAME .. "|r.")
    end
  end

  return okCM and okMacro
end

function Bridge:TryAutoInstall()
  if InCombatLockdown() then
    self.pendingInstall = true
    return
  end

  self.pendingInstall = false
  local okCM = self:InstallCMCondition()
  local okMacro = self:InstallMacro()
  local ok = okCM and okMacro

  if not CombatMode_ReticlePetMoveToDB then
    CombatMode_ReticlePetMoveToDB = {}
  end

  if ok and not CombatMode_ReticlePetMoveToDB.greeted then
    CombatMode_ReticlePetMoveToDB.greeted = true
    self:Print("Installed CM custom condition + |cff00ff00" .. self.MACRO_NAME .. "|r macro.")
    self:Print("Bind |cff00ff00` |r to that macro. Use |cff00ff00/cmpet|r for help.")
  end
end

function Bridge:ShowStatus()
  local cm = self:GetCM()
  local current = cm and cm.DB and cm.DB.global and (cm.DB.global.customCondition or "") or ""
  local conditionOk = current:find("CombatMode_ReticlePetMoveTo:WantsCursorUnlock", 1, true)
    and not current:find("petMoveActive", 1, true)

  local macroIndex = GetMacroIndexByName(self.MACRO_NAME)
  local unlockOn = self:ShouldUnlockCursorDuringPetMove()
  self:Print(
    (conditionOk and "|cff00ff00CM condition: installed|r" or "|cffffcc00CM condition: missing|r")
      .. " | "
      .. (macroIndex > 0 and ("|cff00ff00Macro: " .. self.MACRO_NAME .. " #" .. macroIndex .. "|r") or "|cffffcc00Macro: missing|r")
  )
  self:Print(
    unlockOn and "Cursor unlock: |cff00ff00on|r" or "Cursor unlock: |cff00ff00off|r (reticle locked while aiming)"
  )
  self:Print("Run |cff00ff00/cmpet install|r to reinstall. Bind |cff00ff00` |r to the macro.")
  self:Print("|cff00ff00/cmpet unlock|r toggles free-cursor mode during pet move.")
end

SLASH_COMBATMODE_RETICLEPETMOVETO1 = "/cmpet"
SlashCmdList["COMBATMODE_RETICLEPETMOVETO"] = function(msg)
  msg = strtrim(msg or ""):lower()
  if msg == "install" or msg == "setup" then
    Bridge:InstallAll(false)
  elseif msg == "unlock" then
    if not CombatMode_ReticlePetMoveToDB then
      CombatMode_ReticlePetMoveToDB = {}
    end
    local enable = not Bridge:ShouldUnlockCursorDuringPetMove()
    CombatMode_ReticlePetMoveToDB.unlockCursor = enable
    if enable then
      Bridge:Print("Cursor unlock during pet move: |cff00ff00on|r (free mouse while aiming).")
    else
      Bridge:Print("Cursor unlock during pet move: |cff00ff00off|r (reticle stays locked; LMB still places pet).")
    end
  elseif msg == "macro" then
    Bridge:Print(Bridge.MACRO_TEXT:gsub("\n", " "))
  elseif msg == "condition" then
    Bridge:Print(Bridge.CONDITION_BODY)
  else
    Bridge:ShowStatus()
  end
end

local installFrame = CreateFrame("Frame")
installFrame:RegisterEvent("PLAYER_LOGIN")
installFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
installFrame:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_LOGIN" then
    C_Timer.After(0, function()
      Bridge:TryAutoInstall()
    end)
  elseif event == "PLAYER_REGEN_ENABLED" and Bridge.pendingInstall then
    Bridge:TryAutoInstall()
  end
end)
