@TYPE:FRAGMENT;
@IDENTIFIER:LIGHTING_AMBIENCE;
@PRIORITY:9;

uniform vec4 Lighting_Ambience;

vec4 astral_main(){
    return CurrentColor * Lighting_Ambience;
}
