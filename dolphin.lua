-- Follow steps (1) through (5) below to set up this script
-- for your version of Dolphin.




-- (1) Specify your Dolphin version here.

-- If you use a version of Dolphin listed here (recommended if you want to
-- set up this script as easily as possible), uncomment the line for that
-- version, and comment out the rest of the version lines. Then you're good
-- to go; you can ignore the rest of the steps!

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
local dolphinVersion = "4.0-4191"
--------------------



-- The following variables are memory addresses that depend on the Dolphin
-- version. Since addresses are written in hex, make sure you have the "0x"
-- before the actual number.



--------------------
-- (2) Follow this: http://tasvideos.org/forum/t/13462 tutorial to get a
-- "pointerscan result". Doubleclick on the Address column and enter the address
-- after the ' "Dolphin.exe"+ ' (don't forget the 0x).
--
-- If this address doesn't work consistently, follow the tutorial again
-- and try picking a different address. 

local gameRAMStartPointerAddress = nil
if dolphinVersion == "3.5-2302-x64" then
  gameRAMStartPointerAddress = 0x04961818
elseif dolphinVersion == "4.0-2826" then
  gameRAMStartPointerAddress = 0x00D1EBC8
elseif dolphinVersion == "4.0-4191" then
  gameRAMStartPointerAddress = 0x00BD6710
end
--------------------

--------------------
-- (3) Next, we want to find a Dolphin instruction that is run exactly once per
-- frame. Depending on your version of Dolphin, there's a harder or easier way
-- to do this.

-- 3A. Harder way that should work in any Dolphin version, including 4.0-2826:
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
-- box. Then right-click the address in the bottom box and choose "Find out
-- what writes to this address". Choose Yes if you get a Confirmation dialog.
--
-- Now advance your Dolphin game by 5 frames again. Hopefully an entry will
-- appear in the dialog that just popped up, with the number 5 in the Count
-- column (if not, try a different address). Click the Stop button.
--
-- Right-click that entry and choose "Show this address in the disassembler".
-- Look near the top of the Memory Viewer dialog and you should see
-- "Dolphin.exe+" followed by a hex address. Use that hex address as the
-- oncePerFrameAddress. (If you don't see Dolphin.exe, but rather some kind
-- of DLL, try a different address from the scan you did previously.)
--
-- If you can't fully read the hex address because the bottom is cut off,
-- look back at the previous dialog; the first thing in the "Instruction"
-- column is a hex address. Hopefully, the last 5 digits of this
-- address should match the last 5 digits of the oncePerFrameAddress!

-- 3B. Easier way that works in earlier versions such as Dolphin 3.5-2302:
--
-- Set the Value Type to "Array of byte" and uncheck "Writable" under Memory
-- Scan Options. Make sure the "Hex" box is checked and search for:
--
-- 48 63 D8 48 03 DF 48 83 7D C0 10
-- if you have 64 bit Dolphin
--
-- 83 C4 0C 83 7C 24 1C 10 8D 3C 06
-- if you have 32 bit Dolphin
--
-- There should be one result, right-click that result and click "Disassemble
-- this memory region". Enter the number after the "Dolphin.exe+" at the top.
--
-- Make sure to check "Writable" again, and really check it, because it has
-- three states.

local oncePerFrameAddress = nil
if dolphinVersion == "3.5-2302-x64" then
  oncePerFrameAddress = 0x00425671
elseif dolphinVersion == "4.0-2826" then
  oncePerFrameAddress = 0x004AD770
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
  --
  -- Example value: In Dolphin 3.5-2302 x64 and many 4.0 versions,
  -- this is usually 0x7FFF0000.
  
  return readIntLE(getAddress("Dolphin.exe")+gameRAMStartPointerAddress, 4)
end



return {
  oncePerFrameAddress = oncePerFrameAddress,
  
  getGameStartAddress = getGameStartAddress,
}
