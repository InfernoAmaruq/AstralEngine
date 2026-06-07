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

local MAINSHADER

Renderer.GetMainShader = function()
    return MAINSHADER
end

Renderer.SetMainShader = function(Shader)
    MAINSHADER = Shader
end

local OitExtractRaw = GetService"ShaderService".ComposeShader(ENUM.ShaderType.Fragment, "OIT/Composite",{Include = {"PostProcessing/AO/SSAO", "PostProcessing/Bloom/Extract.glsl", "Fog"}})
print(OitExtractRaw)
local OITEXTRACT = lovr.graphics.newShader('fill',OitExtractRaw)

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
local WeakMt = {__mode = "k"}
local SolidStack, TransparentStack = {Material = setmetatable({},WeakMt)}, {Material = setmetatable({},WeakMt)}

function Renderer.AddToStack(Solid,Entity,Material) -- number
    local Stack = Solid and SolidStack or TransparentStack

    if Material then
        Stack.Material[Material] = Stack.Material[Material] or {}
        Stack.Material[Material][#Stack.Material[Material]+1] = Entity
    else
        Stack[#Stack + 1] = Entity
    end

end

function Renderer.RemoveFromStack(Entity, Bool) -- number
    if Bool ~= nil then
        local Stack = Bool and SolidStack or TransparentStack
        local Idx = table.find(Stack,Entity)

        if not Idx then
            for _,t in pairs(Stack.Material) do
                local j = table.find(t,Entity)
                if j then
                    Idx = j
                    Stack = t
                end
            end
        end

        if not Idx then return end
        local Top = Stack[#Stack]
        Stack[Idx] = Top
        Stack[#Stack] = nil
    else
        for i = 1, 2 do
            local Stack = i == 1 and SolidStack or TransparentStack
            local Idx = table.find(Stack, Entity)

            if not Idx then
                for _,t in pairs(Stack.Material) do
                    local j = table.find(t,Entity)
                    if j then
                        Idx = j
                        Stack = t
                    end
                end
            end

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
        &PV:setFaceCull(CULL)
}

local VecZero,VecOne = Vec2(0,0),Vec2(1,1)

@macro<L,!USEBRACK>{SETMAINSHADERPARAMS(&PASS,&TRANSPARENT,&SH,&SB) = 
    &PASS:setShader(MAINSHADER)
    &PASS:send("Lighting_Ambience",CAMERA[9])
    &PASS:send("Transparent",&TRANSPARENT)
    &PASS:send("Lighting_Data",Renderer.Lighting.LightBuffer)

    &PASS:send("PBR_SphericalHarmonics",&SH)

    if &SB then
        &PASS:send("PBR_EnvMap",&SB)
    end
}

@macro<L,!USEBRACK>{PROCESSSTACK(&STACK, &PASS, &STATE) =
        for eind = 1, #&STACK do
            local E = &STACK[eind]
            local RenT = RendStorage[E]
            local Comp = SetComponents[E]
            local Mat = Comp.Material
            if (RenT[2] & CMASK) == 0 then
                continue
            end
            if Mat then
                &PASS:setColor(Mat[4])
                &PASS:send("Material_UVScale",Mat[2])
                &PASS:send("Material_UVOffset",Mat[3])
                &PASS:send("Material_FillMode",Mat[5])
                &PASS:send("Material_ObjectScale",Comp.Transform[5])
                &PASS:setSampler(Mat[6] and "nearest" or "linear")
            else
                &PASS:send("Material_UVScale",VecOne)
                &PASS:send("Material_UVOffset",VecZero)
                &PASS:send("Material_FillMode",0)
            end

            local RETFLAG = TYPETOPROCESS[RenT[1]](&PASS, E, Comp)
            if not RETFLAG then continue end
            if RETFLAG & &F_SHADER_RESET ~= 0 then
                SETMAINSHADERPARAMS(&PASS,&STATE,sh,sb)
            end
        end
}

function Renderer.DrawSolid()
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

    local GetMatrixPose = GetMatrixPose

    for cind = 1, #Cams do
        local e = Cams[cind]
        local CAMERA = CamStorage[e]

        local pass, SolidPass, TransPass = CAMERA[11][1], CAMERA[22][1], CAMERA[21][1]

        local CMASK = CAMERA[&Cam.Mask] -- cameramask
        local Projection = CAMERA[26]
        local MATRIX = TransStorage[e][3]
        local CULL = CAMERA[15] and 'back'

        pass:reset()
        SETPASSPARAMS(SolidPass)
        SETPASSPARAMS(TransPass)

        local sb = CAMERA[28]
        local sh = CAMERA[29]
        if sb then
            sb = sb[1] or sb
            SolidPass:skybox(sb)
        end

        SETMAINSHADERPARAMS(SolidPass,false,sh,sb)

        SolidPass:push('state')

        PROCESSSTACK(SolidStack,SolidPass,false)

        for LovrMat,t in pairs(SolidStack.Material) do
            SolidPass:setMaterial(LovrMat)
            PROCESSSTACK(t,SolidPass,false)
        end

        SolidPass:pop'state'
    end
end

function Renderer.DrawTransparent()
    local Cams = Cams
    local TransparentStack = TransparentStack
    local SetComponents = Component.SetComponents
    local CamStorage = Component.Components.Camera.Storage
    local TransStorage = Component.Components.Transform.Storage
    local RendStorage = Component.Components.RenderTarget.Storage

    for cind = 1, #Cams do
        local e = Cams[cind]
        local CAMERA = CamStorage[e]

        local CMASK = CAMERA[&Cam.Mask] -- cameramask

        local TransPass = CAMERA[21][1]

        TransPass:setDepthWrite(false)
        TransPass:setDepthTest('>=')
        TransPass:setBlendMode(1,'add','premultiplied')
        TransPass:setBlendMode(2,'add','premultiplied')

        local sb = CAMERA[28]
        local sh = CAMERA[29]
        sb = sb and sb[1] or sb

        SETMAINSHADERPARAMS(TransPass,true,sh,sb)

        TransPass:push('state')
        PROCESSSTACK(TransparentStack,TransPass,true)

        for LovrMat,t in pairs(TransparentStack.Material) do
            TransPass:setMaterial(LovrMat)
            PROCESSSTACK(t,TransPass,true)
        end
        TransPass:pop('state')
    end
end

local SSAO_Noise_Image = lovr.data.newImage(4,4,"rgba8")
math.randomseed(os.clock() * tonumber(debug.getaddress({})))
SSAO_Noise_Image:mapPixel(function()
    local x = math.random()
    local y = math.random()
    local Unit = vec2(x,y):normalize() * 255
    return Unit.x,Unit.y
end)
local SSAO_Noise_Texture = AstralEngine.Graphics.NewRawTexture(SSAO_Noise_Image,{usage = {"sample"}})
SSAO_Noise_Image:release()

local BlurShaderRaw = GetService"ShaderService".ComposeShader(ENUM.ShaderType.Fragment, "Camera/BlurPass")
local BlurSampler = lovr.graphics.newSampler({wrap = "clamp"})
local BlurShader = lovr.graphics.newShader("fill",BlurShaderRaw)

local FinalShaderRaw = GetService"ShaderService".ComposeShader(ENUM.ShaderType.Fragment, "Camera/Finalise")
local FinalShader = lovr.graphics.newShader("fill",FinalShaderRaw)

function Renderer.Composite()
    local Cams = Cams
    local Components = Component.Components
    local CamStorage = Components.Camera.Storage
    local TransStorage = Components.Transform.Storage

    for cind = 1, #Cams do
        local e = Cams[cind]
        local CAMERA = CamStorage[e]

        local pass = CAMERA[11][1]
        local compositePass = CAMERA[37][1]
        local blurPassH = CAMERA[38][1]
        local blurPassV = CAMERA[39][1]

        local Solid = CAMERA[20][1]
        local Transparent = CAMERA[13][1]
        local Reveal = CAMERA[23][1]

        local Proj = CAMERA[26]
        local Inv = mat4(Proj):invert()
        local VM = mat4(TransStorage[e][3]):invert()

        local Near = CAMERA[5]

        local Depth = CAMERA[24][1]

        -- get our camera data
        local BloomData = Components.BloomFX.Storage[e]
        local DoBloom = BloomData and BloomData.Active or false

        local DOFData = Components.DepthOfFieldFX.Storage[e]
        local DoDOF = DOFData and DOFData.Active or false

        local FogData = Components.FogFX.Storage[e]
        local DoFog = FogData and FogData.Active or false

        -- STEPS: Compsite, AO, Extract

        compositePass:reset()
        compositePass:setShader(OITEXTRACT)
        compositePass:setFaceCull()
        compositePass:setBlendMode("none")

        -- extract conf
        compositePass:send("OIT_TexSolid",Solid)
        compositePass:send("OIT_TexTransparent",Transparent)
        compositePass:send("OIT_TexReveal",Reveal)
        compositePass:send("OIT_TexDepth", Depth)
        compositePass:send("OIT_TexNormal", CAMERA[30][1])

        -- config fog
        compositePass:send("Fog_DoFog",DoFog)
        if DoFog then
            compositePass:send("Fog_CamNear",Near)
            compositePass:send("Fog_Info",FogData.__gpuBuffer)
        end

        -- config bloom
        compositePass:send("ExtractBloom",DoBloom)
        if DoBloom then
            compositePass:send("BrightnessThreshold",BloomData.Threshold)
        end

        -- ssao conf
        compositePass:send("Proj",Proj)
        compositePass:send("ProjInv",Inv)
        compositePass:send("ViewMatrix",VM)
        compositePass:send("SSAO_Noise",SSAO_Noise_Texture)

        compositePass:setDepthWrite(false)
        compositePass:setSampler('nearest')
        compositePass:fill()

        -- now we blur

        blurPassV:reset()
        blurPassV:setShader(BlurShader)
        blurPassV:setSampler(BlurSampler)

        blurPassH:reset()
        blurPassH:setShader(BlurShader)
        blurPassH:setSampler(BlurSampler)
        blurPassH:send("Horizontal",true)
        blurPassH:send("AO_Tex",CAMERA[34][1])
        blurPassH:send("DoBloom",DoBloom)
        blurPassH:send("Color_Tex",CAMERA[33][1])

        blurPassH:send("CamNear", Near)
        blurPassH:send("Depth_Tex",Depth)
        blurPassV:send("CamNear", Near)
        blurPassV:send("Depth_Tex",Depth)

        blurPassH:send("DoDOF",DoDOF)
        blurPassV:send("DoDOF",DoDOF)
        if DoDOF then
            local Dat = DOFData.__gpuBuffer
            local DataDist = DOFData.FadeDistance
            blurPassH:send("DOFData",Dat)
            blurPassH:send("DOFFadeDist",DataDist)
            blurPassV:send("DOFData",Dat)
            blurPassV:send("DOFFadeDist",DataDist)
        end

        if DoBloom then
            local Size, Strength = BloomData.Size, BloomData.Strength

            blurPassH:send("Bloom_Tex",CAMERA[36][1])
            blurPassH:send("BloomSize",Size)
            blurPassH:send("BloomStrength",Strength)

            blurPassV:send("BloomSize",Size)
            blurPassV:send("BloomStrength",Strength)
            blurPassV:send("Bloom_Tex",CAMERA[41][1])
        end

        blurPassH:fill()

        blurPassV:send("Horizontal",false)
        blurPassV:send("AO_Tex",CAMERA[42][1])
        blurPassV:send("Color_Tex",CAMERA[40][1])
        blurPassV:send("DoBloom",DoBloom)
        blurPassV:fill()

        -- now to main
        pass:reset()
        pass:setShader(FinalShader)

        pass:send("ColorTex",CAMERA[32][1])
        pass:send("AO",CAMERA[35][1])
        pass:send("DoBloom",DoBloom)
        pass:send("Bloom",CAMERA[31][1])

        -- set gamma and exposure
        pass:send("gamma",.9)
        pass:send("exposure",1)

        pass:fill()
    end
end

Renderer.Late[#Renderer.Late+1] = function()
    local RS = GetService("RunService")
    local Flag = RS.Flags.Raw | RS.Flags.Contextless

    RS.BindToStep("_REND_SCENE_SOLID",ENUM.StepPriority.RenderSceneSolid.RawValue,Renderer.DrawSolid,Flag)
    RS.BindToStep("_REND_SCENE_TRANS",ENUM.StepPriority.RenderSceneTransparent.RawValue,Renderer.DrawTransparent,Flag)
    RS.BindToStep("_REND_SCENE_COMPOSITE",ENUM.StepPriority.RenderSceneComposite.RawValue,Renderer.Composite,Flag)
end
