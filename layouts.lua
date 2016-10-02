package.loaded.utils = nil
local utils = require "utils"
local subclass = utils.subclass
local classInstantiate = utils.classInstantiate


local Layout = {
  displayElements = {},
}


function Layout:init(window, game)
  self.window = window
  self.game = game
  
  self.window:setSize(self.windowSize[1], self.windowSize[2])
  
  self.uiObjs = {}
  for _, element in pairs(self.displayElements) do
    if not element.uiObj then
      if element.type == 'label' then
        element.uiObj = self:createLabel(element.initOptions)
      else
        element.uiObj = subclass(element.elementClass)
        element.uiObj.layout = self
        element.uiObj.window = self.window
        element.uiObj.game = game
        element.initCallable(element.uiObj)
      end
    end
    table.insert(self.uiObjs, element.uiObj)
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
      element.uiObj:setCaption(labelDisplay)
    else
      if element.uiObj.update then element.uiObj:update() end
    end
  end

  if self.autoPositioningActive and not self.autoPositioningDone then
    -- Auto-positioning window elements should be done
    -- once we've added valid content to the labels for the first time,
    -- so that we get accurate label sizes.
    -- Thus this step is done at the end of the first update(),
    -- rather than in init().
    self:autoPositionElements()
    self.autoPositioningDone = true
  end
end


function Layout:activateAutoPositioningX()
  -- Auto-position layout elements left to right.
  self.autoPositioningActive = true
  self.autoPositioningDone = false
  self.autoPositioningCoord = 'x'
end
function Layout:activateAutoPositioningY()
  -- Auto-position layout elements top to bottom.
  self.autoPositioningActive = true
  self.autoPositioningDone = false
  self.autoPositioningCoord = 'y'
end


-- Figure out a working set of Y positions for the window elements.
--
-- Positions are calculated based on the window size and element sizes,
-- so that the elements get evenly spaced from top to bottom of the window.
function Layout:autoPositionElements()
  local function getElementLength(element_)
    if self.autoPositioningCoord == 'x' then return element_:getWidth()
    else return element_:getHeight() end
  end
  local function getWindowLength()
    if self.autoPositioningCoord == 'x' then return self.window:getWidth()
    else return self.window:getHeight() end
  end
  local function getElementOtherCoordPos(element_)
    if self.autoPositioningCoord == 'x' then return element_:getTop()
    else return element_:getLeft() end
  end
  local function applyAutoPosition(element_, pos_)
    -- Apply the auto-calculated position coordinate while maintaining the
    -- other coordinate.
    if self.autoPositioningCoord == 'x' then
      element_:setPosition(pos_, element_:getTop())
    else
      element_:setPosition(element_:getLeft(), pos_)
    end
  end

  -- Figure out the total length of the elements if they were put
  -- side by side without any spacing.
  local lengthSum = 0
  
  for _, element in pairs(self.uiObjs) do
    local length = getElementLength(element)
    lengthSum = lengthSum + length
  end
  
  local windowLength = getWindowLength()
  -- Have a gutter of 6 pixels at each end of the window,
  -- and space out the elements uniformly.
  --
  -- It's possible for the spacing to be negative, meaning elements will
  -- overlap. The user should rectify this situation by making the
  -- window bigger.
  local minPos = 6
  local maxPos = windowLength - 6
  local numSpaces = #(self.uiObjs) - 1
  local elementSpacing = (maxPos - minPos - lengthSum) / (numSpaces)
  
  local currentPos = minPos
  for _, element in pairs(self.uiObjs) do
    applyAutoPosition(element, currentPos)
    
    local length = getElementLength(element)
    currentPos = currentPos + length + elementSpacing
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



-- Initialize a GUI label.
-- Based on: http://forum.cheatengine.org/viewtopic.php?t=530121
function Layout:createLabel(options)

  -- Call the Cheat Engine function to create a label.
  local label = createLabel(self.window)
  if label == nil then error("Failed to create label.") end
  
  label:setPosition(options.x or 0, options.y or 0)
  label:setCaption(options.text or "")
  
  local font = label:getFont()
  if options.fontSize ~= nil then font:setSize(options.fontSize) end
  if options.fontName ~= nil then font:setName(options.fontName) end
  if options.fontColor ~= nil then font:setColor(options.fontColor) end
  
  return label
