package.loaded.utils = nil
local utils = require "utils"
local classInstantiate = utils.classInstantiate


local Layout = {
  displayElements = {},
}


function Layout:init(window, game)
  self.window = window
  self.game = game
  
  self.window:setSize(self.windowSize[1], self.windowSize[2])
  
  -- TODO: Maybe element.obj should be called displayObj or uiObj
  self.displayObjs = {}
  for _, element in pairs(self.displayElements) do
    if element.type == 'label' then
      element.obj = self:createLabel(element.initOptions)
    elseif element.type == 'image' then
      local imageClassObj =
        self:createImage(element.ImageClass, element.initOptions)
      element.obj = imageClassObj.image
      element.updateFunc = utils.curry(imageClassObj.update, imageClassObj)
    end
    table.insert(self.displayObjs, element.obj)
  end
end


function Layout:update()
  local game = self.game

  game:updateAddresses()
  
  for _, element in pairs(self.displayElements) do
    if element.type == 'label' then
      local displayTexts = {}
      for _, displayFunc in pairs(element.displayFuncs) do
        table.insert(displayTexts, displayFunc())
      end
      local labelDisplay = table.concat(displayTexts, '\n')
      element.obj:setCaption(labelDisplay)
    elseif element.type == 'image' then
      element.updateFunc()
    end
  end

  -- Positioning window elements should be done once we've added valid content
  -- to the labels for the first time, so that we get accurate label sizes.
  -- Thus this step is done at the end of the first update(),
  -- rather than in init().
  if not self.windowElementsPositioned then
    self:positionWindowElements(self.displayObjs)
    self.windowElementsPositioned = true
  end
end


-- Initialize a GUI label.
-- Based on: http://forum.cheatengine.org/viewtopic.php?t=530121
function Layout:createLabel(options)

  -- Call the Cheat Engine function to create a label.
  local label = createLabel(self.window)
  if label == nil then error("Failed to create label.") end
  
  label:setPosition(options.x or 0, options.y or 0)
  label:setCaption(options.text or "")
  
  font = label:getFont()
  if options.fontSize ~= nil then font:setSize(options.fontSize) end
  if options.fontName ~= nil then font:setName(options.fontName) end
  if options.fontColor ~= nil then font:setColor(options.fontColor) end
  
  return label
end


function Layout:addLabel(initOptions)
  local label = {
    type='label', obj=nil, displayFuncs={}, initOptions=initOptions}
  self.lastAddedLabel = label
  table.insert(self.displayElements, label)
end


function Layout:addItem(item, displayOptions)
  if not self.lastAddedLabel then
    error("Must add a label before adding an item.")
  end
  
  if tostring(type(item)) == 'function' then
    -- Take the item itself to be a function which returns the desired
    -- value as a string, and takes display options.
    table.insert(
      self.lastAddedLabel.displayFuncs,
      utils.curry(item, displayOptions)
    )
  else
    -- Assume the item is a table where item:display(displayOptions)
    -- would get the desired value as a string, while applying the options.
    table.insert(
      self.lastAddedLabel.displayFuncs,
      utils.curry(item.display, item, displayOptions)
    )
  end
end


function Layout:createImage(ImageClass, options)
  return classInstantiate(ImageClass, self.game, self.window, options)
end


function Layout:addImage(ImageClass, initOptions)
  local image = {
    type='image', obj=nil, updateFunc=nil,
    ImageClass=ImageClass, initOptions=initOptions}
  table.insert(self.displayElements, image)
end


-- Figure out a working set of Y positions for the window elements.
--
-- Positions are calculated based on the window size and element sizes,
-- so that the elements get evenly spaced from top to bottom of the window.
function Layout:positionWindowElements(windowElements)
  local heightSum = 0
  for _, element in pairs(windowElements) do
    local height = element:getHeight()
    heightSum = heightSum + height
  end
  
  local windowHeight = self.window:getHeight()
  local minY = 6
  local maxY = windowHeight - 6
  local numSpaces = #windowElements - 1
  local elementSpacing = (maxY - minY - heightSum) / (numSpaces)
  
  local currentY = minY
  for _, element in pairs(windowElements) do
    local x = element:getLeft()
    element:setPosition(x, currentY)
    
    local height = element:getHeight()
    currentY = currentY + height + elementSpacing
  end
