local WoWAPI = require("test.helpers.wow_api")
local lu = require("luaunit")
local spy = require("test.helpers.spy")

-- Load PetMoveToCommand + PetMoveToService in isolation
local function loadService()
  local ns = {}
  loadfile("src/PetMoveToCommand.lua")("CombatMode_PetMoveTo", ns)
  loadfile("src/PetMoveToService.lua")("CombatMode_PetMoveTo", ns)
  return ns
end

-- Create a minimal CombatMode stub with spyable LockFreeLook
local function makeCM()
  return {
    LockFreeLook = spy.new(),
    ShouldFreeLookBeOff = function() return false end,
  }
end

TestPetMoveToService = {}

function TestPetMoveToService:setUp()
  WoWAPI.Reset()
  self.ns = loadService()
  self.cm = makeCM()
  self.service = self.ns.PetMoveToService:New(self.cm)
end

-- Construction

function TestPetMoveToService:test_new_requires_cm()
  lu.assertErrorMsgContains("requires a CombatMode", function()
    self.ns.PetMoveToService:New(nil)
  end)
end

function TestPetMoveToService:test_new_starts_without_pending_command()
  lu.assertFalse(self.service:HasPendingCommand())
end

-- Activate

function TestPetMoveToService:test_activate_creates_pending_command()
  self.service:Activate()
  lu.assertTrue(self.service:HasPendingCommand())
end

function TestPetMoveToService:test_activate_within_grace_is_ignored()
  self.service:Activate()
  local first = self.service.pendingCommand
  WoWAPI.AdvanceTime(0.1) -- within STARTUP_GRACE (0.35)
  self.service:Activate()
  lu.assertIs(self.service.pendingCommand, first)
end

function TestPetMoveToService:test_activate_past_grace_cancels_and_creates_new()
  self.service:Activate()
  local first = self.service.pendingCommand
  WoWAPI.AdvanceTime(0.5) -- past STARTUP_GRACE
  self.service:Activate()
  lu.assertEquals(first.state, "cancelled")
  lu.assertNotIs(self.service.pendingCommand, first)
  lu.assertEquals(self.service.pendingCommand.state, "targeting")
end

-- Cancel

function TestPetMoveToService:test_cancel_when_idle_is_noop()
  self.service:Cancel()
  lu.assertFalse(self.service:HasPendingCommand())
end

function TestPetMoveToService:test_cancel_finalizes_and_resolves()
  self.service:Activate()
  local cmd = self.service.pendingCommand
  self.service:Cancel()
  lu.assertEquals(cmd.state, "cancelled")
  lu.assertFalse(self.service:HasPendingCommand())
end

-- OnMouseDown

function TestPetMoveToService:test_left_click_confirms()
  self.service:Activate()
  local cmd = self.service.pendingCommand
  self.service:OnMouseDown("LeftButton")
  lu.assertEquals(cmd.state, "confirmed")
end

function TestPetMoveToService:test_right_click_cancels()
  self.service:Activate()
  local cmd = self.service.pendingCommand
  self.service:OnMouseDown("RightButton")
  lu.assertEquals(cmd.state, "cancelled")
  lu.assertFalse(self.service:HasPendingCommand())
end

function TestPetMoveToService:test_click_when_idle_is_noop()
  self.service:OnMouseDown("LeftButton")
  lu.assertFalse(self.service:HasPendingCommand())
end

function TestPetMoveToService:test_click_when_finalized_is_noop()
  self.service:Activate()
  self.service.pendingCommand:Cancel()
  self.service:OnMouseDown("LeftButton")
  -- Still has command ref (not resolved via service), but state unchanged
  lu.assertEquals(self.service.pendingCommand.state, "cancelled")
end

-- OnSpellStopTargeting

function TestPetMoveToService:test_spell_stop_within_grace_is_ignored()
  self.service:Activate()
  local cmd = self.service.pendingCommand
  WoWAPI.AdvanceTime(0.1) -- within STARTUP_GRACE
  self.service:OnSpellStopTargeting()
  lu.assertEquals(cmd.state, "targeting")
end

function TestPetMoveToService:test_spell_stop_past_grace_cancels()
  self.service:Activate()
  local cmd = self.service.pendingCommand
  WoWAPI.AdvanceTime(0.5) -- past STARTUP_GRACE
  self.service:OnSpellStopTargeting()
  lu.assertEquals(cmd.state, "cancelled")
  lu.assertFalse(self.service:HasPendingCommand())
end

function TestPetMoveToService:test_spell_stop_when_idle_is_noop()
  self.service:OnSpellStopTargeting()
  lu.assertFalse(self.service:HasPendingCommand())
end

-- RelockCursor

function TestPetMoveToService:test_relock_calls_lock_free_look_when_not_mouselooking()
  WoWAPI.SetMouselooking(false)
  self.service:RelockCursor()
  lu.assertEquals(self.cm.LockFreeLook.callCount, 1)
end

function TestPetMoveToService:test_relock_skips_when_already_mouselooking()
  WoWAPI.SetMouselooking(true)
  self.service:RelockCursor()
  lu.assertEquals(self.cm.LockFreeLook.callCount, 0)
end

-- ScheduleRelockCursor (timer-based resolution)

function TestPetMoveToService:test_confirm_schedules_delayed_resolution()
  self.service:Activate()
  self.service:OnMouseDown("LeftButton")
  -- Command confirmed but service still has pending (waiting for timer)
  lu.assertTrue(self.service:HasPendingCommand())

  WoWAPI.AdvanceTime(self.ns.PetMoveToService.RELOCK_DELAY)
  WoWAPI.FirePendingTimers()
  lu.assertFalse(self.service:HasPendingCommand())
end

function TestPetMoveToService:test_timer_is_identity_gated()
  self.service:Activate()
  self.service:OnMouseDown("LeftButton")

  -- Advance past grace period so re-activation is allowed
  WoWAPI.AdvanceTime(self.ns.PetMoveToService.STARTUP_GRACE + 0.1)
  self.service:Activate()
  local second = self.service.pendingCommand

  WoWAPI.AdvanceTime(self.ns.PetMoveToService.RELOCK_DELAY)
  WoWAPI.FirePendingTimers()
  -- The old timer fired but was a no-op (identity mismatch)
  lu.assertTrue(self.service:HasPendingCommand())
  lu.assertIs(self.service.pendingCommand, second)
end

os.exit(lu.LuaUnit.run())
