local COMP = GetService("Component")
local REND = GetService("Renderer")

local SpriteRenderer = {}

local NULL_BUFFER = lovr.graphics.newBuffer("i32x4",{-1,-1,-1,-1})
local ProcessorFunc = function(p, _, c)
    local SR = c.SpriteRenderer
    local Img = SR[1]
    if not Img then
        return
    end
    p:push('state')
    p:setColor(SR[2],SR[3],SR[4],SR[5])
    local TRANSFORM = c.Transform
    if rawget(Img,2) then
        p:send("AtlasData",Img[2])
    else
        p:send("AtlasData",NULL_BUFFER)
    end
    local Sampler = SR[6]

    if Sampler then p:setSampler"nearest" end

    if SR[7] then
        p:draw(Img[1] or Img, TRANSFORM[3])
    else
        p:setMaterial(Img[1] or Img)
        p:plane(TRANSFORM[3])
    end
    p:pop('state')
end

local REnum = ENUM.RenderType
local Top = REnum:GetTop()
REnum.__Append("SpriteRenderer", Top + 1)
REND.AppendRenderTTP(REnum["SpriteRenderer"], ProcessorFunc)

local SRMT = {
    __index = function(self, k)
        if k == "Texture" then
            return self[1]
        elseif k == "Color" then
            return self.__ClrVal
        elseif k == "UseNearest" then
            return self[6]
        elseif k == "ScaleWithAspect" then
            return self[7]
        end
    end,
    __newindex = function(SR, k, v)
        if k == "Texture" then
            rawset(SR, 1, v)
        elseif k == "UseNearest" then
            SR[6] = v
        elseif k == "Color" then
            assert(color.validate(v), v.." IS NOT A VALID COLOR")
            SR.__ClrVal = v
            local OldAlpha = SR[5]
            WRITECOLOR(v)
            local NewAlpha = SR[5]
            local RT = self.__RenderTypePtr
            if OldAlpha == 1 and NewAlpha < 1 then
                RT[".ToStack"](RT,true)
            elseif NewAlpha == 1 and OldAlpha < 1 then
                RT[".FromStack"](RT,true)
            end
        elseif k == "ScaleWithAspect" then
            SR[7] = v
        end
    end,
}

@macro<L,!USEBRACK>:WRITECOLOR(&C) = SR[2], SR[3], SR[4], SR[5] = color.unpack(&C);

SpriteRenderer.Name = "SpriteRenderer"
SpriteRenderer.Pattern = {}
SpriteRenderer.Metadata = {}
SpriteRenderer.Metadata.__create = function(DATA, Entity, ShouldSink)
    AstralEngine.Assert(not COMP.HasComponent(e,"RenderTarget"), "Entity already has RenderTarget component. Cannot bind more than 1 RenderTarget to an entity!")

    local Image = DATA.Texture

    local SR = {}

    local RT = COMP.AddComponent(Entity, "RenderTarget", { Value = Top + 1, Solid = false })
    if not COMP.HasComponent(Entity, "Transform") and not ShouldSink then
        COMP.AddComponent(Entity, "Transform")
    end

    local Color = DATA.Color or color.fromRGBA(255,255,255,255)
    WRITECOLOR(Color)

    if SR[5] == 1 then
        RT[".ToStack"](RT,true)
    end

    SR.__ClrVal = Color
    SR[1] = Image
    SR[6] = DATA.UseNearest or false
    SR[7] = DATA.ScaleWithAspect or false
    SR.__Ent = Entity
    SR.__RenderTypePtr = RT
    setmetatable(SR, SRMT)

    return SR
end

SpriteRenderer.Metadata.__remove = function(_,e)
    if COMP.HasComponent(e,"RenderTarget") then
        COMP.RemoveComponent(e,"RenderTarget",true)
    end
end

SpriteRenderer.Metadata.SoftDependency = {
    Transform = true
}
SpriteRenderer.Metadata.HardExclusison = {
    RenderTarget = true
}

return SpriteRenderer
