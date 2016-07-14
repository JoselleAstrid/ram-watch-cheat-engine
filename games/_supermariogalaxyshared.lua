-- Super Mario Galaxy 1 and 2, shared functions and definitions



local utils = require "utils"
local utils_math = require "utils_math"
local vtypes = require "valuetypes"
local dolphin = require "dolphin"

local Vector3 = utils_math.Vector3

local subclass = vtypes.subclass



local function timeDisplay(framesObj, which, displayType)
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
    
  local format = nil
  if displayType == "narrow" then
    format = "%s:\n %s\n %d"
  else
    format = "%s: %s | %d"
  end
  
  local display = string.format(format, label, timeStr, frames)
  return display
end



-- TODO: Check if needed

-- local function coordsDisplay(x, y, z, label, defaultBD, defaultAD, options)
--   options.beforeDecimal = options.beforeDecimal or defaultBD
--   options.afterDecimal = options.afterDecimal or defaultAD
--   options.signed = options.signed or true
  
--   local v = Vector3:new(x:get(), y:get(), z:get())
--   return v:display(label, options)
-- end



-- TODO: Check if needed

-- local function floatToStrWithDefaults(defaultOptions)
--   local f = function (defaultOptions, self, options)
--     local combinedOptions = {}
--     -- First apply default options
--     for key, value in pairs(defaultOptions) do
--       combinedOptions[key] = value
--     end
--     -- Then apply passed-in options, replacing default options
--     -- of the same keys
--     for key, value in pairs(options) do
--       combinedOptions[key] = value
--     end
--     return utils.floatToStr(self.value, combinedOptions)
--   end
--   return utils.curry(f, defaultOptions)
-- end



local DerivedValue = {}
DerivedValue.label = "Value label goes here"
DerivedValue.initialValue = 0.0

function DerivedValue:new()
  -- Make an object of the "class" DerivedValue.
  local obj = {}
  setmetatable(obj, self)
  self.__index = self
  
  obj.value = self.initialValue
  obj.lastUpdateFrame = dolphin.getFrameCount()
  
  return obj
end

function DerivedValue:updateValue()
  -- This function should update self.value.
  error("Function not implemented")
end

function DerivedValue:update()
  local currentFrame = dolphin.getFrameCount()
  if self.lastUpdateFrame == currentFrame then return end
  self.lastUpdateFrame = currentFrame
  
  self:updateValue()
end

function DerivedValue:get()
  self:update()
  return self.value
end

function DerivedValue:displayValue(options)
  return utils.floatToStr(self.value, options)
end

function DerivedValue:display(passedOptions)
  local options = {}
  -- First apply default options
  if self.displayDefaults then
    for key, value in pairs(self.displayDefaults) do
      options[key] = value
    end
  end
  -- Then apply passed-in options, replacing default options of the same keys
  if passedOptions then
    for key, value in pairs(passedOptions) do
      options[key] = value
    end
  end
  
  local label = options.label or self.label
  
  self:update()
  if options.narrow then
    return label..":\n "..self:displayValue(options)
  else
    return label..": "..self:displayValue(options)
  end
end

-- TODO: Check if needed

-- local DerivedValue = {}

-- function DerivedValue:new(vars, updateFunction, label, initialValue, displayFunction)
--   -- Make an object of the "class" DerivedValue.
--   local obj = {}
--   setmetatable(obj, self)
--   self.__index = self
  
--   obj.vars = vars
--   obj.updateFunction = updateFunction
--   obj.label = label
--   obj.displayFunction = displayFunction or utils.floatToStr
  
--   obj.lastUpdateFrame = dolphin.getFrameCount()
--   obj.value = initialValue
  
--   return obj
-- end

-- function DerivedValue:update()
--   local currentFrame = dolphin.getFrameCount()
--   if self.lastUpdateFrame == currentFrame then return end
--   self.lastUpdateFrame = currentFrame
  
--   self:updateFunction()
-- end

-- function DerivedValue:get()
--   self:update()
--   return self.value
-- end

-- function DerivedValue:display(options)
--   self:update()
--   if options.narrow then
--     return self.label..":\n "..self.displayFunction(self.value, options)
--   else
--     return self.label..": "..self.displayFunction(self.value, options)
--   end
-- end



function VToDerivedValue(vObj)
  local obj = DerivedValue:new()
  obj.vObj = vObj
  obj.label = vObj.label
  function obj:updateValue()
    self.value = vObj:get()
  end
  return obj
end



-- Velocity calculated as position change.

local Velocity = subclass(DerivedValue)
Velocity.label = "To be determined in new()"
Velocity.initialValue = 0.0

function Velocity:new(pos, coordinates)
  local obj = DerivedValue.new(self)
  
  -- coordinates - a string such as "X" "Y" "XZ" "XYZ"
  obj.posObjects = {}
  if string.find(coordinates, "X") then table.insert(obj.posObjects, pos.x) end
  if string.find(coordinates, "Y") then table.insert(obj.posObjects, pos.y) end
  if string.find(coordinates, "Z") then table.insert(obj.posObjects, pos.z) end
  obj.numCoordinates = #obj.posObjects
  
  if obj.numCoordinates == 1 then obj.label = coordinates.." Vel"
  else obj.label = coordinates.." Speed" end
  
  -- If we're tracking velocity of 1 coordinate, it should have a +/- display.
  -- If more than 1 coordinate, it'll just be a magnitude, so need no +/-.
  local defaultSigned = (obj.numCoordinates == 1)
  obj.displayDefaults = {signed=defaultSigned}
  
  return obj
end

function Velocity:updateValue()
  -- Update prev and curr position
  self.prevPos = self.currPos
  self.currPos = {}
  for _, posObject in pairs(self.posObjects) do
    table.insert(self.currPos, posObject:get())
  end
  
  if self.prevPos == nil then
    self.value = 0.0
    return
  end
  
  -- Update velocity based on prev and curr position
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

-- TODO: Check if needed

-- local function updateVelocity(self)
--   -- Update prev and curr position
--   self.prevPos = self.currPos
--   self.currPos = {}
--   for _, posObject in pairs(self.posObjects) do
--     table.insert(self.currPos, posObject:get())
--   end
  
--   if self.prevPos == nil then
--     self.value = 0.0
--     return
--   end
  
--   -- Update velocity based on prev and curr position
--   if self.numCoordinates == 1 then
--     self.value = self.currPos[1] - self.prevPos[1]
--   else
--     local sumOfSquaredDiffs = 0.0
--     for n = 1, self.numCoordinates do
--       local diff = self.currPos[n] - self.prevPos[n] 
--       sumOfSquaredDiffs = sumOfSquaredDiffs + diff*diff
--     end
--     self.value = math.sqrt(sumOfSquaredDiffs)
--   end
-- end