end


function Layout:addLabel(passedInitOptions)
  local initOptions = {}
  -- First apply default options
  if self.labelDefaults then
    for k, v in pairs(self.labelDefaults) do initOptions[k] = v end
  end
  -- Then apply passed-in options, replacing default options of the same keys
  if passedInitOptions then
    for k, v in pairs(passedInitOptions) do initOptions[k] = v end
  end

  local label = {
    type='label', uiObj=nil, displayFuncs={}, initOptions=initOptions}
  self.lastAddedLabel = label
  table.insert(self.displayElements, label)
end


-- Add a text-displayable item to the current label.
function Layout:addItem(item, passedDisplayOptions)
  if not self.lastAddedLabel then
    error("Must add a label before adding an item.")
  end
  
  local displayOptions = {}
  -- First apply default options
  if self.itemDisplayDefaults then
    for k, v in pairs(self.itemDisplayDefaults) do displayOptions[k] = v end
  end
  -- Then apply passed-in options, replacing default options of the same keys
  if passedDisplayOptions then
    for k, v in pairs(passedDisplayOptions) do displayOptions[k] = v end
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



local SimpleElement = {
  uiObj = nil,
  update = nil,
}

function SimpleElement:getWidth() return self.uiObj:getWidth() end
function SimpleElement:getHeight() return self.uiObj:getHeight() end
function SimpleElement:getLeft() return self.uiObj:getLeft() end
function SimpleElement:getTop() return self.uiObj:getTop() end
function SimpleElement:setPosition(x, y) self.uiObj:setPosition(x, y) end


