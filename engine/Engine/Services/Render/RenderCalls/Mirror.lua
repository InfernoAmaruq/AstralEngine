local Renderer = select(1, ...)

Renderer.Late[#Renderer.Late + 1] = function()
    if not lovr.headset then
        return
    end
    local RS = GetService("RunService")
    local Flag = RS.Flags.Raw | RS.Flags.Contextless

    RS.BindToStep("_MIRROR_TO_WINDOW", ENUM.StepPriority.RenderMirror, function()
        local Tex = lovr.headset.getTexture()
        lovr.graphics.getWindowPass():fill(Tex)
    end, Flag)
end