-- local function Velocity(px, py, pz, coordinates)
--   -- coordinates - a string such as "X" "Y" "XZ" "XYZ"
--   local numCoordinates = string.len(coordinates)
  
--   local posObjects = {}
--   if string.find(coordinates, "X") then table.insert(posObjects, px) end
--   if string.find(coordinates, "Y") then table.insert(posObjects, py) end
--   if string.find(coordinates, "Z") then table.insert(posObjects, pz) end
--   local numCoordinates = #posObjects
  
--   local label = nil
--   if numCoordinates == 1 then label = coordinates.." Velocity"
--   else label = coordinates.." Speed" end
  
--   -- If we're tracking velocity of 1 coordinate, it should have a +/- display.
--   -- If more than 1 coordinate, it'll just be a magnitude, so need no +/-.
--   local defaultSigned = (numCoordinates == 1)
  
--   local obj = DerivedValue:new(
--     {},
--     updateVelocity,
--     label,
--     0.0,  -- initial value
--     floatToStrWithDefaults{signed=defaultSigned}
--   )
--   obj.numCoordinates = numCoordinates
--   obj.posObjects = posObjects
  
--   return obj
-- end

-- TODO: Check if needed

-- local Velocity = {}

-- function Velocity:new(x, y, z, coordinates)
--   -- coordinates - a string such as "X" "Y" "XZ" "XYZ" 

--   -- Make an object of the "class" Velocity.
--   local obj = {}
--   setmetatable(obj, self)
--   self.__index = self
  
--   obj.lastUpdateFrame = dolphin.getFrameCount()
--   obj.numCoordinates = string.len(coordinates)
  
--   local pos = {X = x, Y = y, Z = z}
--   obj.posObjects = {}
--   for char in coordinates:gmatch"." do
--     table.insert(obj.posObjects, pos[char])
--   end
--   obj.value = 0.0
  
--   if obj.numCoordinates == 1 then obj.label = coordinates.." Velocity"
--   else obj.label = coordinates.." Speed" end
  
--   return obj
-- end
  
-- function Velocity:update()
--   local currentFrame = dolphin.getFrameCount()
--   if self.lastUpdateFrame == currentFrame then return end
--   self.lastUpdateFrame = currentFrame

--   -- Update prev and curr position
--   self.prevPos = self.currPos
--   self.currPos = {}
--   for _, posObject in pairs(self.posObjects) do
--     table.insert(self.currPos, posObject:get())
--   end
  
--   -- Update velocity value
  
--   if self.prevPos == nil then
--     self.value = 0.0
--     return
--   end
  
--   if self.numCoordinates == 1 then
--     self.value = self.currPos[1] - self.prevPos[1]
--   else
--     local sumOfSquaredDiffs = 0.0
--     for n = 1, self.numCoordinates do
--       local diff = self.currPos[n] - self.prevPos[n] 
--       sumOfSquaredDiffs = sumOfSquaredDiffs + diff*diff
--     end
--     self.value = math.sqrt(sumOfSquaredDiffs)
--   end
-- end

-- function Velocity:get()
--   -- Alternative to display()
--   self:update()
--   return self.value
-- end

-- function Velocity:display(options)
--   self:update()

--   options.beforeDecimal = options.beforeDecimal or 2 
--   options.afterDecimal = options.afterDecimal or 3
--   local narrow = options.narrow or false
  
--   -- If 1 coordinate, or coordinates don't apply, always make +/- sign visible
--   if self.numCoordinates == 1 or self.numCoordinates == nil then
--     options.signed = true
--   end
  
--   local s = utils.floatToStr(self.value, options)
  
--   if narrow then
--     return self.label..":\n "..s
--   else
--     return self.label..": "..s
--   end
-- end



local RateOfChange = subclass(DerivedValue)
RateOfChange.label = "Label to be passed into new()"
RateOfChange.initialValue = 0.0

function RateOfChange:new(baseValue, label)
  local obj = DerivedValue.new(self)
  
  obj.baseValue = baseValue
  obj.label = label
  -- Display the same way as the base value
  obj.displayValue = baseValue.displayValue
  
  return obj
end

function RateOfChange:updateValue()
  -- Update prev and curr stat values
  self.prevStat = self.currStat
  self.baseValue:update()
  self.currStat = self.baseValue.value
  
  -- Update rate of change value
  if self.prevStat == nil then
    self.value = 0.0
  else
    self.value = self.currStat - self.prevStat
  end
end

-- TODO: Check if needed

-- local function updateRateOfChange(self)
--   -- Update prev and curr stat values
--   self.prevStat = self.currStat
--   self.vars.baseValue:update()
--   self.currStat = self.vars.baseValue.value
  
--   -- Update rate of change value
--   if self.prevStat == nil then
--     self.value = 0.0
--   else
--     self.value = self.currStat - self.prevStat
--   end
-- end

-- local function RateOfChange(baseValue, label)
--   return DerivedValue:new(
--     {baseValue=baseValue},
--     updateRateOfChange,
--     label,
--     0.0,  -- initial value
--     baseValue.display
--   )
-- end

-- TODO: Check if needed

-- local RateOfChange = {}

-- function RateOfChange:new(statObj, label)
--   -- Make an object of the "class" RateOfChange.
--   local obj = {}
--   setmetatable(obj, self)
--   self.__index = self
  
--   obj.lastUpdateFrame = dolphin.getFrameCount()
--   obj.statObj = statObj
--   obj.value = 0.0
  
--   -- Display function will be the statObj's display function
--   obj.display = statObj.display
  
--   obj.label = label
  
--   return obj
-- end
  
-- function RateOfChange:update()
--   local currentFrame = dolphin.getFrameCount()
--   if self.lastUpdateFrame == currentFrame then return end
--   self.lastUpdateFrame = currentFrame

--   -- Update prev and curr stat values
--   self.prevStat = self.currStat
--   self.statObj:update()
--   self.currStat = self.statObj.value
  
--   -- Update rate of change value
--   if self.prevStat == nil then
--     self.value = 0.0
--   else
--     self.value = self.currStat - self.prevStat
--   end
-- end



-- Difference between gravity up-vector and character tilt up-vector.
-- We might also call this 'skew' when the character is tilted on
-- non-tilting ground.

local Tilt = subclass(DerivedValue)
Tilt.label = "Not used"
Tilt.initialValue = "Not used"

function Tilt:new(dgrav, utilt)
  local obj = DerivedValue.new(self)
  
  obj.dgrav = dgrav
  obj.utilt = utilt
  
  return obj
