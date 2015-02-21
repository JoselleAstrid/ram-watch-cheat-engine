-- Advanced UI with togglable value displays, value-edit
-- buttons, and add-to-CE-list buttons.

local utils = require "utils"
local vtypes = require "valuetypes"

local openEditWindow = vtypes.openEditWindow



local ValueDisplay = {
  valuesToDisplay = {},
  listButtons = {},
  editButtons = {},
  checkBoxes = {},
  trackedValues = {},
}

function ValueDisplay:new(
  window, label, updateAddressesFunction,
  trackedValues, initiallyActive, valueDisplayWidth)

  -- Make an object of the "class" ValueDisplay.
  -- Idea from http://www.lua.org/pil/16.1.html
  local obj = {}
  setmetatable(obj, self)
  self.__index = self
  
  obj.window = window
  obj.label = label
  obj.updateAddressesFunction = updateAddressesFunction
  obj.trackedValues = trackedValues
  
  if valueDisplayWidth == nil then valueDisplayWidth = 250 end
  obj.editButtonX = valueDisplayWidth + 10
  obj.listButtonX = valueDisplayWidth + 60
  obj.checkboxX = valueDisplayWidth + 110
  
  obj:addCheckboxes(initiallyActive)
  
  return obj
end

function ValueDisplay:update()
  self.updateAddressesFunction()
  
  local lines = {}
  for n, v in pairs(self.valuesToDisplay) do
    table.insert(lines, v:getDisplay())
    
    local isValid = v:isValid()
    self.listButtons[n]:setEnabled(isValid)
    self.editButtons[n]:setEnabled(isValid)
  end
  self.label:setCaption(table.concat(lines, "\n"))
end

function ValueDisplay:rebuild()
  self.valuesToDisplay = {}
  
  -- Remove the previous buttons
  for _, button in pairs(self.listButtons) do
    button.destroy()
  end
  for _, button in pairs(self.editButtons) do
    button.destroy()
  end
  self.listButtons = {}
  self.editButtons = {}
  
  for boxN, checkBox in pairs(self.checkBoxes) do
    if checkBox:getState() == cbChecked then
      -- Box is checked; include this value in the display.
      
      -- Include the value itself
      local value = self.trackedValues[boxN]
      table.insert(self.valuesToDisplay, value)
      
      -- Include an edit button
      local editButton = createButton(self.window)
      local posY = 28*(#self.valuesToDisplay - 1) + 5
      editButton:setPosition(self.editButtonX, posY)
      editButton:setCaption("Edit")
      editButton:setSize(40, 20)
      local font = editButton:getFont()
      font:setSize(10)
      
      editButton:setOnClick(utils.curry(
        openEditWindow, value,
        utils.curry(self.update, self)
      ))
      table.insert(self.editButtons, editButton)
  
      -- Include an add-to-address-list button
      local listButton = createButton(self.window)
      local posY = 28*(#self.valuesToDisplay - 1) + 5
      listButton:setPosition(self.listButtonX, posY)
      listButton:setCaption("List")
      listButton:setSize(40, 20)
      local font = listButton:getFont()
      font:setSize(10)
      
      listButton:setOnClick(utils.curry(value.addAddressesToList, value))
      table.insert(self.listButtons, listButton)
    end
  end
end

function ValueDisplay:addCheckboxes(initiallyActive)
  -- Make a list of checkboxes, one for each possible memory value to look at.
    
  -- For the purposes of seeing which values are initially active, we just
  -- identify values by their addresses. This assumes we don't depend on
  -- having copies of the same value objects.
  --
  -- Note: making "sets" in Lua is kind of roundabout.
  -- http://www.lua.org/pil/11.5.html
  local isInitiallyActive = {}
  for _, mvObj in pairs(initiallyActive) do
    isInitiallyActive[mvObj] = true
  end
  
  -- Getting the label for a checkbox may require some addresses to be
  -- computed first.
  self.updateAddressesFunction()
  
  for mvObjN, mvObj in pairs(self.trackedValues) do
    local checkBox = createCheckBox(self.window)
    local posY = 20*(mvObjN-1) + 5
    checkBox:setPosition(self.checkboxX, posY)
    checkBox:setCaption(mvObj:getLabel())
    
    local font = checkBox:getFont()
    font:setSize(9)
    
    -- When a checkbox is checked, the corresponding memory value is displayed.
    checkBox:setOnChange(utils.curry(self.rebuild, self))
    
    if isInitiallyActive[mvObj] then
      checkBox:setState(cbChecked)
    end
    
    table.insert(self.checkBoxes, checkBox)
  end
  
  -- Ensure that the initially checked values actually get initially checked.
  self:rebuild()
end



return {
  ValueDisplay = ValueDisplay,
}

