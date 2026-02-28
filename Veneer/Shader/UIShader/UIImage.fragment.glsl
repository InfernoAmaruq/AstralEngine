@PRIORITY:0;
@IDENTIFIER:UIIMAGE_FIT;

#define UI_IMAGE_FIT_NONE       0
#define UI_IMAGE_FIT_STRETCH    1
#define UI_IMAGE_FIT_CROP       2
#define UI_IMAGE_FIT_FIT        3

uniform int UIImageFit = UI_IMAGE_FIT_NONE;
uniform vec2 RectSize;

vec2 FitUV(vec2 InUV){
    if (UIImageFit == UI_IMAGE_FIT_STRETCH) return InUV;

    vec2 ImageSize = textureSize(ColorTexture,0);

    float RectAspect = RectSize.x / RectSize.y;
    float ImageAspect = ImageSize.x / ImageSize.y;

    vec2 UVOut = InUV;
    vec2 Scale;

    switch (UIImageFit) {
        case UI_IMAGE_FIT_CROP:

            if (ImageAspect > RectAspect)
                Scale = vec2(ImageAspect / RectAspect, 1.0);
            else
                Scale = vec2(1.0, RectAspect / ImageAspect);

            UVOut = (UVOut - 0.5) / Scale + 0.5;
            
            break;
        case UI_IMAGE_FIT_FIT:

            if (ImageAspect > RectAspect)
                Scale = vec2(1.0, RectAspect / ImageAspect);
            else
                Scale = vec2(ImageAspect / RectAspect, 1.0);

            UVOut = (UVOut - 0.5) / Scale + 0.5;

            break;
    }

    if (UVOut.x > 1 || UVOut.x < 0 || UVOut.y > 1 || UVOut.y < 0) return vec2(-1,-1);

    return UVOut;
}

vec4 astral_main(){
    vec2 NewUV = UIImageFit == UI_IMAGE_FIT_NONE ? UV : FitUV(UV);

    NewUV.y = 1 - NewUV.y;

    if (NewUV.x < 0) discard;

    return Color * getPixel(ColorTexture, NewUV);
}
