--[[ PetMoveToCommand e2e — verifies command state machine in the live client. ]]

local _, ns = ...
local E2E = ns.E2E
local assert, assertEquals = E2E.assert, E2E.assertEquals

local tests = {}

tests[#tests + 1] = {
  name = "PetMoveToCommand:New creates targeting command",
  fn = function()
    local cmd = ns.PetMoveToCommand:New()
    assertEquals(cmd.state, "targeting", "initial state")
    assert(cmd.startTime > 0, "startTime should be positive")
    assert(cmd.endTime == nil, "endTime should be nil")
  end,
}

tests[#tests + 1] = {
  name = "PetMoveToCommand:Confirm transitions to confirmed",
  fn = function()
    local cmd = ns.PetMoveToCommand:New()
    cmd:Confirm()
    assertEquals(cmd.state, "confirmed", "state after confirm")
    assert(cmd.endTime ~= nil, "endTime should be set")
  end,
}

tests[#tests + 1] = {
  name = "PetMoveToCommand:Cancel transitions to cancelled",
  fn = function()
    local cmd = ns.PetMoveToCommand:New()
    cmd:Cancel()
    assertEquals(cmd.state, "cancelled", "state after cancel")
    assert(cmd.endTime ~= nil, "endTime should be set")
  end,
}

tests[#tests + 1] = {
  name = "PetMoveToCommand double-confirm throws",
  fn = function()
    local cmd = ns.PetMoveToCommand:New()
    cmd:Confirm()
    local ok = pcall(cmd.Confirm, cmd)
    assert(not ok, "double confirm should error")
  end,
}

E2E:Register(tests)
