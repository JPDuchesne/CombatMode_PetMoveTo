--[[ PetMoveToCommand.lua — single /petmoveto activation ]]

local _, ns = ...

local PetMoveToCommand = {}
PetMoveToCommand.__index = PetMoveToCommand

function PetMoveToCommand:New()
  return setmetatable({
    startTime = GetTime(),
    endTime = nil,
    state = "targeting",
  }, self)
end

function PetMoveToCommand:Confirm()
  if self.state ~= "targeting" then
    error("PetMoveToCommand: cannot confirm from state '" .. self.state .. "'")
  end
  self.state = "confirmed"
  self.endTime = GetTime()
end

function PetMoveToCommand:Cancel()
  if self.state ~= "targeting" then
    error("PetMoveToCommand: cannot cancel from state '" .. self.state .. "'")
  end
  self.state = "cancelled"
  self.endTime = GetTime()
end

function PetMoveToCommand:IsFinalized()
  return self.state ~= "targeting"
end

ns.PetMoveToCommand = PetMoveToCommand