end

function Tilt:updateValue()
  local ugrav = self.dgrav:get():times(-1)
  local utilt = self.utilt:get()
  
  -- Catch the case where the up vectors are the same. This should keep us from
  -- displaying undefined values like -1.#J or -1.#IO.
  if ugrav:nearlyEquals(utilt) then
    self.rotationRadians = 0.0
    self.rotationAxis = Vector3:new(0.0,1.0,0.0)
    self.diff = Vector3:new(0.0,0.0,0.0)
    return
  end
  
  -- Cross product: to get a rotation axis, from gravity up vector
  -- to tilt up vector.
  -- Then ensure we get a normalized rotation axis.
  self.rotationAxis = ugrav:cross(utilt):normalized()
  
  local x = self.rotationAxis.x
  -- Check for NaN or +/-infinity.
  if x ~= x or x == math.huge or x == -math.huge then
    -- Up vector difference is either 0, or close enough to 0 that our axis
    -- calculation can't work. Either way, we'll treat it as 0 and ensure that
    -- we can display valid values.
    self.rotationAxis = Vector3:new(0.0,1.0,0.0)
    self.rotationRadians = 0.0
    self.diff = Vector3:new(0.0,0.0,0.0)
    return
  end
  
  -- Dot product: to get rotational difference between gravity and tilt.
  self.rotationRadians = math.acos(ugrav:dot(utilt))
  
  -- Alternate, crude representation of tilt: difference between up vectors
  self.diff = utilt:minus(ugrav)
end

function Tilt:getRotation()
  self:update()
  return {self.rotationRadians, self.rotationAxis}
end

function Tilt:displayRotation()
  self:update()
  local format = "Tilt:\n %+.2f°\n Axis %+.2f\n      %+.2f\n      %+.2f"
  
  return string.format(
    format,
    math.deg(self.rotationRadians),
    self.rotationAxis.x,
    self.rotationAxis.y,
    self.rotationAxis.z
  )
end

function Tilt:getDiff()
  self:update()
  return self.diff
end

function Tilt:displayDiff(options)
  self:update()
  
  options.beforeDecimal = options.beforeDecimal or 1
  options.afterDecimal = options.afterDecimal or 3
  options.signed = options.signed or true
  return self.diff:display("Tilt (Diff)", options)
end

-- TODO: Check if needed

-- local function updateTilt(self)
--   local ugrav = Vector3:new(self.vars.ugravx:get(), self.vars.ugravy:get(), self.vars.ugravz:get())
--   local utilt = Vector3:new(self.vars.utiltx:get(), self.vars.utilty:get(), self.vars.utiltz:get())
  
--   -- Dot product: to get rotation amount
--   local dot = ugrav:dot(utilt)
--   self.rotationRadians = math.acos(dot)
--   -- Cross product: to get a rotation axis, from planet up vector
--   -- to character up vector.
--   -- Then ensure we get a normalized rotation axis.
--   self.rotationAxis = ugrav:cross(utilt):normalized()
  
--   -- Alternate, crude representation of tilt: difference between up vectors
--   self.diff = utilt:minus(ugrav)
-- end

-- local function getRotationTilt(self)
--   self:update()
--   return {self.rotationRadians, self.rotationAxis}
-- end

-- local function displayRotationTilt(self)
--   self:update()
--   local format = "Tilt:\n %+.2f°\n Axis %+.2f\n      %+.2f\n      %+.2f"
  
--   return string.format(
--     format,
--     math.deg(self.rotationRadians),
--     self.rotationAxis.x,
--     self.rotationAxis.y,
--     self.rotationAxis.z
--   )
-- end

-- local function getDiffTilt(self)
--   self:update()
--   return self.diff
-- end

-- local function displayDiffTilt(self, options)
--   self:update()
  
--   options.beforeDecimal = options.beforeDecimal or 1
--   options.afterDecimal = options.afterDecimal or 3
--   return self.diff:display("Tilt (Diff)", options)
-- end

-- local function Tilt(ugravx, ugravy, ugravz, utiltx, utilty, utiltz)
--   local obj = DerivedValue:new(
--     {ugravx=ugravx, ugravy=ugravy, ugravz=ugravz,
--      utiltx=utiltx, utilty=utilty, utiltz=utiltz},
--     updateTilt,
--     "Tilt",
--     nil  -- No initial value because we won't use self.value
--   )
  
--   -- We'll have multiple get/display functions because there's multiple
--   -- values here.
--   obj.getRotation = getRotationTilt
--   obj.displayRotation = displayRotationTilt
--   obj.getDiff = getDiffTilt
--   obj.displayDiff = displayDiffTilt
  
--   return obj
-- end

-- TODO: Check if needed

-- local Skew = {}

-- function Skew:new(ugravx, ugravy, ugravz, utiltx, utilty, utiltz)
--   -- Make an object of the "class" Skew.
--   local obj = {}
--   setmetatable(obj, self)
--   self.__index = self
  
--   obj.ugravx = ugravx
--   obj.ugravy = ugravy
--   obj.ugravz = ugravz
--   obj.utiltx = utiltx
--   obj.utilty = utilty
--   obj.utiltz = utiltz
  
--   obj.lastUpdateFrame = dolphin.getFrameCount()
--   obj.rotationRadians = 0.0
--   obj.rotationAxis = Vector3:new(0,0,0)
  
--   return obj
-- end
  
-- function Skew:update()
--   local currentFrame = dolphin.getFrameCount()
--   if self.lastUpdateFrame == currentFrame then return end
--   self.lastUpdateFrame = currentFrame
  
--   -- Update value
  
--   local ugrav = Vector3:new(self.ugravx:get(), self.ugravy:get(), self.ugravz:get())
--   local utilt = Vector3:new(self.utiltx:get(), self.utilty:get(), self.utiltz:get())
  
--   -- Dot product: to get rotation amount
--   local dot = ugrav:dot(utilt)
--   self.rotationRadians = math.acos(dot)
--   -- Cross product: to get a rotation axis, from planet up vector
--   -- to character up vector.
--   -- Then ensure we get a normalized rotation axis.
--   self.rotationAxis = ugrav:cross(utilt):normalized()
  
--   -- Alternate, crude representation of skew: difference between up vectors
--   self.diff = utilt:minus(ugrav)
-- end

-- function Skew:getRotation()
--   self:update()
--   return {self.rotationRadians, self.rotationAxis}
-- end

-- function Skew:displayRotation()
--   self:update()
--   local format = "Tilt:\n %+.2f°\n Axis %+.2f\n      %+.2f\n      %+.2f"
  
