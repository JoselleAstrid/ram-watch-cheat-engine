-- Metroid Prime
-- US version 1.00
local gameId = "GM8E01"

-- This is a sample script that is simpler and less structured than the other
-- game scripts (F-Zero GX, Super Mario Galaxy, etc.).
-- It's meant to be a little easier to follow for those new to Lua.

-- If you have a lot of possible RAM values you might want to look at, or
-- a lot of different layouts with code overlap, consider looking at the
-- other game scripts for ideas on making things more structured. 



-- Imports.

-- First we make sure that the imported modules get de-cached as needed, since
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



-- Here's the memory address where the game's memory begins.
local o = dolphin.getGameStartAddress(gameId)



-- GUI layout specifications.

local mainLabel = nil
local statRecorder = {}

local updateMethod = nil
local updateTimeInterval = nil
local updateButton = nil

local layoutA = {
  
  init = function(window)
    -- This function will get called once at the beginning,
    -- to initialize things.
    
    -- We'll have the display refresh every time a time interval has passed.
    -- Other options are "breakpoint" (refresh on every game frame) and
    -- "button" (refresh when a button is clicked).
    -- Note: this update-method stuff is only built in for Dolphin. If it's
    -- another emulator/PC game, then you will have to figure out how to get
    -- "breakpoint" updates working yourself.
    updateMethod = "timer"
    -- The time interval will be 0.033 seconds, so it'll try to refresh
    -- about 30 times per second.
    updateTimeInterval = 33
  
    -- Set the display window's size.
    window:setSize(400, 80)
  
    -- Add a blank label to the window at position x=10, y=5. In the update
    -- function, which is called on every frame, we'll update the label text.
    mainLabel = initLabel(window, 10, 5, "")
  end,
  
  update = function()
    -- This function will get called once per frame.
  
    -- Get the RAM values for Samus's position.
    local posX = readFloatBE(o + 0x46B9BC, 4)
    local posY = readFloatBE(o + 0x46B9CC, 4)
    local posZ = readFloatBE(o + 0x46B9DC, 4)
    
    -- Display the position values on the Cheat Engine window's label.
    -- The "1" passed into floatToStr tells it to display one decimal place.
    mainLabel:setCaption(
      "Pos: " .. floatToStr(posX, 1)
      .. " | " .. floatToStr(posY, 1)
      .. " | " .. floatToStr(posZ, 1)
    )
  end,
}


local layoutB = {
  
  init = function(window)
    updateMethod = "timer"
    updateTimeInterval = 33
    
    window:setSize(300, 130)
  
    mainLabel = initLabel(window, 10, 5, "")
    
    -- Set up GUI elements for recording stats to a file. Put the GUI
    -- elements at y position 90.
    statRecorder = StatRecorder:new(window, 90)
  end,
  
  update = function()
    -- Get the RAM values for Samus's X and Y velocity.
    local velX = readFloatBE(o + 0x46BAB4, 4)
    local velY = readFloatBE(o + 0x46BAB8, 4)
    
    -- Compute Samus's speed in the XY plane.
    local speedXY = math.sqrt(velX*velX + velY*velY)
    
    -- Display the speed.
    mainLabel:setCaption(
      "XY Speed: " .. floatToStr(speedXY)
    )
    
    -- Additionally, record the speed stats to a text file, one text line per
    -- number.
    --
    -- This file will be called "stats.txt", and will be in one of two places:
    -- (A) The same directory as the cheat table you have open.
    -- (B) The same directory as the Cheat Engine .exe file, if you don't
    --     have a cheat table open.
    --
    -- For example, if the stat recording goes for 10 seconds (600
    -- frames), then stats.txt will have 600 lines like:
    -- 8.83
    -- 9.16
    -- 9.43
    -- (etc.)
    if statRecorder.currentlyTakingStats then
      local s = floatToStr(speedXY, 2)
      statRecorder:takeStat(s)
    end
  end,
}



-- *** CHOOSE YOUR LAYOUT HERE ***

-- To switch between GUI layouts, just change this one line. If you want
-- layoutB, then this line should read "local layout = layoutB".
-- Then in the "Lua script: Cheat Table" dialog, click "Execute script" again.

local layout = layoutA



-- Initializing and customizing the GUI window.

local window = createForm(true)

-- Put it in the center of the screen.
-- Alternatively you can use something like: window:setPosition(100, 300) 
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


dolphin.setupDisplayUpdates(
  updateMethod, layout.update, window, updateTimeInterval, updateButton)

