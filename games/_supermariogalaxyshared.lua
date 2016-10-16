-- Super Mario Galaxy 1 and 2, shared functions and definitions



package.loaded.dolphin = nil
local dolphin = require "dolphin"
package.loaded.utils = nil
local layouts = require "layouts"
package.loaded.layouts = nil
local utils = require "utils"
local subclass = utils.subclass
package.loaded.utils_math = nil
local utils_math = require "utils_math"
local Vector3 = utils_math.Vector3
package.loaded.valuetypes = nil
local valuetypes = require "valuetypes"
local V = valuetypes.V
local MV = valuetypes.MV
local Vector3Value = valuetypes.Vector3Value
local RateOfChange = valuetypes.RateOfChange
local ResettableValue = valuetypes.ResettableValue



local SMGshared = subclass(dolphin.DolphinGame)

function SMGshared:init(options)
  dolphin.DolphinGame.init(self, options)
end

local GV = SMGshared.blockValues



-- At least one computation requires knowing the character we're currently
-- playing as. Unfortunately, we don't know where the character specification
-- is in SMG1/2 memory at the moment, so we have to set the character manually.
-- Possible values: 'mario', 'luigi', 'yoshi'.
--
-- Here we just set a default value.
-- Set to a different value in layout code as needed, like:
-- game.character = 'luigi'
SMGshared.character = 'mario'



-- Tracking time based on a memory value which represents number of frames
-- since time = 0.

local Time = subclass(Value)
SMGshared.Time = Time
Time.label = "Should be set by subclass"
Time.initialValue = nil

function Time:init(frames)
  self.frames = frames
  Value.init(self)
end

function Time:updateValue()
  self.frames:update()
end

function Time:displayValue(options)
  local frames = self.frames:get()
  
  local hours = math.floor(frames / (60*60*60))
  local mins = math.floor(frames / (60*60)) % 60
  local secs = math.floor(frames / 60) % 60
  local centis = math.floor((frames % 60) * (100/60))
  
  local timeStr = nil
  if hours > 0 then
    timeStr = string.format("%d:%02d:%02d.%02d", hours, mins, secs, centis)
  else
    timeStr = string.format("%d:%02d.%02d", mins, secs, centis)
  end
    
  if options.narrow then
    return string.format("%s\n %d", timeStr, frames)
  else
    return string.format("%s | %d", timeStr, frames)
  end
end


-- In-game level time in SMG2, level-timer-esque value in SMG1
GV.stageTime = subclass(Time)
GV.stageTime.label = "Stage time"
function GV.stageTime:init()
  Time.init(self, self.game.stageTimeFrames)
end


-- SMG2 only
GV.fileTime = subclass(Time)
GV.fileTime.label = "File time"
function GV.fileTime:init()
  Time.init(self, self.game.fileTimeFrames)
end



-- Velocity calculated as position change.

local Velocity = subclass(Value)
SMGshared.Velocity = Velocity
Velocity.label = "Label to be determined"
Velocity.initialValue = 0.0

function Velocity:init(coordinates)
  Value.init(self)
  
  -- coordinates - a string such as "X" "Y" "XZ" "XYZ"
  self.posObjects = {}
  if string.find(coordinates, "X") then table.insert(self.posObjects, self.game.pos.x) end
  if string.find(coordinates, "Y") then table.insert(self.posObjects, self.game.pos.y) end
  if string.find(coordinates, "Z") then table.insert(self.posObjects, self.game.pos.z) end
  self.numCoordinates = #self.posObjects
  
  if self.numCoordinates == 1 then self.label = coordinates.." Vel"
  else self.label = coordinates.." Speed" end
  
  -- If we're tracking velocity of 1 coordinate, it should have a +/- display.
  -- If more than 1 coordinate, it'll just be a magnitude, so need no +/-.
  local defaultSigned = (self.numCoordinates == 1)
  self.displayDefaults = {signed=defaultSigned}
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



-- Difference between gravity up-vector and character tilt up-vector.
-- We might also call this 'skew' when the character is tilted on
-- non-tilting ground.

