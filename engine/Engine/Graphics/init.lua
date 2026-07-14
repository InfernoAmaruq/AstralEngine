local OgTex = lovr.graphics.newTexture
local FS = lovr.filesystem

local RefToRebuild = setmetatable({}, { __mode = "v" })

local function ResolvePath(Path)
    if FS.isFile(Path) then
        return Path
    end
    local CallFrom = debug.getinfo(3, "S")
    local LocalizedPath = CallFrom.source:gsub("%@")

    return FS.normalize(FS.folderFromPath(LocalizedPath) .. Path)
end

AstralEngine.Graphics = {
    NewTexture = function(...)
        local Args = { ... }

        if type(Args[1]) == "string" then
            Args[1] = ResolvePath(Args[1])
        end

        return OgTex(unpack(Args))
    end,
    NewPass = lovr.graphics.newPass,
    NewTextureView = lovr.graphics.newTextureView,
    NewBuffer = lovr.graphics.newBuffer,

    SetBackgroundColor = lovr.graphics.setBackgroundColor,
    GetBackgroundColor = lovr.graphics.getBackgroundColor,
    EnableTiming = lovr.graphics.setTimingEnabled,
    IsTimingEnabled = lovr.graphics.isTimingEnabled,
    GetDefaultFont = lovr.graphics.getDefaultFont,
}

function AstralEngine.Window.__WindowResizedTextures(...)
    for _, v in pairs(RefToRebuild) do
        if v.ResizeCallback then
            v.ResizeCallback(v, v.__IsPass, ...)
        end
    end
end

AstralEngine.Graphics.GPU = require("DeviceQuery")
