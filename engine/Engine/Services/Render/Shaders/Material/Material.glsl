#pragma once

uniform mat4 Material_Matrix;
uniform sampler Material_PixelSampler;

#define HAS_MATERIAL_HEADER

uniform vec3 Material_ObjectScale;

#ifdef INSTANCING_ACTIVE

readonly buffer INSTANCE_Material {
    mat4 Material_MatrixInstanced[];
};

readonly buffer INSTANCE_Scale {
    vec3 Material_ObjectScaleInstanced[];
};

#define Material_UV (IsInstanced ? Material_MatrixInstanced[InstIndex][0] : Material_Matrix[0])
#define Material_Color (IsInstanced ? Material_MatrixInstanced[InstIndex][1] : Material_Matrix[1])
#define Material_FitMode int(IsInstanced ? Material_MatrixInstanced[InstIndex][2].x : Material_Matrix[2].x)
#define Material_UsePixelSampler int(IsInstanced ? Material_MatrixInstanced[InstIndex][2].y : Material_Matrix[2].y) == 1
#define Material_Scale (IsInstanced ? Material_ObjectScaleInstanced[InstIndex] : Material_ObjectScale)
#define Material_ShadowAlpha (IsInstanced ? Material_MatrixInstanced[InstIndex][2].z : Material_Matrix[2].z)
#define Material_Emissive (IsInstanced ? Material_MatrixInstanced[InstIndex][3] : Material_Matrix[3])

#else

#define Material_UV Material_Matrix[0]
#define Material_Color Material_Matrix[1]
#define Material_FitMode int(Material_Matrix[2].x)
#define Material_UsePixelSampler int(Material_Matrix[2].y) == 1
#define Material_Scale Material_ObjectScale
#define Material_ShadowAlpha Material_Matrix[2].z
#define Material_Emissive Material_Matrix[3]

#endif

#ifdef GL_FRAGMENT_SHADER
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

    vec4 sColor = Material_Color;

	if (Material_UsePixelSampler) {
	    s = newSurface();
	    linearMaterial(s);
	    finalizeSurface(s);
	} else
	    s = getDefaultSurface();

	s.baseColor *= sColor;
    
    vec4 emissiveColor = Material_Emissive;
    s.emissive.rgb += emissiveColor.rgb * emissiveColor.a;

    return s;
}
#else

#define MATERIAL_FIT_MODE_STRETCH 0
#define MATERIAL_FIT_MODE_TILE 1
#define MATERIAL_FIT_MODE_CROP 2

void Material_GetUV(inout vec2 UV){
    int FitMode = Material_FitMode;

    if (FitMode == MATERIAL_FIT_MODE_TILE){
        vec2 ImageSize = textureSize(ColorTexture,0);

        float ImageAspect = ImageSize.x / ImageSize.y;

        UV.y = UV.y * ImageAspect;

        vec3 AbsNormal = abs(Normal);
        vec2 AbsScale;

        if (AbsNormal.z > AbsNormal.x && AbsNormal.z > AbsNormal.y)
            AbsScale = Material_Scale.xy;
        else if (AbsNormal.y > AbsNormal.x)
            AbsScale = Material_Scale.xz;
        else
            AbsScale = Material_Scale.zy;

        UV = UV * AbsScale;
    }
    else if (FitMode == MATERIAL_FIT_MODE_CROP){
        vec2 ImageSize = textureSize(ColorTexture,0);

        float ImageAspect = ImageSize.x / ImageSize.y;

        UV.x = UV.x / ImageAspect + 0.25;
    }

    vec4 MatUV = Material_UV;
    vec2 Material_UVOffset = MatUV.xy;
    vec2 Material_UVScale = MatUV.zw;

    UV = UV * Material_UVScale + Material_UVOffset;
}

#endif