local tilt = subclass(Value)
GV.tilt = tilt
tilt.label = "Label not used"
tilt.initialValue = "Value field not used"

function tilt:init()
  Value.init(self)
  
  self.dgrav = self.game.downVectorGravity
  self.utilt = self.game.upVectorTilt
end

function tilt:updateValue()
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

function tilt:getRotation()
  self:update()
  return {self.rotationRadians, self.rotationAxis}
end

function tilt:displayRotation()
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

function tilt:getDiff()
  self:update()
  return self.diff
end

function tilt:displayDiff(options)
  options = options or {}
  self:update()
  
  options.beforeDecimal = options.beforeDecimal or 1
  options.afterDecimal = options.afterDecimal or 3
  options.signed = options.signed or true
  return self.diff:display("Tilt (Diff)", options)
end



local upwardVelocity = subclass(Value)
GV.upwardVelocity = upwardVelocity
upwardVelocity.label = "Upward Vel"
upwardVelocity.initialValue = 0.0
upwardVelocity.displayDefaults = {signed=true}

function upwardVelocity:init()
  Value.init(self)
  
  self.pos = self.game.pos
  self.dgrav = self.game.downVectorGravity
end

function upwardVelocity:updateValue()
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



local lateralVelocity = subclass(Value)
GV.lateralVelocity = lateralVelocity
lateralVelocity.label = "Lateral Spd"
lateralVelocity.initialValue = 0.0

function lateralVelocity:init()
  Value.init(self)
  
  self.pos = self.game.pos
  self.dgrav = self.game.downVectorGravity
end

function lateralVelocity:updateValue()
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



local upwardVelocityLastJump = subclass(Value)
GV.upwardVelocityLastJump = upwardVelocityLastJump
upwardVelocityLastJump.label = "Up Vel\nlast jump"
upwardVelocityLastJump.initialValue = 0.0
upwardVelocityLastJump.displayDefaults = {signed=true}

function upwardVelocityLastJump:init()
  Value.init(self)
  
  self.pos = self.game.pos
  self.dgrav = self.game.downVectorGravity
end

function upwardVelocityLastJump:updateValue()
  local pos = self.pos:get()
  local onGround = self.game:onGround()
      
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



-- If we jumped right now, our tilt would give us
-- this much extra initial upward velocity.
-- (e.g. a bonus of +0.9 means that, if we normally start with
-- 22 upward velocity, then here we start with 22.9.)

local upVelocityTiltBonus = subclass(Value)
GV.upVelocityTiltBonus = upVelocityTiltBonus
upVelocityTiltBonus.label = "Up Vel\ntilt bonus\nprediction"
upVelocityTiltBonus.initialValue = 0.0
upVelocityTiltBonus.displayDefaults = {signed=true}

function upVelocityTiltBonus:init()
  Value.init(self)
  
  -- A Vector3's x, y, and z fields aren't set until the vector is initialized.
  valuetypes.initValueAsNeeded(self.game.pos_early1)
  
  self.nextVel = self.game:V(
    Vector3Value,
    self.game:V(RateOfChange, self.game.pos_early1.x),
    self.game:V(RateOfChange, self.game.pos_early1.y),
    self.game:V(RateOfChange, self.game.pos_early1.z)
  )
  
  self.dgrav = self.game.downVectorGravity
  self.tilt = self.game.tilt
end

function upVelocityTiltBonus:updateValue()
  -- Don't update if not on the ground.
  -- This way, during a jump, we can see what the
  -- predicted bonus velocity was for that jump.
  if not self.game:onGround() then return end
  
  -- Get the tilt.
  local array = self.tilt:getRotation()
  local tiltRadians = array[1]
  local tiltAxis = array[2]
  
  -- If no tilt, then we know there's no up vel bonus, and we're done.
  if tiltRadians == 0.0 then
    self.value = 0.0
    return
  end

  -- Get the in-memory velocity that'll be observed on the NEXT frame.
  local nextVel = self.nextVel:get()
  
  -- Account for the fact that lateral speed gets
  -- multiplied by a factor when you jump.
  -- This factor is related to the character's max run speed.
  -- We haven't found the character's max run speed in memory yet, so we have
  -- to determine it manually.
  local maxRunSpeed = nil
  if self.game.character == 'mario' then maxRunSpeed = 13
  elseif self.game.character == 'luigi' then maxRunSpeed = 15
  elseif self.game.character == 'yoshi' then maxRunSpeed = 18
  else error("Unrecognized character: "..tostring(self.game.character))
  end
  nextVel = nextVel:times(12.5/maxRunSpeed)
  
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



