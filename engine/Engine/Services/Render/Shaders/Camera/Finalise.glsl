#ifdef GL_FRAGMENT_SHADER
uniform sampler2D ColorTex;
uniform sampler2D AO;
uniform sampler2D Bloom;

uniform float exposure;
uniform float gamma;

uniform bool DoBloom;

vec4 lovrmain(){
    vec3 c = getPixel(ColorTex,UV).rgb;
    float ao = getPixel(AO,UV).r;

    c *= ao;

    if (DoBloom){
        vec3 bloomColor = getPixel(Bloom,UV).rgb;
        c += bloomColor;
    }

    vec3 result = vec3(1.0) - exp(-c * exposure);

    result = pow(result, vec3(1.0 / gamma));
    return vec4(result,1);
}
#else
vec4 lovrmain() { return DefaultPosition; }
#endif
