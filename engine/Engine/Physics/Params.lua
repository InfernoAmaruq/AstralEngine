local Params = {}

-- RAYCAST

do
    -- idx rules [[
    --  1 = Tags,
    --  2 = ObjTable,
    --  3 = Callback,
    --  4 = FilterType
    -- ]]

    Params.RaycastParams = {}
    local RT = Params.RaycastParams

    RT.FilterType = {
        Blacklist = 0,
        Whitelist = 1,
    }

    local RTMT = {
        __newindex = function(self, k, v) end,
        __index = function(self, k) end,
    }

    RT.New = function()
        return setmetatable({}, RTMT)
    end
end

-- OVERLAP

-- QUERRY

return Params
