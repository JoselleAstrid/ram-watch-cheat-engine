-- Base class for games running in Dolphin emulator.



-- Imports.

package.loaded.utils = nil
local utils = require 'utils'
local readIntLE = utils.readIntLE
local subclass = utils.subclass
package.loaded.valuetypes = nil
local valuetypes = require 'valuetypes'
local MemoryValue = valuetypes.MemoryValue
package.loaded.game = nil
local gameModule = require 'game'



local DolphinGame = subclass(gameModule.Game)
DolphinGame.exeName = 'Dolphin.exe'

function DolphinGame:init(options)
  if not options.gameVersion then error("Must provide a gameVersion.") end

  local version = string.lower(options.gameVersion)
  self.gameId = self.supportedGameVersions[version]
  if not self.gameId then
    error("gameVersion not supported: " .. options.gameVersion)
  end

  if options.frameCounterAddress then
    self.frameCounterAddress =
      getAddress(self.exeName) + options.frameCounterAddress
  end
  if options.oncePerFrameAddress then
    self.oncePerFrameAddress =
      getAddress(self.exeName) + options.oncePerFrameAddress
  end

  self.constantGameStartAddress =
    options.constantGameStartAddress or nil

  gameModule.Game.init(self, options)

  -- Subclasses of DolphinGame must set a gameId attribute in their init().
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



return {
  DolphinGame = DolphinGame,
}
