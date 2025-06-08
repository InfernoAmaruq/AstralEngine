function lovr.conf(t)
  t.identity = 'test'
  t.modules.graphics = os.getenv and not os.getenv('CI')
  t.window = nil
end

-- TODO temporary workaround for Luau
collectgarbage = collectgarbage or function() end
