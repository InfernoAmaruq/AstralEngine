@flag{
    Cam.Mask = 1, Cam.Orth = 2, Cam.W = 7, Cam.H = 8, Cam.FOV = 6, Cam.Aspect = 3, Cam.Near = 5, Cam.Far = 4,
    STC.FaceCull = [2] and 'back', STC.ViewCull = 3
}

local Renderer = select(1, ...)

-- DECLARATIONS

local Window = AstralEngine.Window
local mat4 = mat4
local Orth = mat4.orthographic
local Pers = mat4.perspective

-- FLAGS

@flag{
    F_SHADER_RESET = 0xff00f1
}

Renderer.Flags = {
    SHADER_RESET = &F_SHADER_RESET
}

local ShaderService = GetService("ShaderService","ShaderService")
local V,F = ShaderService.ComposeShader(ENUM.ShaderType.Graphics,"Camera",{
    Include = {}
})

local MAINSHADER = lovr.graphics.newShader(V,F)

local OITCOMPOSITE = lovr.graphics.newShader('fill',[[
    uniform sampler2DMS TexSolid;
    uniform sampler2DMS TexTransparent;
    uniform sampler2DMS TexReveal;

    const int Samples = 4;

    vec3 ResolveRGB(sampler2DMS InputSampler, ivec2 UV){
        vec3 AccumColor = vec3(0.0);
        for (int i = 0; i < Samples; ++i){
            AccumColor += texelFetch(InputSampler,UV,i).rgb * 0.25;
        }
        return AccumColor;
    }

    vec2 ResolveRG(sampler2DMS InputSampler, ivec2 UV){
        vec2 AccumColor = vec2(0.0);
        for (int i = 0; i < Samples; ++i){
            AccumColor += texelFetch(InputSampler,UV,i).rg * 0.25;
        }
        return AccumColor;
    }

    vec4 lovrmain()
    {
        //vec3 Solid = getPixel(TexSolid,UV).rgb;
        //vec3 Accum = getPixel(TexTransparent,UV).rgb;
        //vec4 Reveal = getPixel(TexReveal,UV);

        ivec2 iUV = ivec2(UV.xy * Resolution);

        vec3 Solid = ResolveRGB(TexSolid,iUV);
        vec3 Accum = ResolveRGB(TexTransparent,iUV);
        vec2 Reveal = ResolveRG(TexReveal,iUV);

        float Norm = max(Reveal.g, 1e-5);
        vec3 TransColor = Accum / Norm;
        float TransAlpha = 1.0 - exp(-Reveal.r);

        return vec4(Solid * (1.0 - TransAlpha) + TransColor * TransAlpha,1.0);

        //return vec4(vec3(TransAlpha),1);
    }
]])

-- VARS
-- cams

local Cams = {}

