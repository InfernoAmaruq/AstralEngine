local Renderer = select(1, ...)

Renderer.Late[#Renderer.Late + 1] = function()
    local RS = GetService("RunService")
    local Flag = RS.Flags.Raw | RS.Flags.Contextless

    local CoreCamera = nil
    local Bound = false

    local function RenderFunc(Pass)
        Pass:fill(CoreCamera[12][1])
    end

    Renderer.SetPrimaryCamera = function(Camera)
        if CoreCamera then
            CoreCamera[10] = false
        end
        CoreCamera = Camera
        Camera[10] = true

        if Camera and not Bound then
            Bound = true
            RS.BindToStep("_REND_TO_PASS", ENUM.StepPriority.RenderSubmit.RawValue, RenderFunc, Flag)
        elseif not CoreCamera and Bound then
            Bound = false
            RS.UnbindFromStep("_REND_TO_PASS")
        end
    end
end
