-- Super Mario Galaxy 1 and 2, shared functions and definitions



local utils = require "utils"
local dolphin = require "dolphin"



local function timeDisplay(framesObj, which)
  local frames = nil
  if which == "stage" then frames = framesObj:get()
  else frames = framesObj:get() end
  
  local centis = math.floor((frames % 60) * (100/60))
  local secs = math.floor(frames / 60) % 60
  
  local timeStr = nil
  local label = nil
  
  if which == "stage" then
    local mins = math.floor(frames / (60*60))
    timeStr = string.format("%d:%02d.%02d",
      mins, secs, centis
    )
    label = "Stage time"
  else
    local mins = math.floor(frames / (60*60)) % 60
    local hrs = math.floor(frames / (60*60*60))
    timeStr = string.format("%d:%02d:%02d.%02d",
      hrs, mins, secs, centis
    )
    label = "File time"
  end
    
  local display = string.format("%s: %s | %d",
    label, timeStr, frames
  )
  return display
end



local function posDisplay(x, y, z, displayType, beforeDecimal, afterDecimal)
  local beforeDecimal = beforeDecimalP
  local afterDecimal = afterDecimalP
  if beforeDecimal == nil then beforeDecimal = 5 end 
  if afterDecimal == nil then afterDecimal = 1 end 
  
  local numFormat = "%+0"..(beforeDecimal+afterDecimal+2).."."..afterDecimal.."f"
    
  local format = nil
  if displayType == "narrow" then
    format = "XYZ Pos:\n %s\n %s\n %s"
  else
    format = "XYZ Pos: %s | %s | %s"
  end
  
  return string.format(
    format,
    string.format(numFormat, x:get()),
    string.format(numFormat, y:get()),
    string.format(numFormat, z:get())
  )
end



-- Velocity calculated as position change.

local Velocity = {}

function Velocity:new(x, y, z, coordinates)
  -- coordinates - examples: "X" "Y" "XZ" "XYZ" 

  -- Make an object of the "class" Velocity.
  local obj = {}
  setmetatable(obj, self)
  self.__index = self
  
  obj.lastUpdateFrame = dolphin.getFrameCount()
  obj.numCoordinates = string.len(coordinates)
  if obj.numCoordinates == 1 then obj.label = coordinates.." Velocity"
  else obj.label = coordinates.." Speed" end
  
  local pos = {X = x, Y = y, Z = z}
  obj.posObjects = {}
  for char in coordinates:gmatch"." do
    table.insert(obj.posObjects, pos[char])
  end
  obj.value = 0.0
  
  return obj
end
  
function Velocity:update()
  local currentFrame = dolphin.getFrameCount()
  if self.lastUpdateFrame == currentFrame then return end
  self.lastUpdateFrame = currentFrame

  -- Update prev and curr position
  self.prevPos = self.currPos
  self.currPos = {}
  for _, posObject in pairs(self.posObjects) do
    table.insert(self.currPos, posObject:get())
  end
  
  local s = ""
  for _, v in pairs(self.currPos) do s = s..tostring(v) end
  
  -- Update velocity value
  
  if self.prevPos == nil then
    self.value = 0.0
    return
  end
  
  if self.numCoordinates == 1 then
    self.value = self.currPos[1] - self.prevPos[1]
  else
    local sumOfSquaredDiffs = 0.0
    for n = 1, self.numCoordinates do
      local diff = self.currPos[n] - self.prevPos[n] 
      sumOfSquaredDiffs = sumOfSquaredDiffs + diff*diff
    end
    self.value = math.sqrt(sumOfSquaredDiffs)
  end
end

function Velocity:display(beforeDecimalP, afterDecimalP, withoutLabel)
  self:update()

  local beforeDecimal = beforeDecimalP
  local afterDecimal = afterDecimalP
  if beforeDecimal == nil then beforeDecimal = 2 end 
  if afterDecimal == nil then afterDecimal = 3 end 
  
  local valueStr = nil
  if self.numCoordinates == 1 then
    local format = "%+0"..(beforeDecimal+afterDecimal+2).."."..afterDecimal.."f"
    valueStr = string.format(format, self.value)
  else
    local format = "%0"..(beforeDecimal+afterDecimal+1).."."..afterDecimal.."f"
    valueStr = string.format(format, self.value)
  end
  
  if withoutLabel then return valueStr
  else return self.label..": "..valueStr end
end



