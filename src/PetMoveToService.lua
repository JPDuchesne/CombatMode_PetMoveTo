--[[ PetMoveToService.lua — command lifecycle, event handling, cursor management ]]

local _, ns = ...
local PetMoveToCommand = ns.PetMoveToCommand
local IsMouselooking = IsMouselooking

---@class PetMoveToService
---@field cm table CombatMode addon reference (injected)
---@field pendingCommand PetMoveToCommand? Current command, nil when idle
---@field hooked boolean? Whether the CM cursor-lock hook is active
local PetMoveToService = {}
PetMoveToService.__index = PetMoveToService

PetMoveToService.STARTUP_GRACE = 0.35  -- Ignore SpellStopTargeting / re-activation after activation
PetMoveToService.RELOCK_DELAY  = 0.5   -- Delay before re-locking cursor after confirmation

---Construct a fully initialized service. Registers WoW event handlers.
---@param cm table CombatMode addon reference
---@return PetMoveToService
function PetMoveToService:New(cm)
  if not cm then error("PetMoveToService requires a CombatMode addon reference.", 0) end

  local service = setmetatable({
    cm = cm,
    pendingCommand = nil,
  }, self)

  hooksecurefunc("SpellStopTargeting", function()
    service:OnSpellStopTargeting()
  end)

  local frame = CreateFrame("Frame")
  frame:RegisterEvent("GLOBAL_MOUSE_DOWN")
  frame:SetScript("OnEvent", function(_, _, button)
    service:OnMouseDown(button)
  end)

  return service
end

---Start a new pet-move command. If a command is already pending,
---it is cancelled (past grace) or the call is ignored (within grace).
function PetMoveToService:Activate()
  if self.pendingCommand then
    if (GetTime() - self.pendingCommand.startTime) < self.STARTUP_GRACE then
      return
    end
    if not self.pendingCommand:IsFinalized() then
      self.pendingCommand:Cancel()
    end
  end
  self.pendingCommand = PetMoveToCommand:New()
end

---Cancel the pending command (if any) and resolve immediately.
function PetMoveToService:Cancel()
  if not self:HasPendingCommand() then return end
  if not self.pendingCommand:IsFinalized() then
    self.pendingCommand:Cancel()
  end
  self:ResolveCommand()
end

---Whether the service has a pending command.
---@return boolean
function PetMoveToService:HasPendingCommand()
  return self.pendingCommand ~= nil
end

---Resolve the pending command. Transitions service to idle.
function PetMoveToService:ResolveCommand()
  if not self.pendingCommand then return end
  self.pendingCommand = nil
  self:RelockCursor()
end

---Re-engage CM mouselook if not already active.
function PetMoveToService:RelockCursor()
  if self.cm.LockFreeLook and not IsMouselooking() then
    self.cm.LockFreeLook()
  end
end

---Finalize the command as confirmed and schedule delayed resolution.
---@param command PetMoveToCommand
function PetMoveToService:ConfirmCommand(command)
  command:Confirm()
  self:ScheduleRelockCursor()
end

---Finalize the command as cancelled and resolve immediately.
---@param command PetMoveToCommand
function PetMoveToService:CancelCommand(command)
  command:Cancel()
  self:ResolveCommand()
end

---Schedule cursor re-lock after RELOCK_DELAY. Uses an identity-gated closure:
---if the pending command changes before the timer fires, the callback is a no-op.
function PetMoveToService:ScheduleRelockCursor()
  local command = self.pendingCommand
  C_Timer.NewTimer(self.RELOCK_DELAY, function()
    if self.pendingCommand == command then
      self:ResolveCommand()
    end
  end)
end

---Handle GLOBAL_MOUSE_DOWN. LMB confirms, RMB cancels.
---Ignored if no pending command or command is already finalized.
---@param button string "LeftButton"|"RightButton"
function PetMoveToService:OnMouseDown(button)
  if not self:HasPendingCommand() then return end
  if self.pendingCommand:IsFinalized() then return end

  if button == "LeftButton" then
    self:ConfirmCommand(self.pendingCommand)
  elseif button == "RightButton" then
    self:CancelCommand(self.pendingCommand)
  end
end

---Handle SpellStopTargeting hook (Esc key). Cancels the command unless
---within STARTUP_GRACE of activation or already finalized.
function PetMoveToService:OnSpellStopTargeting()
  if not self:HasPendingCommand() then return end
  if self.pendingCommand:IsFinalized() then return end
  if (GetTime() - self.pendingCommand.startTime) < self.STARTUP_GRACE then return end

  self:CancelCommand(self.pendingCommand)
end

ns.PetMoveToService = PetMoveToService
