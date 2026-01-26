local Params = {}

-- RAYCAST

local Physics = GetService("Physics", "Physics")

do
    -- idx rules [[
    --  1 = Tags,
    --  2 = ObjTable,
    --  3 = Callback,
    --  4 = FilterType
    -- ]]

    Params.RaycastParams = {}
    local RT = Params.RaycastParams

    local BlacklistRaw = 1
    local WhitelistRaw = 2

    ENUM({ Blacklist = BlacklistRaw, Whitelist = WhitelistRaw }, "RaycastFilterType")

    local RTF = {
        RecomputeTags = function(self)
            local BaseString = table.concat(self[".LiveTags"])

            for _, v in ipairs(self[".StaticTags"]) do
                BaseString = BaseString .. " ~" .. v
            end

            self[".Tags"] = BaseString
        end,
        GetTags = function(self, Static)
            return Static and self[".StaticTags"] or self[".LiveTags"]
        end,
        AddTag = function(self, Tag, Static)
            local To = Static and self[".StaticTags"] or self[".LiveTags"]
            table.insert(To, Tag)
            self:RecomputeTags()
        end,
        RemoveTag = function(self, Tag, Static)
            local To = Static and self[".StaticTags"] or self[".LiveTags"]
            table.remove(To, table.find(Static, Tag))
            self:RecomputeTags()
        end,
    }

    local RTMT = {
        __index = function(self, k)
            if k == "FilterType" then
                return _[".RFilterType"]
            end
            return RTF[k]
        end,
        __newindex = function(self, k, v)
            if k == "FilterType" then
                rawset(self, ".RFilterType", v.RawValue)
            end
        end,
    }

    RT.New = function()
        local Tab = {
            [".StaticTags"] = {},
            [".LiveTags"] = {},
            [".Tags"] = nil, -- string
            GetFirst = true,
            FilterInstances = {},
        }

        local BaseCallback = function(C, S, x, y, z, nx, ny, nz, tri, frac)
            local CT = Tab
            local Type = CT[".RFilterType"]
            local Out = CT.__OUT

            local Valid = true
            if List and Type then
                local Entity = C:getUserData().Entity
                if Type == WhitelistRaw then
                    Valid = CT.FilterInstances[Entity] and true or false
                else
                    Valid = not CT.FilterInstances[Entity]
                end
            end
            if Valid then
                local Obj = Physics.RaycastData.New()
                Obj.Position:set(x, y, z)
                Obj.Normal:set(nx, ny, nz)
                Obj.Collider = C
                Obj.Shape = S
                Obj.TriId = tri
                Obj.Entity = C and C:getUserData().Entity
                if Out then
                    Out[#Out + 1] = Obj
                else
                    rawset(CT, "__OUT", Obj)
                    return 1
                end
            end
            return frac
        end

        Tab.Callback = BaseCallback

        return setmetatable(Tab, RTMT)
    end

    RT.Default = RT.New()
end

-- OVERLAP

-- QUERRY

return Params
