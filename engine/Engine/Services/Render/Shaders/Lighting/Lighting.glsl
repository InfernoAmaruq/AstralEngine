uniform vec4 Lighting_Ambience;

#ifndef MAX_LIGHTS
#define MAX_LIGHTS 256
#endif

#define LIGHTTYPE_POINT 0
#define LIGHTTYPE_SPOT 1
#define LIGHTTYPE_SURFACE 2
#define LIGHTTYPE_DIRECTIONAL 3

uniform sampler2DArrayShadow Light_Shadowmaps;

struct PaddedLight {
    vec4 Position; // w for max dist
    vec4 Direction; // w is angle and must be > 0
    vec4 Color; // a for brightness
    vec4 SurfaceSizeHardnessType; // xy for surface size, w for hardness, z for type
    vec4 UpVectorCastShadow; // xyz for upvec (normalized), w for shadow index
};

uniform Lighting_Data {
    uint Light_LightCount;

    PaddedLight Light_LightData[MAX_LIGHTS];

    vec4 Light_Positions[MAX_LIGHTS]; // where w is max distance
    vec4 Light_Directions[MAX_LIGHTS]; // where w is angle and MUST be > 0. If angle is < 0, interpret it as a point light!
    vec4 Light_Colors[MAX_LIGHTS];
    vec4 Light_Extras[MAX_LIGHTS];
    vec4 Light_ExtrasTwo[MAX_LIGHTS];
};

uniform sampler2D Lighting_LTC;
uniform sampler2D Lighting_LTC_Amp;

uniform mat4 CamTransform;

struct Light {
    vec3 position;
    float rad2;
    float brightness;
    vec3 color;
    vec3 upVec;
    int shadowIndex;
    float angleCos;
    vec3 direction;
    vec2 surfaceSize;
    int type;
    float hardness; 
};

Light lighting_getLight(int id){
    Light l;

    PaddedLight pl = Light_LightData[id];

    l.color = pl.Color.rgb;
    l.position = pl.Position.xyz;
    l.rad2 = pl.Position.w;
    l.brightness = pl.Color.a;
    l.angleCos = pl.Direction.w;
    l.direction = pl.Direction.xyz;
    l.hardness = pl.SurfaceSizeHardnessType.w;
    l.surfaceSize = pl.SurfaceSizeHardnessType.xy;
    l.type = int(pl.SurfaceSizeHardnessType.z);
    l.upVec = pl.UpVectorCastShadow.xyz;
    l.shadowIndex = int(pl.UpVectorCastShadow.w);

    return l;
}

#define LUT_SIZE 32.0

/* Get uv coordinates into LTC lookup texture */
vec2 ltcCoords(float cosTheta, float roughness) {
    float theta = acos(cosTheta);
    vec2 coords = vec2(roughness, theta/(0.5 * PI));

    /* Scale and bias coordinates, for correct filtered lookup */
    coords = coords*(LUT_SIZE - 1.0)/LUT_SIZE + 0.5/LUT_SIZE;

    return coords;
}

/* Get inverse matrix from LTC lookup texture */
mat3 ltcMatrix(vec2 coord) {
    vec4 t = texture(Lighting_LTC, coord);
    mat3 Minv = mat3(
        vec3(  1,   0, t.y),
        vec3(  0, t.z,   0),
        vec3(t.w,   0, t.x)
    );

    return Minv;
}

float integrateEdge(vec3 v1, vec3 v2) {
    float cosTheta = dot(v1, v2);
    cosTheta = clamp(cosTheta, -0.9999, 0.9999);

    float theta = acos(cosTheta);
    /* For theta <= 0.001 `theta/sin(theta)` is approximated as 1.0 */
    float res = cross(v1, v2).z*((theta > 0.001) ? theta/sin(theta) : 1.0);
    return res;
}

