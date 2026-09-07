Shader "Custom/Blackhole2D"
{
    Properties
    {
        _BlackHoleLUT ("Black Hole LUT (RGBA)", 2D) = "black" {}
				_RenderTexture("Camera Render Texture", 2D) = "back" {}
        _DiskTex ("Accretion Disk Texture", 2D) = "white" {}
        _DiskColor ("Disk Tint Color", Color) = (1, 0.5, 0, 1)
				_Scale ("Scale", Float) = 1
				_Brightness ("Brightness", Float) = 1
				_DarkMask ("Darkness Mask", Float) = 500
        _AngularVelocity ("Angular Velocity", Float) = 1
        _AngleScale ("Angle Scale", Float) = 1
				_NoiseOuterRadius("Outer Radius of Noise", Float) = 4
				_NoiseInnerRadius("Inner Radius of Noise", Float) = 1 
				_NoiseCompression("Noise Compression", Float) = 5
    }

    SubShader
    {
        Tags { "RenderType"="Transparent" "Queue"="Transparent+1" "RenderPipeline" = "UniversalPipeline" }
        Blend SrcAlpha OneMinusSrcAlpha
        Cull Off
        ZWrite Off

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
						#include "Assets/Shaders/HLSL/perlin.hlsl"

            struct VSInput
						{
                float4 positionOS   : POSITION;
                float2 uv           : TEXCOORD0;
            };

            struct VSOutput
            {
                float4 positionCS   : SV_POSITION;
                float2 uv           : TEXCOORD0;
								float4 screenUV 		: TEXCOORD1;
            };

            TEXTURE2D(_RenderTexture);		SAMPLER(sampler_RenderTexture);
            TEXTURE2D(_BlackHoleLUT);			SAMPLER(sampler_BlackHoleLUT);
            TEXTURE2D(_DiskTex);					SAMPLER(sampler_DiskTex);

            float4 _DiskColor;
						float _Scale, _Brightness, _AngularVelocity, _AngleScale, _NoiseInnerRadius, _NoiseOuterRadius, _NoiseCompression, _DarkMask;

            VSOutput vert(VSInput input)
            {
                VSOutput output;
                VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
                output.positionCS = vertexInput.positionCS;
                output.uv = input.uv;
								output.screenUV = GetVertexPositionInputs(input.positionOS.xyz).positionNDC;
                return output;
            }

            float4 frag(VSOutput input) : SV_Target
            {
								float2 uvNormalized = (input.uv - 0.5) * _Scale;
								float2 blackholeUV = uvNormalized + 0.5;
								//LUTから情報を採取
                float4 lut = SAMPLE_TEXTURE2D(_BlackHoleLUT, sampler_BlackHoleLUT, blackholeUV);

								//中心に落ちたのなら
                if (lut.a == 1.0) 
                {
                    return float4(0, 0, 0, 1);
                }

								//Look Up TableをLook Upして背景おサンプルを採取
                float2 distortedUV = input.uv + lut.rg;
                float4 backgroundColor = SAMPLE_TEXTURE2D(_RenderTexture, sampler_RenderTexture, distortedUV);

								//降着円盤用の色
                float4 diskColor = float4(0, 0, 0, 0);

								float darkMask = 1/min(_Scale * _DarkMask*length(input.uv - 0.5)*length(input.uv - 0.5), 1);

								float2 normalizedRadial = float2(lut.b, lut.a);
                if (length(normalizedRadial) > 1.0)
                {
										darkMask = 1;
										float2 radial = (normalizedRadial * (_NoiseOuterRadius - _NoiseInnerRadius)) + (normalizedRadial * _NoiseInnerRadius);
                    float distanceFromCenterNormalized = (length(radial) - (_NoiseOuterRadius - _NoiseInnerRadius))/(_NoiseOuterRadius - _NoiseInnerRadius);
                    radial *= _NoiseCompression; // add a small offset based on distance from center
                    float angle = atan2(radial.y, radial.x);
										float radius = length(radial);
                    angle *= _AngleScale;
                    float timeOffset = _Time.x * _AngularVelocity;
                    float noise = fbmNoise3D(float3(radius * cos(angle + timeOffset), radius * sin(angle + timeOffset), _Time.x)
                    , 1, 2.17, 0.5);
                    float3 color = _DiskColor * noise;
                    color *= 5*noise;
                    diskColor.a = 1.0;
                    diskColor.rgb = color * _Brightness;
                }

                float4 finalColor = lerp(backgroundColor, diskColor, diskColor.a);
								finalColor.rgb /= darkMask;
                return finalColor;
            }
            ENDHLSL
        }
    }
}