-- This class is mostly redundant with Cheat Engine's defined Button class,
-- but we define our own LayoutButton (wrapping around CE's Button) for:
-- (1) consistency with other layout element classes
-- (2) not confusing CE's Button update() function with the update() function
-- our Layout class looks for in elements
local LayoutButton = subclass(SimpleElement)

function LayoutButton:setOnClick(f) self.uiObj:setOnClick(f) end

function LayoutButton:init(window, text, options)
  options = options or {}
  options.x = options.x or 0
  options.y = options.y or 0
  
  self.uiObj = createButton(window)
  self.uiObj:setPosition(options.x, options.y)
  self.uiObj:setCaption(text)
  
  for _, element in pairs({self.uiObj}) do
    local font = element:getFont()
    if options.fontSize ~= nil then font:setSize(options.fontSize) end
    if options.fontName ~= nil then font:setName(options.fontName) end
    if options.fontColor ~= nil then font:setColor(options.fontColor) end
  end
  
  local buttonFontSize = self.uiObj:getFont():getSize()
  local buttonWidth = buttonFontSize * 6  -- Chars in 'Update'
  local buttonHeight = buttonFontSize * 2.0 + 8
  self.uiObj:setSize(buttonWidth, buttonHeight)
end

function Layout:addButton(window, text, passedInitOptions)
  local initOptions = {}
  -- First apply default options
  if self.labelDefaults then
    utils.updateTable(initOptions, self.labelDefaults)
  end
  -- Then apply passed-in options, replacing default options of the same keys
  if passedInitOptions then
    utils.updateTable(initOptions, passedInitOptions)
  end

  local uiObj = classInstantiate(LayoutButton, window, text, initOptions)
  local button = {
    uiObj=uiObj,
    elementClass=nil,
    initCallable=nil,
  }
  table.insert(self.displayElements, button)
  
  return uiObj
end


function Layout:addImage(ImageClass, initOptions)  
  local image = {
    uiObj=nil,
    elementClass=ImageClass,
    initCallable=utils.curryInstance(ImageClass.init, initOptions),
  }
  table.insert(self.displayElements, image)
end



-- A UI element that holds other elements.

local CompoundElement = {
  elements = {},
  position = nil,
}

function CompoundElement:addElement(relativePosition, uiObj)
  table.insert(self.elements, {relativePosition=relativePosition, uiObj=uiObj})
end

function CompoundElement:getWidth()
  local width = 0
  for _, element in pairs(self.elements) do
    width = math.max(
      width, element.relativePosition[1] + element.uiObj:getWidth())
  end
  return width
end

function CompoundElement:getHeight()
  local height = 0
  for _, element in pairs(self.elements) do
    height = math.max(
      height, element.relativePosition[2] + element.uiObj:getHeight())
  end
  return height
end

function CompoundElement:getLeft()
  return self.position[1]
end
function CompoundElement:getTop()
  return self.position[2]
end

function CompoundElement:positionElements()
  for _, element in pairs(self.elements) do
    element.uiObj:setPosition(
      self.position[1] + element.relativePosition[1],
      self.position[2] + element.relativePosition[2]
    )
  end
end

function CompoundElement:setPosition(x, y)
  self.position = {x, y}
  self:positionElements()
end



-- Writing stats to a file.

local FileWriter = subclass(CompoundElement)
utils.updateTable(FileWriter, {
  button = nil,
  timeLimitField = nil,
  secondsLabel = nil,
  timeElapsedLabel = nil,
  endFrame = nil,
  framerate = nil,
  
  currentlyTakingStats = false,
  currentFrame = nil,
  valuesTaken = nil,
})
    
function FileWriter:init(filename, outputStringGetter, options)
  options = options or {}
  options.x = options.x or 0
  options.y = options.y or 0
  
  self.filename = filename
  self.outputStringGetter = outputStringGetter
  self:initializeUI(options)
  self:setPosition(options.x, options.y)
  
  -- TODO: Make framerate a variable on the game class
  self.framerate = 60
end

function FileWriter:initializeUI(options)
  self.button = createButton(self.window)
  self.button:setCaption("Take stats")
  self.button:setOnClick(utils.curry(self.startTakingStats, self))
  
  self.timeLimitField = createEdit(self.window)
  self.timeLimitField.Text = "10"
  
  self.secondsLabel = self.layout:createLabel(options)
  self.secondsLabel:setCaption("seconds")
  
  self.timeElapsedLabel = self.layout:createLabel(options)
  -- Allow auto-layout to detect an appropriate width for this element
  -- even though it's not active yet. (Example display: 10.00)
  self.timeElapsedLabel:setCaption("     ")
  
  -- We initialize these elements directly through Cheat Engine's functions,
  -- and thus there is no 'options' interface on the creation function.
  -- So we set attributes here instead.
  local nonLabelElements = {self.button, self.timeLimitField}
  for _, element in pairs(nonLabelElements) do
    local font = element:getFont()
    if options.fontSize ~= nil then font:setSize(options.fontSize) end
    if options.fontName ~= nil then font:setName(options.fontName) end
    if options.fontColor ~= nil then font:setColor(options.fontColor) end
  end
  
  -- Add the elements to the layout.
  local buttonX = 10
  local buttonFontSize = self.button:getFont():getSize()
  local buttonWidth = buttonFontSize * 10
  local buttonHeight = buttonFontSize * 2.0 + 8
  self:addElement({buttonX, 0}, self.button)
  self.button:setSize(buttonWidth, buttonHeight)
  
  local timeLimitFieldX = buttonX + buttonWidth + 5
  local timeLimitFieldFontSize = self.timeLimitField:getFont():getSize()
  local timeLimitFieldWidth = timeLimitFieldFontSize * 5
  local timeLimitFieldHeight = buttonFontSize * 1.5
  self:addElement({timeLimitFieldX, 0}, self.timeLimitField)
  self.timeLimitField:setSize(timeLimitFieldWidth, timeLimitFieldHeight)
  
  local secondsLabelX = timeLimitFieldX + timeLimitFieldWidth + 5
  local secondsLabelY = 3
  self:addElement({secondsLabelX, secondsLabelY}, self.secondsLabel)
  
  local timeElapsedLabelX = secondsLabelX + self.secondsLabel:getWidth() + 15
  local timeElapsedLabelY = 3
  self:addElement({timeElapsedLabelX, timeElapsedLabelY}, self.timeElapsedLabel)
end
  
function FileWriter:startTakingStats()
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
  self.button:setOnClick(utils.curry(self.stopTakingStats, self))
  -- Disable the time limit field
  self.timeLimitField:setEnabled(false)
end
  
function FileWriter:takeStat()
  self.valuesTaken[self.currentFrame] = self.outputStringGetter()
  
  -- Display the current frame count
  self.timeElapsedLabel:setCaption(
    string.format("%.2f", self.currentFrame / self.framerate))
  
  self.currentFrame = self.currentFrame + 1
  if self.currentFrame > self.endFrame then
    self:stopTakingStats()
  end
end
  
function FileWriter:stopTakingStats()
  -- Collect the stats in string form and write them to a file.
  --
  -- This file will be created in either:
  -- (A) The same directory as the cheat table you have open.
  -- (B) The same directory as the Cheat Engine .exe file, it you don't
  --   have a cheat table open.
  local statsStr = table.concat(self.valuesTaken, "\n")
  local statsFile = io.open(self.filename, "w")
  statsFile:write(statsStr)
  statsFile:close()
  
  self.currentlyTakingStats = false
  self.currentFrame = nil
  self.valuesTaken = {}
  self.endFrame = nil
  
  self.button:setCaption("Take stats")
  self.button:setOnClick(utils.curry(self.startTakingStats, self))
  self.timeLimitField:setEnabled(true)
  
  self.timeElapsedLabel:setCaption("")
end

function FileWriter:update()
  if self.currentlyTakingStats then
    self:takeStat()
  end
end


function Layout:addFileWriter(
    item, filename, passedOutputOptions, passedInitOptions)
  -- Create a callable that will get a display of the tracked value
  -- for file writing.
  local outputOptions = {nolabel=true}
  if passedOutputOptions then
    utils.updateTable(outputOptions, passedOutputOptions)
  end
  local outputStringGetter = utils.curry(item.display, item, outputOptions)
  
  -- Options for displaying the fileWriter's UI elements.
  local initOptions = {}
  -- First apply default options
  if self.labelDefaults then
    utils.updateTable(initOptions, self.labelDefaults)
  end
  -- Then apply passed-in options, replacing default options of the same keys
  if passedInitOptions then
    utils.updateTable(initOptions, passedInitOptions)
  end
  
  local fileWriter = {
    uiObj=nil,
    elementClass=FileWriter,
    initCallable=utils.curryInstance(
      FileWriter.init, filename, outputStringGetter, initOptions),
  }
  table.insert(self.displayElements, fileWriter)
end



local EditableValue = subclass(CompoundElement)
utils.updateTable(EditableValue, {
  valueObj = nil,
  valueLabel = nil,
  editButton = nil,
})
    
function EditableValue:init(valueObj, options)
  options = options or {}
  options.x = options.x or 0
  options.y = options.y or 0
  
  self.valueObj = valueObj
  self:initializeUI(options)
  self:setPosition(options.x, options.y)
end

function EditableValue:initializeUI(options)
  self.valueLabel = self.layout:createLabel(options)

  self.editButton = createButton(self.window)
  self.editButton:setCaption("Edit")
  self.editButton:setOnClick(utils.curry(self.openEditWindow, self))

  self.listButton = createButton(self.window)
  self.listButton:setCaption("List")
  self.listButton:setOnClick(utils.curry(self.addAddressesToList, self))
  
  -- Set non-label font attributes.
  for _, element in pairs({self.editButton, self.listButton}) do
    local font = element:getFont()
    if options.fontSize ~= nil then font:setSize(options.fontSize) end
    if options.fontName ~= nil then font:setName(options.fontName) end
    if options.fontColor ~= nil then font:setColor(options.fontColor) end
  end
  
  -- Add the elements to the layout.
  self:addElement({10, 3}, self.valueLabel)
  
  local buttonX = options.buttonX or 300
  local buttonFontSize = self.editButton:getFont():getSize()
  local buttonWidth = buttonFontSize * 4  -- 4 chars in both 'Edit' and 'List'
  local buttonHeight = buttonFontSize * 2.0 + 8
  
  self:addElement({buttonX, 0}, self.editButton)
  self.editButton:setSize(buttonWidth, buttonHeight)
  
  self:addElement({buttonX + buttonWidth + 4, 0}, self.listButton)
  self.listButton:setSize(buttonWidth, buttonHeight)
end

function EditableValue:update()
  self.valueLabel:setCaption(self.valueObj:display())
end

function EditableValue:openEditWindow()
  -- Create an edit window
  local window = createForm(true)
  window:setSize(400, 50)
  window:centerScreen()
  window:setCaption(self.valueObj:getEditWindowTitle())
  
  -- Add a text box with the current value
  local textField = createEdit(window)
  textField:setPosition(70, 10)
  textField:setSize(200, 20)
  textField.Text = self.valueObj:getEditFieldText()
  
  -- Add an OK button in the window, which would change the value
  -- to the text field contents, and close the window
  local okButton = createButton(window)
  okButton:setPosition(300, 10)
  okButton:setCaption("OK")
  okButton:setSize(30, 25)
  
  local okAction = utils.curry(
    self.editWindowOKAction, self, window, textField)
  okButton:setOnClick(okAction)
  
  -- Add a Cancel button in the window, which would just close the window
  local cancelButton = createButton(window)
  cancelButton:setPosition(340, 10)
  cancelButton:setCaption("Cancel")
  cancelButton:setSize(50, 25)
  cancelButton:setOnClick(utils.curry(window.close, window))
  
  -- Add a reset button, if applicable
  if self.valueObj.getResetValue then
    local resetButton = createButton(window)
    resetButton:setPosition(5, 10)
    resetButton:setCaption("Reset")
    resetButton:setSize(50, 25)
    local resetValue = function(valueObj, textField_)
      textField_.Text = valueObj:toStrForEditField(valueObj:getResetValue())
    end
    resetButton:setOnClick(utils.curry(resetValue, self.valueObj, textField))
  end
  
  -- Put the initial focus on the text field.
  textField:setFocus()
end

function EditableValue:editWindowOKAction(window, textField)
  local newValue = self.valueObj:strToValue(textField.Text)
  
  -- Do nothing if the entered value is empty or invalid
  if newValue == nil then return end
  
  self.valueObj:set(newValue)
  
  -- Delay for a bit first, because it seems that the
  -- write to the memory address needs a bit of time to take effect.
  -- TODO: Use Timer instead of sleep?
  sleep(50)
  -- Update the display
  self:updateDisplay()
  -- Close the edit window
  window:close()
end

function EditableValue:addAddressesToList()
  local addressList = getAddressList()
  local entries = self.valueObj:getAddressListEntries()
  
  for _, entry in pairs(entries) do
    local memoryRecord = addressList:createMemoryRecord()
    
    -- setAddress doesn't work for some reason, despite being in CE's Help docs.
    -- So we'll just set the address property directly.
    memoryRecord.Address = entry.Address
    
    memoryRecord:setDescription(entry.Description)
    memoryRecord.Type = entry.Type
    
    if entry.Type == vtCustom then
      memoryRecord.CustomTypeName = entry.CustomTypeName
    elseif entry.Type == vtBinary then
      -- TODO: Can't figure out how to set Binary start bit and size.
      -- And this entry is useless if it's a 0-sized Binary display (which is
      -- default). So, best we can do is to make this entry a Byte...
      memoryRecord.Type = vtByte
      
      -- This didn't work.
      --memoryRecord.Binary.Startbit = entry.BinaryStartBit
      --memoryRecord.Binary.Size = entry.BinarySize
    end
  end
end


function Layout:addEditableValue(valueObj, passedInitOptions)
  -- Options for displaying the UI elements.
  local initOptions = {}
  -- First apply default options
  if self.labelDefaults then
    utils.updateTable(initOptions, self.labelDefaults)
  end
  -- Then apply passed-in options, replacing default options of the same keys
  if passedInitOptions then
    utils.updateTable(initOptions, passedInitOptions)
  end
  
  local editableValue = {
    uiObj=nil,
    elementClass=EditableValue,
    initCallable=utils.curryInstance(EditableValue.init, valueObj, initOptions),
  }
  table.insert(self.displayElements, editableValue)
end



return {
  Layout = Layout,
  SimpleElement = SimpleElement,
}