int clipQuadToHorizon(inout vec3 L[5]) {
    /* Detect clipping config */
    int config = 0;
    if(L[0].z > 0.0) config += 1;
    if(L[1].z > 0.0) config += 2;
    if(L[2].z > 0.0) config += 4;
    if(L[3].z > 0.0) config += 8;

    int n = 0;

    if(config == 0) {
        // clip all
    } else if(config == 1) { // V1 clip V2 V3 V4
        n = 3;
        L[1] = -L[1].z * L[0] + L[0].z * L[1];
        L[2] = -L[3].z * L[0] + L[0].z * L[3];
    } else if(config == 2) { // V2 clip V1 V3 V4
        n = 3;
        L[0] = -L[0].z * L[1] + L[1].z * L[0];
        L[2] = -L[2].z * L[1] + L[1].z * L[2];
    } else if(config == 3) { // V1 V2 clip V3 V4
        n = 4;
        L[2] = -L[2].z * L[1] + L[1].z * L[2];
        L[3] = -L[3].z * L[0] + L[0].z * L[3];
    } else if(config == 4) { // V3 clip V1 V2 V4
        n = 3;
        L[0] = -L[3].z * L[2] + L[2].z * L[3];
        L[1] = -L[1].z * L[2] + L[2].z * L[1];
    } else if(config == 5) { // V1 V3 clip V2 V4, impossible
        n = 0;
    } else if(config == 6) { // V2 V3 clip V1 V4
        n = 4;
        L[0] = -L[0].z * L[1] + L[1].z * L[0];
        L[3] = -L[3].z * L[2] + L[2].z * L[3];
    } else if(config == 7) { // V1 V2 V3 clip V4
        n = 5;
        L[4] = -L[3].z * L[0] + L[0].z * L[3];
        L[3] = -L[3].z * L[2] + L[2].z * L[3];
    } else if(config == 8) { // V4 clip V1 V2 V3
        n = 3;
        L[0] = -L[0].z * L[3] + L[3].z * L[0];
        L[1] = -L[2].z * L[3] + L[3].z * L[2];
        L[2] =  L[3];
    } else if(config == 9) { // V1 V4 clip V2 V3
        n = 4;
        L[1] = -L[1].z * L[0] + L[0].z * L[1];
        L[2] = -L[2].z * L[3] + L[3].z * L[2];
    } else if(config == 10) { // V2 V4 clip V1 V3, impossible
        n = 0;
    } else if(config == 11) { // V1 V2 V4 clip V3
        n = 5;
        L[4] = L[3];
        L[3] = -L[2].z * L[3] + L[3].z * L[2];
        L[2] = -L[2].z * L[1] + L[1].z * L[2];
    } else if(config == 12) { // V3 V4 clip V1 V2
        n = 4;
        L[1] = -L[1].z * L[2] + L[2].z * L[1];
        L[0] = -L[0].z * L[3] + L[3].z * L[0];
    } else if(config == 13) { // V1 V3 V4 clip V2
        n = 5;
        L[4] = L[3];
        L[3] = L[2];
        L[2] = -L[1].z * L[2] + L[2].z * L[1];
        L[1] = -L[1].z * L[0] + L[0].z * L[1];
    } else if(config == 14) { // V2 V3 V4 clip V1
        n = 5;
        L[4] = -L[0].z * L[3] + L[3].z * L[0];
        L[0] = -L[0].z * L[1] + L[1].z * L[0];
    } else if(config == 15) { // V1 V2 V3 V4
        n = 4;
    }

    if(n == 3)
        L[3] = L[0];
    if(n == 4)
        L[4] = L[0];

    return n;
}

