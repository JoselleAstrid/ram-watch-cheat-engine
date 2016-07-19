package.loaded.valuetypes = nil
local vtypes = require "valuetypes"
local classInstantiate = vtypes.classInstantiate



local function initWindow(options)
  -- Create Cheat Engine window
  local window = createForm(true)
  
  -- Window position {xpixels, ypixels}; if nil, put at center of screen
  if options.windowPosition ~= nil then
    window:setPosition(options.windowPosition)
  else
    window:centerScreen()
  end
  
  -- Window title
  window:setCaption("RAM Display")
  
  -- Font
  local font = window:getFont()
  -- TODO: Allow customization
  font:setName("Calibri")
  font:setSize(16)
  
  return window
end

local function start(options)
  local gameModuleName =
    options.gameModuleName or error("Must provide a gameModuleName.")
  local layoutName =
    options.layoutName or error("Must provide a layoutName.")
  
  package.loaded[gameModuleName] = nil
  local GameClass = require(gameModuleName)
  local game = classInstantiate(GameClass, options)

  local window = initWindow(options)
  
  -- Get the requested layout.
  local layout = nil
  for _, layoutModuleName in pairs(game.layoutModuleNames) do
    package.loaded[layoutModuleName] = nil
    local layoutModule = require(layoutModuleName)
    
    for name, layoutCandidate in pairs(layoutModule.layouts) do
      if name == layoutName then
        layout = layoutCandidate
        break
      end
    end
  end
  if layout == nil then
    error("Couldn't find layout named: " .. layoutName)
  end
    
  layout:init(window, game)
  
  game:startUpdating(layout)
end


return {
  start = start,
}
