local FS = lovr.filesystem

local Mounted = {}

lovr.filesystem.getMounted = function()
    return Mounted
end

local function RecursiveMount(Path, Search, CoreMountPoint, Recurse, Handler)
    local Files = FS.getDirectoryItems(Search)
    for _, v in ipairs(Files) do
        if FS.isDirectory(Search .. "/" .. v) then
            local TruePath = Path .. "/" .. v .. "/"

            local MountAt = CoreMountPoint .. "/" .. v
            if Handler then
                MountAt = Handler(v, TruePath, Search .. "/" .. v) or MountAt
            end

            local MountAttempt, Err = FS.mount(TruePath, MountAt, true)
            if MountAttempt then
                Mounted[MountAt] = TruePath
                if Recurse then
                    RecursiveMount(TruePath, Search .. "/" .. v, MountAt, true, Handler)
                end
            else
                print("Failed mount of:", Search .. "/" .. v, Err)
            end
        end
    end
end

return RecursiveMount
