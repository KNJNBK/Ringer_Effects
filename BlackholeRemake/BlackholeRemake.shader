Shader "Custom/BlackholeRemake"
{
    Properties
    {
        [MainTexture] _BaseMap("Base Map", 2D) = "white" {}
				_Color1("Color 1", Color) = (1, 1, 1, 1)
				_Color2("Color 2", Color) = (1, 1, 1, 1)
        _HighlightMap("Highlight Map", 2D) = "white" {}
				_CompressionCoefficient("Compression Coefficient", Float) = 1
				_Multiplier("Compression Multiplier", Float) = 1
				_Offset("Compression Offset", Float) = 1
				_OuterRadius("Outer Radius", Float) = 1
				_InnerRadius("Inner Radius", Float) = 1
				_Brightness("Brightness", Float) = 1
				_TotalScale("Scale", Float) = 1
    }

    SubShader
    {
        Tags {"Queue" = "Transparent" "RenderType" = "Transparent" "RenderPipeline" = "UniversalPipeline" }
				ZWrite Off
				Blend SrcAlpha OneMinusSrcAlpha
        Pass
        {
            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
						#include "Assets/Shaders/BlackholeRemake/perlin.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float2 uv : TEXCOORD0;
            };

            TEXTURE2D(_BaseMap);			SAMPLER(sampler_BaseMap);
						TEXTURE2D(_HighlightMap);	SAMPLER(sampler_HighlightMap);

            CBUFFER_START(UnityPerMaterial)
								float4 _Color1, _Color2;
                float4 _BaseMap_ST;
								float _CompressionCoefficient, _Multiplier, _Offset, _InnerRadius, _OuterRadius, _Brightness, _TotalScale;
            CBUFFER_END

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.uv = TRANSFORM_TEX(IN.uv, _BaseMap);
                return OUT;
            }

						//アルファ合成
						float4 alphaCompositePremultipliedAlpha(float4 over_color, float4 under_color){
							float3 final_color = over_color.rgb * over_color.a  + under_color.rgb * (1 - over_color.a);
							float final_alpha = under_color.a + (over_color.a * (1 - under_color.a));
							return float4(final_color.rgb, final_alpha);
						}
						
						//ブラックホール周りの渦巻きみたいなノイズ
						float4 swirlThing(float2 uv, float scale, float4 color){
								float2 adjusted_uv_centered = (uv - 0.5) / scale;
								float angle = atan2(adjusted_uv_centered.y, adjusted_uv_centered.x) + 5 * _Time.y;
								float angle_normalized = angle / TWO_PI;
								float radius = length(adjusted_uv_centered);

								float2 shiftedUV = float2(radius * cos(angle), radius * sin(angle));
								float3 samplingPoint = 3 * float3(shiftedUV, 2 * _Time.x);
								float noiseValueX = perlinNoise3D(samplingPoint);
								float noiseValueY = perlinNoise3D(samplingPoint + float3(20, 20, 20));

                half4 alpha = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, adjusted_uv_centered + float2(0.5, 0.5) + 0.05 * float2(noiseValueX, noiseValueY));
								alpha *= smoothstep(_OuterRadius, _OuterRadius - 0.05, radius);
								float sourceAlpha = alpha.a;


								float sampling_radius = length(adjusted_uv_centered);
								float sampling_radius_normalized = sampling_radius / 0.4;
								sampling_radius *= _Multiplier * pow(sampling_radius_normalized, _CompressionCoefficient) + _Offset;

								float2 sampling_coords = sampling_radius * float2(cos(angle), sin(angle));
								float dropletsNoiseValue = perlinNoise3D(6 * float3(sampling_coords, 2 * _Time.x)) + 0.5;
								dropletsNoiseValue += 0.2 * smoothstep(0, 0.5, radius);
								dropletsNoiseValue *= smoothstep(_OuterRadius, _OuterRadius - 0.05, radius);
								float inversionMask = smoothstep(0.01, 0.2, dropletsNoiseValue - 0.2);
								float inverted_dropletsNoiseValue = saturate((1.0 - dropletsNoiseValue) * inversionMask);
								inverted_dropletsNoiseValue *= pow(smoothstep(0, 1, sampling_radius), 0.1);
								inverted_dropletsNoiseValue *= pow(inverted_dropletsNoiseValue, 2);

								return float4(color.rgb * _Brightness, saturate(max(sourceAlpha - 0.2 * dropletsNoiseValue, inverted_dropletsNoiseValue)));
						}

						//ノイズのマスク
						float swirlThingFade(float time){
							return smoothstep(0.9, 0.5, (1 - time)) * smoothstep(0.0, 0.3, (1 - time));
						}

            float4 frag(Varyings IN) : SV_Target
            {
								float delta_angle = 10 * _Time.y;
								float2 centered_uv = IN.uv - 0.5;
								float radius = _TotalScale * length(centered_uv);
								float angle = atan2(centered_uv.y, centered_uv.x);

								float color_period = 1;
								float interpolant = sin((_Time.y % color_period / color_period) * TWO_PI);
								float4 color = _Color1 * interpolant + _Color2 * (1 - interpolant);
								float4 highlight = smoothstep(0.5 / _TotalScale, 0.1 / _TotalScale, length(centered_uv)) * float4(10 * _Brightness * color.rgb, 0.5 * SAMPLE_TEXTURE2D(_HighlightMap, sampler_HighlightMap, float2(radius * cos(angle + delta_angle) + 0.5, radius * sin(angle + delta_angle) + 0.5)).a);

								float4 dark_center = float4(0, 0, 0, 0.8 * smoothstep(0.12, 0.11, radius));

								float period = 0.6;
								float time1 = 1 - ((_Time.y % period) / period);
								float time2 = 1 - (((_Time.y + 0.2) % period)/ period);
								float time3 = 1 - (((_Time.y + 0.4) % period) / period);

								float4 swirl1 = swirlThingFade(time1) * swirlThing(IN.uv, 1.5 * time1 / _TotalScale, color);
								float4 swirl2 = swirlThingFade(time2) * swirlThing(IN.uv, 1.5 * time2 / _TotalScale, color);
								float4 swirl3 = swirlThingFade(time3) * swirlThing(IN.uv, 1.5 * time3 / _TotalScale, color);
								float4 darkBG = float4(0,0,0, smoothstep(0.5 / _TotalScale, 0.1 / _TotalScale, length(centered_uv)));
								float4 a = alphaCompositePremultipliedAlpha(swirl1 + swirl2 + swirl3, darkBG);
								float4 b = alphaCompositePremultipliedAlpha(highlight, a);
								float4 final = alphaCompositePremultipliedAlpha(dark_center, b);
								return final;
            }

            ENDHLSL
        }
    }
}
