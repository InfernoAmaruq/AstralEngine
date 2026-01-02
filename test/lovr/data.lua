group('data', function()
  group('Blob', function()
    test(':getName', function()
      -- Test that Blob copies its name instead of relying on Lua string staying live
      blob = lovr.data.newBlob('foo', 'b' .. 'ar')
      collectgarbage()
      expect(blob:getName()).to.equal('b' .. 'ar')
    end)

    test(':set* byte range', function()
      blob = lovr.data.newBlob(1)
      expect(function() blob:setU8(-10, 7) end).to.fail()
      expect(function() blob:setU8(10, 7) end).to.fail()
      expect(function() blob:setF32(0, 7) end).to.fail()
    end)

    test(':setI8', function()
      blob = lovr.data.newBlob(16)
      for i = 1, 16 do blob:setI8(i - 1, i - 8) end
      for i = 1, 16 do expect(blob:getI8(i - 1)).to.equal(i - 8) end
    end)

    test(':setU8', function()
      blob = lovr.data.newBlob(16)
      for i = 1, 16 do blob:setU8(i - 1, i + 150) end
      for i = 1, 16 do expect(blob:getU8(i - 1)).to.equal(i + 150) end
    end)

    test(':setI16', function()
      blob = lovr.data.newBlob(4)
      blob:setI16(0, -5000, 5000)
      expect(blob:getI16(0)).to.equal(-5000)
      expect(blob:getI16(2)).to.equal(5000)
    end)

    test(':setU16', function()
      blob = lovr.data.newBlob(6)
      blob:setU16(0, 0, 1, 60000)
      expect(blob:getU16()).to.equal(0)
      expect({ blob:getU16(2, 2) }).to.equal({ 1, 60000 })
    end)

    test(':setI32', function()
      blob = lovr.data.newBlob(8)
      blob:setI32(4, -12345678)
      expect(blob:getI32(4)).to.equal(-12345678)
    end)

    test(':setU32', function()
      blob = lovr.data.newBlob(4)
      blob:setU32(0, 0xaabbccdd)
      expect(blob:getU32()).to.equal(0xaabbccdd)
      expect(blob:getU8(0)).to.equal(0xdd)
      expect(blob:getU8(1)).to.equal(0xcc)
      expect(blob:getU8(2)).to.equal(0xbb)
      expect(blob:getU8(3)).to.equal(0xaa)
    end)

    test(':setF32', function()
      blob = lovr.data.newBlob(12)
      blob:setF32(0, 1, -1000, 1000000)
      expect({ blob:getF32(0, 3) }).to.equal({ 1, -1000, 1000000 })
    end)

    test(':setF64', function()
      blob = lovr.data.newBlob(8)
      blob:setF64(0, 2 ^ 53)
      expect(blob:getF64(0)).to.equal(2 ^ 53)
    end)
  end)

  group('Image', function()
    test(':setPixel', function()
      local image = lovr.data.newImage(4, 4)
      image:setPixel(0, 0, 1, 0, 0, 1)
      expect({ image:getPixel(0, 0) }).to.equal({ 1, 0, 0, 1 })

      -- Default alpha
      image:setPixel(1, 1, 0, 1, 0)
      expect({ image:getPixel(1, 1) }).to.equal({ 0, 1, 0, 1 })

      -- Out of bounds
      expect(function() image:setPixel(4, 4, 0, 0, 0, 0) end).to.fail()
      expect(function() image:setPixel(-4, -4, 0, 0, 0, 0) end).to.fail()

      -- f16
      image = lovr.data.newImage(4, 4, 'rg16f')
      image:setPixel(0, 0, 1, 2, 3, 4)
      image:setPixel(3, 3, 9, 8, 7, 6)
      expect({ image:getPixel(0, 0) }).to.equal({ 1, 2, 0, 1 })
      expect({ image:getPixel(3, 3) }).to.equal({ 9, 8, 0, 1 })
    end)
  end)
end)
