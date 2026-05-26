local Component = GetService("Component")

local Bloom = {}
Bloom.Name = "BloomFX"
Bloom.Metadata = {}

Bloom.Metadata.__create = function(Input, Entity)
    if not Component.HasComponent(Entity, "Camera") then
        AstralEngine.Log("Camera component missing! BloomFX will not work!", "warn", "FX")
    end

    local t = {}

    t.Active = Input.Active == nil and true or Input.Active
    t.Size = Input.Size or 1
    t.Strength = Input.Strength or 1
    t.Threshold = Input.Threshold or 0.7

    return t
end

return Bloom
