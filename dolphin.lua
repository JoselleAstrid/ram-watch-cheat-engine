-- Follow steps (1) through (5) below to set up this script
-- for your version of Dolphin.




-- (1) Specify your Dolphin version here. Changing this is OPTIONAL if you
-- are using a version that makes step 2 unnecessary, and if you also
-- don't need step 3.

-- If you use a specific version of Dolphin listed here, uncomment the line
-- for that version, and comment out the rest of the version lines.
-- Then you're good to go; you can ignore the rest of the steps!

-- If you use a different version of Dolphin, add a line for your Dolphin
-- version here, and uncomment the rest of the version lines.
-- Then, below, follow the instructions to get gameRAMStartPointerAddress and
-- oncePerFrameAddress; and for each of these, add an elseif clause for your
-- Dolphin version.

-- A line is "commented out" if it has two dashes at the start. This means
-- the Lua engine will ignore the line. If you are looking at this script
-- in Cheat Engine, make sure you have View -> Syntax Highlighting checked,
-- and the comments should show with a gray color and italics.
-- To "uncomment" a commented-out line, just remove the two dashes from the
-- start of the line.

--local dolphinVersion = "3.5-2302-x64"
--local dolphinVersion = "4.0-2826"
--local dolphinVersion = "4.0-3599"
--local dolphinVersion = "4.0-4191"
local dolphinVersion = "4.x"
--------------------



-- The following variables are memory addresses that depend on the Dolphin
-- version. Since addresses are written in hex, make sure you have the "0x"
-- before the actual number.



--------------------
-- (2) Find a pointer to the address that has the game RAM's start location.
-- This is OPTIONAL if you are using a Dolphin version whose game
-- start address is always 0x7FFF0000. This should include any version 4.0 or
-- higher, and even some later 3.x versions.
--
-- Follow this: http://tasvideos.org/forum/t/13462 tutorial to get a
-- "pointerscan result". Doubleclick on the Address column and enter the address
-- after the ' "Dolphin.exe"+ ' (don't forget the 0x).
--
-- If this address doesn't work consistently, follow the tutorial again
-- and try picking a different address.

local gameRAMStartPointerAddress = nil
if dolphinVersion == "3.5-2302-x64" then
  gameRAMStartPointerAddress = 0x04961818
end
--------------------

--------------------
-- (3) This step is about defining frameCounterAddress and oncePerFrameAddress.
-- These are OPTIONAL depending on what Lua script functions you are
-- interested in:

-- frameCounterAddress
-- If your Lua script is refreshed based on a Cheat
-- Engine timer, defining this lets you reduce CPU usage when emulation
-- is paused or running slowly.

-- oncePerFrameAddress
-- Defining this is needed if your Lua script is
-- refreshed on a breakpoint. Using breakpoints ensures that the Lua script
-- refreshes exactly once per game frame, but breakpoints also hurt
-- emulation performance.

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

local frameCounterAddress = nil
if dolphinVersion == "3.5-2302-x64" then
  -- TODO
  frameCounterAddress = nil
elseif dolphinVersion == "4.0-2826" then
  frameCounterAddress = 0x00C18D88
elseif dolphinVersion == "4.0-3599" then
  frameCounterAddress = 0x00C30198
elseif dolphinVersion == "4.0-4191" then
  frameCounterAddress = 0x00C3C838
end

local oncePerFrameAddress = nil
if dolphinVersion == "3.5-2302-x64" then
  oncePerFrameAddress = 0x00425671
elseif dolphinVersion == "4.0-2826" then
  oncePerFrameAddress = 0x004AD770
elseif dolphinVersion == "4.0-3599" then
  oncePerFrameAddress = 0x004A683B
elseif dolphinVersion == "4.0-4191" then
  oncePerFrameAddress = 0x004AD2DB
end
--------------------

-- If you got this far, you're done setting up the script for your
-- version of Dolphin! The next step is to make (or modify) a game-specific
-- script to suit your needs.

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------


-- Imports.

-- De-cache if we're re-running the script.
package.loaded.utils = nil

local utils = require "utils"

local readIntLE = utils.readIntLE




local function getGameStartAddress()
  -- Get the game's start address. We'll use this as a base for all
  -- other addresses.
  if gameRAMStartPointerAddress == nil then
    return 0x7FFF0000
  end
  
  return readIntLE(getAddress("Dolphin.exe")+gameRAMStartPointerAddress, 4)
end



return {
  frameCounterAddress = frameCounterAddress,
  oncePerFrameAddress = oncePerFrameAddress,
  
  getGameStartAddress = getGameStartAddress,
}