function SMGshared:getButton(button)
  -- Return 1 if button is pressed, 0 otherwise.
  --
  -- TODO: Check if this can be universally implemented, with same addresses
  -- and all, for any Wii/GC game.
  local b1 = self.buttons1
  local b2 = self.buttons2
  
  local value = nil
  if button == "H" then value = b1:get()[1]  -- Home
  elseif button == "C" then value = b1:get()[2]
  elseif button == "Z" then value = b1:get()[3]
  elseif button == "A" then value = b1:get()[5]
  elseif button == "B" then value = b1:get()[6]
  elseif button == "+" then value = b2:get()[4]
  elseif button == "^" then value = b2:get()[5]
  elseif button == "v" then value = b2:get()[6]
  elseif button == ">" then value = b2:get()[7]
  elseif button == "<" then value = b2:get()[8]
  else error("Button code not recognized: " .. tostring(button))
  end
  
  return value
end



GV.shake = V(Value)
GV.shake.initialValue = {wiimote=0, nunchuk=0}

function GV.shake:updateValue()
  self.value = {
    wiimote=self.game.wiimoteShakeBit:get(),
    nunchuk=self.game.nunchukShakeBit:get(),
  }
end

function GV.shake:display()
  self:update()
  
  if self.value.wiimote == 1 then return "Wiimote shake"
  elseif self.value.nunchuk == 1 then return "Nunchuk shake"
  else return ""
  end
end



GV.spinStatus = V(Value)
GV.spinStatus.initialValue = {phase='noSpin', spinType='unknown'}

function GV.spinStatus:updateValue()
  local cooldownTimer = self.game.spinCooldownTimer:get()
  local attackTimer = self.game.spinAttackTimer:get()
  local shakeValues = self.game.shake:get()
  
  self.previousValue = self.value
  self.value = {phase=nil, spinType=nil}
  
  if cooldownTimer > 0 then
    if attackTimer > 0 then
      -- We know we're in the middle of the spin animation.
      self.value.phase = 'spin'
      
      -- Update the spin type based on the current shake input,
      -- ONLY if we have just started a spin.
      if self.previousValue.phase == 'noSpin' or cooldownTimer == 79 then
        -- Just started a spin: either there was no spin on the previous frame,
        -- or the cooldown timer is at its max value.
        -- Both checks are imperfect. The 'noSpin' check misses the case where
        -- a new spin is started JUST as the previous spin ends (1 frame
        -- window). The timer check might miss a spin-start if this Lua script
        -- skips a frame.
        -- The idea is that reliability should be higher with both checks
        -- working together.
        if shakeValues.wiimote == 1 then self.value.spinType = 'wiimote'
        elseif shakeValues.nunchuk == 1 then self.value.spinType = 'nunchuk'
        else self.value.spinType = 'unknown'
        end
      else
        -- If we haven't just started a spin, then the previous spin is
        -- still going.
        self.value.spinType = self.previousValue.spinType
      end
    else
      -- Spin attack is over, but need to wait to do another spin.
      self.value.phase = 'cooldown'
      self.value.spinType = self.previousValue.spinType
    end
  else
    if attackTimer > 0 then
      -- Spin attack is going in midair. (This includes "fake" midair spins,
      -- and still-active spin attacks after jump canceling a ground spin.)
      self.value.phase = 'attackSpin'
      
      -- TODO: Check if the max timer here is still 79.
      if self.previousValue.phase == 'noSpin' or cooldownTimer == 79 then
        if shakeValues.wiimote == 1 then self.value.spinType = 'wiimote'
        elseif shakeValues.nunchuk == 1 then self.value.spinType = 'nunchuk'
        else self.value.spinType = 'unknown'
        end
      else
        self.value.spinType = self.previousValue.spinType
      end
    else
      -- Both spin animation and effect are inactive.
      self.value.phase = 'noSpin'
    end
  end
