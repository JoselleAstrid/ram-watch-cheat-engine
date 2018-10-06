-- Tests for utils.lua.

-- To run these tests, get luaunit.lua from here:
-- https://github.com/bluebird75/luaunit
-- and put that luaunit file in the same directory as this file.
-- Then use your system's lua .exe to run this file.

local lu = require 'luaunit'

-- Add main RWCE directory to path
package.path = "../?.lua;" .. package.path

package.loaded.utils = nil
local utils = require 'utils'
local floatToStr = utils.floatToStr


TestFloatToStr = {}

function TestFloatToStr:testNil()
  lu.assertEquals(floatToStr(nil), "nil")
end

function TestFloatToStr:testNoOptions()
  -- afterDecimal defaults to 3
  lu.assertEquals(floatToStr(3.0), "3.000")
end

function TestFloatToStr:testBeforeDecimal()
  -- Add zeroes to reach 3 digits before decimal
  lu.assertEquals(floatToStr(1.234, {beforeDecimal=3}), "001.234")
  -- Already have 3 digits before decimal; no extra zeroes
  lu.assertEquals(floatToStr(123.456, {beforeDecimal=3}), "123.456")
  -- Already have more than 3 digits before decimal; no extra zeroes
  lu.assertEquals(floatToStr(1234.567, {beforeDecimal=3}), "1234.567")
  -- Same as above, but with negative sign
  lu.assertEquals(floatToStr(-1.234, {beforeDecimal=3}), "-01.234")
  lu.assertEquals(floatToStr(-12.345, {beforeDecimal=3}), "-12.345")
  lu.assertEquals(floatToStr(-123.456, {beforeDecimal=3}), "-123.456")
end

function TestFloatToStr:testLeftPaddingMethod()
  -- Zeroes
  lu.assertEquals(
    floatToStr(1.234, {beforeDecimal=3, leftPaddingMethod='zero'}), "001.234")
  lu.assertEquals(
    floatToStr(-1.234, {beforeDecimal=3, leftPaddingMethod='zero'}), "-01.234")
  lu.assertEquals(
    floatToStr(0.234, {beforeDecimal=3, leftPaddingMethod='zero'}), "000.234")
  lu.assertEquals(
    floatToStr(-0.234, {beforeDecimal=3, leftPaddingMethod='zero'}), "-00.234")
  -- Spaces
  lu.assertEquals(
    floatToStr(1.234, {beforeDecimal=3, leftPaddingMethod='space'}), "  1.234")
  lu.assertEquals(
    floatToStr(-1.234, {beforeDecimal=3, leftPaddingMethod='space'}), " -1.234")
  lu.assertEquals(
    floatToStr(0.234, {beforeDecimal=3, leftPaddingMethod='space'}), "  0.234")
  lu.assertEquals(
    floatToStr(-0.234, {beforeDecimal=3, leftPaddingMethod='space'}), " -0.234")
end

function TestFloatToStr:testAfterDecimal()
  -- Round down
  lu.assertEquals(floatToStr(1.249, {afterDecimal=1}), "1.2")
  -- Round up
  lu.assertEquals(floatToStr(1.251, {afterDecimal=1}), "1.3")
  -- Add zeroes
  lu.assertEquals(floatToStr(1.25, {afterDecimal=5}), "1.25000")
  -- Before and after options together
  lu.assertEquals(floatToStr(1.25, {beforeDecimal=3, afterDecimal=5}), "001.25000")
  lu.assertEquals(floatToStr(-1.25, {beforeDecimal=3, afterDecimal=5}), "-01.25000")
end

function TestFloatToStr:testTrimTrailingZeros()
  lu.assertEquals(floatToStr(1.25, {afterDecimal=5, trimTrailingZeros=true}), "1.25")
  -- Integer
  lu.assertEquals(floatToStr(1.0, {afterDecimal=5, trimTrailingZeros=true}), "1")
end

function TestFloatToStr:testSigned()
  -- Positive
  lu.assertEquals(floatToStr(1.25, {signed=true}), "+1.250")
  lu.assertEquals(floatToStr(1.25, {beforeDecimal=3, signed=true}), "+01.250")
  -- Negative
  lu.assertEquals(floatToStr(-1.25, {signed=true}), "-1.250")
  lu.assertEquals(floatToStr(-1.25, {beforeDecimal=3, signed=true}), "-01.250")
end


lu.LuaUnit:run()
