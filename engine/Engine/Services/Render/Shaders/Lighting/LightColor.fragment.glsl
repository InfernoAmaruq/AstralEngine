@TYPE:FRAGMENT;
@IDENTIFIER:LIGHTING_COLOR;
@PRIORITY:20;

#define MAX_LIGHTS 256

#define LIGHTTYPE_POINT 0
#define LIGHTTYPE_SPOT 1
#define LIGHTTYPE_SURFACE 2

uniform Lighting_Data {
    uint Light_LightCount;

    vec4 Light_Positions[MAX_LIGHTS]; // where w is max distance
    vec4 Light_Directions[MAX_LIGHTS]; // where w is angle and MUST be > 0. If angle is < 0, interpret it as a point light!
    vec4 Light_Colors[MAX_LIGHTS];
    vec4 Light_Extras[MAX_LIGHTS];
};

struct Light {
    vec3 position;
    float rad2;
    float brightness;
    vec3 color;
    float angleCos;
    vec3 direction;
    vec2 surfaceSize;
    int type;
    float hardness;

    float linear;
    float quadratic;
};

Light lighting_getLight(int id){
    Light l;

    vec4 pos = Light_Positions[id];
    vec4 color = Light_Colors[id];
    vec4 dir = Light_Directions[id];
    vec4 extras = Light_Extras[id];

    l.color = color.rgb;
    l.position = pos.xyz;
    l.rad2 = pos.w;
    l.brightness = color.a;
    l.angleCos = dir.w;
    l.direction = dir.xyz;
    l.hardness = extras.w;
    l.surfaceSize = extras.xy;
    l.type = int(extras.z);

    return l;
}

vec3 lighting_getLights(const Surface s){
    vec3 AccumColor = vec3(0);
    for (int i = 0; i < Light_LightCount; ++i){
        Light l = lighting_getLight(i);

        vec3 diff = l.position - PositionWorld;

        float distSqr = dot(diff,diff);

        if (distSqr > l.rad2) continue;

        float h = l.hardness;

        float d = distSqr / l.rad2;

        float distAtt = pow(1.0 - d,h);

        // calculate angle

        float spot = 1.0;

        if (l.type == LIGHTTYPE_SPOT){
            float directionality = dot(normalize(diff),l.direction);
            if (directionality < l.angleCos){
                continue;
            }

            float s = smoothstep(l.angleCos,1.0,directionality);

            spot = pow(s,h);
        }

        // do color

        float att = distAtt * spot;

        vec3 clr = getLighting(s,diff,vec4(l.color,l.brightness * 2.5),att); // tweak brightness so it looks a bit brighter

        AccumColor += clr;
    }
    return AccumColor;
}

vec4 astral_main(){

}
