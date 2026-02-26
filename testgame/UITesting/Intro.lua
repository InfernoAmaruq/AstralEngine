local SignalPlugin = AstralEngine.Plugins.SignalLib

local ES = GetService("Entity")
local IntroModule = {}
IntroModule.__index = IntroModule

local IntroTime = 4

local FlameLogo = [[



     δ   σ
             δ
    /\   /\
δ   \/·`·\/
    «_@ @_»
 σ    \w/ σ
  δ
            δ



  > Flare Amaro
]]

-- allocing directly cause its about as temp as shit can be
local Folder = lovr.filesystem.folderFromPath(lovr.filesystem.getCurrentPath())
local Font = lovr.graphics.newFont(Folder .. "IntroFont.ttf")
local Logo = lovr.graphics.newTexture(Folder .. "Logo.png")

IntroModule.Load = function(Camera, Time)
    IntroTime = Time or IntroTime
    local Data = {}

    Data.Finished = SignalPlugin.new(SignalPlugin.Type.NoCtx | SignalPlugin.Type.RTC)

    local UICam = ES.New("IntroCam")
    UICam:AddComponent("UICamera", {
        Camera = Camera,
    })

    -- define bg
    local BackgroundCanvas = ES.New("BGCanvas")
    BackgroundCanvas:AddComponent("Ancestry")
    BackgroundCanvas:AddComponent("UIRoot", {
        Size = { Scale = vec2(1, 1) },
    })
    BackgroundCanvas:AddComponent("UICanvas", { Color = color.fromRGB(0, 0, 0) })
    BackgroundCanvas.Parent = UICam

    -- define fg
    local FGCanvas = ES.New("FGCanvas")
    FGCanvas:AddComponent("Ancestry")
    FGCanvas:AddComponent("UIRoot", {
        Size = { Scale = vec2(1, 1) },
        ZIndex = 100,
    })
    FGCanvas:AddComponent("UICanvas", { Color = color.fromRGBA(0, 0, 0, 0) })
    FGCanvas.Parent = BackgroundCanvas

    -- define textbox w logo
    --[[local TextBox = ES.New("UIText")
    TextBox:AddComponent("Ancestry")
    TextBox:AddComponent("UIRoot", {
        Size = { Scale = vec2(1, 1) },
        Position = { Scale = vec2(-0.02, 0) },
    })
    TextBox:AddComponent("UIText", { Color = color.fromRGB(255, 0, 0), Text = FlameLogo, Font = Font, FontSize = 60 })
    TextBox.Parent = BackgroundCanvas]]

    local AstralLogo = ES.New("LogoTexture")
    AstralLogo:AddComponent("Ancestry")
    AstralLogo:AddComponent("UIRoot", {
        Size = { Scale = vec2(1, 1) },
    })

    AstralLogo:AddComponent("UITexture", {
        Texture = Logo,
        FitMode = ENUM.ImageFitMode.Fit,
    })
    AstralLogo.Parent = BackgroundCanvas

    Data.Objects = {
        Camera = UICam,
        BG = BackgroundCanvas,
        FG = FGCanvas,
        Logo = AstralLogo,
    }

    setmetatable(Data, IntroModule)

    return Data
end

local BindName = "__SPLASHSCREEN_INTO_TICK"
local RS = GetService("RunService")

local Timer = 0
local Obj = nil
local Playing = false
local Func = function(dt)
    Timer = Timer + dt

    local Half = IntroTime / 2
    local n = 1 - (0.5 - 0.5 * math.cos(math.pi * (Timer / Half)))
    Obj.Objects.FG.UICanvas.Color = color.fromRGBA(0, 0, 0, n * 255)

    if Timer >= IntroTime then
        Obj.Objects.FG:Destroy()
        Obj.Objects.Logo:Destroy()
        Obj.Objects.BG:Destroy()
        Obj.Objects.Camera:Destroy()
        Logo:release()
        Font:release()
        RS.UnbindFromStep(BindName)
        Obj.Finished:Fire()
    end
end

IntroModule.Play = function(self)
    if Playing then
        return
    end
    Obj = self
    Playing = true
    RS.BindToStep(BindName, 500, Func)
end

return IntroModule
