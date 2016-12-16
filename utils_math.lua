-- Math related utility classes/functions.
-- Named to avoid conflict/confusion with the standard math module.

local utils = require "utils"



local Vector3 = {}

function Vector3:new(x, y, z)
  -- Make an object of the "class" Vector3.
  local obj = {}
  setmetatable(obj, self)
  self.__index = self

  obj.x = x
  obj.y = y
  obj.z = z

  return obj
end

function Vector3:plus(v2)
  -- Add another Vector3.
  return Vector3:new(self.x+v2.x, self.y+v2.y, self.z+v2.z)
end

function Vector3:minus(v2)
  -- Subtract another Vector3.
  return Vector3:new(self.x-v2.x, self.y-v2.y, self.z-v2.z)
end

function Vector3:times(c)
  -- Multiply by scalar.
  return Vector3:new(c*self.x, c*self.y, c*self.z)
end

function Vector3:dot(v2)
  -- Dot product with another Vector3.
  return self.x*v2.x + self.y*v2.y + self.z*v2.z
end

function Vector3:cross(v2)
  -- Cross product with another Vector3.
  return Vector3:new(
    self.y*v2.z - self.z*v2.y,
    self.z*v2.x - self.x*v2.z,
    self.x*v2.y - self.y*v2.x
  )
end

function Vector3:nearlyEquals(v2)
  -- See if another Vector3 is nearly equal to this one. (We don't
  -- attempt exact equality because we're dealing with floats in general.)
  return (
    math.abs(self.x - v2.x) < 0.00001
    and math.abs(self.y - v2.y) < 0.00001
    and math.abs(self.z - v2.z) < 0.00001
  )
end

function Vector3:magnitude()
  return math.sqrt(self.x*self.x + self.y*self.y + self.z*self.z)
end

function Vector3:normalized()
  -- Normalized version (magnitude of 1).
  local mag = self:magnitude()
  return Vector3:new(self.x/mag, self.y/mag, self.z/mag)
end

function Vector3:display(label, options)
  local narrow = options.narrow or false

  local format = nil
  if narrow then
    format = "%s:\n X %s\n Y %s\n Z %s"
  else
    format = "%s: X %s | Y %s | Z %s"
  end

  return string.format(
    format,
    label,
    utils.floatToStr(self.x, options),
    utils.floatToStr(self.y, options),
    utils.floatToStr(self.z, options)
  )
end



return {
  Vector3 = Vector3,
}