function Renderer.AddCamera(Entity)
    Cams[#Cams + 1] = Entity
end

function Renderer.RemoveCamera(Entity)
    local Idx
    for _,v in ipairs(Cams) do
        if v == Entity then
            Idx = v
            break
        end
    end
    if not Idx then return end
    local Last = Cams[#Cams]
    Cams[Idx] = Last
    Cams[#Cams] = nil
end

-- stack

local SolidStack, TransparentStack = {}, {}

function Renderer.AddToStack(Solid,Entity) -- number
    local Stack = Solid and SolidStack or TransparentStack
    Stack[#Stack + 1] = Entity
end

function Renderer.RemoveFromStack(Entity, Bool) -- number
    if Bool ~= nil then
        local Stack = Bool and SolidStack or TransparentStack
        local Idx = table.find(Stack,Entity)
        if not Idx then return end
        local Top = Stack[#Stack]
        Stack[Idx] = Top
        Stack[#Stack] = nil
    else
        for i = 1, 2 do
            local Stack = i == 1 and SolidStack or TransparentStack
            local Idx = table.find(Stack, Entity)
            if not Idx then continue end
            local Last = Stack[#Stack]
            Stack[Idx] = Last
            Stack[#Stack] = nil
        end
    end
end

local Component = GetService("Component","Component")

local TYPETOPROCESS = {}

function Renderer.AppendRenderTTP(Enum, Func)
    assert(typeof(Enum) == "__ENUM_RenderType", "Enum passed not a render type enum")
    local Val = Enum.RawValue

    TYPETOPROCESS[Val] = Func
end

@macro<L,!USEBRACK>{SETPASSPARAMS(&PV) =
        &PV:reset()
        &PV:setViewPose(1, MATRIX)
        &PV:setProjection(1, Projection)
        &PV:setShader(MAINSHADER)
        &PV:setFaceCull(CULL)
}

@macro<L,!USEBRACK>{PROCESSSTACK(&STACK, &PASS) =
        for eind = 1, #&STACK do
            local E = &STACK[eind]
            local RenT = RendStorage[E]
            if RenT[2] !&== CMASK then
                continue
            end
            local RETFLAG = TYPETOPROCESS[RenT[1]](&PASS, E, SetComponents[E])
            if not RETFLAG then continue end
            if RETFLAG &== &F_SHADER_RESET then
                &PASS:setShader(MAINSHADER)
            end
        end
}

function Renderer.DrawScene(Frame)
    if not Frame then print("RESIZING") return end
    local Cams = Cams
    local TransparentStack = TransparentStack
    local SolidStack = SolidStack
    local SetComponents = Component.SetComponents
    local W, H = Window.W, Window.H
    local BaseRatio = W / H

    local Matrix = mat4
    local Pers = Pers
    local Orth = Orth
    local TYPETOPROCESS = TYPETOPROCESS

    local CamStorage = Component.Components.Camera.Storage
    local TransStorage = Component.Components.Transform.Storage
    local RendStorage = Component.Components.RenderTarget.Storage

    local HalfH = H / 2
    local HalfW = W / 2

    local DrawnToScreen = false

    for cind = 1, #Cams do
        local e = Cams[cind]
        local CAMERA = CamStorage[e]

        local pass, SolidPass, TransPass = CAMERA[11][1], CAMERA[22][1], CAMERA[21][1]

        local CMASK = CAMERA[&Cam.Mask] -- cameramask

        local Projection = CAMERA[&Cam.Orth]
            and Orth(
                Matrix(),
                CAMERA[7] or -HalfW,
                CAMERA[8] or HalfW,
                HalfH,
                -HalfH,
                CAMERA[5],
                CAMERA[4]
            )                                                                 -- W, H, Near, Far
            or Pers(Matrix(), CAMERA[6], CAMERA[3] or BaseRatio, CAMERA[5], CAMERA[4]) -- FOV, Aspect, Near, Far
        local MATRIX = TransStorage[e][3]
        local CULL = CAMERA[15] and 'back'

        pass:reset()
        SETPASSPARAMS(SolidPass)
        SETPASSPARAMS(TransPass)

        SolidPass:send('Transparent',false)

        -- INITIAL PASSES
        PROCESSSTACK(SolidStack,SolidPass)
        TransPass:setDepthWrite(false)
        TransPass:setDepthTest('>=')
        TransPass:setBlendMode(1,'add','premultiplied')
        TransPass:setBlendMode(2,'add','premultiplied')
        TransPass:send('Transparent', true)
        PROCESSSTACK(TransparentStack,TransPass)

        -- MIXING

        local Solid = CAMERA[20][1]
        local Transparent = CAMERA[13][1]
        local Reveal = CAMERA[23][1]

        pass:setShader(OITCOMPOSITE)
        pass:setFaceCull()
        pass:setBlendMode("none")
        pass:send("TexSolid",Solid)
        pass:send("TexTransparent",Transparent)
        pass:send("TexReveal",Reveal)
        pass:setDepthTest()
        pass:setDepthWrite(false)
        pass:setSampler'nearest'

        pass:fill()

        if not DrawnToScreen and CAMERA[10] then
            Frame:setDepthWrite(false)
            Frame:setSampler(CAMERA[16] and 'nearest' or 'linear')
            Frame:fill(CAMERA[12][1])
            DrawnToScreen = true
        end
    end
end

Renderer.Late[#Renderer.Late+1] = function()
end
