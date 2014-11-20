-- F-Zero GX



-- Imports.

-- First make sure that the imported modules get de-cached as needed, since
-- we may be re-running the script in the same run of Cheat Engine.
package.loaded.shared = nil
package.loaded.utils = nil
package.loaded.dolphin = nil

local shared = require "shared"
local utils = require "utils"
local dolphin = require "dolphin"

local readIntBE = utils.readIntBE
local readFloatBE = utils.readFloatBE
local floatToStr = utils.floatToStr
local initLabel = utils.initLabel
local debugDisp = utils.debugDisp
local StatRecorder = utils.StatRecorder

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------



-- Data structure for RAM values we care about.

local values = {
  baseStats = {},
  state = {},
}



-- Computing RAM values.

local baseStatsBlockOffsets = {
  accel = 0x8,
  body = 0x44,
  boostDuration = 0x34,
  boostInterval = 0x38,
  cameraReorienting = 0x4C,
  cameraRepositioning = 0x50,
  drag = 0x40,
  grip1 = 0x10,
  grip2 = 0x30,
  grip3 = 0x14,
  maxSpeed = 0xC,
  slideTurn = 0x24,
  strafe = 0x28,
  tilt1 = 0x54,
  tilt2 = 0x5C,
  tilt3 = 0x6C,
  tilt4 = 0x74,
  trackCollision = 0x9C,
  turning1 = 0x18,
  turning2 = 0x20,
  turning3 = 0x2C,
  turningAccel = 0x1C,
  turningDecel = 0x3C,
  weight = 0x4,
}

local stateBlockOffsets = {
  accel = 0x220,
  body = 0x30,
  boostDuration = 0x230,
  boostInterval = 0x234,
  cameraReorienting = 0x34,
  cameraRepositioning = 0x38,
  drag = 0x23C,
  grip1 = 0xC,
  grip2 = 0x24,
  grip3 = 0x28,
  maxSpeed = 0x22C,
  obstacleCollision = 0x584,
  slideTurn = 0x18,
  strafe = 0x1C,
  tilt1 = 0x24C,
  tilt2 = 0x254,
  tilt3 = 0x304,
  tilt4 = 0x30C,
  trackCollision = 0x588,
  turning1 = 0x10,
  turning2 = 0x14,
  turning3 = 0x20,
  turningAccel = 0x2C,
  turningDecel = 0x238,
  weight = 0x8,
  
  machineId = 0x6,
  machineName = 0x3C,
  posX = 0x7C,
  posY = 0x80,
  posZ = 0x84,
  velX = 0x94,
  velY = 0x98,
  velZ = 0x9C,
  kmh = 0x17C,
  energy = 0x184,
}

local valueTypes = {
  -- Only add an entry here if it's something other than a float.
  machineName = "string",
}

local maxStringLengthToRead = 64

local function readStateValue(address, key)
  if valueTypes[key] == "string" then
    return readString(address + values.o, maxStringLengthToRead)
  else
    -- float
    return readFloatBE(address + values.o, 4)
  end
end