--   return string.format(
--     format,
--     math.deg(self.rotationRadians),
--     self.rotationAxis.x,
--     self.rotationAxis.y,
--     self.rotationAxis.z
--   )
-- end

-- function Skew:getDiff()
--   self:update()
--   return self.diff
-- end

-- function Skew:displayDiff(options)
--   self:update()
  
--   options.beforeDecimal = options.beforeDecimal or 1
--   options.afterDecimal = options.afterDecimal or 3
  
--   return self.diff:display("Skew (Diff)", options)
-- end



-- TODO: Determine if needed

-- function SkewDiffDotVelocity:new(skew, vx, vy, vz)
--   local obj = {}
--   setmetatable(obj, self)
--   self.__index = self
  
--   obj.skew = skew
--   obj.vx = vx
--   obj.vy = vy
--   obj.vz = vz
  
--   obj.lastUpdateFrame = dolphin.getFrameCount()
--   obj.value = 0.0
  
--   return obj
-- end
  
-- function SkewDiffDotVelocity:update()
--   local currentFrame = dolphin.getFrameCount()
--   if self.lastUpdateFrame == currentFrame then return end
--   self.lastUpdateFrame = currentFrame
  
--   local diff = self.skew:getDiff()
--   self.value = diff[1]*self.vx:get() + diff[2]*self.vy:get() + diff[3]*self.vz:get()
-- end

-- SkewDiffDotVelocity.display = Velocity.display



-- TODO: Determine if this non-general Accel is needed anymore

-- local Accel = {}

-- function Accel:new(x, y, z, coordinates)
--   -- Make an object of the "class" Accel.
--   local obj = {}
--   setmetatable(obj, self)
--   self.__index = self
  
--   obj.lastUpdateFrame = dolphin.getFrameCount()
--   obj.velObject = Velocity:new(x, y, z, coordinates)
--   obj.value = 0.0
  
--   obj.numCoordinates = string.len(coordinates)
--   obj.label = coordinates.." Accel"
  
--   return obj
-- end
  
-- function Accel:update()
--   local currentFrame = dolphin.getFrameCount()
--   if self.lastUpdateFrame == currentFrame then return end
--   self.lastUpdateFrame = currentFrame

--   -- Update prev and curr velocity
--   self.prevVel = self.currVel
--   self.velObject:update()
--   self.currVel = self.velObject.value
  
--   -- Update accel value
  
--   if self.prevVel == nil then
--     self.value = 0.0
--     return
--   end
  
--   self.value = self.currVel - self.prevVel
-- end

-- Accel.display = Velocity.display



local UpwardVelocity = subclass(DerivedValue)
UpwardVelocity.label = "Upward Vel"
UpwardVelocity.initialValue = 0.0

function UpwardVelocity:new(pos, dgrav)
  local obj = DerivedValue.new(self)
  
  obj.pos = pos
  obj.dgrav = dgrav
  
  return obj
end

function UpwardVelocity:updateValue()
  local pos = self.pos:get()
  
  if self.prevPos == nil then
    self.value = 0.0
  else
    -- Update value. First get the overall velocity
    local vel = pos:minus(self.prevPos)
    -- 1D upward velocity = dot product of up vector and velocity vector
    self.value = vel:dot(self.prevUp)
  end
  
  -- Prepare for next step
  self.prevPos = pos
  self.prevUp = self.dgrav:get():times(-1)
end

UpwardVelocity.displayDefaults = {signed=true}

-- TODO: Check if needed

-- local function updateUpwardVelocity(self)
--   local px = self.vars.px:get()
--   local py = self.vars.py:get()
--   local pz = self.vars.pz:get()
  
--   if self.prevpx == nil then
--     self.value = 0.0
--   else
--     -- Update value
--     local vx = px - self.prevpx
--     local vy = py - self.prevpy
--     local vz = pz - self.prevpz
--     -- 1D upward velocity = dot product of up vector and velocity vector
--     self.value = vx*self.prevux + vy*self.prevuy + vz*self.prevuz
--   end
  
--   -- Prepare for next step
--   self.prevpx = px
--   self.prevpy = py
--   self.prevpz = pz
--   self.prevux = self.vars.ux:get()
--   self.prevuy = self.vars.uy:get()
--   self.prevuz = self.vars.uz:get()
-- end

-- local function UpwardVelocity(px, py, pz, ux, uy, uz)
--   return DerivedValue:new(
--     {px=px, py=py, pz=pz, ux=ux, uy=uy, uz=uz},
--     updateUpwardVelocity,
--     "Upward Vel",
--     0.0,  -- initial value
--     floatToStrWithDefaults{signed=true}
--   )
-- end

-- TODO: Check if needed

-- local UpwardVelocity = {}

-- function UpwardVelocity:new(px, py, pz, ux, uy, uz)
--   -- Make an object of the "class" UpwardVelocity.
--   local obj = {}
--   setmetatable(obj, self)
--   self.__index = self
  
--   -- Position objects
--   obj.px = px
--   obj.py = py
--   obj.pz = pz
  
--   -- Up-vector objects
--   obj.ux = ux
--   obj.uy = uy
--   obj.uz = uz
  
--   -- Previous step's values
--   obj.prev = {
--     px=nil, py=nil, pz=nil, ux=nil, uy=nil, uz=nil
--   }
  
--   obj.lastUpdateFrame = dolphin.getFrameCount()
--   obj.value = 0.0
--   obj.label = "Upward Vel"
  
--   return obj
-- end
  
-- function UpwardVelocity:update()
--   local currentFrame = dolphin.getFrameCount()
--   if self.lastUpdateFrame == currentFrame then return end
--   self.lastUpdateFrame = currentFrame
  
--   local px = self.px:get()
--   local py = self.py:get()
--   local pz = self.pz:get()
  
--   if self.prev.px == nil then
--     self.value = 0.0
--   else
--     -- Update value
--     local vx = px - self.prev.px
--     local vy = py - self.prev.py
--     local vz = pz - self.prev.pz
--     -- 1D upward velocity = dot product of up vector and velocity vector
--     self.value = vx*self.prev.ux + vy*self.prev.uy + vz*self.prev.uz
--   end
  
--   -- Prepare for next step
  
--   self.prev.px = px
--   self.prev.py = py
--   self.prev.pz = pz
--   self.prev.ux = self.ux:get()
--   self.prev.uy = self.uy:get()
--   self.prev.uz = self.uz:get()
-- end

-- UpwardVelocity.display = Velocity.display



local LateralVelocity = subclass(DerivedValue)
LateralVelocity.label = "Lateral Spd"
LateralVelocity.initialValue = 0.0

