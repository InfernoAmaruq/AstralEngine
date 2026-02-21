@PRIORITY:1;
@IDENTIFIER:UISTENCIL;
uniform bool TransparentToStencil = false;

vec4 astral_main(){
    if (!TransparentToStencil && CurrentColor.a <= 0) discard;
}
