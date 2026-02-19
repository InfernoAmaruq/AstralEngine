local EntityService = GetService("Entity")

local WorldCam = RES["CAMERA"]
local CamComp = WorldCam.Camera

WorldCam:AddComponent("UICamera", { Camera = CamComp, ProcessInputs = true })
WorldCam:AddComponent("Ancestry")

local UICanvas = EntityService.New("Canvas")
UICanvas:AddComponent("UICanvas")
UICanvas.Ancestry.Parent = WorldCam
UICanvas.UIRoot.OffsetPosition = vec2(50, 50)
UICanvas.UIRoot.OffsetSize = vec2(100, 100)

local UICOMPONENT2 = EntityService.New("Canvas2")
UICOMPONENT2:AddComponent("UICanvas")
UICOMPONENT2.Ancestry.Parent = UICanvas
UICOMPONENT2.UIRoot.OffsetPosition = vec2(0, 0)
UICOMPONENT2.UIRoot.ScalePosition = vec2(1, 1)
UICOMPONENT2.UIRoot.ScaleSize = vec2(0, 0)
UICOMPONENT2.UIRoot.OffsetSize = vec2(50, 50)
UICOMPONENT2.UIRoot.AnchorPoint = vec2(0, 0)
UICOMPONENT2.UICanvas.Color = color.fromRGBA(255, 0, 0, 255)

local Loose = EntityService.New("Canvas4")
Loose:AddComponent("UICanvas")
Loose.Parent = WorldCam
Loose.UIRoot.ScalePosition = vec2(0.5, 0.5)
Loose.UIRoot.OffsetPositon = vec2(0, 0)
Loose.UIRoot.OffsetSize = vec2(300, 500)
Loose.UICanvas.Color = color.fromRGBA(100, 100, 100, 255)
Loose.UIRoot.AnchorPoint = vec2(0.5, 0.5)

local UITEXT = EntityService.New("Text")
UITEXT:AddComponent("UITexture", {
    Texture = GetService("AssetService").NewTexture("../Img/cart.png"),
    FitMode = ENUM.ImageFitMode.Fit,
})
UITEXT.Parent = Loose
UITEXT.UIRoot.ScaleSize = vec2(1, 1)
UITEXT.UIRoot.ZIndex = 1000000