function LateralVelocity:new(pos, dgrav)
  local obj = DerivedValue.new(self)
  
  obj.pos = pos
  obj.dgrav = dgrav
  
  return obj
end

function LateralVelocity:updateValue()
  local pos = self.pos:get()
  
  if self.prevPos == nil then
    self.value = 0.0
  else
    -- Update value. First get the overall velocity
    local vel = pos:minus(self.prevPos)
    -- 1D upward velocity = dot product of up vector and velocity vector
    local upVel1D = vel:dot(self.prevUp)
    -- Make into a 3D vector
    local upVelVector = self.prevUp:times(upVel1D)
    -- 2D lateral speed =
    -- magnitude of (overall velocity vector minus upward velocity vector)
    self.value = vel:minus(upVelVector):magnitude()
  end
  
  -- Prepare for next step
  self.prevPos = pos
  self.prevUp = self.dgrav:get():times(-1)
end



local UpwardVelocityLastJump = subclass(DerivedValue)
UpwardVelocityLastJump.label = "Up Vel\nlast jump"
UpwardVelocityLastJump.initialValue = 0.0

function UpwardVelocityLastJump:new(pos, dgrav, onGround)
  local obj = DerivedValue.new(self)
  
  obj.pos = pos
  obj.dgrav = dgrav
  obj.onGround = onGround
  
  return obj
end

function UpwardVelocityLastJump:updateValue()
  local pos = self.pos:get()
  local onGround = self.onGround()
      
  -- Implementation based on up velocity value.
  local vel = nil
  local upVel = nil
  if self.prevPos ~= nil then
    vel = pos:minus(self.prevPos)
    upVel = vel:dot(self.prevUp)
    if upVel > 10 and upVel - self.prevUpVel > 10 then
      self.value = upVel
    end
  end
  self.prevUpVel = upVel
  
  -- Implementation based on the onGround bit. Finicky for anything
  -- other than regular jumps.
  -- if self.prevPos ~= nil then
  --   if not onGround and self.prevOnGround then
  --     -- We just jumped. Time to update.
      
  --     -- First get the overall velocity
  --     local vel = pos:minus(self.prevPos)
  --     -- 1D upward velocity = dot product of up vector and velocity vector
  --     local upVel = vel:dot(self.prevUp)
      
  --     self.value = upVel
  --   end
  -- end
  
  -- Prepare for next step
  self.prevPos = pos
  self.prevUp = self.dgrav:get():times(-1)
  self.prevOnGround = onGround
end

UpwardVelocityLastJump.displayDefaults = {signed=true}



-- If we jumped right now, our tilt would give us
-- this much extra initial upward velocity.
-- (e.g. a bonus of +0.9 means that, if we normally start with
-- 22 upward velocity, then here we start with 22.9.)

local UpVelocityTiltBonus = subclass(DerivedValue)
UpVelocityTiltBonus.label = "Up Vel\ntilt bonus\nprediction"
UpVelocityTiltBonus.initialValue = 0.0

function UpVelocityTiltBonus:new(nextVel, dgrav, onGround, tiltValue)
  local obj = DerivedValue.new(self)
  
  obj.nextVel = nextVel
  obj.dgrav = dgrav
  obj.onGround = onGround
  obj.tiltValue = tiltValue

  return obj
end

function UpVelocityTiltBonus:updateValue()
  -- Don't update if not on the ground.
  -- This way, during a jump, we can see what the
  -- predicted bonus velocity was for that jump.
  if not self.onGround() then return end
  
  -- Get the tilt.
  local array = self.tiltValue:getRotation()
  local tiltRadians = array[1]
  local tiltAxis = array[2]
  
  -- If no tilt, then we know there's no up vel bonus, and we're done.
  if tiltRadians == 0.0 then
    self.value = 0.0
    return
  end

  -- Get the in-memory velocity that'll be observed on the NEXT frame.
  local nextVel = self.nextVel:get()
  
  -- Additionally, account for the fact that lateral speed gets
  -- multiplied by a factor when you jump.
  -- Mario = 12.5/13, Luigi = 12.5/15, Yoshi = 12.5/18.
  -- TODO: Have a method of detecting the character. Even dash pepper Yoshi
  -- would need a different case...
  nextVel = nextVel:times(12.5/15)
  
  -- If no velocity, then we know there's no up vel bonus, and we're done.
  if math.abs(nextVel:magnitude()) < 0.000001 then
    self.value = 0.0
    return
  end
  
  -- The up vel tilt bonus doesn't care about slopes if they don't affect
  -- your tilt.
  --
  -- To ensure that standing on non-tilting slopes doesn't throw off our
  -- calculation, project the velocity vector onto the "ground plane"
  -- (the plane perpendicular to the gravity up vector), and keep the
  -- same magnitude.
  -- As it turns out, this seems to be the correct thing to do for
  -- tilting slopes, too.
  --
  -- First, get the upward component of velocity (upward in terms of gravity).
  local ugrav = self.dgrav:get():times(-1)
  local upVel = ugrav:times(nextVel:dot(ugrav))
  
  -- Overall velocity - upward component = lateral component. (Again, in
  -- terms of gravity.)
  local lateralVel = nextVel:minus(upVel)
  
  -- Apply the original magnitude.
  -- We'll call the result "ground velocity".
  local lateralVelMagnitude = lateralVel:magnitude()
  local groundVel = lateralVel:times(
      nextVel:magnitude() / lateralVelMagnitude )
  
  -- Apply the tilt to the ground velocity vector.
  -- This is a vector rotation, which we'll calculate with Rodrigues' formula.
  local term1 = groundVel:times(math.cos(tiltRadians))
  local term2 = tiltAxis:cross(groundVel):times(math.sin(tiltRadians))
  local term3 = tiltAxis:times( tiltAxis:dot(groundVel) * (1-math.cos(tiltRadians)) )
  local tiltedVelocity = term1:plus(term2):plus(term3)
  
  -- Finally, find the upward component of the tilted velocity. This is the
  -- bonus up vel that the tilted velocity gives us.
  self.value = tiltedVelocity:dot(ugrav)
end

UpVelocityTiltBonus.displayDefaults = {signed=true}

-- TODO: Check if needed

-- local function updateUpVelocityTiltBonus(self)
--   -- This velocity vector:
--   -- - Is our next frame's velocity (needed for our calculation)
--   -- - Doesn't disregard non-tilting slopes (bad for our calculation, but
--   --   don't know how to avoid)
--   local velocity = Vector3:new(
--     self.vars.baseVelX:get(),
--     self.vars.baseVelY:get(),
--     self.vars.baseVelZ:get()
--   )
  
