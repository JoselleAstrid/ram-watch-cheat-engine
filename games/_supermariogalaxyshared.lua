-- Super Mario Galaxy 1 and 2, shared functions and definitions



package.loaded.dolphin = nil
local dolphin = require "dolphin"
package.loaded.utils = nil
local utils = require "utils"
local subclass = utils.subclass
package.loaded.utils_math = nil
local utils_math = require "utils_math"
local Vector3 = utils_math.Vector3
package.loaded.valuetypes = nil
local vtypes = require "valuetypes"
local Vector3Value = vtypes.Vector3Value





local SMGshared = subclass(dolphin.DolphinGame)

function SMGshared:init(options)
  dolphin.DolphinGame.init(self, options)
end



function SMGshared:timeDisplay(framesObj, which, options)
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
  if options.narrow then
    format = "%s:\n %s\n %d"
  else
    format = "%s: %s | %d"
  end
  
  local display = string.format(format, label, timeStr, frames)
  return display
end

function SMGshared:stageTimeDisplay(options)
  return self:timeDisplay(self.stageTimeFrames, "stage", options)
end

-- SMG2 only
function SMGshared:fileTimeDisplay(options)
  return self:timeDisplay(self.fileTimeFrames, "stage", options)
end



SMGshared.DerivedValue = {}
SMGshared.DerivedValue.label = "Value label goes here"
SMGshared.DerivedValue.initialValue = 0.0

function SMGshared.DerivedValue:init()
  self.value = self.initialValue
  self.lastUpdateFrame = self.game:getFrameCount()
end

function SMGshared.DerivedValue:updateValue()
  -- Subclasses should implement this function to update self.value.
  error("Function not implemented")
end

function SMGshared.DerivedValue:update()
  local currentFrame = self.game:getFrameCount()
  if self.lastUpdateFrame == currentFrame then return end
  self.lastUpdateFrame = currentFrame
  
  self:updateValue()
end

function SMGshared.DerivedValue:get()
  self:update()
  return self.value
end

function SMGshared.DerivedValue:displayValue(options)
  return utils.floatToStr(self.value, options)
end

function SMGshared.DerivedValue:display(passedOptions)
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

function SMGshared:newDV(class, ...)
  -- Like classInstantiate(), except the game attribute is set
  -- before init() is called
  local obj = subclass(class)
  obj.game = self
  obj:init(...)
  return obj
end



function SMGshared:VToDerivedValue(vObj)
  local obj = self:newDV(self.DerivedValue)
  obj.vObj = vObj
  obj.label = vObj.label
  function obj:updateValue()
    self.value = self.vObj:get()
  end
  return obj
end



-- Velocity calculated as position change.

SMGshared.Velocity = subclass(SMGshared.DerivedValue)
SMGshared.Velocity.label = "Label to be passed as argument"
SMGshared.Velocity.initialValue = 0.0

function SMGshared.Velocity:init(coordinates)
  self.game.DerivedValue.init(self)
  
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

function SMGshared.Velocity:updateValue()
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



SMGshared.RateOfChange = subclass(SMGshared.DerivedValue)
SMGshared.RateOfChange.label = "Label to be passed as argument"
SMGshared.RateOfChange.initialValue = 0.0

function SMGshared.RateOfChange:init(baseValue, label)
  self.game.DerivedValue.init(self)
  
  self.baseValue = baseValue
  self.label = label
  -- Display the same way as the base value
  self.displayValue = baseValue.displayValue
end

function SMGshared.RateOfChange:updateValue()
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



-- Difference between gravity up-vector and character tilt up-vector.
-- We might also call this 'skew' when the character is tilted on
-- non-tilting ground.

SMGshared.Tilt = subclass(SMGshared.DerivedValue)
SMGshared.Tilt.label = "Not used"
SMGshared.Tilt.initialValue = "Not used"

function SMGshared.Tilt:init()
  self.game.DerivedValue.init(self)
  
  self.dgrav = self.game.downVectorGravity
  self.utilt = self.game.upVectorTilt
end

function SMGshared.Tilt:updateValue()
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

function SMGshared.Tilt:getRotation()
  self:update()
  return {self.rotationRadians, self.rotationAxis}
end

function SMGshared.Tilt:displayRotation()
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

function SMGshared.Tilt:getDiff()
  self:update()
  return self.diff
end

function SMGshared.Tilt:displayDiff(options)
  self:update()
  
  options.beforeDecimal = options.beforeDecimal or 1
  options.afterDecimal = options.afterDecimal or 3
  options.signed = options.signed or true
  return self.diff:display("Tilt (Diff)", options)
end



SMGshared.UpwardVelocity = subclass(SMGshared.DerivedValue)
SMGshared.UpwardVelocity.label = "Upward Vel"
SMGshared.UpwardVelocity.initialValue = 0.0
SMGshared.UpwardVelocity.displayDefaults = {signed=true}

function SMGshared.UpwardVelocity:init()
  self.game.DerivedValue.init(self)
  
  self.pos = self.game.pos
  self.dgrav = self.game.downVectorGravity
