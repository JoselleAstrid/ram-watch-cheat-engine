local shared = require "shared"



-- tonumber fix, so that it properly handles strings starting with "-0".
-- See the following bug report: http://cheatengine.org/mantis/view.php?id=328
if originalTonumber==nil then
  originalTonumber=tonumber
end

function tonumber(str)
  local result = originalTonumber(str)
  if string.sub(str,1,1) == "-" and result > 0 then
    result = -result
  end

  return result
end



-- Curry implementation.
-- From: http://lua-users.org/lists/lua-l/2007-01/msg00205.html
-- (Linked from: http://lua-users.org/wiki/CurriedLua)
local function curry1(f,v)
  return function (...)  return f(v,...)  end
end
local function curry(f,v,...)
  if v == nil then return f end
  return curry( curry1(f,v), ... )
end



local function readIntBE(address, numberOfBytesToRead)
  -- In: address - address of a big-endian memory value we want to read
  --     numberOfBytesToRead - the number of bytes to read from that address
  -- Out: integer value of the memory that was read
  
  if numberOfBytesToRead == nil then numberofBytesToRead = 4 end
  
  -- Call Cheat Engine's built-in readBytes() function.
  -- The "true" parameter says we want the return value as a table of the bytes.
  local bytes = readBytes(address, numberOfBytesToRead, true)
  
  -- If the read failed (maybe an unreadable address?), return nil.
  if bytes == nil then return nil end
  
  local sum = 0
  for _, byteValue in pairs(bytes) do
    sum = 256*sum + byteValue
  end
  return sum
end

local function readIntLE(address, numberOfBytesToRead)
  -- Same, but for little-endian
  
  if numberOfBytesToRead == nil then numberofBytesToRead = 4 end
  
  local bytes = readBytes(address, numberOfBytesToRead, true)
  
  if bytes == nil then return nil end
  
  -- We go backwards through the byte array. Other than that, this works the
  -- same as the big-endian version.
  local sum = 0
  for index = #bytes, 1, -1 do
    local byteValue = bytes[index]
    sum = 256*sum + byteValue
  end
  return sum
end

local twoTo31 = 0x80000000
local twoTo23 = 0x800000
local twoTo63 = 0x8000000000000000
local twoTo52 = 0x10000000000000

local function intToFloat(x)
  -- In: 4-byte integer value
  -- Out: floating-point value from the same bytes
  --
  -- For example, to see what you'd get if you pass in the number 64,
  -- go here and enter 00000040 (64 in hex) in the top box:
  -- http://babbage.cs.qc.cuny.edu/IEEE-754.old/Decimal.html
  
  -- Bits: 31 - sign (s), 30-23 - exponent (e), 22-0 - mantissa (m)
  if x == 0 then return 0 end
  local s = nil
  local em = nil
  if x < twoTo31 then
    s = 1
    em = x
  else
    s = -1
    em = x - twoTo31
  end
  local e = math.floor(em / twoTo23) - 127  -- 2^7 - 1
  local m = (em % twoTo23) / twoTo23 + 1
  return s*(2^e)*m
end

local function intToDouble(x)
  -- In: 8-byte integer value
  -- Out: floating-point value from the same bytes
  
  -- Bits: 63 - sign (s), 62-52 - exponent (e), 51-0 - mantissa (m)
  if x == 0 then return 0 end
  local s = nil
  local em = nil
  if x < twoTo63 then
    s = 1
    em = x
  else
    s = -1
    em = x - twoTo63
  end
  local e = math.floor(em / twoTo52) - 1023  -- 2^10 - 1
  local m = (em % twoTo52) / twoTo52 + 1
  return s*(2^e)*m
end

local function readFloatBE(address, numberOfBytesToRead)
  return intToFloat(readIntBE(address, numberOfBytesToRead))
end

local function readFloatLE(address, numberOfBytesToRead)
  return intToFloat(readIntLE(address, numberOfBytesToRead))
end

-- Note: Cheat Engine already has a readFloat(), which probably does LE
-- (little-endian). So don't be surprised if you forget the BE/LE in the name
-- and it still runs.

local function intToHexStr(x)
  -- In: integer value
  -- Out: string of the integer's hexadecimal representation
  return string.format("0x%08X", x)
end

local function floatToStr(x, precision, trimTrailingZeros)
  -- In: floating-point value
  -- Out: string representation, with the specified precision
  --      (number of decimal places). If not specified, defaults to 3.
  --      If trimTrailingZeros is true, will display fewer decimal digits if
  --      the final digits are zeros.
  if x == nil then return "nil" end
  
  if not precision then precision = 3 end
  
  local s = string.format("%."..precision.."f", x)
  if trimTrailingZeros then
    return tostring(tonumber(s))
  else
    return s
  end
end



-- Scan for a string and return the address of the first result.
-- If there is no result, it returns nil.
local function scanStr(str)
  local startaddr=0
  local stopaddr=0x7fffffffffffffff
  local scan = createMemScan()
  scan.OnlyOneResult=true
  scan.firstScan(soExactValue,vtString,rtTruncated,str,"",startaddr,stopaddr,
  "+W-C",fsmNotAligned,"",false,false,false,true)
  scan.waitTillDone()
  return scan.getOnlyResult()
end



-- Initialize a GUI label.
-- Based on: http://forum.cheatengine.org/viewtopic.php?t=530121
local function initLabel(window, x, y, text)
  local label = createLabel(window)
  if label == nil then return nil end
  label:setCaption(text)
  label:setPosition(x, y)
  return label
end



-- If you need to debug something, you'll probably want a
-- debug display on the window.
--
-- To use this, first set shared.debugLabel = initLabel(<your arguments here>)
-- in your layout's init() function.
-- Then call debugDisp("your debug text here") whenever you want to display
-- some debug text.
-- Since the debugLabel is in the "shared" module, you can set the debugLabel
-- in any module and then call debugDisp in any other module, and it should
-- still work.
--
-- Tip: If you are trying to display an object that might have a nil value,
-- use tostring, like this:
-- debugDisp(tostring(myObject))
-- so that nil will display as "nil", instead of as no text at all. tostring
-- also improves the display of some other kinds of objects.

shared.debugLabel = nil
local function debugDisp(str)
  if shared.debugLabel ~= nil then
    shared.debugLabel:setCaption(str)
  end
end



-- Writing stats to a file.

local StatRecorder = {
  button = nil,
  timeLimitField = nil,
  secondsLabel = nil,
  timeElapsedLabel = nil,
  endFrame = nil,
  framerate = nil,
  
  currentlyTakingStats = false,
  currentFrame = nil,
  valuesTaken = nil,
}
  
function StatRecorder:startTakingStats()
  -- Get the time limit from the field. If it's not a valid number,
  -- don't take any stats.
  local seconds = tonumber(self.timeLimitField.Text)
  if seconds == nil then return end
  self.endFrame = self.framerate * seconds
  
  self.currentlyTakingStats = true
  self.currentFrame = 1
  self.valuesTaken = {}
  
  -- Change the Start taking stats button to a Stop taking stats button
  self.button:setCaption("Stop stats")
  self.button:setOnClick(curry(self.stopTakingStats, self))
  -- Disable the time limit field
  self.timeLimitField:setEnabled(false)
end
  
function StatRecorder:takeStat(str)
  self.valuesTaken[self.currentFrame] = str
  
  -- Display the current frame count
  self.timeElapsedLabel:setCaption(string.format("%.2f", self.currentFrame / self.framerate))
  
  self.currentFrame = self.currentFrame + 1
  if self.currentFrame > self.endFrame then
    self:stopTakingStats()
  end
end
  
function StatRecorder:stopTakingStats()
  -- Collect the stats in string form and write them to a file.
  --
  -- This file will be created in either:
  -- (A) The same directory as the cheat table you have open.
  -- (B) The same directory as the Cheat Engine .exe file, it you don't
  --   have a cheat table open.
  local statsStr = table.concat(self.valuesTaken, "\n")
  local statsFile = io.open("stats.txt", "w")
  statsFile:write(statsStr)
  statsFile:close()
  
  self.currentlyTakingStats = false
  self.currentFrame = nil
  self.valuesTaken = {}
  self.endFrame = nil
  
  self.button:setCaption("Take stats")
  self.button:setOnClick(curry(self.startTakingStats, self))
  self.timeLimitField:setEnabled(true)
  
  self.timeElapsedLabel:setCaption("")
end
    
function StatRecorder:new(window, baseYPos, framerate)

  -- Make an object of the "class" StatRecorder.
  -- Idea from http://www.lua.org/pil/16.1.html
  local obj = {}
  setmetatable(obj, self)
  self.__index = self
  
  obj:initializeUI(window, baseYPos)
  
  if framerate ~= nil then
    self.framerate = framerate
  else
    self.framerate = 60
  end
  
  return obj
end

function StatRecorder:initializeUI(window, baseYPos)
  self.button = createButton(window)
  self.button:setPosition(10, baseYPos)
  self.button:setCaption("Take stats")
  self.button:setOnClick(curry(self.startTakingStats, self))
  local buttonFont = self.button:getFont()
  buttonFont:setSize(10)
  
  self.timeLimitField = createEdit(window)
  self.timeLimitField:setPosition(100, baseYPos)
  self.timeLimitField:setSize(60, 20)
  self.timeLimitField.Text = "10"
  local fieldFont = self.timeLimitField:getFont()
  fieldFont:setSize(10)
  
  self.secondsLabel = initLabel(window, 165, baseYPos+3, "seconds")
  local secondsFont = self.secondsLabel:getFont()
  secondsFont:setSize(10)
  
  self.timeElapsedLabel = initLabel(window, 240, baseYPos-5, "")
end



return {
  curry = curry,
  
  readIntBE = readIntBE,
  readIntLE = readIntLE,
  intToDouble = intToDouble,
  readFloatBE = readFloatBE,
  readFloatLE = readFloatLE,
  intToHexStr = intToHexStr,
  floatToStr = floatToStr,
  
  scanStr = scanStr,
  
  initLabel = initLabel,
  debugDisp = debugDisp,
  
  StatRecorder = StatRecorder,
}
