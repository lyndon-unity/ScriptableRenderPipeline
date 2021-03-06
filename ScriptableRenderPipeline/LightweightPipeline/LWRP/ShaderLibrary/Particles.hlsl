#include "Core.hlsl"
#include "InputSurface.hlsl"
#include "CoreRP/ShaderLibrary/Color.hlsl"

TEXTURE2D(_CameraDepthTexture);
SAMPLER(sampler_CameraDepthTexture);
float4 _SoftParticleFadeParams;
float4 _CameraFadeParams;

#define SOFT_PARTICLE_NEAR_FADE _SoftParticleFadeParams.x
#define SOFT_PARTICLE_INV_FADE_DISTANCE _SoftParticleFadeParams.y

#define CAMERA_NEAR_FADE _CameraFadeParams.x
#define CAMERA_INV_FADE_DISTANCE _CameraFadeParams.y

#if defined (_COLORADDSUBDIFF_ON)
half4 _ColorAddSubDiff;
#endif

// Color function
#if defined(UNITY_PARTICLE_INSTANCING_ENABLED)
#define vertColor(c) \
        vertInstancingColor(c);
#else
#define vertColor(c)
#endif

// Flipbook vertex function
#if defined(UNITY_PARTICLE_INSTANCING_ENABLED)
#if defined(_FLIPBOOK_BLENDING)
#define vertTexcoord(v, o) \
        vertInstancingUVs(v.texcoords.xy, o.texcoord, o.texcoord2AndBlend);
#else
#define vertTexcoord(v, o) \
        vertInstancingUVs(v.texcoords.xy, o.texcoord); \
        o.texcoord = TRANSFORM_TEX(o.texcoord, _MainTex);
#endif
#else
#if defined(_FLIPBOOK_BLENDING)
#define vertTexcoord(v, o) \
        o.texcoord = v.texcoords.xy; \
        o.texcoord2AndBlend.xy = v.texcoords.zw; \
        o.texcoord2AndBlend.z = v.texcoordBlend;
#else
#define vertTexcoord(v, o) \
        o.texcoord = TRANSFORM_TEX(v.texcoords.xy, _MainTex);
#endif
#endif

// Fading vertex function
#if defined(SOFTPARTICLES_ON) || defined(_FADING_ON)
#define vertFading(o, positionWS, positionCS) \
    o.projectedPosition.xy = positionCS.xy * 0.5 + positionCS.w; \
    o.projectedPosition.y *= _ProjectionParams.x; \
    o.projectedPosition.w = positionCS.w; \
    o.projectedPosition.z = -TransformWorldToView(positionWS.xyz).z
#else
#define vertFading(o, positionWS, positionCS)
#endif

// Color blending fragment function
#if defined(_COLOROVERLAY_ON)
#define fragColorMode(i) \
    albedo.rgb = lerp(1 - 2 * (1 - albedo.rgb) * (1 - i.color.rgb), 2 * albedo.rgb * i.color.rgb, step(albedo.rgb, 0.5)); \
    albedo.a *= i.color.a;
#elif defined(_COLORCOLOR_ON)
#define fragColorMode(i) \
    half3 aHSL = RgbToHsv(albedo.rgb); \
    half3 bHSL = RgbToHsv(i.color.rgb); \
    half3 rHSL = half3(bHSL.x, bHSL.y, aHSL.z); \
    albedo = half4(HsvToRgb(rHSL), albedo.a * i.color.a);
#elif defined(_COLORADDSUBDIFF_ON)
#define fragColorMode(i) \
    albedo.rgb = albedo.rgb + i.color.rgb * _ColorAddSubDiff.x; \
    albedo.rgb = lerp(albedo.rgb, abs(albedo.rgb), _ColorAddSubDiff.y); \
    albedo.a *= i.color.a;
#else
#define fragColorMode(i) \
    albedo *= i.color;
#endif

// Pre-multiplied alpha helper
#if defined(_ALPHAPREMULTIPLY_ON)
#define ALBEDO_MUL albedo
#else
#define ALBEDO_MUL albedo.a
#endif

// Soft particles fragment function
#if defined(SOFTPARTICLES_ON) && defined(_FADING_ON)
#define fragSoftParticles(i) \
    if (SOFT_PARTICLE_NEAR_FADE > 0.0 || SOFT_PARTICLE_INV_FADE_DISTANCE > 0.0) \
    { \
        float sceneZ = LinearEyeDepth(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture, i.projectedPosition.xy / i.projectedPosition.w), _ZBufferParams); \
        float fade = saturate (SOFT_PARTICLE_INV_FADE_DISTANCE * ((sceneZ - SOFT_PARTICLE_NEAR_FADE) - i.projectedPosition.z)); \
        ALBEDO_MUL *= fade; \
    }
#else
#define fragSoftParticles(i)
#endif

// Camera fading fragment function
#if defined(_FADING_ON)
#define fragCameraFading(i) \
    float cameraFade = saturate((i.projectedPosition.z - CAMERA_NEAR_FADE) * CAMERA_INV_FADE_DISTANCE); \
    ALBEDO_MUL *= cameraFade;
#else
#define fragCameraFading(i)
#endif

// Vertex shader input
struct appdata_particles
{
    float4 vertex : POSITION;
    float3 normal : NORMAL;
    half4 color : COLOR;
#if defined(_FLIPBOOK_BLENDING) && !defined(UNITY_PARTICLE_INSTANCING_ENABLED)
    float4 texcoords : TEXCOORD0;
    float texcoordBlend : TEXCOORD1;
#else
    float2 texcoords : TEXCOORD0;
#endif
#if defined(_NORMALMAP)
    float4 tangent : TANGENT;
#endif
};

