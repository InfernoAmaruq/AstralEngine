@TYPE:FRAGMENT;
@IDENTIFIER:MATERIAL_SURFACE;
@PRIORITY:0;

Surface linearMaterial(inout Surface surface) {
  surface.baseColor = Color * texture(sampler2D(ColorTexture, Material_PixelSampler),UV);
  surface.emissive = Material.glow.rgb * Material.glow.a * texture(sampler2D(GlowTexture,Material_PixelSampler),UV).rgb;
  surface.metalness = Material.metalness * texture(sampler2D(MetalnessTexture,Material_PixelSampler),UV).b;
  surface.roughness = Material.roughness * texture(sampler2D(RoughnessTexture,Material_PixelSampler),UV).g;
  surface.occlusion = Material.occlusionStrength * texture(sampler2D(OcclusionTexture,Material_PixelSampler),UV).r;
  surface.clearcoat = Material.clearcoat * texture(sampler2D(ClearcoatTexture,Material_PixelSampler),UV).r;
  surface.clearcoatRoughness = getMaterialClearcoatRoughness();
  if (flag_normalMap) {
    vec3 normalScale = vec3(Material.normalScale, Material.normalScale, 1.);
    surface.normal = TangentMatrix * normalize((texture(sampler2D(NormalTexture, Material_PixelSampler), UV).rgb * 2. - 1.) * normalScale);
  }
  return surface;
}

Surface getMaterialSurface(){
    Surface s;

    if (IsInstanced) {
    }

    if (Material_UsePixelSampler) {
        s = newSurface();
        linearMaterial(s);
        finalizeSurface(s);
    } else
	    s = getDefaultSurface();

    s.baseColor *= Material_Color;

    return s;
}

vec4 astral_main(){}