local function buttonDisp(buttons1, buttons2, button)
  local value = nil
  if button == "H" then  -- Home
    value = buttons1:get()[1]
  elseif button == "C" then
    value = buttons1:get()[2]
  elseif button == "Z" then
    value = buttons1:get()[3]
  elseif button == "A" then
    value = buttons1:get()[5]
  elseif button == "B" then
    value = buttons1:get()[6]
  elseif button == "+" then
    value = buttons2:get()[4]
  elseif button == "^" then
    value = buttons2:get()[5]
  elseif button == "v" then
    value = buttons2:get()[6]
  elseif button == ">" then
    value = buttons2:get()[7]
  elseif button == "<" then
    value = buttons2:get()[8]
  end
  if value == 1 then
    return button
  else
    return " "
  end
end



local spinDisplay = ""
local function getSpinType(wiimoteSpinBit, nunchukSpinBit)
  if wiimoteSpinBit:get() == 1 then
    return "Wiimote spin"
  elseif nunchukSpinBit:get() == 1 then
    return "Nunchuk spin"
  else
    -- This should really only happen if the script is started in the middle
    -- of a spin.
    return "?"
  end
end
local function spinDisp(spinCooldownTimer, spinAttackTimer, getSpinType)
  local cooldownTimer = spinCooldownTimer:get()
  local attackTimer = spinAttackTimer:get()
  
  if cooldownTimer > 0 then
    if attackTimer > 0 then
      -- We know we're in the middle of the spin animation, but the question
      -- is when to check for a new kind of spin (Wiimote or Nunchuk).
      --
      -- If you shake the Wiimote and then immediately shake the Nunchuk after,
      -- then you should still be considered in the middle of a Wiimote spin,
      -- despite the fact that you turned on the "would activate a Nunchuk
      -- spin" bit.
      --
      -- So we only check for a new kind of spin if there is no spin currently
      -- going on, or if the cooldown timer is at its highest value, meaning a
      -- spin must have just started on this frame. (There is potential for the
      -- script to miss this first frame, though. So if you precisely follow a
      -- Wiimote spin with a Nunchuk spin, the display may fail to update
      -- accordingly.)
      if spinDisplay == "" or cooldownTimer == 79 then
        spinDisplay = getSpinType()
      end
    else
      -- Spin attack is over, but need to wait to do another spin.
      spinDisplay = "(Cooldown)"
    end
  else
    if attackTimer > 0 then
      -- Spin attack is going in midair. (This includes "fake" midair spins,
      -- and still-active spin attacks after jump canceling a ground spin.)
      -- We'll just display this the same as any other spin.
      if spinDisplay == "" or cooldownTimer == 79 then
        spinDisplay = getSpinType()
      end
    else
      -- Both spin animation and effect are inactive.
      spinDisplay = ""
    end
  end
  return spinDisplay
end



local function inputDisplay(stickX, stickY, buttonDisp, spinDisp, displayType)
  local displayStickX = string.format("%+.3f", stickX:get())
  local displayStickY = string.format("%+.3f", stickY:get())
  local displayButtons1 = string.format("%s%s%s%s%s",
    buttonDisp("C"), buttonDisp("^"), buttonDisp("v"),
    buttonDisp("<"), buttonDisp(">")
  )
  local displayButtons2 = string.format("%s%s%s%s%s",
    buttonDisp("A"), buttonDisp("B"), buttonDisp("Z"),
    buttonDisp("+"), buttonDisp("H")
  )
  local displaySpin = spinDisp()
  
  if displayType == "compact" then
    return string.format(
      "%s\n".."%s   %s\n".."%s   %s",
      displaySpin,
      displayStickX, displayButtons1,
      displayStickY, displayButtons2
    )
  else
    return string.format(
      "Stick   Buttons\n".."%s   %s\n".."%s   %s\n".."  %s",
      displayStickX, displayButtons1,
      displayStickY, displayButtons2,
      displaySpin
    )
  end
end



local function drawStickInput(stickX, stickY, canvas, width)
  -- The canvas is assumed to be square
  
  canvas:ellipse(0,0, width,width)
  
  -- stickX and stickY range from -1 to 1. Transform that to a range from
  -- 0 to width. Also, stickY goes bottom to top while image coordinates go
  -- top to bottom, so add a negative sign to get it right.
  local x = stickX:get()*(width/2) + (width/2)
  local y = stickY:get()*(-width/2) + (width/2)
  canvas:line(width/2,width/2, x,y)
end



return {
  timeDisplay = timeDisplay,
  posDisplay = posDisplay,
  Velocity = Velocity,
  buttonDisp = buttonDisp,
  getSpinType = getSpinType,
  spinDisp = spinDisp,
  inputDisplay = inputDisplay,
  drawStickInput = drawStickInput,
}