struct VertexOutputLit
{
    half4 color                     : COLOR;
    float2 texcoord                 : TEXCOORD0;
#if _NORMALMAP
    half3 tangent                   : TEXCOORD1;
    half3 binormal                  : TEXCOORD2;
    half3 normal                    : TEXCOORD3;
#else
    half3 normal                    : TEXCOORD1;
#endif

#if defined(_FLIPBOOK_BLENDING)
    float3 texcoord2AndBlend        : TEXCOORD4;
#endif
#if defined(SOFTPARTICLES_ON) || defined(_FADING_ON)
    float4 projectedPosition        : TEXCOORD5;
#endif
    float4 posWS                    : TEXCOORD6; // xyz: position; w = fogFactor;
    half4 viewDirShininess          : TEXCOORD7; // xyz: viewDir; w = shininess
    float4 clipPos                  : SV_POSITION;
};

half4 readTexture(TEXTURE2D_ARGS(_Texture, sampler_Texture), VertexOutputLit IN)
{
    half4 color = SAMPLE_TEXTURE2D(_Texture, sampler_Texture, IN.texcoord);
#ifdef _FLIPBOOK_BLENDING
    half4 color2 = SAMPLE_TEXTURE2D(_Texture, sampler_Texture, IN.texcoord2AndBlend.xy);
    color = lerp(color, color2, IN.texcoord2AndBlend.z);
#endif
    return color;
}

half3 NormalTS(VertexOutputLit IN)
{
#if defined(_NORMALMAP)
    #if BUMP_SCALE_NOT_SUPPORTED
        return UnpackNormal(readTexture(TEXTURE2D_PARAM(_BumpMap, sampler_BumpMap), IN));
    #else
        return UnpackNormalScale(readTexture(TEXTURE2D_PARAM(_BumpMap, sampler_BumpMap), IN), _BumpScale);
    #endif
#else
    return half3(0.0h, 0.0h, 1.0h);
#endif
}

half3 Emission(VertexOutputLit IN)
{
#if defined(_EMISSION)
    return readTexture(TEXTURE2D_PARAM(_EmissionMap, sampler_EmissionMap), IN).rgb * _EmissionColor.rgb;
#else
    return half3(0.0h, 0.0h, 0.0h);
#endif
}

half4 Albedo(VertexOutputLit IN)
{
    half4 albedo = readTexture(TEXTURE2D_PARAM(_MainTex, sampler_MainTex), IN) * IN.color;

    // No distortion Support
    fragColorMode(IN);
    fragSoftParticles(IN);
    fragCameraFading(IN);

    return albedo;
}

half4 SpecularGloss(VertexOutputLit IN, half alpha)
{
    half4 specularGloss = half4(0.0h, 0.0h, 0.0h, 1.0h);
#ifdef _SPECGLOSSMAP
    specularGloss = readTexture(TEXTURE2D_PARAM(_SpecGlossMap, sampler_SpecGlossMap), IN);
#elif defined(_SPECULAR_COLOR)
    specularGloss = _SpecColor;
#endif

#ifdef _GLOSSINESS_FROM_BASE_ALPHA
    specularGloss.a = alpha;
#endif
    return specularGloss;
}

half AlphaBlendAndTest(half alpha)
{
#if defined(_ALPHABLEND_ON) || defined(_ALPHAPREMULTIPLY_ON) || defined(_ALPHAOVERLAY_ON)
    half result = alpha;
#else
    half result = 1.0h;
#endif
    AlphaDiscard(result, _Cutoff, 0.0001h);

    return result;
}

half3 AlphaModulate(half3 albedo, half alpha)
{
#if defined(_ALPHAMODULATE_ON)
    return lerp(half3(1.0h, 1.0h, 1.0h), albedo, alpha);
#else
    return albedo;
#endif
}

void InitializeSurfaceData(VertexOutputLit IN, out SurfaceData surfaceData)
{
    half4 albedo = Albedo(IN);

#if defined(_METALLICGLOSSMAP)
    half2 metallicGloss = readTexture(TEXTURE2D_PARAM(_MetallicGlossMap, sampler_MetallicGlossMap), IN).ra * half2(1.0, _Glossiness);
#else
    half2 metallicGloss = half2(_Metallic, _Glossiness);
#endif

    half3 normalTS = NormalTS(IN);
    half3 emission = Emission(IN);

    surfaceData.albedo = albedo.rbg;
    surfaceData.specular = half3(0.0h, 0.0h, 0.0h);
    surfaceData.normalTS = normalTS;
    surfaceData.emission = emission;
    surfaceData.metallic = metallicGloss.r;
    surfaceData.smoothness = metallicGloss.g;
    surfaceData.occlusion = 1.0;

    surfaceData.alpha = AlphaBlendAndTest(albedo.a);
    surfaceData.albedo = AlphaModulate(surfaceData.albedo, surfaceData.alpha);
}

void InitializeInputData(VertexOutputLit IN, half3 normalTS, out InputData input)
{
    input.positionWS = IN.posWS.xyz;

#if _NORMALMAP
    input.normalWS = TangentToWorldNormal(normalTS, IN.tangent, IN.binormal, IN.normal);
#else
    input.normalWS = FragmentNormalWS(IN.normal);
#endif

    input.viewDirectionWS = FragmentViewDirWS(IN.viewDirShininess.xyz);
    input.shadowCoord = float4(0, 0, 0, 0);
    input.fogCoord = IN.posWS.w;
    input.vertexLighting = half3(0.0h, 0.0h, 0.0h);
    input.bakedGI = half3(0.0h, 0.0h, 0.0h);
}
