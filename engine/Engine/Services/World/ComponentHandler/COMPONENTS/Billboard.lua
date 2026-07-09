local Component = GetService("Component", "Component")
local Render = GetService("Renderer")

local Billboard = {}
Billboard.Name = "Billboard"
Billboard.Metadata = {}

Billboard.Metadata.__create = function(Data, Ent)
    AstralEngine.Assert(
        not Component.GetComponent(e, "RenderTarget"),
        "Entity already has RenderTarget component. Cannot bind more than 1 RenderTarget to an entity!",
        "Billboard"
    )

    local RT = Component.AddComponent(e, "RenderTarget")

    RT:Update(RT:GetMaterial(), RT.Flags.Stack_Solid, Val, Val, RT:GetShader())
end

Billboard.Metadata.__create = function(_, e)
    if Component.GetComponent(e, "RenderTarget") then
        Component.RemoveComponent(e, "RenderTarget", true)
    end
end

return Billboard
