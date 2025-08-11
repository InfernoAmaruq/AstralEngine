function lovr.conf(t)
  t.identity = 'test'
  t.modules.graphics = arg[1] ~= '--headless'
  t.window = nil
end
