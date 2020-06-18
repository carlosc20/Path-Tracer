#include "common.h"

// -----------------------------------------------
// Glossy Reflections (Specular materials with rugosity) 
extern "C" __global__ void __closesthit__glossy() {

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
    const float3 pos = optixGetWorldRayOrigin() + optixGetRayTmax() * rayDir ;

    if (dot(nn, rayDir) > 0.0)
        nn = -nn;


    const float glossiness = optixLaunchParams.global->glossiness;

    float3 nextRayDir;
    float3 reflectDir = reflect(optixGetWorldRayDirection(), nn);
    uint32_t seed = prd.seed;

    do {
        const float z1 = rnd(seed);
        const float z2 = rnd(seed);
        cosine_power_sample_hemisphere( z1, z2, nextRayDir, glossiness );
        Onb onb( reflectDir );
        onb.inverse_transform( nextRayDir );
    } while (dot(nextRayDir, nn) < 0.001);
    prd.seed = seed;

    // set origin and direction for next ray
    prd.direction = nextRayDir;
    prd.origin    = pos;

    prd.attenuation *= sbtData.diffuse;
}