float ltcEvaluate(vec3 N, vec3 V, vec3 P, mat3 Minv, vec3 points[4]) {
    /* Construct orthonormal basis around N */
    vec3 T1 = normalize(V - N*dot(V, N));
    vec3 T2 = cross(N, T1);

    /* Rotate area light in (T1, T2, R) basis */
    Minv = Minv*transpose(mat3(T1, T2, N));

    /* Allocate 5 vertices for polygon (one additional which may result from
     * clipping) */
    vec3 L[5];
    L[0] = Minv*(points[0] - P);
    L[1] = Minv*(points[1] - P);
    L[2] = Minv*(points[2] - P);
    L[3] = Minv*(points[3] - P);

    /* Clip light quad so that the part behind the surface does not affect the
     * lighting of the point */
    int n = clipQuadToHorizon(L);
    if(n == 0)
        return 0.0;

    // project onto sphere
    L[0] = normalize(L[0]);
    L[1] = normalize(L[1]);
    L[2] = normalize(L[2]);
    L[3] = normalize(L[3]);
    L[4] = normalize(L[4]);

    /* Integrate over the clamped cosine distribution in the domain of the
     * transformed light polygon */
    float sum = integrateEdge(L[0], L[1])
              + integrateEdge(L[1], L[2])
              + integrateEdge(L[2], L[3]);
    if(n >= 4)
        sum += integrateEdge(L[3], L[4]);
    if(n == 5)
        sum += integrateEdge(L[4], L[0]);

    /* Negated due to winding order */
    sum = max(0,-sum);

    return sum;
}

vec3 lighting_getLights(const Surface s){
    vec3 AccumColor = vec3(0);
    vec3 camPos = CamTransform[3].xyz;

    vec3 V = normalize(camPos - PositionWorld);

    for (int i = 0; i < Light_LightCount; ++i){
        Light l = lighting_getLight(i);

        float distAtt = 1;
        float spot = 1;
        vec3 diff;
        float h = l.hardness;

	switch(l.type){
		case LIGHTTYPE_DIRECTIONAL:
			distAtt = 1;
			diff = -l.direction; // prolly wont work right with shadows..
			break;
		case LIGHTTYPE_SPOT:
            diff = l.position - PositionWorld;
			float distSqr = dot(diff, diff);

			if (distSqr > l.rad2) continue;

			float d = distSqr / l.rad2;
			distAtt = pow(1.0 - d, h);

			float directionality = dot(normalize(diff),l.direction);
			if (directionality < l.angleCos) { continue; }

			float smoothed = smoothstep(l.angleCos,1.0,directionality);

			spot = pow(smoothed,h);

            break;
		case LIGHTTYPE_POINT:
			diff = l.position - PositionWorld;
			distSqr = dot(diff, diff);

			if (distSqr > l.rad2) continue;

			d = distSqr / l.rad2;
			distAtt = pow(1.0 - d, h);

			break;
		case LIGHTTYPE_SURFACE:
			diff = l.position - PositionWorld;
			distSqr = dot(diff,diff);

			if (distSqr > l.rad2) continue;

			if (dot(s.normal, normalize(diff)) < 0.0) continue;

			float NV = max(dot(V,s.normal),0);
			vec2 coords = ltcCoords(NV,s.roughness);
			mat3 Minv = ltcMatrix(coords);

			vec3 halfWidth = cross(l.direction, l.upVec) * l.surfaceSize.x / 2;
			vec3 halfHeight = l.upVec * l.surfaceSize.y / 2;

			vec3 corners[4];
			corners[0] = l.position - halfWidth - halfHeight;
			corners[1] = l.position + halfWidth - halfHeight;
			corners[2] = l.position + halfWidth + halfHeight;
			corners[3] = l.position - halfWidth + halfHeight;

			float Lo_i = ltcEvaluate(s.normal,V,PositionWorld,Minv,corners);

			vec2 f = texture(Lighting_LTC_Amp,coords).xy;

			float m = s.metalness;

			distAtt = 1.0 - (distSqr / l.rad2);
			Lo_i *= distAtt;
			Lo_i *= 1/h;

			vec3 diffColor = s.baseColor.rgb * (1.0 - m);
			vec3 specColor = mix(s.f0, s.baseColor.rgb, m);

			vec3 LightContribution = Lo_i * (f.x * specColor + f.y * diffColor) * l.color.rgb * l.brightness;
			AccumColor += LightContribution;

			continue;
			break;
	}

        // do color

        float att = distAtt * spot;

        vec3 clr = getLighting(s,diff,vec4(l.color,l.brightness * 2.5),att); // tweak brightness so it looks a bit brighter

        AccumColor += clr;
    }
    return AccumColor;
}