end

function SMGshared.UpwardVelocity:updateValue()
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



SMGshared.LateralVelocity = subclass(SMGshared.DerivedValue)
SMGshared.LateralVelocity.label = "Lateral Spd"
SMGshared.LateralVelocity.initialValue = 0.0

function SMGshared.LateralVelocity:init()
  self.game.DerivedValue.init(self)
  
  self.pos = self.game.pos
  self.dgrav = self.game.downVectorGravity
end

function SMGshared.LateralVelocity:updateValue()
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



SMGshared.UpwardVelocityLastJump = subclass(SMGshared.DerivedValue)
SMGshared.UpwardVelocityLastJump.label = "Up Vel\nlast jump"
SMGshared.UpwardVelocityLastJump.initialValue = 0.0
SMGshared.UpwardVelocityLastJump.displayDefaults = {signed=true}

function SMGshared.UpwardVelocityLastJump:init()
  self.game.DerivedValue.init(self)
  
  self.pos = self.game.pos
  self.dgrav = self.game.downVectorGravity
end

function SMGshared.UpwardVelocityLastJump:updateValue()
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

SMGshared.UpVelocityTiltBonus = subclass(SMGshared.DerivedValue)
SMGshared.UpVelocityTiltBonus.label = "Up Vel\ntilt bonus\nprediction"
SMGshared.UpVelocityTiltBonus.initialValue = 0.0
SMGshared.UpVelocityTiltBonus.displayDefaults = {signed=true}

function SMGshared.UpVelocityTiltBonus:init()
  self.game.DerivedValue.init(self)
  
  self.nextVel = Vector3Value:new(
    self.game:newDV(self.game.RateOfChange, self.game:VToDerivedValue(self.game.pos_early1.x)),
    self.game:newDV(self.game.RateOfChange, self.game:VToDerivedValue(self.game.pos_early1.y)),
    self.game:newDV(self.game.RateOfChange, self.game:VToDerivedValue(self.game.pos_early1.z)),
    "Velocity"
  )
  
  self.dgrav = self.game.downVectorGravity
  self.tiltValue = self.game:newDV(self.game.Tilt)
end

function SMGshared.UpVelocityTiltBonus:updateValue()
  -- Don't update if not on the ground.
  -- This way, during a jump, we can see what the
  -- predicted bonus velocity was for that jump.
  if not self.game:onGround() then return end
  
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



function SMGshared:buttonDisp(button)
  local value = nil
  if button == "H" then  -- Home
    value = self.buttons1:get()[1]
  elseif button == "C" then
    value = self.buttons1:get()[2]
  elseif button == "Z" then
    value = self.buttons1:get()[3]
  elseif button == "A" then
    value = self.buttons1:get()[5]
  elseif button == "B" then
    value = self.buttons1:get()[6]
  elseif button == "+" then
    value = self.buttons2:get()[4]
  elseif button == "^" then
    value = self.buttons2:get()[5]
  elseif button == "v" then
    value = self.buttons2:get()[6]
  elseif button == ">" then
    value = self.buttons2:get()[7]
  elseif button == "<" then
    value = self.buttons2:get()[8]
  end
  if value == 1 then
    return button
  else
    return " "
  end
end



SMGshared.spinDisplay = ""
function SMGshared:getShakeType()
  if self.wiimoteSpinBit:get() == 1 then
    return "Wiimote"
  elseif self.nunchukSpinBit:get() == 1 then
    return "Nunchuk"
  else
    -- This should really only happen if the script is started in the middle
    -- of a spin.
    return nil
  end
end
function SMGshared:shakeDisp()
  local shakeType = self:getShakeType()
  if shakeType ~= nil then
    return shakeType.." shake"
  else
    return ""
  end
end
function SMGshared:spinDisp()
  local cooldownTimer = self.spinCooldownTimer:get()
  local attackTimer = self.spinAttackTimer:get()
  local shakeType = self:getShakeType()
  
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



function SMGshared:inputDisplay(shakeOrSpin, displayType)
  
  local displayStickX = string.format("%+.3f", self.stickX:get())
  local displayStickY = string.format("%+.3f", self.stickY:get())
  local displayButtons1 = string.format("%s%s%s%s%s",
    self:buttonDisp("C"), self:buttonDisp("^"), self:buttonDisp("v"),
    self:buttonDisp("<"), self:buttonDisp(">")
  )
  local displayButtons2 = string.format("%s%s%s%s%s",
    self:buttonDisp("A"), self:buttonDisp("B"), self:buttonDisp("Z"),
    self:buttonDisp("+"), self:buttonDisp("H")
  )
  local displayShakeOrSpin = nil
  if shakeOrSpin == "both" then
    displayShakeOrSpin = self:shakeDisp().."\n"..self:spinDisp()
  elseif shakeOrSpin == "shake" then
    displayShakeOrSpin = self:shakeDisp()
  else
    displayShakeOrSpin = self:spinDisp()
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



SMGshared.StickInputImage = {}

