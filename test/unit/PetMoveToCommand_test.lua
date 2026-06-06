local WoWAPI = require("test.helpers.wow_api")
local lu = require("luaunit")

-- Load only PetMoveToCommand (not the full addon, to avoid DI wiring)
local ns = {}
local chunk = assert(loadfile("src/PetMoveToCommand.lua"))
chunk("CombatMode_PetMoveTo", ns)

local PetMoveToCommand = ns.PetMoveToCommand

TestPetMoveToCommand = {}

function TestPetMoveToCommand:setUp()
  WoWAPI.Reset()
end

function TestPetMoveToCommand:test_new_starts_in_targeting_state()
  local cmd = PetMoveToCommand:New()
  lu.assertEquals(cmd.state, "targeting")
end

function TestPetMoveToCommand:test_new_records_start_time()
  WoWAPI.AdvanceTime(5.0)
  local cmd = PetMoveToCommand:New()
  lu.assertEquals(cmd.startTime, 5.0)
end

function TestPetMoveToCommand:test_new_has_nil_end_time()
  local cmd = PetMoveToCommand:New()
  lu.assertNil(cmd.endTime)
end

function TestPetMoveToCommand:test_confirm_transitions_to_confirmed()
  local cmd = PetMoveToCommand:New()
  cmd:Confirm()
  lu.assertEquals(cmd.state, "confirmed")
end

function TestPetMoveToCommand:test_confirm_records_end_time()
  local cmd = PetMoveToCommand:New()
  WoWAPI.AdvanceTime(1.0)
  cmd:Confirm()
  lu.assertEquals(cmd.endTime, 1.0)
end

function TestPetMoveToCommand:test_cancel_transitions_to_cancelled()
  local cmd = PetMoveToCommand:New()
  cmd:Cancel()
  lu.assertEquals(cmd.state, "cancelled")
end

function TestPetMoveToCommand:test_cancel_records_end_time()
  local cmd = PetMoveToCommand:New()
  WoWAPI.AdvanceTime(2.0)
  cmd:Cancel()
  lu.assertEquals(cmd.endTime, 2.0)
end

function TestPetMoveToCommand:test_confirm_from_confirmed_throws()
  local cmd = PetMoveToCommand:New()
  cmd:Confirm()
  lu.assertErrorMsgContains("cannot confirm", function() cmd:Confirm() end)
end

function TestPetMoveToCommand:test_confirm_from_cancelled_throws()
  local cmd = PetMoveToCommand:New()
  cmd:Cancel()
  lu.assertErrorMsgContains("cannot confirm", function() cmd:Confirm() end)
end

function TestPetMoveToCommand:test_cancel_from_confirmed_throws()
  local cmd = PetMoveToCommand:New()
  cmd:Confirm()
  lu.assertErrorMsgContains("cannot cancel", function() cmd:Cancel() end)
end

function TestPetMoveToCommand:test_cancel_from_cancelled_throws()
  local cmd = PetMoveToCommand:New()
  cmd:Cancel()
  lu.assertErrorMsgContains("cannot cancel", function() cmd:Cancel() end)
end

function TestPetMoveToCommand:test_is_finalized_false_while_targeting()
  local cmd = PetMoveToCommand:New()
  lu.assertFalse(cmd:IsFinalized())
end

function TestPetMoveToCommand:test_is_finalized_true_after_confirm()
  local cmd = PetMoveToCommand:New()
  cmd:Confirm()
  lu.assertTrue(cmd:IsFinalized())
end

function TestPetMoveToCommand:test_is_finalized_true_after_cancel()
  local cmd = PetMoveToCommand:New()
  cmd:Cancel()
  lu.assertTrue(cmd:IsFinalized())
end

os.exit(lu.LuaUnit.run())
