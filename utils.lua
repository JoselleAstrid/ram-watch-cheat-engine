-- Various utility functions.

local utils = {}



-- tonumber fix, so that it properly handles strings starting with "-0".
-- See the following bug report: http://cheatengine.org/mantis/view.php?id=328
if originalTonumber==nil then
  originalTonumber=tonumber
end

function tonumber(str)
  local result = originalTonumber(str)
  if string.sub(str,1,1) == "-" and result > 0 then
    result = -result
  end

  return result
end



-- Return true if the module named name can be found, false otherwise.
-- Throw an error if the module exists but has a syntax error.
--
-- This is useful for loading a module only if it exists.
-- The built-in require() will get an error if the module doesn't exist.
-- So, use this function and then call require() only if true is returned.
--
-- Note that ipairs does almost the same thing as pairs, except it stops
-- when one of the values is nil. It seems to work for our purposes from
-- testing so far, at least.
--
-- Source: http://stackoverflow.com/questions/15429236/
function utils.isModuleAvailable(name)
  if package.loaded[name] then
    return true
  else
    for _, searcher in ipairs(package.searchers or package.loaders) do
      local loader = searcher(name)
      if type(loader) == 'function' then
        package.preload[name] = loader
        return true
      end
    end
    return false
  end
end



function utils.tableContentsToStr(t)
  local items = {}
  for key, value in pairs(t) do
    table.insert(items, tostring(key)..": "..tostring(value))
  end
  return table.concat(items, "\n")
end


function utils.updateTable(tableToUpdate, table2)
  -- Update tableToUpdate with the values in table2. If a key exists in both
  -- tables, overwrite.
  for key, value in pairs(table2) do
    tableToUpdate[key] = value
  end
end


-- Check if a value is within a table's values.
-- If you do existence checks in a large table, better to add the things to
-- check for as table keys instead of table values.
-- That lets you check existence with the "in" operator, which is faster.
--
-- However, sometimes it's easier to add as values and you don't care about
-- performance. That's where this function comes in.
function utils.isValueInTable(tbl, value)
  for _, v in pairs(tbl) do
    if v == value then return true end
  end
  return false
end



