local COMP = GetService("Component")
local REND = GetService("Renderer")

local SpriteRenderer = {}

local vec2 = vec2
local ProcessorFunc = function(p, _, c)
    if not c.Material then
        return
    end
    local SR = c.SpriteRenderer
    p:push("state")
    local TRANSFORM = c.Transform

    if SR[1] then
        local SCALE = TRANSFORM[5].xy
        local TEX_SCALE = vec2(c.Material[1]:getDimensions())
        local AR = TEX_SCALE.x / TEX_SCALE.y
        SCALE.y = SCALE.y / AR
        p:plane(TRANSFORM[1], SCALE, TRANSFORM[2])
    else
        p:plane(TRANSFORM[3])
    end
    p:pop("state")
end

local REnum = ENUM.RenderType
local Top = REnum:GetTop()
REnum.__Append("SpriteRenderer", Top + 1)
REND.AppendRenderTTP(REnum["SpriteRenderer"], ProcessorFunc)

local SRMT = {
    __index = function(self, k)
        if k == "ScaleWithAspect" then
            return self[1]
        end
    end,
    __newindex = function(SR, k, v)
        if k == "ScaleWithAspect" then
            SR[1] = v
        end
    end,
}

SpriteRenderer.Name = "SpriteRenderer"
SpriteRenderer.Metadata = {}
SpriteRenderer.Metadata.__create = function(DATA, Entity, ShouldSink)
    AstralEngine.Assert(
        not COMP.HasComponent(e, "RenderTarget"),
        "Entity already has RenderTarget component. Cannot bind more than 1 RenderTarget to an entity!"
    )

    local SR = {}

    local RT = COMP.AddComponent(Entity, "RenderTarget", { Value = Top + 1, Solid = false })
    if not COMP.HasComponent(Entity, "Transform") and not ShouldSink then
        COMP.AddComponent(Entity, "Transform")
    end

    SR[1] = DATA.ScaleWithAspect or false
    SR.__Ent = Entity
    setmetatable(SR, SRMT)

    return SR
end

SpriteRenderer.Metadata.__remove = function(_, e)
    if COMP.HasComponent(e, "RenderTarget") then
        COMP.RemoveComponent(e, "RenderTarget", true)
    end
end

SpriteRenderer.Metadata.SoftDependency = {
    Transform = true,
}
SpriteRenderer.Metadata.HardExclusison = {
    RenderTarget = true,
}

return SpriteRenderer
