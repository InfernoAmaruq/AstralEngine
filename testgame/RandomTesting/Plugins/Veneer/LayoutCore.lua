--╔──────────────────────────────────────────────────╗
--│                 LayoutCore.lua                   │
--│ Abstract module for creating UILayout components │
--╚──────────────────────────────────────────────────╝

--\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//
--              DEPENDENCY
--\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//

local EnumData = require("../EnumData")
local EntityService = GetService("Entity")
local Component = GetService("Component")

--\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//
-- STATIC ABSTRACT COMPONENT DECLARATION
--\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//

local LayoutCore = {}

local HardDependency, HardExclusion = { UIRoot = true, Ancestry = true }, {}

-- Main register entry point for components inheriting this
LayoutCore.Register = function(InstancedData)
    local Name = InstancedData.Name

    -- we want it to block constructs for all other UI layouts
    HardExclusion[Name] = true

    local ComponentTable = {
        Metadata = {
            HardDependency = HardDependency,
            UILayoutObject = true,
            HardExclusion = HardExclusion,
        },
        Name = Name,
    }

    return ComponentTable
end

return LayoutCore