-- Curry implementation.
-- From: http://lua-users.org/lists/lua-l/2007-01/msg00205.html
-- (Linked from: http://lua-users.org/wiki/CurriedLua)
local function curry1(f,v)
  return function (...)  return f(v,...)  end
end
function utils.curry(f,v,...)
  if v == nil then return f end
  return utils.curry( curry1(f,v), ... )
end

-- Curry an instance function.
function utils.curryInstance(f, ...)
  local function func(f_, args, instance)
    return f_(instance, unpack(args))
  end
  -- From here, all that remains is to pass in the instance.
  return utils.curry(func, f, {...})
end



function utils.readIntBE(address, numberOfBytesToRead)
  -- In: address - address of a big-endian memory value we want to read
  --     numberOfBytesToRead - the number of bytes to read from that address
  -- Out: integer value of the memory that was read

  if numberOfBytesToRead == nil then numberOfBytesToRead = 4 end

  -- Call Cheat Engine's built-in readBytes() function.
  -- The "true" parameter says we want the return value as a table of the bytes.
  local bytes = readBytes(address, numberOfBytesToRead, true)

  -- If the read failed (maybe an unreadable address?), return nil.
  if bytes == nil then return nil end

  local sum = 0
  for _, byteValue in pairs(bytes) do
    sum = 256*sum + byteValue
  end
  return sum
end

function utils.readIntLE(address, numberOfBytesToRead)
  -- Same, but for little-endian

  if numberOfBytesToRead == nil then numberOfBytesToRead = 4 end

  local bytes = readBytes(address, numberOfBytesToRead, true)

  if bytes == nil then return nil end

  -- We go backwards through the byte array. Other than that, this works the
  -- same as the big-endian version.
  local sum = 0
  for index = #bytes, 1, -1 do
    local byteValue = bytes[index]
    sum = 256*sum + byteValue
  end
  return sum
end

local twoTo31 = 0x80000000
local twoTo23 = 0x800000
local twoTo63 = 0x8000000000000000
local twoTo52 = 0x10000000000000

function utils.intToFloat(x)
  -- In: 4-byte integer value
  -- Out: floating-point value from the same bytes
  --
  -- For example, to see what you'd get if you pass in the number 64,
  -- go here and enter 00000040 (64 in hex) in the top box:
  -- http://babbage.cs.qc.cuny.edu/IEEE-754.old/Decimal.html

  -- Reference: http://www.doc.ic.ac.uk/~eedwards/compsys/float/
  -- Bits: 31 - sign (s), 30-23 - exponent (e), 22-0 - mantissa (m)
  if x == 0 then return 0 end
  local s = nil
  local em = nil
  if x < twoTo31 then
    s = 1
    em = x
  else
    s = -1
    em = x - twoTo31
  end
  local e = math.floor(em / twoTo23) - 127  -- 2^7 - 1
  local m = (em % twoTo23) / twoTo23 + 1
  return s*(2^e)*m
end

function utils.intToDouble(x)
  -- In: 8-byte integer value
  -- Out: floating-point value from the same bytes

  -- Bits: 63 - sign (s), 62-52 - exponent (e), 51-0 - mantissa (m)
  if x == 0 then return 0 end
  local s = nil
  local em = nil
  if x < twoTo63 then
    s = 1
    em = x
  else
    s = -1
    em = x - twoTo63
  end
  local e = math.floor(em / twoTo52) - 1023  -- 2^10 - 1
  local m = (em % twoTo52) / twoTo52 + 1
  return s*(2^e)*m
end

function utils.readFloatBE(address, numberOfBytesToRead)
  return utils.intToFloat(utils.readIntBE(address, numberOfBytesToRead))
end

function utils.readFloatLE(address, numberOfBytesToRead)
  return utils.intToFloat(utils.readIntLE(address, numberOfBytesToRead))
end

-- Note: Cheat Engine already has a readFloat(), which probably does LE
-- (little-endian). So don't be surprised if you forget the BE/LE in the name
-- and it still runs.

function utils.unsignedToSigned(v, numOfBytes)
  -- In: unsigned integer value, and the number of bytes at its address
  -- Out: signed version of this value
  local possibleValues = 2^(numOfBytes*8)
  if v >= possibleValues/2 then
    return v - possibleValues
  else
    return v
  end
end
function utils.signedToUnsigned(v, numOfBytes)
  local possibleValues = 2^(numOfBytes*8)
  if v < 0 then
    return v + possibleValues
  else
    return v
  end
end

function utils.intToHexStr(x)
  -- In: integer value
  -- Out: string of the integer's hexadecimal representation
  if x == nil then return "nil" end

  return string.format("0x%08X", x)
end

function utils.intToStr(x, options)
  -- In: integer value
  -- Out: string representation, as detailed by the options
  if x == nil then return "nil" end
  options = options or {}

  local f = "%"
  if options.signed then f = f.."+" end
  if options.digits then
    if options.signed then
      -- The number after the 0 should be number of digits + sign
      f = f.."0"..(options.digits+1)
    else
      -- The number after the 0 should be number of digits only
      f = f.."0"..(options.digits)
    end
  end
  f = f.."d"
  return string.format(f, x)
end

function utils.floatToStr(x, options)
  -- In: floating-point value
  -- Out: string representation, as detailed by the options
  if x == nil then return "nil" end
  if options == nil then options = {} end

  -- Guarantee at least a certain number of digits before the decimal
  local beforeDecimal = options.beforeDecimal or nil
  -- Display a certain number of digits after the decimal
  local afterDecimal = options.afterDecimal or 3
  -- Trim zeros from the right end
  local trimTrailingZeros = options.trimTrailingZeros or false
  -- Always display a + or - in front of the value depending on the sign
  local signed = options.signed or false

  local f = "%"
  if signed then f = f.."+" end
  if beforeDecimal then
    if signed then
      -- The number after the 0 counts all digits + decimal point + sign
      f = f.."0"..(beforeDecimal+afterDecimal+2)
    else
      -- The number after the 0 counts all digits + decimal point
      f = f.."0"..(beforeDecimal+afterDecimal+1)
    end
  end
  f = f.."."..afterDecimal.."f"

  local s = string.format(f, x)

  if trimTrailingZeros then
    -- Trim off 0s one at a time from the right
    while s:sub(-1) == "0" do s = s:sub(1,-2) end
    -- If there's nothing past the decimal now, trim the decimal too
    if s:sub(-1) == "." then s = s:sub(1,-2) end
  end

  return s
end

function utils.displayAnalog(v, valueType, posSymbol, negSymbol, options)
  -- Display a signed analog value, e.g. something that ranges
  -- anywhere from -100 to +100.
  -- Can provide custom positive/negative symbols such as > and <.
  local s = nil
  if valueType == 'int' then s = utils.intToStr(math.abs(v), options)
  elseif valueType == 'float' then s = utils.floatToStr(math.abs(v), options)
  else error("Unsupported valueType: "..tostring(valueType))
  end

  if v == 0 then s = "  "..s
  elseif v > 0 then s = posSymbol.." "..s
  else s = negSymbol.." "..s end
  return s
end



-- Functions for writing values to memory.

function utils.writeIntBE(address, value, numberOfBytesToWrite)
  local remainingValue = value
  local bytes = {}
  for n = numberOfBytesToWrite,1,-1 do
    byteValue = remainingValue % 256
    byteValue = tonumber(string.format("%.f", byteValue))  -- round to int
    remainingValue = (remainingValue - byteValue) / 256
    remainingValue = tonumber(string.format("%.f", remainingValue))
    bytes[n] = byteValue
  end

  writeBytes(address, bytes)
end

function utils.floatToInt(x)
  -- In: floating-point value
  -- Out: 4-byte integer value from the same bytes
  --
  -- For example, to see what you'd get if you pass in the number 47.125,
  -- go here and enter 47.125 in the top box:
  -- http://babbage.cs.qc.cuny.edu/IEEE-754.old/Decimal.html
  -- Then copy the "Hexadecimal" result until "Single precision (32 bits)", and
  -- go to Google search, paste that value, and type " in decimal" afterward.
  -- Do the search to get your integer.

  -- Reference: http://www.doc.ic.ac.uk/~eedwards/compsys/float/
  -- Bits: 31 - sign (s), 30-23 - exponent (e), 22-0 - mantissa (m)

  local s, absX = nil, nil
  if x > 0 then
    s = 0
    absX = x
  elseif x == 0.0 then
    -- This must be handled specially, otherwise we will attempt to compute
    -- log(0.0) later (which gives -inf, and long story short, doesn't give
    -- us the desired function result of 0 here).
    return 0
  else
    s = 1
    absX = -x
  end

  -- In Lua 5.1, math.log doesn't take a second argument for the base. Need to
  -- divide by log(2) to get the base-2 log.
  local e = math.floor(math.log(absX) / math.log(2))

  -- Compute the mantissa, which should end up between 0 and 1.
  local mantissa = (absX / (2^e)) - 1
  -- And encode it into 23 bits.
  local m = twoTo23 * mantissa

  -- Now we have all the parts, so put them together.
  local result = twoTo31*s + twoTo23*(e+127) + m
  return result
end

function utils.writeFloatBE(address, value, numberOfBytesToWrite)
  utils.writeIntBE(
    address, utils.floatToInt(value, numberOfBytesToWrite), numberOfBytesToWrite
  )
end



-- Scan for a string and return the address of the first result.
-- If there is no result, it returns nil.
function utils.scanStr(str)
  local startaddr=0
  local stopaddr=0x7fffffffffffffff
  local scan = createMemScan()
  scan.OnlyOneResult=true
  scan.firstScan(soExactValue,vtString,rtTruncated,str,"",startaddr,stopaddr,
  "+W-C",fsmNotAligned,"",false,false,false,true)
  scan.waitTillDone()
  return scan.getOnlyResult()
end



--
-- Inheritance related.
--

-- Kind of like inheritance, except it just copies the fields from the parents
-- to the children.
--
-- This means you can easily have multiple parents ordered by priority
-- (so the 2nd parent's stuff takes precedence over the 1st parent's, etc.).
--
-- It also means no "super" calls; you'd have to explicitly go
-- like MySuperClass.myFunc(self, ...) instead of doing a super call.
function utils.copyFields(child, parents)
  for _, parent in pairs(parents) do
    for key, value in pairs(parent) do
      if type(value) == 'table' then
        -- Simple assignment here would mean that the subclass and superclass
        -- share the same table for this field.
        -- Instead, we must build a new table.
        child[key] = {}
        utils.updateTable(child[key], value)
      else
        child[key] = value
      end
    end
  end
end

-- Basically a shortcut for copyFields.
function utils.subclass(...)
  local parents = {}
  for _, v in pairs({...}) do
    table.insert(parents, v)
  end

  local subcls = {}
  utils.copyFields(subcls, parents)
  return subcls
end

-- Create an object of a class, and call init() to initialize the object.
-- Similar to class instantiation in Python, or 'new' keyword in Java (init is
-- basically the constructor), etc.
function utils.classInstantiate(class, ...)
  local obj = utils.subclass(class)
  obj:init(...)
  return obj
end



return utils

