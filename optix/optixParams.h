#pragma once

#include "../include/launchParamsGlobal.h"
#include  "../include/util.h"

struct GlobalParams{
    float4 lightPos;
    float4 *accumBuffer;
    int shadowRays;
    float gamma;
    float lightScale;
    float glossiness;
    bool rrTermination;
};


struct LaunchParams
{
    Frame frame;
    Camera camera;
    OptixTraversableHandle traversable;

    GlobalParams *global;
};

