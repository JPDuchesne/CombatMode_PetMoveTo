--[[ PetMoveToCommand.lua — single /petmoveto activation ]]

local _, ns = ...

---@alias PetMoveToCommandState "targeting"|"confirmed"|"cancelled"

---@class PetMoveToCommand
---@field startTime number Creation timestamp (GetTime)
---@field endTime number? Finalization timestamp, nil while targeting
---@field state PetMoveToCommandState
local PetMoveToCommand = {}
PetMoveToCommand.__index = PetMoveToCommand

---Create a new command. State starts as "targeting".
---@return PetMoveToCommand
function PetMoveToCommand:New()
  return setmetatable({
    startTime = GetTime(),
    endTime = nil,
    state = "targeting",
  }, self)
end

---Finalize as confirmed.
---Throws if not in "targeting" state.
function PetMoveToCommand:Confirm()
  if self.state ~= "targeting" then
    error("PetMoveToCommand: cannot confirm from state '" .. self.state .. "'")
  end
  self.state = "confirmed"
  self.endTime = GetTime()
end

---Finalize as cancelled.
---Throws if not in "targeting" state.
function PetMoveToCommand:Cancel()
  if self.state ~= "targeting" then
    error("PetMoveToCommand: cannot cancel from state '" .. self.state .. "'")
  end
  self.state = "cancelled"
  self.endTime = GetTime()
end

---Whether the command has reached a terminal state (confirmed or cancelled).
---@return boolean
function PetMoveToCommand:IsFinalized()
  return self.state ~= "targeting"
end

ns.PetMoveToCommand = PetMoveToCommand
