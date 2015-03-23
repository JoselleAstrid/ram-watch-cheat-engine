-- Dolphin emulator related code and configuration.



-- CONFIGURATION

--------------------
-- (1) frameCounterAddress and oncePerFrameAddress.
-- 
-- REQUIRED for some layouts, OPTIONAL for other layouts.
-- Information on setting these variables (and whether you need to):
-- https://github.com/yoshifan/ram-watch-cheat-engine/wiki/Finding-frameCounterAddress-and-oncePerFrameAddress

local frameCounterAddress = nil
local oncePerFrameAddress = nil

--------------------

-- (2) constantGameStartAddress
--
-- OPTIONAL.
-- Normally, right after clicking Execute Script, there is a slow-ish scan
-- to find the game start address. This scan will happen as long as
-- constantGameStartAddress is nil (default).
--
-- If you're bothered by the slowness of the initial scan, and you KNOW the
-- game start address for your version of Dolphin, you can set that as
-- constantGameStartAddress below. This way the slow scan will be skipped.
--
-- You might also use constantGameStartAddress if the scan just doesn't get
-- the correct address for your Dolphin version (always a possibility...
-- the address scheme has changed at least twice over the Dolphin versions
-- I've tested).
--
-- Tips:
-- - If your version is 3.5-0 to 4.0-4191 (roughly), 0xFFFF0000 should work.
-- However, versions before 3.5-2302 (roughly) will only work this way if
-- it's the first time you've run a game since starting Dolphin. If you close
-- a game and start it up again, this address will move!
-- - Starting around 4.0-4808 (roughly) the working address seems to be
-- 0x2FFFF0000.

local constantGameStartAddress = nil

--------------------

-- End of CONFIGURATION

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------


-- Imports.

-- De-cache if we're re-running the script.
package.loaded.utils = nil

local utils = require "utils"

local readIntLE = utils.readIntLE
  
  

local function getGameStartAddress(gameId)
  if constantGameStartAddress then
    return constantGameStartAddress
  else
    local memScan = createMemScan()
    memScan.firstScan(
      soExactValue,  -- scan option
      vtString,  -- variable type
      0,  -- rounding type
      gameId,  -- value to scan for
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
        gameId, gameId
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
        gameId, allFoundAddressesStr
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
end



local timer = nil
local timerFunction = nil
local frameCount = nil
local updateOK = true

local function updateFrameCount()
  frameCount = utils.readIntLE(getAddress("Dolphin.exe")+frameCounterAddress)
end

local function getFrameCount()
  -- This function lets game-specific modules get the Dolphin frame count.
  -- 
  if not frameCounterAddress then
    error("This layout uses the Dolphin frame counter, so you need to set"
          .." frameCounterAddress in dolphin.lua to make it work.")
  end
  return frameCount
end

local function setupDisplayUpdates(
  updateMethod, updateFunction, window, timerInterval, updateButton)
  
  -- updateMethod
  --   string representing the update method.
  -- updateFunction
  --   to be called here whenever an update is needed.
  -- window
  --   if updateMethod is "timer", this is required so that we
  --   can assign window to be the timer's parent object.
  -- timerInterval
  --   if updateMethod is "timer", this is the number
  --   of milliseconds to wait till the next update.
  -- updateButton
  --   if updateMethod is "button", this is the button
  --   that you'd click to update the display.

  -- Clean up from previous runs of the script 
  if oncePerFrameAddress then
    debug_removeBreakpoint(getAddress("Dolphin.exe")+oncePerFrameAddress)
  end
  
  if updateMethod == "timer" then
  
    -- Set the window to be the timer's parent, so that when the window is
    -- closed, the timer will stop being called. This allows us to edit and then
    -- re-run the script, and then close the old window to stop previous timer
    -- loops.
    timer = createTimer(window)
    -- Time interval at which we'll periodically call a function.
    timer.setInterval(timerInterval)
    
    timerFunction = function()
      if not updateOK then
        -- The previous update call must've gotten an error before
        -- finishing. Stop calling the update function to prevent it
        -- from continually getting errors from here.
        timer.destroy()
        return
      end
      
      updateOK = false
    
      if frameCounterAddress then
        -- Only update if the game has advanced at least one frame. This way we
        -- can pause emulation and let the game stay paused without wasting too
        -- much CPU.
        local lastUpdateCheckFrame = frameCount
        updateFrameCount()
        
        if lastUpdateCheckFrame ~= frameCount then
          updateFunction()
        end
      else
        -- If we have no way to count frames, then just update
        -- no matter what.
        updateFunction()
      end
      
      updateOK = true
    end
    
    -- Start calling this function periodically.
    timer.setOnTimer(timerFunction)
  
  elseif updateMethod == "breakpoint" then
  
    if oncePerFrameAddress == nil then
      error("This layout uses breakpoint updates, so you need to set"
            .." oncePerFrameAddress in dolphin.lua to make it work.")
    end
  
    -- This sets a breakpoint at a particular Dolphin instruction which
    -- should be called exactly once every frame.
    debug_setBreakpoint(getAddress("Dolphin.exe")+oncePerFrameAddress)
    
    -- If the oncePerFrameAddress was chosen correctly, the
    -- following function should run exactly once every frame.
    function debugger_onBreakpoint()
      -- Check if the previous update call got an error. If so, stop calling
      -- the update function so the user isn't bombarded with errors
      -- once per frame.
      if not updateOK then return 1 end
    
      updateOK = false
    
      if frameCounterAddress then
        -- Update the frameCount in case the layout's update code is using it.
        updateFrameCount()
      end
      
      updateFunction()
      
      updateOK = true
      
      return 1
    end
    
  elseif updateMethod == "button" then
    
    -- First do an initial update.
    updateFunction()
    -- Set the update function to run when the update button is clicked.
    updateButton:setOnClick(updateFunction)
  
  end
end



return {
  frameCounterAddress = frameCounterAddress,
  oncePerFrameAddress = oncePerFrameAddress,
  
  getGameStartAddress = getGameStartAddress,
  getFrameCount = getFrameCount,
  setupDisplayUpdates = setupDisplayUpdates,
}
