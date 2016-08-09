-- Base code for games running in Dolphin emulator.



-- Imports.

package.loaded.utils = nil
local utils = require 'utils'
local readIntLE = utils.readIntLE
local subclass = utils.subclass
package.loaded.valuetypes = nil
local vtypes = require 'valuetypes'
local MemoryValue = vtypes.MemoryValue



local DolphinGame = {
  valuesToInitialize = {},
}

function DolphinGame:init(options)
  self.gameVersion =
    options.gameVersion or error("Must provide a gameVersion.")
    
  self.frameCounterAddress =
    options.frameCounterAddress or nil
  self.oncePerFrameAddress =
    options.oncePerFrameAddress or nil
  self.constantGameStartAddress =
    options.constantGameStartAddress or nil
  
  for _, value in pairs(self.valuesToInitialize) do
    value.obj.game = self
    value.initCallable()
  end
    
  -- Subclasses of DolphinGame must set a gameId attribute in their init().
end


-- Like classInstantiate(), except the game attribute is set
-- before init() is called.
-- If the Game object isn't initialized yet, use VDeferredInit() instead.
function DolphinGame:V(ValueClass, ...)
  local newValue = subclass(ValueClass)
  newValue.game = self
  newValue:init(...)
  return newValue
end


-- Create Values which are initialized after <value>.game is set.
function DolphinGame:VDeferredInit(ValueClass, ...)
  local newValue = subclass(ValueClass)
  local initCallable = utils.curry(ValueClass.init, newValue, ...)
  
  -- Save the object in a table.
  -- Later, when we have an initialized Game object,
  -- we'll iterate over this table, set the game attribute for each object,
  -- and call init() on each object.
  table.insert(
    self.valuesToInitialize, {obj=newValue, initCallable=initCallable})
  
  return newValue
end


-- Create MemoryValues which are initialized after <value>.game is set.
--
-- Creation isn't entirely straightforward because we want
-- MemoryValue instances to be a mixin of multiple classes.
function DolphinGame:MVDeferredInit(
    label, offset, mvClass, typeMixin, extraArgs)
  local newMV = subclass(mvClass, typeMixin)
  
  local function f(newMV_, label_, offset_, mvClass_, typeMixin_, extraArgs_)
    mvClass_.init(newMV_, label_, offset_)
    typeMixin_.init(newMV_, extraArgs_)
  end
  
  local initCallable = utils.curry(
    f, newMV, label, offset, mvClass, typeMixin, extraArgs)
  
  -- Save the object in a table.
  -- Later, when we have an initialized Game object,
  -- we'll iterate over this table, set the game attribute for each object,
  -- and call init() on each object.
  table.insert(
    self.valuesToInitialize, {obj=newMV, initCallable=initCallable})
    
  return newMV
end


