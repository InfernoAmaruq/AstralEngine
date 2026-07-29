local Model = { Name = "Model" }

local Index = {
    Model = 1,
    ModelData = 2,
    NodeEntitiesPresent = 3,
}

local Methods = {
    SummonNodeEntities = function(self) end,
    KillNodeEntities = function(self) end,

    -- NODES

    GetNodeCount = function() end,
    GetRootNode = function() end,

    -- NON PROMOTED

    SetNodeScale = function() end,
    SetNodePosition = function() end,
    SetNodeRotation = function() end,
    SetNodeOrientation = function() end,
    SetNodeTransform = function() end,
    SetNodePose = function() end,

    GetNodeScale = function() end,
    GetNodePosition = function() end,
    GetNodeRotation = function() end,
    GetNodeOrientation = function() end,
    GetNodeTransform = function() end,
    GetNodePose = function() end,

    SetDrawNode = function() end,
    GetDrawNode = function() end,

    -- PROMOTED

    -- ANIMATIONS

    GetAnimation = function() end,
    GetAnimations = function() end,
    AddAnimation = function() end,
}

Model.New = function(Input, Entity, Sink) end

return Model
