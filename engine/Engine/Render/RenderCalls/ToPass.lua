local Renderer = select(1, ...)

Renderer.Late[#Renderer.Late + 1] = function() end
