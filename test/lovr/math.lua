group('math', function()
  group('Curve', function()
    test(':slice', function()
      local points = {
        vec3(0, 0, 0),
        vec3(0, 1, 0),
        vec3(1, 2, 0),
        vec3(2, 1, 0),
        vec3(2, 0, 0)
      }

      curve = lovr.math.newCurve(points)
      slice = curve:slice(0, 1)
      for i = 1, #points do
        expect({ curve:getPoint(i) }).to.equal({ slice:getPoint(i) })
      end
    end)
  end)

  group('mat4', function()
    test('mul mat4', function()
      local a = mat4():perspective(math.rad(80), 1440 / 900, 0.01, 0)
      local b = mat4({ 0, 1.7, 0 }, { 0, 0, 0, 1 }):invert()
      local r = {
        0.74484598636627, 0, 0, 0, 0, -1.1917536258698,
        0, 0, 0, 0, 0, -1, 0, 2.0259811878204, 0.0099999997764826, 0
      }
      expect({ (a * b):unpack(true) }).to.equal(r, 1e-4)
      expect({ (a * b):unpack(true) }).to.equal(r, 1e-4)
      expect({ (a:mul(b)):unpack(true) }).to.equal(r, 1e-4)
    end)

    test('mul vec3', function()
      local m = mat4({ 0, 2, 0 }, { 0, 0, 0, 1 })
      expect(m * { 1, 2, 3 }).to.equal({ 1, 4, 3 })
      expect(m:mul({ 1, 2, 3 })).to.equal({ 1, 4, 3 })
      expect(m * { x = 1, y = 2, z = 3 }).to.equal({ x = 1, y = 4, z = 3 })
      expect(m:mul({ x = 1, y = 2, z = 3 })).to.equal({ x = 1, y = 4, z = 3 })

      local mt = { __index = { a = 123 } }
      local function inspect_val(v)
        return { v, getmetatable(v) }
      end
      expect(inspect_val(m * setmetatable({ 1, 2, 3 }, mt))).to.equal({ { 1, 4, 3 }, mt })
      expect(inspect_val(m:mul(setmetatable({ 1, 2, 3 }, mt)))).to.equal({ { 1, 4, 3 }, mt })
      expect(inspect_val(m * setmetatable({ x = 1, y = 2, z = 3 }, mt)))
        .to.equal({ { x = 1, y = 4, z = 3 }, mt })
      expect(inspect_val(m:mul(setmetatable({ x = 1, y = 2, z = 3 }, mt))))
        .to.equal({ { x = 1, y = 4, z = 3 }, mt })
    end)
  end)
end)
