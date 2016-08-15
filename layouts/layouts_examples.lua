-- Merge the following layout modules into one module.
layouts_examples_modules_names = {
  'layouts_examples_verbose',
}

local layouts = {}
for _, layoutModuleName in pairs(layouts_examples_modules_names) do
  package.loaded[layoutModuleName] = nil
  local layoutModule = require(layoutModuleName)
  
  for name, layout in pairs(layoutModule.layouts) do
    layouts[name] = layout
  end
end

return {
  layouts = layouts,
}
