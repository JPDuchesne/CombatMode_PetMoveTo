--[[ wow_env.lua — WoW API stubs for unit testing outside the game client.

Provides just enough of the WoW Lua API surface so that addon source files
can be loaded and exercised in a standard Lua 5.1 interpreter.

Usage:
  require("test.helpers.wow_env")
  local ns, addonName = loadAddon("CombatMode_PetMoveTo.toc")
]]

-- Time simulation
local currentTime = 0

function GetTime()
  return currentTime
end

--- Advance the simulated clock. Test-only helper, not a WoW API.
---@param seconds number
function AdvanceTime(seconds)
  currentTime = currentTime + seconds
end

--- Reset the simulated clock to zero. Test-only helper.
function ResetTime()
  currentTime = 0
end

-- Timer simulation — tracks pending timers so tests can fire them.
local timers = {}
local nextTimerId = 1

C_Timer = C_Timer or {}

function C_Timer.NewTimer(duration, callback)
  local id = nextTimerId
  nextTimerId = nextTimerId + 1
  local timer = { id = id, fireAt = currentTime + duration, callback = callback, cancelled = false }
  table.insert(timers, timer)
  return timer
end

--- Fire all timers whose fireAt <= currentTime. Test-only helper.
function FirePendingTimers()
  local fired = {}
  for i, timer in ipairs(timers) do
    if not timer.cancelled and timer.fireAt <= currentTime then
      timer.callback()
      table.insert(fired, i)
    end
  end
  -- Remove fired timers in reverse order
  for i = #fired, 1, -1 do
    table.remove(timers, fired[i])
  end
end

--- Clear all pending timers. Test-only helper.
function ClearTimers()
  timers = {}
  nextTimerId = 1
end

-- Frame system stubs
local frames = {}

---@class FakeFrame
---@field events table<string, function>
---@field scripts table<string, function>
local FakeFrame = {}
FakeFrame.__index = FakeFrame

function FakeFrame:RegisterEvent(event)
  self.events[event] = true
end

function FakeFrame:UnregisterEvent(event)
  self.events[event] = nil
end

function FakeFrame:SetScript(name, handler)
  self.scripts[name] = handler
end

function FakeFrame:GetScript(name)
  return self.scripts[name]
end

function CreateFrame(frameType, name, parent, template)
  local frame = setmetatable({
    type = frameType,
    name = name,
    events = {},
    scripts = {},
  }, FakeFrame)
  table.insert(frames, frame)
  return frame
end

--- Fire an event on all frames that registered for it.
---@param event string
---@param ... any
function FireEvent(event, ...)
  for _, frame in ipairs(frames) do
    if frame.events[event] and frame.scripts["OnEvent"] then
      frame.scripts["OnEvent"](frame, event, ...)
    end
  end
end

--- Clear all frames. Test-only helper.
function ClearFrames()
  frames = {}
end

-- String utilities (WoW globals)
function strtrim(str)
  if not str then return "" end
  return str:match("^%s*(.-)%s*$")
end

-- Combat lockdown
local inCombatLockdown = false

function InCombatLockdown()
  return inCombatLockdown
end

--- Set combat lockdown state. Test-only helper.
function SetCombatLockdown(locked)
  inCombatLockdown = locked
end

-- Mouselook
local mouselooking = false

function IsMouselooking()
  return mouselooking
end

--- Set mouselook state. Test-only helper.
function SetMouselooking(active)
  mouselooking = active
end

-- Macro stubs
local macros = {} -- { [index] = { name, icon, body, perChar } }
local nextMacroIndex = 1

function CreateMacro(name, icon, body, perChar)
  local index = nextMacroIndex
  nextMacroIndex = nextMacroIndex + 1
  macros[index] = { name = name, icon = icon, body = body, perChar = perChar }
  return index
end

function EditMacro(index, name, icon, body)
  if macros[index] then
    macros[index].name = name
    macros[index].icon = icon
    macros[index].body = body
  end
end

function GetMacroIndexByName(name)
  for index, macro in pairs(macros) do
    if macro.name == name then return index end
  end
  return 0
end

function GetNumMacros()
  local global, perChar = 0, 0
  for _, macro in pairs(macros) do
    if macro.perChar then perChar = perChar + 1 else global = global + 1 end
  end
  return global, perChar
end

--- Clear all macros. Test-only helper.
function ClearMacros()
  macros = {}
  nextMacroIndex = 1
end

-- hooksecurefunc stub — attaches a post-hook to a global function
local hookedFunctions = {}

function hooksecurefunc(name, hook)
  local original = _G[name]
  if original then
    _G[name] = function(...)
      original(...)
      hook(...)
    end
  else
    _G[name] = hook
  end
  table.insert(hookedFunctions, { name = name, hook = hook })
end

--- Clear hooked functions. Test-only helper.
function ClearHooks()
  hookedFunctions = {}
end

-- SpellStopTargeting default (hooked by PetMoveToService)
function SpellStopTargeting() end

-- LibStub minimal stub (for AceAddon lookups)
LibStub = LibStub or setmetatable({}, {
  __call = function(self, name)
    return self
  end,
})

function LibStub:GetAddon(name)
  return LibStub._addons and LibStub._addons[name] or {}
end

--- Register a fake addon for LibStub. Test-only helper.
function LibStub:RegisterAddon(name, addon)
  self._addons = self._addons or {}
  self._addons[name] = addon
end

--- Clear LibStub registrations. Test-only helper.
function LibStub:ClearAddons()
  self._addons = {}
end

-- print stub (captures output for assertion)
local printLog = {}

local _realPrint = print
function print(...)
  local args = { ... }
  local msg = table.concat(args, "\t")
  table.insert(printLog, msg)
end

--- Get captured print output. Test-only helper.
function GetPrintLog()
  return printLog
end

--- Clear captured print output. Test-only helper.
function ClearPrintLog()
  printLog = {}
end

-- .toc-based addon loader
---@param tocPath string path to the .toc file
---@return table ns the addon's namespace table
---@return string addonName
function loadAddon(tocPath)
  local ns = {}
  local addonName = tocPath:match("([^/\\]+)%.toc$")
  for line in io.lines(tocPath) do
    if not line:match("^%s*#") and not line:match("^%s*$") then
      local filePath = line:gsub("\\", "/"):match("^%s*(.-)%s*$")
      local chunk = assert(loadfile(filePath))
      chunk(addonName, ns)
    end
  end
  return ns, addonName
end

--- Reset all WoW environment state between tests.
function ResetWoWEnv()
  ResetTime()
  ClearTimers()
  ClearFrames()
  ClearMacros()
  ClearHooks()
  ClearPrintLog()
  SetCombatLockdown(false)
  SetMouselooking(false)
  LibStub:ClearAddons()
  _G.CombatMode_PetMoveTo = nil
  _G.SpellStopTargeting = function() end
  _G.SLASH_COMBATMODE_PETMOVETO1 = nil
  _G.SlashCmdList = _G.SlashCmdList or {}
  _G.SlashCmdList["COMBATMODE_PETMOVETO"] = nil
end
