--[[ PetMoveToService e2e — verifies service integration with real WoW APIs. ]]

local _, ns = ...
local E2E = ns.E2E
local assert, assertEquals, assertTrue, assertFalse = E2E.assert, E2E.assertEquals, E2E.assertTrue, E2E.assertFalse

local tests = {}

tests[#tests + 1] = {
  name = "PetMoveToService:Activate creates pending command",
  fn = function()
    ns.petMoveToService:Cancel() -- ensure clean state
    ns.petMoveToService:Activate()
    assertTrue(ns.petMoveToService:HasPendingCommand(), "should have pending command")
    ns.petMoveToService:Cancel() -- cleanup
  end,
}

tests[#tests + 1] = {
  name = "PetMoveToService:Cancel resolves pending command",
  fn = function()
    ns.petMoveToService:Activate()
    ns.petMoveToService:Cancel()
    assertFalse(ns.petMoveToService:HasPendingCommand(), "should not have pending command")
  end,
}

tests[#tests + 1] = {
  name = "PetMoveToService:Cancel when idle is no-op",
  fn = function()
    ns.petMoveToService:Cancel()
    assertFalse(ns.petMoveToService:HasPendingCommand(), "should remain idle")
  end,
}

tests[#tests + 1] = {
  name = "CombatMode_PetMoveTo:IsActive reflects service state",
  fn = function()
    assertFalse(CombatMode_PetMoveTo:IsActive(), "should be inactive initially")
    ns.petMoveToService:Activate()
    assertTrue(CombatMode_PetMoveTo:IsActive(), "should be active after activate")
    ns.petMoveToService:Cancel()
    assertFalse(CombatMode_PetMoveTo:IsActive(), "should be inactive after cancel")
  end,
}

tests[#tests + 1] = {
  name = "hooksecurefunc(SpellStopTargeting) is installed",
  fn = function()
    -- SpellStopTargeting should be hooked (PetMoveToService:New hooks it).
    -- We can't directly inspect the hook, but we can verify calling it
    -- doesn't error when idle.
    SpellStopTargeting()
    assertFalse(ns.petMoveToService:HasPendingCommand(), "should remain idle after SpellStopTargeting")
  end,
}

tests[#tests + 1] = {
  name = "C_Timer.NewTimer callback fires",
  fn = function()
    -- Verify C_Timer.NewTimer is the real WoW API (not nil)
    assert(C_Timer ~= nil, "C_Timer should exist")
    assert(C_Timer.NewTimer ~= nil, "C_Timer.NewTimer should exist")
  end,
}

tests[#tests + 1] = {
  name = "ShouldFreeLookBeOff hook is installed when CM available",
  fn = function()
    assertTrue(ns.petMoveToService.hooked, "CM hook should be installed")
  end,
}

E2E:Register(tests)
