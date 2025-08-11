io.stdout:setvbuf('no')
print('running tests')
group('lovr', function()
  for i, file in ipairs(lovr.filesystem.getDirectoryItems('lovr')) do
    local module = file:match('%a+')
    if lovr[module] then
      print(('running %s tests'):format(module))
      require('lovr/' .. module)
    end
  end
end)
