@TYPE:VERTEX;
@PRIORITY:100000;
@IDENTIFIER:OIT_DRAW;

layout(location = 1) out vec4 SecondPos;

vec4 astral_main(){
    SecondPos = CurrentPosition;
    return CurrentPosition;
}
