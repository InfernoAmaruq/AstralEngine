local Renderer = select(1, ...)

Renderer.Late[#Renderer.Late + 1] = function()
    local RS = GetService("RunService")
    local Flag = RS.Flags.Raw | RS.Flags.Contextless

    local CoreCamera = nil
    local Bound = false

    local function RenderFunc(Pass)
        Pass:setDepthWrite(false)
        Pass:setSampler(CoreCamera[16] and "nearest" or "linear")
        Pass:fill(CoreCamera[12][1])
    end

    Renderer.SetPrimaryCamera = function(Camera, State)
        if State then
            if CoreCamera then
                CoreCamera[10] = false
            end
            CoreCamera = Camera
            Camera[10] = true
            if not Bound then
                Bound = true
                RS.BindToStep("_REND_TO_PASS", ENUM.StepPriority.RenderSubmit.RawValue, RenderFunc, Flag)
            end
        elseif not State and Camera == CoreCamera then
            CoreCamera = nil
            Camera[10] = falses
            RS.UnbindFromStep("_REND_TO_PASS")
            Bound = false
        end
    end
end
