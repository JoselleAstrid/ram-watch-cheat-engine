package.loaded.utils = nil
local utils = require "utils"
local classInstantiate = utils.classInstantiate



local function createWindow(options)
  -- Create Cheat Engine window
  local window = createForm(true)

  -- Window position {xpixels, ypixels}; if nil, put at center of screen
  if options.windowPosition ~= nil then
    window:setPosition(options.windowPosition[1], options.windowPosition[2])
  else
    window:centerScreen()
  end

  -- Window title
  window:setCaption("RAM Display")

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

  local window = createWindow(options)

  -- Figure out which layout modules we are checking.
  local layoutModuleNames = {
    -- Layouts that could be used for multiple games
    'layouts_generic',
    -- User-defined layouts (not under version control)
    'layouts_custom',
    -- Example layouts that aren't as directly practical as the ones in the
    -- game-specific modules or the generic module, but still show off some
    -- useful things
    'layouts_examples',
  }
  -- Game-specific layout modules
  for _, name in pairs(game.layoutModuleNames) do
    table.insert(layoutModuleNames, name)
  end

  -- Get the requested layout.
  local layout = nil
  for _, layoutModuleName in pairs(layoutModuleNames) do
    -- Due to the way we're checking the existence of layout modules, we must
    -- first ensure the module is not considered loaded OR preloaded.
    package.preload[layoutModuleName] = nil
    package.loaded[layoutModuleName] = nil
    -- Check that the layout module exists. In particular we want to tolerate
    -- non-existence of the custom module.
    if utils.isModuleAvailable(layoutModuleName) then
      local layoutModule = require(layoutModuleName)

      for name, layoutCandidate in pairs(layoutModule.layouts) do
        if name == layoutName then
          layout = layoutCandidate
          break
        end
      end
    end
  end
  if layout == nil then
    error("Couldn't find layout named: " .. layoutName)
  end

  local layoutOptions = options.layoutOptions or {}
  layout.window = window
  layout.game = game
  layout:init(unpack(layoutOptions))

  game:startUpdating(layout)
end


return {
  start = start,
}
