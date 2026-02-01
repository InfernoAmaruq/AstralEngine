local Data = {}

do
    local PoolSize = 100
    local Top = PoolSize
    local DATAPOOL = table.array(PoolSize)

    local MT = {
        __tostring = function(self)
            if not self.Entity then
                return "Query Result: N\\A"
            end
            return "Query Result: "
                .. tostring(self.Entity)
                .. " at "
                .. tostring(self.Position)
                .. " & "
                .. tostring(self.Normal)
        end,
    }

    local function Alloc(IsTemp)
        return setmetatable({
            __temp = IsTemp,
            Position = IsTemp and vec3() or Vec3(),
            Normal = IsTemp and vec3() or Vec3(),
            Collider = nil,
            TriId = nil,
            Shape = nil,
            Entity = nil,
        }, MT)
    end

    local function GetTab()
        if Top > 0 then
            local t = DATAPOOL[Top]
            t.Entity = nil
            Top = Top - 1
            return t
        end
        return Alloc(true)
    end

    local function ReleaseTab(Obj)
        if Obj.__temp then
            return
        end
        Top = Top + 1
        DATAPOOL[Top] = Obj
    end

    for i = 1, PoolSize do
        DATAPOOL[i] = Alloc()
    end

    local QueryData = {}

    QueryData.New = GetTab
    QueryData.Release = ReleaseTab

    Data.QueryData = QueryData
end

return Data