local compute = {
    
  o = function()
    values.o = dolphin.getGameStartAddress()
  end,
  
  refPointer = function()
    -- Pointer that we'll use for reference.
    -- Not sure what this is meant to point to exactly, but when this pointer
    -- changes value, some other relevant addresses (like the settings
    -- slider value) move by the same amount as the value change.
    local address = 0x801B78A8
    values.refPointer = readIntBE(address + values.o, 4)
  end,
  
  machineStateBlockAddress = function()
    local pointerAddress = values.refPointer + 0x22779C
    values.machineStateBlockAddress = readIntBE(pointerAddress + values.o, 4)
  end,
  
  machineBaseStatsBlockAddress = function()
    local machineIdAddress = values.machineStateBlockAddress + stateBlockOffsets.machineId
    local machineId = readIntBE(machineIdAddress + values.o, 2)
    values.machineBaseStatsBlockAddress = 0x81554000 + (0xB4*machineId)
  end,
  
  baseStats = function(key)
    local address = values.machineBaseStatsBlockAddress + baseStatsBlockOffsets[key]
    values.baseStats[key] = readFloatBE(address + values.o, 4)
  end,
  
  state = function(key)
    local address = values.machineStateBlockAddress + stateBlockOffsets[key]
    values.state[key] = readStateValue(address, key)
  end,
  
  stateOfOtherMachine = function(key, machineIndex)
    local address = (values.machineStateBlockAddress
      + (0x620 * machineIndex)
      + stateBlockOffsets[key])
      
    if values.state[machineIndex] == nil then
      values.state[machineIndex] = {}
    end
    
    values.state[machineIndex][key] = readStateValue(address, key)
  end,
  
  kmh = function()
    -- This address has your km/h speed as displayed in-game on the
    -- *next* frame.
    -- There is no known address for the displayed speed on the current frame,
    -- but we can get that by just taking the previous km/h value.
    local address = values.machineStateBlockAddress + stateBlockOffsets.kmh
    
    values.currKmh = values.nextKmh
    values.nextKmh = readFloatBE(address + values.o, 4)
  end,
  
  numOfMachinesParticipating = function()
    local address = values.refPointer + 0x1BAEE0
    values.numOfMachinesParticipating = readIntBE(address + values.o, 1)
  end,
}



-- Displaying RAM values.

local keysToLabels = {
  accel = "Accel",
  body = "Body",
  boostDuration = "Boost duration",
  boostInterval = "Boost interval",
  cameraReorienting = "Cam. reorienting",
  cameraRepositioning = "Cam. repositioning",
  drag = "Drag",
  grip1 = "Grip 1",
  grip2 = "Grip 2",
  grip3 = "Grip 3",
  maxSpeed = "Max speed",
  obstacleCollision = "Obstacle collision",
  slideTurn = "Slide turn",
  strafe = "Strafe",
  tilt1 = "Tilt 1",
  tilt2 = "Tilt 2",
  tilt3 = "Tilt 3",
  tilt4 = "Tilt 4",
  trackCollision = "Track collision",
  turning1 = "Turning 1",
  turning2 = "Turning 2",
  turning3 = "Turning 3",
  turningAccel = "Turning accel",
  turningDecel = "Turning decel",
  weight = "Weight",
  
  energy = "Energy",
  currKmh = "km/h",
  nextKmh = "km/h (next)",
}

local getStr = {
  
  settingsSlider = function()
    -- Accel/max speed setting; 0 (full accel) to 100 (full max speed).
    local address = values.refPointer + 0x2453A0
    local settingsSlider = readIntBE(address + values.o, 4)
    
    return string.format("Settings: %d%%", settingsSlider)
  end,
  
  flt = function(key, precision)
    local label = keysToLabels[key]
    
    if values[key] == nil then
      return string.format("%s: nil", label)
    end
    
    return string.format("%s: %s", label, floatToStr(values[key], precision))
  end,
  
  baseStats = function(key, precision)
    -- A compute and getStr function rolled into one. This way our layout code
    -- only has to specify each kind of stat once, rather than in separate
    -- compute and getStr calls.
    compute.baseStats(key)
    local label = keysToLabels[key].." (B)"
    return string.format(
      "%s: %s",
      label,
      floatToStr(values.baseStats[key], precision)
    )
  end,
  
  state = function(key, precision)
    compute.state(key)
    local label = keysToLabels[key]
    return string.format(
      "%s: %s",
      label,
      floatToStr(values.state[key], precision)
    )
  end,
  
  stateOfOtherMachine = function(key, machineIndex, precision)
    local index = tonumber(machineIndex)
    if index == nil then return "nil" end
    index = math.floor(index)
  
    if index+1 > values.numOfMachinesParticipating then
      return string.format("Rival machine %d is N/A", index)
    end
    
    compute.stateOfOtherMachine(key, index)
    compute.stateOfOtherMachine("machineName", index)
    local label = (keysToLabels[key] .. ", "
                   .. tostring(values.state[index]["machineName"]))
    return string.format(
      "%s: %s",
      label,
      floatToStr(values.state[index][key], precision)
    )
  end,
}

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------



-- GUI layout specifications.