end

function GV.spinStatus:display()
  self:update()

  if self.value.phase == 'spin' or self.value.phase == 'attackSpin' then
    -- We'll just display an attacking-only spin (no height boost)
    -- the same way as a full spin.
    if self.value.spinType == 'wiimote' then return "Wiimote spin"
    elseif self.value.spinType == 'nunchuk' then return "Nunchuk spin"
    elseif self.value.spinType == 'unknown' then return "? spin"
    else error("Unrecognized spin type: " .. self.value.spinType)
    end
  elseif self.value.phase == 'cooldown' then
    return "(Cooldown)"
  elseif self.value.phase == 'noSpin' then
    return ""
  else
    error("Unrecognized spin phase: " .. self.value.phase)
  end
end



local input = V(Value)
GV.input = input

function input:buttonDisplay(button)
  local value = self.game:getButton(button)
  if value == 1 then
    return button
  else
    return " "
  end
end

function input:displayAllButtons()
  local s = ""
  for _, button in pairs{"A", "B", "Z", "+", "H", "C", "^", "v", "<", ">"} do
    s = s..self:buttonDisplay(button)
  end
  return s
end

function input:display(options)
  options = options or {}
  
  local lines = {}
  
  if options.shake then table.insert(lines, self.game.shake:display()) end
  if options.spin then table.insert(lines, self.game.spinStatus:display()) end
  
  if options.stick then
    local stickX =
      self.game.stickX:display{nolabel=true, afterDecimal=3, signed=true}
    local stickY =
      self.game.stickY:display{nolabel=true, afterDecimal=3, signed=true}
    table.insert(lines, stickX.." "..stickY)
  end
  
  table.insert(lines, self:displayAllButtons())
  
  return table.concat(lines, "\n")
end



local AnchoredDistance = subclass(ResettableValue)
SMGshared.AnchoredDistance = AnchoredDistance
AnchoredDistance.label = "Label to be determined in init"
AnchoredDistance.initialValue = 0.0

function AnchoredDistance:init(coordinates)
  ResettableValue.init(self, resetButton)
  
  -- coordinates - a string such as "X" "Y" "XZ" "XYZ"
  self.posObjects = {}
  if string.find(coordinates, "X") then table.insert(self.posObjects, self.game.pos.x) end
  if string.find(coordinates, "Y") then table.insert(self.posObjects, self.game.pos.y) end
  if string.find(coordinates, "Z") then table.insert(self.posObjects, self.game.pos.z) end
  self.numCoordinates = #self.posObjects
  
  if numCoordinates == 1 then self.label = coordinates.." Pos Diff"
  else self.label = coordinates.." Distance" end
  
  -- If we're tracking velocity of 1 coordinate, it should have a +/- display.
  -- If more than 1 coordinate, it'll just be a magnitude, so need no +/-.
  local defaultSigned = (self.numCoordinates == 1)
  self.displayDefaults = {signed=defaultSigned}
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



local anchoredHeight = subclass(ResettableValue)
GV.anchoredHeight = anchoredHeight
anchoredHeight.label = "Height"
anchoredHeight.initialValue = 0.0

function anchoredHeight:init()
  ResettableValue.init(self, resetButton)
  
  self.pos = self.game.pos
  self.dgrav = self.game.downVectorGravity
end

function anchoredHeight:updateValue()
  -- Dot product of distance-from-anchor vector and up vector
  self.value = self.pos:get():minus(self.anchor):dot(self.upValue)
end

function anchoredHeight:reset()
  self.anchor = self.pos:get()
  self.upValue = self.dgrav:get():times(-1)
end



return SMGshared
