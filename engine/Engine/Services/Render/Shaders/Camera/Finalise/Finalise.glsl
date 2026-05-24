@TYPE:FRAGMENT;
@PRIORITY:100;
@IDENTIFIER:FINAL_PASS;

uniform sampler2D ColorTex;
uniform sampler2D AO;
uniform sampler2D Bloom;

uniform float exposure;
uniform float gamma;

vec4 astral_main(){
    vec3 c = getPixel(ColorTex,UV).rgb;
    float ao = getPixel(AO,UV).r;
    vec3 bloomColor = getPixel(Bloom,UV).rgb;

    c += bloomColor;

    vec3 result = vec3(1.0) - exp(-c * exposure);

    result = pow(result, vec3(1.0 / gamma));
    CurrentColor = vec4(result,1);
}
