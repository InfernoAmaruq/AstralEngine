local Renderer = select(1, ...)

Renderer.Late[#Renderer.Late + 1] = function()
    local RS = GetService("RunService")
    local Flag = bit.bor(RS.Flags.Raw, RS.Flags.Contextless)

    local CoreCamera = nil

    local function RenderFunc(Pass)
        Pass:reset()
        Pass:setDepthWrite(false)
        Pass:setSampler(CoreCamera[46] and "nearest" or "linear")
        Pass:fill(CoreCamera[1])
    end

    Renderer.SetPrimaryCamera = function(Camera)
        if Camera then
            if not CoreCamera then
                RS.BindToStep("_REND_TO_PASS", Enum.StepPriority.RenderSubmit.Value, RenderFunc, Flag)
            end
            CoreCamera = Camera
        else
            if CoreCamera then
                RS.UnbindFromStep("_REND_TO_PASS")
            end
            CoreCamera = nil
        end
    end

    Renderer.GetPrimaryCamera = function()
        return CoreCamera
    end
end
