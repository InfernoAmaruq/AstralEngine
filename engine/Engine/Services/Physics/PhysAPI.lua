local Physics = select(1, ...)

local Meta = { __type = "PhysicsWorld" }

local CAPTUREFUNC = function(t, ...)
    local s = t
    if typeof(t) == "Entity" then
        s = t:GetComponent("World")
    end
    local FUNC, WORLD = rawget(s, ".NEXTCALL"), rawget(s, "World")
    return FUNC(WORLD, ...)
end

local Methods = {
    Raycast = function(WorldTab, Start, End, Parameters, Out)
        Parameters = Parameters or Physics.RaycastParams.Default

        if not Parameters.GetFirst then
            Out = Out or {}
            Parameters.__OUT = Out
        end

        local ReleaseFunc = Physics.QueryData.Release

        WorldTab.LovrWorld:raycast(Start, End, Parameters[".Tags"], Parameters.Callback)

        if Parameters.GetFirst then
            local Obj = Parameters.__OUT or Physics.QueryData.New()
            Parameters.__OUT = nil
            ReleaseFunc(Obj)
            return Obj
        else
            Parameters.__OUT = nil
            for _, v in ipairs(Out) do
                ReleaseFunc(v)
            end
            return Out
        end
    end,
    Shapecast = function(WorldTab, Shape, ShapeSize, ShapeRotation, Start, End, Parameters, Out)
        Parameters = Parameters or Physics.RaycastParams.Default

        if not Parameters.GetFirst then
            Out = Out or {}
            Parameters.__OUT = Out
        end

        local ReleaseFunc = Physics.QueryData.Release

        local TypeOf = typeof(ShapeRotation)
        local Quat = TypeOf == "Quat" and ShapeRotation

        if not Quat then
            if TypeOf == "Vec4" then
                Quat = quat(ShapeRotation:unpack())
            elseif TypeOf == "Vec3" then
                Quat = quat():setEuler(ShapeRotation:unpack())
            end
        end

        local RawShape = Physics.RaycastParams.GetTempShape(Shape, ShapeSize)

        WorldTab.LovrWorld:shapecast(RawShape, Start, End, Quat, Parameters[".Tags"], Parameters.Callback)

        if Parameters.GetFirst then
            local Obj = Parameters.__OUT or Physics.QueryData.New()
            ReleaseFunc(Obj)
            return Obj
        else
            Parameters.__OUT = nil
            for _, v in ipairs(Out) do
                ReleaseFunc(v)
            end
            return Out
        end
    end,
    Overlap = function(WorldTab, Shape, ShapeSize, Position, ShapeRotation, Parameters, MaxDistance, Out)
        Parameters = Parameters or Physics.RaycastParams.Default

        Out = Out or {}
        Parameters.__OUT = Out

        local ReleaseFunc = Physics.QueryData.Release

        local TypeOf = typeof(ShapeRotation)
        local Quat = TypeOf == "Quat" and ShapeRotation

        if not Quat then
            if TypeOf == "Vec4" then
                Quat = quat(ShapeRotation:unpack())
            elseif TypeOf == "Vec3" then
                Quat = quat():setEuler(ShapeRotation:unpack())
            end
        end

        local RawShape = Physics.RaycastParams.GetTempShape(Shape, ShapeSize)

        WorldTab.LovrWorld:overlapShape(RawShape, Position, Quat, MaxDistance, Parameters[".Tags"], Parameters.Callback)

        Parameters.__OUT = nil
        for _, v in ipairs(Out) do
            ReleaseFunc(v)
        end
        return Out
    end,
    QueryBox = function(WorldTab, Pos, Size, Parameters, Out)
        Parameters = Parameters or Physics.RaycastParams.Default

        Out = Out or {}
        Parameters.__OUT = Out

        local ReleaseFunc = Physics.QueryData.Release

        WorldTab.LovrWorld:queryBox(Pos, Size, Parameters[".Tags"], Parameters.OverlapCallback)

        Parameters.__OUT = nil
        for _, v in ipairs(Out) do
            ReleaseFunc(v)
        end
        return Out
    end,
    QuerySphere = function(WorldTab, Pos, Radius, Parameters, Out)
        Parameters = Parameters or Physics.RaycastParams.Default

        Out = Out or {}
        Parameters.__OUT = Out

        local ReleaseFunc = Physics.QueryData.Release

        WorldTab.LovrWorld:querySphere(Pos, Radius, Parameters[".Tags"], Parameters.OverlapCallback)

        Parameters.__OUT = nil
        for _, v in ipairs(Out) do
            ReleaseFunc(v)
        end
        return Out
    end,
    HasTag = function(World, Name)
        local t = World.TagLookUp[Name]
        return t ~= nil
    end,
    IsStaticTag = function(World, Tag)
        local t = table.find(World.StaticTags, Tag)
        return t and true or false
    end,
}

local AliasMap = {
    Update = "update",
    Interpolate = "interpolate",
}

Meta.Methods = Methods

Meta.__index = function(t, k)
    if Methods[k] then
        return Methods[k]
    end

    k = type(k) == "string" and AliasMap[k] or k
    local W = rawget(t, "LovrWorld")
    local v = W and W[k]

    if k == "Gravity" then
        return t.LovrWorld:getGravity()
    end

    if type(v) == "function" then
        rawset(t, ".NEXTCALL", v)
        return CAPTUREFUNC
    else
        return v or rawget(t, k)
    end
end

Meta.__newindex = function(t, k, v)
    if k == "Gravity" then
        t.LovrWorld:setGravity(v)
        return
    end
    error("CANNOT WRITE TO WORLD", 2)
end

return Meta
