#pragma once

#include "optixParams.h"

extern "C" {
    __constant__ LaunchParams optixLaunchParams;
}

// ray types
enum { RADIANCE=0, SHADOW, RAY_TYPE_COUNT };

struct RadiancePRD{
    float3   emitted;
    float3   radiance;
    float3   attenuation;
    float3   origin;
    float3   direction;
    bool done;
    uint32_t seed;
    int32_t  countEmitted;
};