local label1 = nil
local statRecorder = {}

local layoutA = {
  
  init = function(window)
    -- Set the display window's size.
    window:setSize(300, 200)
  
    -- Add a blank label to the window at position (10,5). In the update
    -- function, which is called on every frame, we'll update the label text.
    label1 = initLabel(window, 10, 5, "")
    
    --shared.debugLabel = initLabel(window, 10, 160, "<debug>")
    
    statRecorder = StatRecorder:new(window, 90)
  end,
  
  update = function()
    compute.o()
    compute.refPointer()
    compute.machineStateBlockAddress()
    compute.kmh()
    label1:setCaption(
      table.concat(
        {
          getStr.settingsSlider(),
          getStr.flt("currKmh", 3),
        },
        "\n"
      )
    )
    
    if statRecorder.currentlyTakingStats then
      local s = floatToStr(values.currKmh, 6)
      statRecorder:takeStat(s)
    end
  end,
}

local layoutB = {
  
  init = function(window)
    window:setSize(400, 300)
  
    label1 = initLabel(window, 10, 5, "")
    
    --shared.debugLabel = initLabel(window, 10, 220, "")
  end,
  
  update = function()
    compute.o()
    compute.refPointer()
    compute.machineStateBlockAddress()
    compute.numOfMachinesParticipating()
    label1:setCaption(
      table.concat(
        {
          getStr.state("energy", 1),
          getStr.stateOfOtherMachine("energy", 1, 1),
          getStr.stateOfOtherMachine("energy", 2, 1),
          getStr.stateOfOtherMachine("energy", 3, 1),
          getStr.stateOfOtherMachine("energy", 4, 1),
          getStr.stateOfOtherMachine("energy", 5, 1),
        },
        "\n"
      )
    )
  end,
}

local layoutC = {
  
  init = function(window)
    window:setSize(300, 130)
  
    label1 = initLabel(window, 10, 5, "")
  end,
  
  update = function()
    compute.o()
    compute.refPointer()
    compute.machineStateBlockAddress()
    compute.machineBaseStatsBlockAddress()
    label1:setCaption(
      table.concat(
        {
          getStr.baseStats("tilt2", 3),
          getStr.state("tilt2", 3),
        },
        "\n"
      )
    )
  end,
}
  


-- Finally, one more layout that focuses on convenient
-- display and editing of stats.

local editableStats = {
  "accel", "body", "boostDuration", "boostInterval",
  "cameraReorienting", "cameraRepositioning", "drag",
  "grip1", "grip2", "grip3", "maxSpeed", "obstacleCollision",
  "slideTurn", "strafe", "tilt1", "tilt2", "tilt3", "tilt4", 
  "trackCollision", "turning1", "turning2", "turning3",
  "turningAccel", "turningDecel", "weight",
}
local checkBoxes = {}
local statsToDisplay = {}
local addToListButtons = {}

local function addStatAddressToList(key)
  local addressList = getAddressList()
  
  -- We'll actually add two entries: actual stat and base stat. The base stat
  -- is more convenient to edit. The actual stat needs disabling an instruction
  -- writing the address before it can be edited, but editing this avoids
  -- having to consider the base -> actual conversion math.
  
  -- First we'll add the actual stat.
  
  local memoryRecord = addressList:createMemoryRecord()
  local address = (
    values.machineStateBlockAddress + stateBlockOffsets[key] + values.o
  )
  -- setAddress doesn't work for some reason, despite being in the Help docs?
  memoryRecord.Address = utils.intToHexStr(address)
  memoryRecord:setDescription(keysToLabels[key])
  
  -- There don't seem to be any constants for memory record types...
  -- By trial and error, these are the types in Cheat Engine 6.3:
  -- 0 = Byte, 1 = 2 Bytes, 2 = 4 Bytes, 3 = 8 Bytes, 4 = Float, 5 = Double,
  -- 6 = String, 7 = Unicode String, 8 = Array of byte, 9 = Binary, 10 = All,
  -- 11 = (none, value <script>), 12 = Pointer, 13 = Custom (exact type is
  -- specified by CustomTypeName)
  memoryRecord.Type = 13
  memoryRecord.CustomTypeName = "Float Big Endian"
  
  -- Now the base stat.
  
  memoryRecord = addressList:createMemoryRecord()
  address = (
    values.machineBaseStatsBlockAddress + baseStatsBlockOffsets[key] + values.o
  )
  memoryRecord.Address = utils.intToHexStr(address)
  memoryRecord:setDescription(keysToLabels[key] .. " (base)")
  memoryRecord.Type = 13
  memoryRecord.CustomTypeName = "Float Big Endian"
