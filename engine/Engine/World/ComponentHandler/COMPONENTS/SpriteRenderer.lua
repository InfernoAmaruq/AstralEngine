local COMP = GetService("Component")
local REND = GetService("Renderer")

local SpriteRenderer = {}

local ProcessorFunc = function(p, _, c)
    if not c.SpriteRenderer[1] then
        return
    end
    p:setColor(1, 1, 1, 1)
    local TRANSFORM = c.Transform
    p:send("IsSprite", true)
    p:draw(c.SpriteRenderer[1][1], TRANSFORM[1], c.SpriteRenderer.Size, TRANSFORM[2])
    p:send("IsSprite", false)
end

local REnum = ENUM.RenderType
REnum.__Append("SpriteRenderer", 7)
-- NTS: ENUM.GetTop()
REND.AppendRenderTTP(REnum["SpriteRenderer"], ProcessorFunc)

local SRMT = {
    __index = function(self, k)
        if k == "Texture" then
            return self[1]
        end
    end,
    __newindex = function(self, k, v)
        if k == "Texture" then
            rawset(self, 1, v)
        end
    end,
}

SpriteRenderer.Name = "SpriteRenderer"
SpriteRenderer.Pattern = {}
SpriteRenderer.Metadata = {}
SpriteRenderer.Metadata.__create = function(DATA, Entity, ShouldSink)
    local Image = DATA.Texture

    local SR = {}
    SR.Size = DATA.Size or 1

    local RT = COMP.AddComponent(Entity, "RenderTarget", { Value = 7, Solid = false })
    if not COMP.HasComponent(Entity, "Transform") and not ShouldSink then
        COMP.AddComponent(Entity, "Transform")
    end

    SR[1] = Image
    setmetatable(SR, SRMT)

    return SR
end
SpriteRenderer.Metadata.__remove = function(self, Entity) end

return SpriteRenderer
