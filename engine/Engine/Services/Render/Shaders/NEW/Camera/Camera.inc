#pragma once

#include "Instancing/Instancing.glsl"
#include "OIT/Write.glsl"

#ifdef GL_FRAGMENT_SHADER
#include "PBR/PBR.inc"
#else
#include "Material/Material.glsl"
#endif