--   local array = self.tilt:getRotation()
--   local tiltRadians = array[1]
--   local tiltAxis = array[2]
  
--   -- Apply the tilt to the ground velocity vector.
--   -- This is a vector rotation, which we'll calculate with Rodrigues' formula.
--   local term1 = velocity:times(math.cos(tiltRadians))
--   local term2 = tiltAxis:cross(velocity):times(math.sin(tiltRadians))
--   local term3 = tiltAxis:times( tiltAxis:dot(velocity) * (1-math.cos(tiltRadians)) )
--   local tiltedVelocity = term1:plus(term2):plus(term3)
  
--   -- Finally, find the upward component of the tilted velocity.
--   -- TODO: Stop updating it when off the ground.
--   local upVectorOfGravity = Vector3:new(
--     self.vars.ugravx:get(),
--     self.vars.ugravy:get(),
--     self.vars.ugravz:get()
--   )
--   self.value = tiltedVelocity:dot(upVectorOfGravity)
-- end

-- local function UpVelocityTiltBonus(baseVelX, baseVelY, baseVelZ, ugravx, ugravy, ugravz, utiltx, utilty, utiltz)

--   local obj = DerivedValue:new(
--     {baseVelX=baseVelX, baseVelY=baseVelY, baseVelZ=baseVelZ,
--      ugravx=ugravx, ugravy=ugravy, ugravz=ugravz},
--     updateUpVelocityTiltBonus,
--     "Up Vel\ntilt bonus",
--     0.0,  -- initial value
--     floatToStrWithDefaults{signed=true}
--   )
--   obj.tilt = Tilt(ugravx, ugravy, ugravz, utiltx, utilty, utiltz)
--   return obj
-- end



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
local function getShakeType(wiimoteSpinBit, nunchukSpinBit)
  if wiimoteSpinBit:get() == 1 then
    return "Wiimote"
  elseif nunchukSpinBit:get() == 1 then
    return "Nunchuk"
  else
    -- This should really only happen if the script is started in the middle
    -- of a spin.
    return nil
  end
end
local function shakeDisp(getShakeType)
  local shakeType = getShakeType()
  if shakeType ~= nil then
    return shakeType.." shake"
  else
    return ""
  end
end
local function spinDisp(spinCooldownTimer, spinAttackTimer, getShakeType)
  local cooldownTimer = spinCooldownTimer:get()
  local attackTimer = spinAttackTimer:get()
  local shakeType = getShakeType()
  
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
        if shakeType ~= nil then
          spinDisplay = shakeType.." spin"
        else
          spinDisplay = "? spin"
        end
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
        if shakeType ~= nil then
          spinDisplay = shakeType.." spin"
        else
          spinDisplay = "? spin"
        end
      end
    else
      -- Both spin animation and effect are inactive.
      spinDisplay = ""
    end
  end
  return spinDisplay
end



local function inputDisplay(stickX, stickY, buttonDisp, shakeDisp, spinDisp,
  shakeOrSpin, displayType)
  
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
  local displayShakeOrSpin = nil
  if shakeOrSpin == "both" then
    displayShakeOrSpin = shakeDisp().."\n"..spinDisp()
  elseif shakeOrSpin == "shake" then
    displayShakeOrSpin = shakeDisp()
  else
    displayShakeOrSpin = spinDisp()
  end
  
  if displayType == "compact" then
    return string.format(
      "%s\n".."%s %s\n".."%s %s",
      displayShakeOrSpin,
      displayStickX, displayButtons1,
      displayStickY, displayButtons2
    )
  else
    return string.format(
      "Stick   Buttons\n".."%s   %s\n".."%s   %s\n".."  %s",
      displayStickX, displayButtons1,
      displayStickY, displayButtons2,
      displayShakeOrSpin
    )
  end
end



local StickInputImage = {}

function StickInputImage:new(stickX, stickY, window, size, x, y, foregroundColor_)
  local obj = {}
  setmetatable(obj, self)
  self.__index = self
  
  local foregroundColor = foregroundColor_ or 0x000000  -- default = black
  
  obj.image = createImage(window)
  obj.image:setPosition(x, y)
  obj.size = size
  obj.image:setSize(size, size)
  obj.canvas = obj.image:getCanvas()
  -- Brush: ellipse() fill
  obj.canvas:getBrush():setColor(0xF0F0F0)
  -- Pen: ellipse() outline, line()
  obj.canvas:getPen():setColor(foregroundColor)
  obj.canvas:getPen():setWidth(2)
  -- Initialize the whole image with the brush color
  obj.canvas:fillRect(0,0, size,size)
  
  obj.stickX = stickX
  obj.stickY = stickY
  
  return obj
end

function StickInputImage:update()
  -- The canvas is assumed to be square
  local size = self.size
  self.canvas:ellipse(0,0, size,size)
  
  -- stickX and stickY range from -1 to 1. Transform that to a range from
  -- 0 to width. Also, stickY goes bottom to top while image coordinates go
  -- top to bottom, so add a negative sign to get it right.
  local x = self.stickX:get()*(size/2) + (size/2)
  local y = self.stickY:get()*(-size/2) + (size/2)
  self.canvas:line(size/2,size/2, x,y)
end



local ResettableValue = subclass(DerivedValue)

function ResettableValue:new(buttonDisp, resetButton, baseValue)
  -- The baseValue's class is expected to define a reset function.
  if not baseValue.reset then
    error("Value of label '"..baseValue.label.."' needs a reset function to be resettable")
  end
  
  local obj = DerivedValue.new(self)
  
  obj.baseValue = baseValue
  obj.label = baseValue.label
  -- Display the same way as the base value
  obj.displayValue = baseValue.displayValue
  
  obj.buttonDisp = buttonDisp
  obj.resetButton = resetButton
  
  return obj
end

function ResettableValue:updateValue()
  -- If the reset button is being pressed, reset the baseValue.
  if self.buttonDisp(self.resetButton) ~= ' ' then self.baseValue:reset() end
  -- Update the baseValue.
  self.baseValue:updateValue()
  -- Update self.value for the purpose of getting the value for display.
  self.value = self.baseValue.value
end

-- TODO: Check if needed. I think this implementation is a bit confused about
-- whether to be a wrapper, or an object replacement.

-- local ResettableValue = subclass(DerivedValue)

-- function ResettableValue:new(buttonDisp, resetButton, baseValue)
--   -- The baseValue's class is expected to define a reset function.
--   if not baseValue.reset then
--     error("Value of label '"..baseValue.label.."' needs a reset function to be resettable")
--   end
  
--   local obj = DerivedValue.new(self)
  
