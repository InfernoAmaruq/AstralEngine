//just defining ASTRAL_API and how shit should export
#pragma once
#if defined(_WIN32) || defined(__CYGWIN__)
    #ifdef ASTRAL_BUILD_DLL
        #define ASTRAL_API __declspec(dllexport)
    #else
        #define ASTRAL_API __declspec(dllimport)
    #endif
#elif defined(__GNUC__) || defined(__clang__)
    #define ASTRAL_API __attribute__((visibility("default")))
#else
    #define ASTRAL_API
#endif
