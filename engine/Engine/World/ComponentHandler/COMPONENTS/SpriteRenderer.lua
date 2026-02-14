local COMP = GetService("Component")
local REND = GetService("Renderer")

local SpriteRenderer = {}

local NULL_BUFFER = lovr.graphics.newBuffer("i32x4",{-1,-1,-1,-1})
local ProcessorFunc = function(p, _, c)
    local SR = c.SpriteRenderer
    if not SR[1] then
        return
    end
    p:push('state')
    p:setColor(SR[3],SR[4],SR[5],SR[6])
    local TRANSFORM = c.Transform
    if rawget(SR[1],2) then
        p:send("AtlasData",SR[1][2])
    else
        p:send("AtlasData",NULL_BUFFER)
    end
    local Sampler = SR[7]

    if Sampler then p:setSampler"nearest" end

    if SR[8] then
        p:draw(SR[1][1] or SR[1], TRANSFORM[1], SR[2], TRANSFORM[2])
    else
        p:setMaterial(SR[1][1] or SR[1])
        p:plane(TRANSFORM[1], SR[2], TRANSFORM[2])
    end
    p:pop('state')
end

local REnum = ENUM.RenderType
local Top = REnum:GetTop()
REnum.__Append("SpriteRenderer", Top)
REND.AppendRenderTTP(REnum["SpriteRenderer"], ProcessorFunc)

local SRMT = {
    __index = function(self, k)
        if k == "Texture" then
            return self[1]
        elseif k == "Size" then
            return self[2].xy
        elseif k == "Color" then
            return self.__ClrVal
        elseif k == "UseNearest" then
            return self[7]
        elseif k == "ScaleWithAspect" then
            return self[8]
        end
    end,
    __newindex = function(SR, k, v)
        if k == "Texture" then
            rawset(SR, 1, v)
        elseif k == "UseNearest" then
            SR[7] = v
        elseif k == "Size" then
            SR[2]:set(v.x,v.y,1e-7)
            local ColComp = COMP.HasComponent(SR.__Ent,"Collider")
            if ColComp then
                ColComp:OnDrawComponentResize(vec3(SR[2]))
            end
        elseif k == "Color" then
            assert(color.validate(v), v.." IS NOT A VALID COLOR")
            SR.__ClrVal = v
            local OldAlpha = SR[6]
            WRITECOLOR(v)
            local NewAlpha = SR[6]
            local RT = self.__RenderTypePtr
            if OldAlpha == 1 and NewAlpha < 1 then
                RT[".ToStack"](RT,true)
            elseif NewAlpha == 1 and OldAlpha < 1 then
                RT[".FromStack"](RT,true)
            end
        elseif k == "ScaleWithAspect" then
            SR[8] = v
        end
    end,
}

@macro<L,!USEBRACK>:WRITECOLOR(&C) = SR[3], SR[4], SR[5], SR[6] = color.unpack(&C);

SpriteRenderer.Name = "SpriteRenderer"
SpriteRenderer.Pattern = {}
SpriteRenderer.Metadata = {}
SpriteRenderer.Metadata.__create = function(DATA, Entity, ShouldSink)
    AstralEngine.Assert(not COMP.HasComponent(e,"RenderTarget"), "Entity already has RenderTarget component. Cannot bind more than 1 RenderTarget to an entity!")

    local Image = DATA.Texture

    local SR = {}
    local RawVec = DATA.Size or vec2(1,1)
    local RealSize = Vec3(RawVec.x,RawVec.y,1e-7) -- make Z incredibly thin so collider can read from it

    local RT = COMP.AddComponent(Entity, "RenderTarget", { Value = Top, Solid = false })
    if not COMP.HasComponent(Entity, "Transform") and not ShouldSink then
        COMP.AddComponent(Entity, "Transform")
    end

    local Color = DATA.Color or color.fromRGBA(255,255,255,255)
    WRITECOLOR(Color)

    if SR[6] == 1 then
        RT[".ToStack"](RT,true)
    end

    SR.__ClrVal = Color
    SR[2] = RealSize
    SR[1] = Image
    SR[7] = DATA.UseNearest or false
    SR[8] = DATA.ScaleWithAspect or false
    SR.__Ent = Entity
    SR.__RenderTypePtr = RT
    setmetatable(SR, SRMT)

    return SR
end

SpriteRenderer.FinalProcessing = function()
   GetService"Physics".BindSizeComponent("SpriteRenderer",2)

    if COMP.TransformRequired then
        table.insert(COMP.TransformRequired,SpriteRenderer.Name)
    end
end

return SpriteRenderer
