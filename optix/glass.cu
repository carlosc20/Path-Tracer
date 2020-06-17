#include "common.h"

// -----------------------------------------------
// Glass Phong rays (Refração)
extern "C" __global__ void __closesthit__glass() {

    const TriangleMeshSBTData &sbtData
      = *(const TriangleMeshSBTData*)optixGetSbtDataPointer();  

    RadiancePRD &prd = *(RadiancePRD *)getPRD<RadiancePRD>();

    // retrieve primitive id and indexes
    const int   primID = optixGetPrimitiveIndex();
    const uint3 index  = sbtData.index[primID];

    // get barycentric coordinates
    const float u = optixGetTriangleBarycentrics().x;
    const float v = optixGetTriangleBarycentrics().y;

    // compute normal
    const float4 n
        = (1.f-u-v) * sbtData.vertexD.normal[index.x]
        +         u * sbtData.vertexD.normal[index.y]
        +         v * sbtData.vertexD.normal[index.z];

    float3 nn = normalize(make_float3(n));

    // intersection position
    const float3 &rayDir =  optixGetWorldRayDirection();
    const float3 pos = optixGetWorldRayOrigin() + optixGetRayTmax() * rayDir;

    // if (dot(nn, rayDir) > 0.0)
    //    nn = -nn;

    float3 nextRayDir;

    // entering glass
    float dotP;
    if (dot(rayDir, nn) < 0) {
        dotP = dot(rayDir, -nn);
        nextRayDir = refract(rayDir, nn, 0.66);
    }
    // exiting glass
    else {
        dotP = 0;
        nextRayDir = refract(rayDir, -nn, 1.5);
    }

    // didn't hit light
    prd.emitted = make_float3(0.0f);
    prd.countEmitted = false;

    if (length(nextRayDir) > 0) // why?
        prd.direction = nextRayDir;

    if (dotP > 0) {
        uint32_t seed = prd.seed;
        const float z = rnd(seed);
        prd.seed = seed;

        // refractive indices
        const float RI_AIR = 1.0f;
        const float RI_GLASS = 1.5f;

        // Reflection coefficient
        float r0 = (RI_GLASS - RI_AIR)/(RI_GLASS + RI_AIR);
        r0 = r0 * r0;
        // Schlick's approximation
        r0 = r0 + (1 - r0) * pow(1-dotP,5);

        // next ray has probability of being used for refraction or reflexion based on r0
        // aprox: refract * (1-r0) + reflect * r0;
        if(z < r0) {
            float3 reflectDir = reflect(rayDir, nn);        
            prd.direction = reflectDir;
        }
    }

    prd.origin = pos;

    // attenuation?
}


// -----------------------------------------------
// Glass Shadow rays
extern "C" __global__ void __closesthit__shadow_glass() {
    optixSetPayload_0( static_cast<uint32_t>(true));
}

/*
extern "C" __global__ void __closesthit__shadow_glass() {

    // ray payload
    float afterPRD = 1.0f;
    uint32_t u0, u1;
    packPointer( &afterPRD, u0, u1 );  

    // intersection position
    const float3 &rayDir =  optixGetWorldRayDirection();
    const float3 pos = optixGetWorldRayOrigin() + optixGetRayTmax() * rayDir;

    
    uint32_t occluded = 0u;
    optixTrace(optixLaunchParams.traversable,
        pos,
        rayDir,
        0.1f,                    // tmin
        1e20f,           // tmax
        0.0f,                    // rayTime
        OptixVisibilityMask( 255 ),
        OPTIX_RAY_FLAG_NONE,
        SHADOW,                 // SBT offset
        RAY_TYPE_COUNT,         // SBT stride
        SHADOW,                 // missSBTIndex
        occluded);

    // attenuation?
}
*/