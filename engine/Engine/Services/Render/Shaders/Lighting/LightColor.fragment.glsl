@TYPE:FRAGMENT;
@IDENTIFIER:LIGHTING_COLOR;
@PRIORITY:20;

#ifndef MAX_LIGHTS
#define MAX_LIGHTS 256
#endif

#define LIGHTTYPE_POINT 0
#define LIGHTTYPE_SPOT 1
#define LIGHTTYPE_SURFACE 2
#define LIGHTTYPE_DIRECTIONAL 3

uniform Lighting_Data {
    uint Light_LightCount;

    vec4 Light_Positions[MAX_LIGHTS]; // where w is max distance
    vec4 Light_Directions[MAX_LIGHTS]; // where w is angle and MUST be > 0. If angle is < 0, interpret it as a point light!
    vec4 Light_Colors[MAX_LIGHTS];
    vec4 Light_Extras[MAX_LIGHTS];
    vec4 Light_ExtrasTwo[MAX_LIGHTS];
};

uniform mat4 CamTransform;

struct Light {
    vec3 position;
    float rad2;
    float brightness;
    vec3 color;
    vec3 upVec;
    bool castShadow;
    float angleCos;
    vec3 direction;
    vec2 surfaceSize;
    int type;
    float hardness; 
};

Light lighting_getLight(int id){
    Light l;

    vec4 pos = Light_Positions[id];
    vec4 color = Light_Colors[id];
    vec4 dir = Light_Directions[id];
    vec4 extras = Light_Extras[id];
    vec4 ext2 = Light_ExtrasTwo[id];

    l.color = color.rgb;
    l.position = pos.xyz;
    l.rad2 = pos.w;
    l.brightness = color.a;
    l.angleCos = dir.w;
    l.direction = dir.xyz;
    l.hardness = extras.w;
    l.surfaceSize = extras.xy;
    l.type = int(extras.z);
    l.upVec = ext2.xyz;
    l.castShadow = ext2.w == 1 ? true : false;

    return l;
}

float lighting_getAngularFalloff(vec3 lightToFrag, vec3 lightDirection, float cosAngle){
    float dir = dot(lightToFrag, lightDirection);
    if (dir < cosAngle) return 0;

    float s = smoothstep(cosAngle, 1.0, dir);

    return s;
}

vec3 lighting_getLights(const Surface s){
    vec3 AccumColor = vec3(0);
    for (int i = 0; i < Light_LightCount; ++i){
        Light l = lighting_getLight(i);

        float distAtt;
        float distSqr;
        float d;
        vec3 diff;
        float h = l.hardness;

        vec3 up = l.upVec;
        bool shadow = l.castShadow;

        switch(l.type){
            case LIGHTTYPE_DIRECTIONAL:
                diff = l.direction;
                distAtt = 1;
                break;
            case LIGHTTYPE_POINT:
            case LIGHTTYPE_SPOT:
                diff = l.position - PositionWorld;

                distSqr = dot(diff,diff);

                if (distSqr > l.rad2) continue;

                d = distSqr / l.rad2;

                distAtt = pow(1.0 - d,h);
                break;
            case LIGHTTYPE_SURFACE:
                vec3 right = cross(l.direction,up);
                float halfWidth = (l.surfaceSize.x * 0.5);
                float halfHeight = (l.surfaceSize.y * 0.5);

                float x = dot(diff, right);
                float y = dot(diff, up);

                x = clamp(x, -halfWidth, halfWidth);
                y = clamp(y, -halfHeight, halfHeight);

                vec3 closest = l.position + right * x + up * y;

                diff = closest - PositionWorld;
                distSqr = dot(diff, diff);

                if (distSqr > l.rad2) continue;

                d = distSqr / l.rad2;
                distAtt = pow(1.0 - d,h);

                break;
        }

        // calculate angle

        float spot = 1.0;

        if (l.type == LIGHTTYPE_SPOT){
            spot = pow(
                lighting_getAngularFalloff(normalize(diff), l.direction, l.angleCos)
            ,h);
        }

        if (l.type == LIGHTTYPE_SURFACE){
            /*
            vec3 points[4];

            points[0] = l.position - halfWidth - halfHeight;
            points[1] = l.position + halfWidth - halfHeight;
            points[2] = l.position + halfWidth + halfHeight;
            points[3] = l.position - halfWidth + halfHeight;
            */
            //distAtt = AreaLightBrightness(PositionWorld, l.position, l.direction, points, h);
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
