#include "Instancing/Instancing.glsl"
#include "Material/Material.glsl"

#ifdef GL_FRAGMENT_SHADER
vec4 lovrmain(){
    float shadowAlpha = Material_ShadowAlpha;
    float alpha = Material_Color.a;

    if (shadowAlpha == -1 || alpha < shadowAlpha) discard;

	return vec4(0);
}
#else
vec4 lovrmain(){
    Material_GetUV(UV);
    return DefaultPosition;
}
#endif
