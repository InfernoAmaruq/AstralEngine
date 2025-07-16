function lovr.conf(t)
  t.identity = 'test'
  t.modules.graphics = not lovr.filesystem.getSource():match('/home/runner')
  t.window = nil
end
