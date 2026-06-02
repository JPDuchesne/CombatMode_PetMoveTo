--[[ e2e_runner.lua — simple in-game test runner for /cmpet e2e.

Collects test functions from e2e test modules, runs them sequentially,
and prints results to the chat frame. No external dependencies.

Each test module returns a table of { name = string, fn = function } entries.
Tests that error are marked as failures; tests that complete without error pass.
]]

local _, ns = ...

local E2E = {}
ns.E2E = E2E

E2E.suites = {}

---Register an e2e test suite (table of { name, fn } entries).
---@param suite table[]
function E2E:Register(suite)
  for _, test in ipairs(suite) do
    table.insert(self.suites, test)
  end
end

---Run all registered e2e tests and print results to chat.
function E2E:Run()
  local passed, failed, errors = 0, 0, {}

  print("|cff33ff99[E2E]|r Running " .. #self.suites .. " tests...")

  for _, test in ipairs(self.suites) do
    local ok, err = pcall(test.fn)
    if ok then
      passed = passed + 1
      print("|cff00ff00  PASS|r " .. test.name)
    else
      failed = failed + 1
      table.insert(errors, { name = test.name, err = tostring(err) })
      print("|cffff5050  FAIL|r " .. test.name .. ": " .. tostring(err))
    end
  end

  print("|cff33ff99[E2E]|r " .. passed .. " passed, " .. failed .. " failed")

  if #errors > 0 then
    print("|cffff5050[E2E] Failures:|r")
    for _, e in ipairs(errors) do
      print("  " .. e.name .. ": " .. e.err)
    end
  end
end

---Simple assertion helper for e2e tests (no LuaUnit in game client).
---@param condition boolean
---@param message string?
function E2E.assert(condition, message)
  if not condition then
    error(message or "assertion failed", 2)
  end
end

---Assert two values are equal.
function E2E.assertEquals(actual, expected, message)
  if actual ~= expected then
    error((message or "assertEquals") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
  end
end

---Assert value is truthy.
function E2E.assertTrue(value, message)
  if not value then
    error((message or "assertTrue") .. ": expected truthy, got " .. tostring(value), 2)
  end
end

---Assert value is falsy.
function E2E.assertFalse(value, message)
  if value then
    error((message or "assertFalse") .. ": expected falsy, got " .. tostring(value), 2)
  end
end
