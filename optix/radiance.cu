#include "common.h"

// -------------------------------------------------------
// Lambert
extern "C" __global__ void __closesthit__radiance() {

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

    // invert normal if hit from behind
    if (dot(nn, rayDir) > 0.0)
        nn = -nn;

    // adds emission if first surface hit is a light or a bounce from a specular surface
    if ((prd.countEmitted || prd.specularBounce) && length(sbtData.emission) != 0) {
        prd.emitted = sbtData.emission;
        prd.done = true;
        return;
    }
    prd.emitted = make_float3(0.0f);
    prd.countEmitted = false;
    prd.specularBounce = false;

    uint32_t seed = prd.seed;

    {
        // set origin and direction for next ray

        const float z1 = rnd(seed);
        const float z2 = rnd(seed);

        float3 w_in;
        cosine_sample_hemisphere( z1, z2, w_in );
        Onb onb( nn );
        onb.inverse_transform( w_in );

        prd.direction = w_in;
        prd.origin    = pos;
    }
    

    const float z1 = rnd(seed);
    const float z2 = rnd(seed);
    prd.seed = seed;

    // random point from light area
    // square area 0.47 x 0.38, XZ plane
    const float3 lightV1 = make_float3(0.47f, 0.0, 0.0f);
    const float3 lightV2 = make_float3(0.0f, 0.0, 0.38f);
    const float3 light_pos = make_float3(optixLaunchParams.global->lightPos) + lightV1 * z1 + lightV2 * z2;

    // Calculate properties of light sample (for area based pdf)
    const float  Ldist = length( light_pos - pos );
    const float3 L     = normalize( light_pos - pos );
    const float  nDl   = dot( nn, L );
    const float3 Ln    = normalize(cross(lightV1, lightV2));
    const float  LnDl  = -dot( Ln, L );

    // check light sample occlusion
    float weight = 0.0f;
    if( nDl > 0.0f && LnDl > 0.0f ) {
        uint32_t occluded = 0u;
        optixTrace(optixLaunchParams.traversable,
            pos,
            L,
            0.1f,                    // tmin
            Ldist - 0.01f,           // tmax
            0.0f,                    // rayTime
            OptixVisibilityMask( 1 ),
            OPTIX_RAY_FLAG_TERMINATE_ON_FIRST_HIT,
            SHADOW,                 // SBT offset
            RAY_TYPE_COUNT,         // SBT stride
            SHADOW,                 // missSBTIndex
            occluded);

        if(!occluded) {
            const float att = Ldist * Ldist;
            const float A = length(cross(lightV1, lightV2));
            weight = nDl * LnDl * A  / att;
        }
    }

    const float3 Lintensity = make_float3(5.0f, 5.0f, 5.0f);

    prd.radiance += Lintensity * weight * optixLaunchParams.global->lightScale;

    if (sbtData.hasTexture && sbtData.vertexD.texCoord0) {  
        // compute pixel texture coordinate
        const float4 tc
          = (1.f-u-v) * sbtData.vertexD.texCoord0[index.x]
          +         u * sbtData.vertexD.texCoord0[index.y]
          +         v * sbtData.vertexD.texCoord0[index.z];
        // fetch texture value
        float4 fromTexture = tex2D<float4>(sbtData.texture,tc.x,tc.y);
        prd.attenuation *= make_float3(fromTexture);
    }
    else
        prd.attenuation *= sbtData.diffuse;

}


extern "C" __global__ void __anyhit__radiance() {}

extern "C" __global__ void __miss__radiance() {
    // miss sets the background color
    RadiancePRD &prd = *(RadiancePRD*)getPRD<RadiancePRD>();
    prd.radiance = make_float3(0.0f, 0.0f, 0.0f); // black
    prd.done = true;
}


// -----------------------------------------------
// Shadow rays

extern "C" __global__ void __closesthit__shadow() {
    optixSetPayload_0( static_cast<uint32_t>(true));
}

extern "C" __global__ void __anyhit__shadow() {}

extern "C" __global__ void __miss__shadow() {
    optixSetPayload_0( static_cast<uint32_t>(false));
}