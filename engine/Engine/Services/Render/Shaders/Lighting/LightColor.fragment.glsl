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
};

uniform mat4 CamTransform;

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

vec3 IntegrateEdgeVec(vec3 v1, vec3 v2)
{
    float x = dot(v1, v2);
    float y = abs(x);

    float a = 0.8543985 + (0.4965155 + 0.0145206*y)*y;
    float b = 3.4175940 + (4.1616724 + y)*y;
    float v = a / b;

    float theta_sintheta = (x > 0.0) ? v : 0.5*inversesqrt(max(1.0 - x*x, 1e-7)) - v;

    return cross(v1, v2)*theta_sintheta;
}

vec3 LTC_Evaluate(vec3 N, vec3 V, vec3 P, mat3 Minv, vec3 points[4])
{
    vec3 T1, T2;
    T1 = normalize(V - N * dot(V, N));
    T2 = cross(N, T1);

    // rotate area light in (T1, T2, N) basis
    Minv = Minv * transpose(mat3(T1, T2, N));

    // polygon (allocate 4 vertices for clipping)
    vec3 L[4];
    // transform polygon from LTC back to origin Do (cosine weighted)
    L[0] = Minv * (points[0] - P);
    L[1] = Minv * (points[1] - P);
    L[2] = Minv * (points[2] - P);
    L[3] = Minv * (points[3] - P);

    // use tabulated horizon-clipped sphere
    // check if the shading point is behind the light
    vec3 dir = points[0] - P; // LTC space
    vec3 lightNormal = cross(points[1] - points[0], points[3] - points[0]);
    bool behind = (dot(dir, lightNormal) < 0.0);

    // cos weighted space
    L[0] = normalize(L[0]);
    L[1] = normalize(L[1]);
    L[2] = normalize(L[2]);
    L[3] = normalize(L[3]);

    // integrate
    vec3 vsum = vec3(0.0);
    vsum += IntegrateEdgeVec(L[0], L[1]);
    vsum += IntegrateEdgeVec(L[1], L[2]);
    vsum += IntegrateEdgeVec(L[2], L[3]);
    vsum += IntegrateEdgeVec(L[3], L[0]);

    // form factor of the polygon in direction vsum
    float len = length(vsum);

    float z = vsum.z/len;
    if (behind)
        z = -z;

    vec2 uv = vec2(z*0.5f + 0.5f, len); // range [0, 1]

    float sum = len;
    if (!behind)
        sum = 0.0;

    vec3 lightCenter = (points[0] + points[1] + points[2] + points[3]) * 0.25;
    float distToLight = length(lightCenter - P);
    float att = 1.0 / (distToLight * distToLight);

    return vec3(sum) * att;
}

vec3 lighting_getLights(const Surface s){
    vec3 AccumColor = vec3(0);
    for (int i = 0; i < Light_LightCount; ++i){
        Light l = lighting_getLight(i);

        float distAtt;
        vec3 diff;
        float h = l.hardness;

        if (l.type == LIGHTTYPE_DIRECTIONAL){
            distAtt = 1;
            diff = l.direction;
        }
        else{
            diff = l.position - PositionWorld;

            float distSqr = dot(diff,diff);

            if (distSqr > l.rad2) continue;

            float d = distSqr / l.rad2;

            distAtt = pow(1.0 - d,h);
        }

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
        else if (l.type == LIGHTTYPE_SURFACE){
            vec3 points[4];

            vec3 halfWidth = l.direction * (l.surfaceSize.x * 0.5);
            vec3 halfHeight = vec3(0,1,0) * (l.surfaceSize.y * 0.5);
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
