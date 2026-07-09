layout(location = 1) out vec4 RevealTexture;
uniform bool Transparent;

#ifdef GL_FRAGMENT_SHADER
vec4 DoOIT(vec4 CurrentColor){
    float a = CurrentColor.a;
        if (a < 0.02) discard;

        if (Transparent){
            if (a > 0.95) discard;
            
            float z = clamp(gl_FragCoord.z,0.0,1.0);
            float DepthWeight = min(pow(z,1.5),0.8);

            float Weight = a * (0.2 + 1.5 * DepthWeight);

            RevealTexture = vec4(- log(1.0-a),Weight,0,0);
            return vec4(CurrentColor.rgb * a * Weight, 1);
        }
        else
        {
            if (a < 0.95) discard;
            return vec4(CurrentColor.rgb,1);
        }
}
#else
vec4 DoOIT(vec4 Pos){
    RevealTexture = Pos;
    return Pos;
}
#endif
