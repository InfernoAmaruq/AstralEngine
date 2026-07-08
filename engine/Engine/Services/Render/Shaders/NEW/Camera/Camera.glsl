#include "Camera.inc"

#define NormalTexture RevealTexture

#ifdef GL_FRAGMENT_SHADER
vec4 lovrmain(){
    vec4 CurrentColor;
    Surface s = PBR_GetSurface(CurrentColor);

    CurrentColor = DoOIT(CurrentColor);

    if (!Transparent) // otherwise write to normal buffer
        NormalTexture = vec4((s.normal + 1)/2,1);

    return CurrentColor;
}
#else
vec4 lovrmain(){
    Material_GetUV(UV);

    vec4 p;
    if (IsInstanced)
        p = GetInstancedTransform();
    else
        p = DefaultPosition;

    return DoOIT(p);
}
#endif
