-- Base class for a game.



-- Imports.

package.loaded.utils = nil
local utils = require 'utils'
local readIntLE = utils.readIntLE
local subclass = utils.subclass
package.loaded.valuetypes = nil
local valuetypes = require 'valuetypes'
local MemoryValue = valuetypes.MemoryValue



local Game = subclass(valuetypes.Block)
Game.blockAlias = 'game'
Game.exeName = nil

function Game:init(options)
  if not self.exeName then
    error("This game doesn't have an exeName specified.")
  end
  
  if options.frameCounterAddress then
    self.frameCounterAddress =
      getAddress(self.exeName) + options.frameCounterAddress
  end
  if options.oncePerFrameAddress then
    self.oncePerFrameAddress =
      getAddress(self.exeName) + options.oncePerFrameAddress
  end
    
  valuetypes.Block.init(self)
end

function Game:getBlock(BlockClass, ...)
  -- Assumes getBlockKey() and init() take the same arguments.
  local key = BlockClass:getBlockKey(...)
  
  -- Create the block if it doesn't exist
  if not BlockClass.blockInstances[key] then
    local blockInstance = subclass(BlockClass)
    -- Block instances need a game attribute so that they can give block
    -- members a game attribute.
    blockInstance.game = self
    blockInstance:init(...)
    BlockClass.blockInstances[key] = blockInstance
  end
  
  -- Return the block
  return BlockClass.blockInstances[key]
end



function Game:updateFrameCount()
  self.frameCount = utils.readIntLE(self.frameCounterAddress)
end

function Game:getFrameCount()
  -- This function lets game-specific modules get the frame count.
  if not self.frameCounterAddress then
    error("Must provide a frameCounterAddress, because this layout uses"
      .." the frame counter.")
  end
  return self.frameCount
end

function Game:startUpdating(layout)
  -- Clean up from previous runs of the script 
  if self.oncePerFrameAddress then
    debug_removeBreakpoint(self.oncePerFrameAddress)
  end
  
  self.updateOK = true
  
  if layout.updateMethod == 'timer' then
    
    -- Frame counter is optional. If it's specified, we'll use it.
    if self.frameCounterAddress then
      self.usingFrameCounter = true
    end
    
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
    
      if game.usingFrameCounter then
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
  
  elseif layout.updateMethod == 'breakpoint' then
  
    if self.oncePerFrameAddress == nil then
      error("Must provide a oncePerFrameAddress, because this layout uses"
        .." breakpoint updates.")
    end
  
    -- Frame counter is required.
    self.usingFrameCounter = true
  
    -- This sets a breakpoint at a particular instruction which
    -- should be called exactly once every frame.
    debug_setBreakpoint(self.oncePerFrameAddress)
    
    -- If the oncePerFrameAddress was chosen correctly, the
    -- following function should run exactly once every frame.
    local function runOncePerFrame(game)
      -- Check if the previous update call got an error. If so, stop calling
      -- the update function so the user isn't bombarded with errors
      -- once per frame.
      if not game.updateOK then return 1 end
    
      game.updateOK = false
    
      if game.usingFrameCounter then
        game:updateFrameCount()
      end
      
      layout:update()
      
      game.updateOK = true
      
      return 1
    end
    debugger_onBreakpoint = utils.curry(runOncePerFrame, self)
    
  elseif layout.updateMethod == 'button' then
    
    self.usingFrameCounter = false
    
    -- First do an initial update.
    layout:update()
    -- Set the update function to run when the update button is clicked.
    layout.updateButton:setOnClick(utils.curry(layout.update, layout))
  
  end
end



return {
  Game = Game,
}

