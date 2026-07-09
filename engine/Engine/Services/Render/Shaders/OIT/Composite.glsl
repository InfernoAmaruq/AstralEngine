uniform sampler2DMS OIT_TexSolid;
uniform sampler2DMS OIT_TexTransparent;
uniform sampler2DMS OIT_TexReveal;
uniform sampler2DMS OIT_TexDepth;
uniform sampler2DMS OIT_TexNormal;

const int Samples = 4;

vec3 OIT_ResolveRGB(sampler2DMS InputSampler, ivec2 UV){
    vec3 AccumColor = vec3(0.0);
    for (int i = 0; i < Samples; ++i){
        AccumColor += texelFetch(InputSampler,UV,i).rgb * 0.25;
    }
    return AccumColor;
}

vec4 OIT_GetColor(){
    ivec2 iUV = ivec2(UV.xy * Resolution);

    vec3 Solid = OIT_ResolveRGB(OIT_TexSolid,iUV);
    vec3 Accum = OIT_ResolveRGB(OIT_TexTransparent,iUV);
    vec2 Reveal = OIT_ResolveRGB(OIT_TexReveal,iUV).rg;

    float Norm = max(Reveal.g, 1e-5);
    vec3 TransColor = Accum / Norm;
    float TransAlpha = 1.0 - exp(-Reveal.r);

    return vec4(Solid * (1.0 - TransAlpha) + TransColor * TransAlpha,1.0);
}

vec4 OIT_Unpack(inout float Depth, inout vec3 Normal){
    ivec2 iUV = ivec2(UV.xy * Resolution);

    Normal = OIT_ResolveRGB(OIT_TexNormal,iUV) * 2 - 1;
    Depth = OIT_ResolveRGB(OIT_TexDepth,iUV).r;


    vec3 Solid = OIT_ResolveRGB(OIT_TexSolid,iUV);
    vec3 Accum = OIT_ResolveRGB(OIT_TexTransparent,iUV);
    vec2 Reveal = OIT_ResolveRGB(OIT_TexReveal,iUV).rg;

    float Norm = max(Reveal.g, 1e-5);
    vec3 TransColor = Accum / Norm;
    float TransAlpha = 1.0 - exp(-Reveal.r);

    return vec4(Solid * (1.0 - TransAlpha) + TransColor * TransAlpha,1.0);
}
