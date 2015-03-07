-- Dolphin emulator related code.



-- (Configuration: MAY BE OPTIONAL depending on what you want)

--------------------
-- (1) frameCounterAddress and oncePerFrameAddress.
-- 
-- These variables are memory addresses that depend on the exact
-- Dolphin version, which is why you have to find/configure them yourself.

-- Each variable enables some optional functionality:
--
-- frameCounterAddress
-- If your Lua script is refreshed based on a Cheat
-- Engine timer, defining this lets you reduce CPU usage when emulation
-- is paused or running slowly.
--
-- oncePerFrameAddress
-- Defining this is needed if your Lua script is
-- refreshed on a breakpoint. Using breakpoints ensures that the Lua script
-- refreshes exactly once per game frame, but breakpoints also hurt
-- emulation performance.

-- How to find the addresses:
--
-- Start your game in Dolphin, then pause the emulation. Now in Cheat Engine,
-- start a new scan with a Scan Type of "Unknown initial value", and a Value
-- Type of "4 Bytes". You shouldn't see any scan results yet; that's normal.
--
-- Now go to Dolphin and advance your game by 5 frames. Go back to
-- Cheat Engine, change the Scan Type to "Increased value by ...", type 5
-- in the Value box, and click Next Scan. Repeat this process a couple
-- more times, possibly using larger numbers of frames as well. Eventually the
-- results should be narrowed down a fair bit.
--
-- Now pick an address from the results list. Try to get a green address, as
-- that is a static address which should not change as long as you're using
-- the same Dolphin version. Double-click this address to add it to the bottom
-- box.
--
-- Right-click that entry and choose "Disassemble this memory region".
-- Look near the top of the Memory Viewer dialog and you should see
-- "Dolphin.exe+" followed by a hex address. Use that hex address as the
-- *frameCounterAddress*. (If you don't see Dolphin.exe, but rather some kind
-- of DLL, try a different address from the scan you did previously.)
--
-- If you can't fully read the hex address because the bottom is cut off,
-- look back at the previous dialog; the first thing in the "Instruction"
-- column is a hex address. Hopefully, the last 5 digits of this
-- address should match the last 5 digits of the frameCounterAddress!
--
-- Now, close the memory viewer and then double-click the address to add it
-- to the bottom box. Right-click the address in the bottom box, and choose
-- "Find out what writes to this address". Choose Yes if you get a
-- Confirmation dialog.
--
-- Now advance your Dolphin game by 5 frames again. Hopefully an entry will
-- appear in the dialog that just popped up, with the number 5 in the Count
-- column (if not, try a different address). Click the Stop button.
--
-- Right-click that entry and choose "Show this address in the disassembler".
-- Again, look at the top of the dialog to find "Dolphin.exe+" followed by a
-- hex address. Use that hex address as the *oncePerFrameAddress*.

-- Since addresses are written in hex, make sure you have the "0x"
-- before the actual number.
--
-- Example values:
-- Dolphin 4.0-2826:
-- local frameCounterAddress = 0x00C18D88
-- local oncePerFrameAddress = 0x004AD770
-- Dolphin 4.0-4191:
-- local frameCounterAddress = 0x00C3C838
-- local oncePerFrameAddress = 0x004AD2DB

local frameCounterAddress = nil
local oncePerFrameAddress = nil

--------------------

-- (2) constantGameStartAddress
--
-- Set to nil (default) to use a safe but slow-ish scan for gameStartAddress.
-- It's only slow when you first Execute your script; once it's
-- running, that's not an issue anymore.
-- 
-- If you're bothered by the slowness of executing the script, you can set
-- this to a constant address number if you KNOW that's the game start address.
-- This way the slow scan will be skipped.
-- Of course, you might also use this if the scan just gives you the wrong
-- address for your Dolphin version (always a possibility).
--
-- Tips:
-- - If your version is 3.5-0 to 4.0-4191 (roughly), 0xFFFF0000 should work.
-- However, versions before 3.5-2302 (roughly) will only work this way if
-- it's the first time you've run a game since starting Dolphin. If you close
-- a game and start it up again, this address will move!
-- - Starting around 4.0-5702 (roughly) the working address seems to be
-- 0x2FFFF0000.

local constantGameStartAddress = nil

--------------------

-- If you've set up the above values, you're done setting up this
-- script for your version of Dolphin! The next step is to make (or modify)
-- a game-specific script to suit your needs.

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
    
    -- The game start address we want should be the 3rd-to-last scan result
    -- ending in 0000.
    -- This means the result whose address is 2nd-last numerically. For some
    -- reason, doing a scan with Lua always gives a final scan result of 00000000.
    -- Other than that, the results are in numerical order of address.
    --
    -- In Dolphin, there's always 3 or 4 copies of each variable in game memory.
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
local frameCount = 0
local updateOK = true

local function getFrameCount()
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
        local newFrameCount = utils.readIntLE(
          getAddress("Dolphin.exe")+frameCounterAddress
        )
        
        if newFrameCount > frameCount then
          updateFunction()
          frameCount = newFrameCount
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