--   obj.baseValue = baseValue
--   obj.label = baseValue.label
--   obj.reset = baseValue.reset
--   -- Display the same way as the base value
--   obj.displayValue = baseValue.displayValue
  
--   obj.buttonDisp = buttonDisp
--   obj.resetButton = resetButton
  
--   return obj
-- end

-- function ResettableValue:updateValue()
--   -- If the reset button is being pressed, call the reset function.
--   if self.buttonDisp(self.resetButton) ~= ' ' then self:reset() end
--   -- Use the baseValue's update routine.
--   self.baseValue.updateValue(self)
-- end

-- TODO: Check if needed

-- local ResettableTracker = {}

-- function ResettableTracker:new(
--   updateFunc, resetFunc, displayFunc, buttonDisp, resetButton)
  
--   local obj = {}
--   setmetatable(obj, self)
--   self.__index = self
  
--   obj.lastUpdateFrame = dolphin.getFrameCount()
  
--   obj.updateFunc = updateFunc
--   obj.resetFunc = resetFunc
--   obj.displayFunc = displayFunc
  
--   obj.buttonDisp = buttonDisp
--   obj.resetButton = resetButton
  
--   return obj
-- end
-- function ResettableTracker:reset()
--   self:resetFunc()
-- end
-- function ResettableTracker:update()
--   local currentFrame = dolphin.getFrameCount()
--   if self.lastUpdateFrame == currentFrame then return end
--   self.lastUpdateFrame = currentFrame
  
--   -- If the reset button is being pressed, call the reset function.
--   if self.buttonDisp(self.resetButton) ~= ' ' then self:reset() end
--   self:updateFunc()
-- end
-- function ResettableTracker:display(...)
--   self:update()
--   return self:displayFunc(...)
-- end



local AnchoredDistance = subclass(DerivedValue)
AnchoredDistance.label = "To be determined in new()"
AnchoredDistance.initialValue = 0.0

function AnchoredDistance:new(pos, coordinates)
  local obj = DerivedValue.new(self)
  
  -- coordinates - a string such as "X" "Y" "XZ" "XYZ"
  obj.posObjects = {}
  if string.find(coordinates, "X") then table.insert(obj.posObjects, pos.x) end
  if string.find(coordinates, "Y") then table.insert(obj.posObjects, pos.y) end
  if string.find(coordinates, "Z") then table.insert(obj.posObjects, pos.z) end
  obj.numCoordinates = #obj.posObjects
  
  if numCoordinates == 1 then obj.label = coordinates.." Pos Diff"
  else obj.label = coordinates.." Distance" end
  
  -- If we're tracking velocity of 1 coordinate, it should have a +/- display.
  -- If more than 1 coordinate, it'll just be a magnitude, so need no +/-.
  local defaultSigned = (obj.numCoordinates == 1)
  obj.displayDefaults = {signed=defaultSigned}
  
  obj:reset()
  
  return obj
end

function AnchoredDistance:updateValue()
  self.currPos = {}
  for _, posObject in pairs(self.posObjects) do
    table.insert(self.currPos, posObject:get())
  end
  
  if self.numCoordinates == 1 then
    self.value = self.currPos[1] - self.anchor[1]
  else
    local sumOfSquaredDiffs = 0.0
    for n = 1, self.numCoordinates do
      local diff = self.currPos[n] - self.anchor[n] 
      sumOfSquaredDiffs = sumOfSquaredDiffs + diff*diff
    end
    self.value = math.sqrt(sumOfSquaredDiffs)
  end
end

function AnchoredDistance:reset()
  -- Reset anchor
  self.anchor = {}
  for _, posObject in pairs(self.posObjects) do
    table.insert(self.anchor, posObject:get())
  end
end

-- TODO: Check if needed

-- local function anchoredDistanceUpdate(self)
--   self.currPos = {}
--   for _, posObject in pairs(self.posObjects) do
--     table.insert(self.currPos, posObject:get())
--   end
  
--   if self.numCoordinates == 1 then
--     self.value = self.currPos[1] - self.anchor[1]
--   else
--     local sumOfSquaredDiffs = 0.0
--     for n = 1, self.numCoordinates do
--       local diff = self.currPos[n] - self.anchor[n] 
--       sumOfSquaredDiffs = sumOfSquaredDiffs + diff*diff
--     end
--     self.value = math.sqrt(sumOfSquaredDiffs)
--   end
-- end
-- local function anchoredDistanceReset(self)
--   self.anchor = self.currPos
-- end
-- local function anchoredDistanceDisplay(self, ...)
--   -- Kind of a sketchy way to re-use a function.
--   -- Might want to reorganize things a bit later.
--   return Velocity.display(self, ...)
-- end

-- local function newAnchoredDistance(x, y, z, buttonDisp,
--   coordinates, resetButton)
  
--   local obj = ResettableTracker:new(
--     anchoredDistanceUpdate, anchoredDistanceReset, anchoredDistanceDisplay,
--     buttonDisp, resetButton
--   )
  
--   local pos = {X = x, Y = y, Z = z}
--   obj.posObjects = {}
--   for char in coordinates:gmatch"." do
--     table.insert(obj.posObjects, pos[char])
--   end
  
--   -- Initialize
--   obj.currPos = {}
--   for _, posObject in pairs(obj.posObjects) do
--     table.insert(obj.currPos, 0.0)
--   end
--   obj.anchor = {}
--   obj:reset()
  
--   obj.numCoordinates = string.len(coordinates)
--   if obj.numCoordinates == 1 then obj.label = coordinates.." Pos Diff"
--   else obj.label = coordinates.." Distance" end
  
--   return obj
-- end



local MaxValue = subclass(DerivedValue)
MaxValue.label = "To be determined in new()"
MaxValue.initialValue = 0.0

function MaxValue:new(baseValue)
  local obj = DerivedValue.new(self)
  
  obj.baseValue = baseValue
  obj.label = "Max "..baseValue.label
  -- Display the same way as the base value
  obj.displayValue = baseValue.displayValue
  
  obj:reset()
  
  return obj
end

function MaxValue:updateValue()
  self.baseValue:update()

  if self.baseValue.value > self.value then
    self.value = self.baseValue.value
  end
end

function MaxValue:reset()
  if self.baseValue.reset then self.baseValue:reset() end
  -- Set max value to (essentially) negative infinity, so any valid value
  -- is guaranteed to be the new max
  self.value = -math.huge
end

-- TODO: Check if needed

-- local function anchoredMaxDistanceUpdate(self)
--   self.anchoredDistObj:update()

