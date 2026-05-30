--[[ PetMoveToService.lua — command lifecycle, event handling, cursor management ]]

local _, ns = ...
local PetMoveToCommand = ns.PetMoveToCommand
local IsMouselooking = IsMouselooking

local PetMoveToService = {}
PetMoveToService.__index = PetMoveToService

PetMoveToService.STARTUP_GRACE = 0.35  -- Ignore SpellStopTargeting / re-activation after activation
PetMoveToService.RELOCK_DELAY  = 0.5   -- Wait after LMB confirm before re-locking cursor

function PetMoveToService:New(cm)
  return setmetatable({
    cm = cm,
    pendingCommand = nil,
  }, self)
end

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

function PetMoveToService:Cancel()
  if not self:HasPendingCommand() then return end
  if not self.pendingCommand:IsFinalized() then
    self.pendingCommand:Cancel()
  end
  self:ResolveCommand()
end

function PetMoveToService:HasPendingCommand()
  return self.pendingCommand ~= nil
end

function PetMoveToService:ResolveCommand()
  if not self.pendingCommand then return end
  self.pendingCommand = nil
  self:RelockCursor()
end

function PetMoveToService:RelockCursor()
  if self.cm.LockFreeLook and not IsMouselooking() then
    self.cm.LockFreeLook()
  end
end

function PetMoveToService:ConfirmCommand(command)
  command:Confirm()
  self:ScheduleRelockCursor()
end

function PetMoveToService:CancelCommand(command)
  command:Cancel()
  self:ResolveCommand()
end

function PetMoveToService:ScheduleRelockCursor()
  local command = self.pendingCommand
  C_Timer.NewTimer(self.RELOCK_DELAY, function()
    if self.pendingCommand == command then
      self:ResolveCommand()
    end
  end)
end

function PetMoveToService:OnMouseDown(button)
  if not self:HasPendingCommand() then return end
  if self.pendingCommand:IsFinalized() then return end

  if button == "LeftButton" then
    self:ConfirmCommand(self.pendingCommand)
  elseif button == "RightButton" then
    self:CancelCommand(self.pendingCommand)
  end
end

function PetMoveToService:OnSpellStopTargeting()
  if not self:HasPendingCommand() then return end
  if self.pendingCommand:IsFinalized() then return end
  if (GetTime() - self.pendingCommand.startTime) < self.STARTUP_GRACE then return end

  self:CancelCommand(self.pendingCommand)
end

function PetMoveToService:Setup()
  hooksecurefunc("SpellStopTargeting", function()
    self:OnSpellStopTargeting()
  end)

  local service = self
  local frame = CreateFrame("Frame")
  frame:RegisterEvent("GLOBAL_MOUSE_DOWN")
  frame:SetScript("OnEvent", function(_, _, button)
    service:OnMouseDown(button)
  end)
end

ns.PetMoveToService = PetMoveToService