function DolphinGame:getGameStartAddress()
  if self.constantGameStartAddress then
    return self.constantGameStartAddress
  end
    
  if self.gameId == nil then
    error("The game script must provide a gameId.")
  end
  
  local memScan = createMemScan()
  memScan.firstScan(
    soExactValue,  -- scan option
    vtString,  -- variable type
    0,  -- rounding type
    self.gameId,  -- value to scan for
    "",  -- input2 (only used for certain scan options)
    0x0, 0xFFFFFFFFFFFFFFFF,  -- first and last address to look through
    "*X-C+W",  -- protection flags
    fsmNotAligned,  -- alignment type; not needed if units are 1 byte
    "1",  -- alignment param (only used if the above is NOT fsmNotAligned)
    false,  -- is hexadecimal input
    false,  -- is not a binary string
    false,  -- is unicode scan
    true  -- is case sensitive
  )
  memScan.waitTillDone()
  local foundList = createFoundList(memScan)
  foundList.initialize()
  
  local addrsEndingIn0000 = {}
  for n = 1, foundList.Count do
    local address = foundList.Address[n]
    if string.sub(address, -4) == "0000" then
      table.insert(addrsEndingIn0000, address)
    end
  end
  
  -- For some reason, doing a scan with Lua always gives a final scan result
  -- of 00000000. Even if there are no other results.
  -- So we check for no actual results with <= 1.
  if foundList.Count <= 1 then
    -- For any newline we also have 2 spaces before it, because the Lua
    -- Engine eats newlines for any errors after the first one.
    local s = string.format(
        "Couldn't find the expected game ID (%s) in memory."
      .." Please confirm that:"
      .."  \n1. Your game's ID matches what the script expects (%s)."
      .." To check this, right-click the game in the Dolphin game list,"
      .." select Properties, and check the title bar of the pop-up window."
      .." If it doesn't match, you may have the wrong game version."
      .."  \n2. In Cheat Engine's Edit menu, Settings, Scan Settings, you"
      .." have MEM_MAPPED checked.",
      self.gameId, self.gameId
    )
    error(s)
  elseif #addrsEndingIn0000 < 3 then
    local foundAddressStrs = {}
    for n = 1, foundList.Count do
      local address = foundList.Address[n]
      table.insert(foundAddressStrs, "0x"..address)
    end
    local allFoundAddressesStr = table.concat(foundAddressStrs, "  \n")
    
    local s = string.format(
        "Couldn't find the game ID (%s) in a usable memory location."
      .." Please confirm that:"
      .."  \n1. The Dolphin game is already running when you execute"
      .." this script. "
      .."  \n2. In Cheat Engine's Edit menu, Settings, Scan Settings, you"
      .." have MEM_MAPPED checked."
      .."  \n3. You are using 64-bit Dolphin. This Lua script currently doesn't"
      .." support 32-bit."
      .."  \nFYI, these are the scan results:"
      .."  \n%s",
      self.gameId, allFoundAddressesStr
    )
    error(s)
  end
  
  -- The game start address we want should be the 2nd-last actual scan
  -- result ending in 0000.
  -- Again, due to the 00000000 non-result at the end, we actually look at
  -- the 3rd-last item.
  --
  -- In 64-bit Dolphin, there's always 3 or 4 copies of each variable in
  -- game memory.
  -- The 2nd-last copy is the only one that shows results when you right-click
  -- and select "find out what writes to this address". Sometimes the 2nd-last
  -- copy is also the only one where something happens if you manually edit it.
  -- So it seems to be the most useful copy, which is why we use it.
  foundList.destroy()
  return tonumber("0x"..addrsEndingIn0000[#addrsEndingIn0000 - 2])
end



function DolphinGame:updateFrameCount()
  self.frameCount = utils.readIntLE(
    getAddress("Dolphin.exe")+self.frameCounterAddress)
end

function DolphinGame:getFrameCount()
  -- This function lets game-specific modules get the Dolphin frame count.
  -- 
  if not self.frameCounterAddress then
    error("Must provide a frameCounterAddress, because this layout uses"
      .." the Dolphin frame counter.")
  end
  return self.frameCount
end

function DolphinGame:startUpdating(layout)
  -- Clean up from previous runs of the script 
  if self.oncePerFrameAddress then
    debug_removeBreakpoint(
      getAddress("Dolphin.exe")+self.oncePerFrameAddress)
  end
  
  self.updateOK = true
  
  if layout.updateMethod == "timer" then
  
    -- Set the window to be the timer's parent, so that when the window is
    -- closed, the timer will stop being called. This allows us to edit and then
    -- re-run the script, and then close the old window to stop previous timer
    -- loops.
    self.timer = createTimer(layout.window)
    -- Time interval at which we'll periodically call a function.
    self.timer.setInterval(layout.updateTimeInterval)
    
    local function timerFunction(game)
      if not game.updateOK then
        -- The previous update call must've gotten an error before
        -- finishing. Stop calling the update function to prevent it
        -- from continually getting errors from here.
        self.timer.destroy()
        return
      end
      
      game.updateOK = false
    
      if game.frameCounterAddress then
        -- Only update if the game has advanced at least one frame. This way we
        -- can pause emulation and let the game stay paused without wasting too
        -- much CPU.
        local lastUpdateCheckFrame = game.frameCount
        game:updateFrameCount()
        
        if lastUpdateCheckFrame ~= game.frameCount then
          layout:update()
        end
      else
        -- If we have no way to count frames, then just update
        -- no matter what.
        layout:update()
      end
      
      game.updateOK = true
    end
    
    -- Start calling this function periodically.
    self.timer.setOnTimer(utils.curry(timerFunction, self))
  
  elseif layout.updateMethod == "breakpoint" then
  
    if self.oncePerFrameAddress == nil then
      error("Must provide a oncePerFrameAddress, because this layout uses"
        .." breakpoint updates.")
    end
  
    -- This sets a breakpoint at a particular Dolphin instruction which
    -- should be called exactly once every frame.
    debug_setBreakpoint(
      getAddress("Dolphin.exe")+self.oncePerFrameAddress)
    
    -- If the oncePerFrameAddress was chosen correctly, the
    -- following function should run exactly once every frame.
    local function runOncePerFrame(game)
      -- Check if the previous update call got an error. If so, stop calling
      -- the update function so the user isn't bombarded with errors
      -- once per frame.
      if not game.updateOK then return 1 end
    
      game.updateOK = false
    
      if game.frameCounterAddress then
        -- Update the frameCount in case the layout's update code is using it.
        game:updateFrameCount()
      end
      
      layout:update()
      
      game.updateOK = true
      
      return 1
    end
    debugger_onBreakpoint = utils.curry(runOncePerFrame, self)
    
  elseif layout.updateMethod == "button" then
    
    -- First do an initial update.
    layout:update()
    -- Set the update function to run when the update button is clicked.
    layout.updateButton:setOnClick(layout.updateFunction)
  
  end
end



return {
  DolphinGame = DolphinGame,
}