--   if self.anchoredDistObj.value > self.value then
--     self.value = self.anchoredDistObj.value
--   end
-- end
-- local function anchoredMaxDistanceReset(self)
--   self.anchoredDistObj:reset()
--   self.value = -math.huge
-- end
-- local function newAnchoredMaxDistance(x, y, z, buttonDisp,
--   coordinates, resetButton)
  
--   local obj = ResettableTracker:new(
--     anchoredMaxDistanceUpdate, anchoredMaxDistanceReset, anchoredDistanceDisplay,
--     buttonDisp, resetButton
--   )
  
--   obj.anchoredDistObj = newAnchoredDistance(
--     x, y, z, buttonDisp, coordinates, resetButton
--   )
--   obj:reset()
  
--   obj.numCoordinates = string.len(coordinates)
--   if obj.numCoordinates == 1 then obj.label = coordinates.." MaxPosDiff"
--   else obj.label = coordinates.." Max Dist" end
  
--   return obj
-- end



local AnchoredHeight = subclass(DerivedValue)
AnchoredHeight.label = "Height"
AnchoredHeight.initialValue = 0.0

function AnchoredHeight:new(pos, dgrav)
  local obj = DerivedValue.new(self)
  
  obj.pos = pos
  obj.dgrav = dgrav
  
  obj:reset()
  
  return obj
end

function AnchoredHeight:updateValue()
  -- Dot product of distance-from-anchor vector and up vector
  self.value = self.pos:get():minus(self.anchor):dot(self.upValue)
end

function AnchoredHeight:reset()
  self.anchor = self.pos:get()
  self.upValue = self.dgrav:get():times(-1)
end

-- TODO: Check if needed

-- local function anchoredHeightUpdate(self)
--   -- Dot product of distance-from-anchor vector and up vector
--   self.value = (
--     (self.px:get() - self.anchorx) * self.uxValue
--     + (self.py:get() - self.anchory) * self.uyValue
--     + (self.pz:get() - self.anchorz) * self.uzValue
--   )
-- end
-- local function anchoredHeightReset(self)
--   self.anchorx = self.px:get()
--   self.anchory = self.py:get()
--   self.anchorz = self.pz:get()
--   self.uxValue = self.ux:get()
--   self.uyValue = self.uy:get()
--   self.uzValue = self.uz:get()
-- end
-- local function anchoredHeightDisplay(self, ...)
--   -- Kind of a sketchy way to re-use a function.
--   -- Might want to reorganize things a bit later.
--   return Velocity.display(self, ...)
-- end

-- local function newAnchoredHeight(px, py, pz, ux, uy, uz, buttonDisp, resetButton)
  
--   local obj = ResettableTracker:new(
--     anchoredHeightUpdate, anchoredHeightReset, anchoredHeightDisplay,
--     buttonDisp, resetButton
--   )
  
--   obj.px = px
--   obj.py = py
--   obj.pz = pz
--   obj.ux = ux
--   obj.uy = uy
--   obj.uz = uz
--   obj.label = "Height"
  
--   obj:reset()
  
--   return obj
-- end



-- TODO: Check if needed

-- local function anchoredMaxHeightUpdate(self)
--   self.anchoredHeightObj:update()

--   if self.anchoredHeightObj.value > self.value then
--     self.value = self.anchoredHeightObj.value
--   end
-- end
-- local function anchoredMaxHeightReset(self)
--   self.anchoredHeightObj:reset()
--   self.value = -math.huge
-- end
-- local function newAnchoredMaxHeight(px, py, pz, ux, uy, uz, buttonDisp, resetButton)
  
--   local obj = ResettableTracker:new(
--     anchoredMaxHeightUpdate, anchoredMaxHeightReset, anchoredHeightDisplay,
--     buttonDisp, resetButton
--   )
  
--   obj.anchoredHeightObj = newAnchoredHeight(
--     px, py, pz, ux, uy, uz, buttonDisp, resetButton
--   )
--   obj.label = "Max Height"
--   obj:reset()
  
  
--   return obj
-- end



local AverageValue = subclass(DerivedValue)
AverageValue.label = "To be determined in new()"
AverageValue.initialValue = 0.0

function AverageValue:new(baseValue)
  local obj = DerivedValue.new(self)
  
  obj.baseValue = baseValue
  obj.label = "Avg "..baseValue.label
  -- Display the same way as the base value
  obj.displayValue = baseValue.displayValue
  
  obj:reset()
  
  return obj
end

function AverageValue:updateValue()
  self.baseValue:update()
  self.sum = self.sum + self.baseValue.value
  self.numOfDataPoints = self.numOfDataPoints + 1

  self.value = self.sum / self.numOfDataPoints
end

function AverageValue:reset()
  if self.baseValue.reset then self.baseValue:reset() end
  self.sum = 0
  self.numOfDataPoints = 0
end

-- TODO: Check if needed

-- local function averageSpeedUpdate(self)
--   self.velObject:update()
--   self.speedSum = self.speedSum + self.velObject.value
--   self.numOfDataPoints = self.numOfDataPoints + 1

--   self.value = self.speedSum / self.numOfDataPoints
-- end
-- local function averageSpeedReset(self)
--   self.speedSum = 0
--   self.numOfDataPoints = 0
-- end
-- local function averageSpeedDisplay(self, ...)
--   -- Kind of a sketchy way to re-use a function.
--   -- Might want to reorganize things a bit later.
--   return Velocity.display(self, ...)
-- end

-- local function newAverageSpeed(newVelocityTracker, buttonDisp,
--   coordinates, resetButton)
  
--   local obj = ResettableTracker:new(
--     averageSpeedUpdate, averageSpeedReset, averageSpeedDisplay,
--     buttonDisp, resetButton
--   )
  
--   obj.velObject = newVelocityTracker(coordinates)
  
--   obj.label = coordinates.." Avg Speed"
  
--   obj:reset()
  
--   return obj
-- end



return {
  timeDisplay = timeDisplay,
  
  VToDerivedValue = VToDerivedValue,
  Velocity = Velocity,
  RateOfChange = RateOfChange,
  Tilt = Tilt,
  UpwardVelocity = UpwardVelocity,
  LateralVelocity = LateralVelocity,
  UpwardVelocityLastJump = UpwardVelocityLastJump,
  UpVelocityTiltBonus = UpVelocityTiltBonus,
  
  buttonDisp = buttonDisp,
  getShakeType = getShakeType,
  shakeDisp = shakeDisp,
  spinDisp = spinDisp,
  inputDisplay = inputDisplay,
  StickInputImage = StickInputImage,
  
  ResettableValue = ResettableValue,
  MaxValue = MaxValue,
  AverageValue = AverageValue,
  AnchoredDistance = AnchoredDistance,
  AnchoredHeight = AnchoredHeight,
}