end


function Layout:setBreakpointUpdateMethod()
  self.updateMethod = 'breakpoint'
end
function Layout:setTimerUpdateMethod(updateTimeInterval)
  self.updateMethod = 'timer'
  self.updateTimeInterval = updateTimeInterval
end
function Layout:setButtonUpdateMethod(updateButton)
  self.updateMethod = 'button'
  self.updateButton = updateButton
end



-- Writing stats to a file.

local StatRecorder = {
  button = nil,
  timeLimitField = nil,
  secondsLabel = nil,
  timeElapsedLabel = nil,
  endFrame = nil,
  framerate = nil,
  
  currentlyTakingStats = false,
  currentFrame = nil,
  valuesTaken = nil,
}
  
function StatRecorder:startTakingStats()
  -- Get the time limit from the field. If it's not a valid number,
  -- don't take any stats.
  local seconds = tonumber(self.timeLimitField.Text)
  if seconds == nil then return end
  self.endFrame = self.framerate * seconds
  
  self.currentlyTakingStats = true
  self.currentFrame = 1
  self.valuesTaken = {}
  
  -- Change the Start taking stats button to a Stop taking stats button
  self.button:setCaption("Stop stats")
  self.button:setOnClick(curry(self.stopTakingStats, self))
  -- Disable the time limit field
  self.timeLimitField:setEnabled(false)
end
  
function StatRecorder:takeStat(str)
  self.valuesTaken[self.currentFrame] = str
  
  -- Display the current frame count
  self.timeElapsedLabel:setCaption(string.format("%.2f", self.currentFrame / self.framerate))
  
  self.currentFrame = self.currentFrame + 1
  if self.currentFrame > self.endFrame then
    self:stopTakingStats()
  end
end
  
function StatRecorder:stopTakingStats()
  -- Collect the stats in string form and write them to a file.
  --
  -- This file will be created in either:
  -- (A) The same directory as the cheat table you have open.
  -- (B) The same directory as the Cheat Engine .exe file, it you don't
  --   have a cheat table open.
  local statsStr = table.concat(self.valuesTaken, "\n")
  local statsFile = io.open("stats.txt", "w")
  statsFile:write(statsStr)
  statsFile:close()
  
  self.currentlyTakingStats = false
  self.currentFrame = nil
  self.valuesTaken = {}
  self.endFrame = nil
  
  self.button:setCaption("Take stats")
  self.button:setOnClick(curry(self.startTakingStats, self))
  self.timeLimitField:setEnabled(true)
  
  self.timeElapsedLabel:setCaption("")
end
    
function StatRecorder:new(window, baseYPos, framerate)

  -- Make an object of the "class" StatRecorder.
  -- Idea from http://www.lua.org/pil/16.1.html
  local obj = {}
  setmetatable(obj, self)
  self.__index = self
  
  obj:initializeUI(window, baseYPos)
  
  if framerate ~= nil then
    obj.framerate = framerate
  else
    obj.framerate = 60
  end
  
  return obj
end

function StatRecorder:initializeUI(window, baseYPos)
  self.button = createButton(window)
  self.button:setPosition(10, baseYPos)
  self.button:setCaption("Take stats")
  self.button:setOnClick(curry(self.startTakingStats, self))
  local buttonFont = self.button:getFont()
  buttonFont:setSize(10)
  
  self.timeLimitField = createEdit(window)
  self.timeLimitField:setPosition(100, baseYPos)
  self.timeLimitField:setSize(60, 20)
  self.timeLimitField.Text = "10"
  local fieldFont = self.timeLimitField:getFont()
  fieldFont:setSize(10)
  
  self.secondsLabel = initLabel(window, 165, baseYPos+3, "seconds")
  local secondsFont = self.secondsLabel:getFont()
  secondsFont:setSize(10)
  
  self.timeElapsedLabel = initLabel(window, 240, baseYPos-5, "")
end


return {
  layouts = {},
  Layout = Layout,
}
