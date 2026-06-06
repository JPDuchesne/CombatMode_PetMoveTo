--[[ spy.lua — lightweight call-tracking utility for tests.

Usage:
  local spy = require("test.helpers.spy")

  local s = spy.new()
  s("hello", 42)
  assert(s.callCount == 1)
  assert(s.calls[1][1] == "hello")

  -- Spy wrapping an existing function
  local s2 = spy.on(myObj, "myMethod")
  myObj:myMethod("arg")
  assert(s2.callCount == 1)
  s2:restore()  -- puts the original back
]]

local M = {}

--- Create a standalone spy function.
---@param returnValue any optional value the spy returns when called
---@return table spy  callable table with .calls, .callCount, :reset()
function M.new(returnValue)
  local s = {
    calls = {},
    callCount = 0,
    returnValue = returnValue,
  }

  setmetatable(s, {
    __call = function(self, ...)
      self.callCount = self.callCount + 1
      self.calls[self.callCount] = { ... }
      return self.returnValue
    end,
  })

  function s:reset()
    self.calls = {}
    self.callCount = 0
  end

  return s
end

--- Spy on an object's method, preserving the original.
---@param obj table
---@param methodName string
---@return table spy  callable table with .calls, .callCount, :restore(), :reset()
function M.on(obj, methodName)
  local original = obj[methodName]
  local s = M.new()
  s._original = original
  s._obj = obj
  s._methodName = methodName

  obj[methodName] = function(...)
    s.callCount = s.callCount + 1
    s.calls[s.callCount] = { ... }
    if original then
      return original(...)
    end
  end

  function s:restore()
    self._obj[self._methodName] = self._original
  end

  return s
end

return M