end

local function rebuildStatsDisplay(window)
  statsToDisplay = {}
  
  -- Remove the previous buttons
  for _, button in pairs(addToListButtons) do
    button.destroy()
  end
  addToListButtons = {}
  
  for boxN, checkBox in pairs(checkBoxes) do
    if checkBox:getState() == 1 then
      -- Box is checked; include this stat in the display.
      
      -- Include the stat display
      local statKey = editableStats[boxN]
      table.insert(statsToDisplay, statKey)
  
      -- Include an add-to-address-list button, to facilitate
      -- editing the stat
      local button = createButton(window)
      local posY = 28*(#statsToDisplay - 1) + 5
      button:setPosition(250, posY)
      button:setCaption("List")
      local font = button:getFont()
      font:setSize(12)
      
      button:setOnClick(utils.curry(addStatAddressToList, statKey))
      
      table.insert(addToListButtons, button)
    end
  end
end

local layoutD = {
  
  init = function(window)
    window:setSize(550, 620)
  
    label1 = initLabel(window, 10, 5, "")
    local font = label1:getFont()
    font:setSize(14)
    
    -- Make a list of checkboxes, one for each possible stat to look at.

    local initiallyCheckedStats = {"accel", "maxSpeed", "weight"}
    -- Making sets in Lua is kind of roundabout.
    -- http://www.lua.org/pil/11.5.html
    local isStatInitiallyChecked = {}
    for _, key in pairs(initiallyCheckedStats) do
      isStatInitiallyChecked[key] = true
    end
    
    for statN, key in pairs(editableStats) do
      local checkBox = createCheckBox(window)
      local posY = 24*(statN-1) + 5
      checkBox:setPosition(350, posY)
      checkBox:setCaption(keysToLabels[key])
      
      local font = checkBox:getFont()
      font:setSize(10)
      
      -- When a checkbox is checked, the corresponding stat is displayed.
      checkBox:setOnChange(utils.curry(rebuildStatsDisplay, window))
      
      if isStatInitiallyChecked[key] then
        checkBox:setState(1)
      end
      
      table.insert(checkBoxes, checkBox)
    end
    
    -- Ensure that the initially checked stats actually get initially checked.
    rebuildStatsDisplay(window)
    
    shared.debugLabel = initLabel(window, 10, 500, "")
  end,
  
  update = function()
    compute.o()
    compute.refPointer()
    compute.machineStateBlockAddress()
    compute.machineBaseStatsBlockAddress()
    
    local statLines = {}
    for statN, key in pairs(statsToDisplay) do
      local line = getStr.state(key, 3)
      table.insert(statLines, line)
    end
    label1:setCaption(table.concat(statLines, "\n"))
  end,
}



-- *** CHOOSE YOUR LAYOUT HERE ***
local layout = layoutA



-- Initializing the GUI window.

local window = createForm(true)
-- Put it in the center of the screen.
window:centerScreen()
-- Set the window title.
window:setCaption("RAM Display")
-- Customize the font.
local font = window:getFont()
font:setName("Calibri")
font:setSize(16)

layout.init(window)

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------



-- This sets a breakpoint at a particular instruction which should be
-- called exactly once every frame.

debug_removeBreakpoint(getAddress("Dolphin.exe")+dolphin.oncePerFrameAddress)
debug_setBreakpoint(getAddress("Dolphin.exe")+dolphin.oncePerFrameAddress)

-- If the oncePerFrameAddress was chosen correctly, everything in the
-- following function should run exactly once every frame. 

function debugger_onBreakpoint()
  
  layout.update()

  return 1

end

