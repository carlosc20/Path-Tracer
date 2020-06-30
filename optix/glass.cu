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

    // refractive indices
    const float RI_AIR = 1.0f;
    const float refractionIndex = optixLaunchParams.global->refractionIndex; // glass -> 1.5
    
    float3 nextRayDir;

    // entering glass
    float dotP;
    if (dot(rayDir, nn) < 0) {
        dotP = dot(rayDir, -nn);
        nextRayDir = refract(rayDir, nn, RI_AIR/refractionIndex);
    }
    // exiting glass
    else {
        dotP = 0;
        nextRayDir = refract(rayDir, -nn, refractionIndex/RI_AIR);
    }


    if (length(nextRayDir) > 0) // why?
        prd.direction = nextRayDir;

    if (dotP > 0) {
        uint32_t seed = prd.seed;
        const float z = rnd(seed);
        prd.seed = seed;


        
        

        // Reflection coefficient
        float r0 = (refractionIndex - RI_AIR)/(refractionIndex + RI_AIR);
        r0 = r0 * r0;
        // Schlick's approximation
        r0 = r0 + (1 - r0) * pow(1-dotP,5);

        // next ray has probability of being used for refraction or reflexion based on r0
        // splitting: refract * (1-r0) + reflect * r0;
        if(z <= r0) {    
            prd.direction = reflect(rayDir, nn); 
        }
    }

    prd.origin = pos;

    prd.attenuation *= sbtData.diffuse;
}


// -----------------------------------------------
// Glass Shadow rays

extern "C" __global__ void __closesthit__shadow_glass() {
    optixSetPayload_0( static_cast<uint32_t>(true));
}