function SMGshared.StickInputImage:init(game, window, options)
  local foregroundColor =
    options.foregroundColor or 0x000000  -- default = black
  
  self.image = createImage(window)
  self.image:setPosition(options.x or 0, options.y or 0)
  self.size = options.size
  self.image:setSize(self.size, self.size)
  self.canvas = self.image:getCanvas()
  -- Brush: ellipse() fill
  self.canvas:getBrush():setColor(0xF0F0F0)
  -- Pen: ellipse() outline, line()
  self.canvas:getPen():setColor(foregroundColor)
  self.canvas:getPen():setWidth(2)
  -- Initialize the whole image with the brush color
  self.canvas:fillRect(0,0, self.size,self.size)
  
  self.stickX = game.stickX
  self.stickY = game.stickY
end

function SMGshared.StickInputImage:update()
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



SMGshared.ResettableValue = subclass(SMGshared.DerivedValue)

function SMGshared.ResettableValue:init(baseValue, resetButton)
  self.game.DerivedValue.init(self)
  
  -- The baseValue's class is expected to define a reset function.
  if not baseValue.reset then
    error("Value of label '" .. baseValue.label
      .. "' needs a reset function to be resettable")
  end
  
  -- Default reset button is D-Pad Down.
  self.resetButton = resetButton or 'v'
  
  self.baseValue = baseValue
  self.label = baseValue.label
  -- Display the same way as the base value
  self.displayValue = baseValue.displayValue
  
  self.buttonDisp = self.game.buttonDisp
end

function SMGshared.ResettableValue:updateValue()
  -- If the reset button is being pressed, reset the baseValue.
  if self.buttonDisp(self.resetButton) ~= ' ' then self.baseValue:reset() end
  -- Update the baseValue.
  self.baseValue:updateValue()
  -- Update self.value for the purpose of getting the value for display.
  self.value = self.baseValue.value
end



SMGshared.AnchoredDistance = subclass(SMGshared.DerivedValue)
SMGshared.AnchoredDistance.label = "Label to be passed as argument"
SMGshared.AnchoredDistance.initialValue = 0.0

function SMGshared.AnchoredDistance:init(coordinates)
  self.game.DerivedValue.init(self)
  
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
  
  self:reset()
end

function SMGshared.AnchoredDistance:updateValue()
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

function SMGshared.AnchoredDistance:reset()
  -- Reset anchor
  self.anchor = {}
  for _, posObject in pairs(self.posObjects) do
    table.insert(self.anchor, posObject:get())
  end
end



SMGshared.MaxValue = subclass(SMGshared.DerivedValue)
SMGshared.MaxValue.label = "Label to be passed as argument"
SMGshared.MaxValue.initialValue = 0.0

function SMGshared.MaxValue:init(baseValue)
  self.game.DerivedValue.init(self)
  
  self.baseValue = baseValue
  self.label = "Max "..baseValue.label
  -- Display the same way as the base value
  self.displayValue = baseValue.displayValue
  
  obj:reset()
end

function SMGshared.MaxValue:updateValue()
  self.baseValue:update()

  if self.baseValue.value > self.value then
    self.value = self.baseValue.value
  end
end

function SMGshared.MaxValue:reset()
  if self.baseValue.reset then self.baseValue:reset() end
  -- Set max value to (essentially) negative infinity, so any valid value
  -- is guaranteed to be the new max
  self.value = -math.huge
end



SMGshared.AnchoredHeight = subclass(SMGshared.DerivedValue)
SMGshared.AnchoredHeight.label = "Height"
SMGshared.AnchoredHeight.initialValue = 0.0

function SMGshared.AnchoredHeight:init()
  self.game.DerivedValue.init(self)
  
  self.pos = self.game.pos
  self.dgrav = self.game.downVectorGravity
  
  self:reset()
end

function SMGshared.AnchoredHeight:updateValue()
  -- Dot product of distance-from-anchor vector and up vector
  self.value = self.pos:get():minus(self.anchor):dot(self.upValue)
end

function SMGshared.AnchoredHeight:reset()
  self.anchor = self.pos:get()
  self.upValue = self.dgrav:get():times(-1)
end



SMGshared.AverageValue = subclass(SMGshared.DerivedValue)
SMGshared.AverageValue.label = "Label to be passed as argument"
SMGshared.AverageValue.initialValue = 0.0

function SMGshared.AverageValue:init(baseValue)
  self.game.DerivedValue.init(self)
  
  self.baseValue = baseValue
  self.label = "Avg "..baseValue.label
  -- Display the same way as the base value
  self.displayValue = baseValue.displayValue
  
  self:reset()
end

function SMGshared.AverageValue:updateValue()
  self.baseValue:update()
  self.sum = self.sum + self.baseValue.value
  self.numOfDataPoints = self.numOfDataPoints + 1

  self.value = self.sum / self.numOfDataPoints
end

function SMGshared.AverageValue:reset()
  if self.baseValue.reset then self.baseValue:reset() end
  self.sum = 0
  self.numOfDataPoints = 0
end



return SMGshared
