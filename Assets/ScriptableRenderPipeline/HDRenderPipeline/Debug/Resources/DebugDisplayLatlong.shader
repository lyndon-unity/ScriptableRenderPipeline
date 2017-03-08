Shader "Hidden/HDRenderPipeline/DebugDisplayLatlong"
{
    SubShader
    {
        Pass
        {
            ZWrite Off
            ZTest Off
            Blend One Zero
            Cull Off

            HLSLPROGRAM
            #pragma target 4.5
            #pragma only_renderers d3d11 ps4 metal // TEMP: unitl we go futher in dev

            #pragma vertex Vert
            #pragma fragment Frag

            #include "ShaderLibrary/Common.hlsl"
            #include "ShaderLibrary/ImageBasedLighting.hlsl"

            TEXTURECUBE(_InputCubemap);
            SAMPLERCUBE(sampler_InputCubemap);
            float _Mipmap;

            struct Attributes
            {
                uint vertexID : SV_VertexID;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 texcoord : TEXCOORD0;
            };

            Varyings Vert(Attributes input)
            {
                Varyings output;
                output.positionCS = GetFullScreenTriangleVertexPosition(input.vertexID);
                output.texcoord = GetFullScreenTriangleTexcoord(input.vertexID);// *_TextureScaleBias.xy + _TextureScaleBias.zw;

                return output;
            }

            float4 Frag(Varyings input) : SV_Target
            {
                uint width, height, depth, mipCount;
                width = height = depth = mipCount = 0;
                _InputCubemap.GetDimensions(width, height, depth, mipCount);
                mipCount = clamp(mipCount, 0, UNITY_SPECCUBE_LOD_STEPS);
                return SAMPLE_TEXTURECUBE_LOD(_InputCubemap, sampler_InputCubemap, LatlongToDirectionCoordinate(input.texcoord.xy), _Mipmap * mipCount);
            }

            ENDHLSL
        }

    }
    Fallback Off
}