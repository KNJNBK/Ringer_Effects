Shader "Custom/Raymarch"
{
    Properties
    {
			_BaseColor("Base Color", Color) = (1,1,1,1)
            _Alpha("Alpha", Float) = 1
        _Frequency ("Frequency", Float) = 10.0 
        _Octaves ("Octaves", Int) = 5 
        _Lacunarity ("Lacunarity", Float) = 2.17 
        _Gain ("Gain", Float) = 0.5 
				_RayStepDistance("Ray Step Distance", Float) = 0.5 
				_RayStepCount("Ray Step Count", Int) = 20 
				_VerticalDrift("Vertical Drift", Float) = 1
				_RotationSpeed("Rotation Speed", Float) = 1
				_InnerRadius("Inner Radius", Float) = 2.0
				_OuterRadius("Outer Radius", Float) = 3.0
				_InnerFadeZone("Inner Fade Zone", Float) = 0.2
				_OuterFadeZone("Outer Fade Zone", Float) = 0.2
				_CompressionPower("Stretch the sampling radially", Float) = 2
				_CompressionScale("Compression Scale", Float) = 2
				_AccumulationMultiplier("Accumulation Scale", Float) = 2
		}
    SubShader
    {
        Tags {"Queue" = "Transparent" "RenderType" = "Transparent" "RenderPipeline" = "UniversalPipeline" }
				ZWrite Off        // don't write to depth buffer
				Blend SrcAlpha OneMinusSrcAlpha  // blend with background using alpha
        Pass
        {
            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
						#include "Assets/Shaders/HLSL/perlin.hlsl"

            struct vertInput {
                float4 vertex : POSITION; //vertex position
                float2 uv : TEXCOORD0;
            };

            struct v2f {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
								float3 localPos : TEXCOORD1;
            };

						struct RayData{
							float3 position;
							float3 direction;
							float step;
							int stepCount;
						};

            float _Alpha, _Frequency, _Lacunarity, _Gain, _RayStepDistance, _VerticalDrift, _RotationSpeed, _InnerRadius, _OuterRadius, _InnerFadeZone, _OuterFadeZone, _CompressionPower, _CompressionScale, _AccumulationMultiplier;
            int _Octaves, _RayStepCount;
						float4 _BaseColor;
						v2f vert(vertInput input){
							v2f o;
							o.pos.xyz = TransformObjectToWorld(input.vertex.xyz);
							o.pos = TransformWorldToHClip(o.pos);
							o.uv = input.uv;
							float3 positionWS = TransformObjectToWorld(input.vertex.xyz);
							o.localPos = input.vertex.xyz;
							return o;
						};

						float4 frag(v2f i) : SV_TARGET
						{
							RayData ray = {i.localPos, float3(0,-1,0), _RayStepDistance, _RayStepCount};
							ray.position *= _Frequency;
							ray.position += float3(0, 0, _Time.x * _VerticalDrift);
							float accumulation;
							float3 noisePos = ray.position;
							float2 radial = noisePos.xy;
							float radius = max(length(radial), 0.001);
							float angle = atan2(radial.y, radial.x);
							float TranslatedAngle = angle + _Time.x * _RotationSpeed;

							float normalizedRadius = (radius - _InnerRadius) / (_OuterRadius - _InnerRadius); // 0 at inner, 1 at outer

							float compressedNormalized = pow(normalizedRadius, _CompressionPower); // e.g. 2.0 or 3.0
							float CompressedRadius = _InnerRadius + (1-compressedNormalized)*(_CompressionScale) * (_OuterRadius - _InnerRadius);
							float2 FinalRadial = float2(CompressedRadius * cos(TranslatedAngle), CompressedRadius * sin(TranslatedAngle));
							float3 FinalSamplingPos = float3(FinalRadial.x, FinalRadial.y, ray.position.z);

							float centerMask = smoothstep(_InnerRadius, _InnerRadius + _InnerFadeZone, radius);

							float ringMask = smoothstep(_InnerRadius, _InnerRadius + _InnerFadeZone, radius)
               * (1.0 - smoothstep(_OuterRadius - _OuterFadeZone, _OuterRadius, radius));

							for (int i = 0; i < ray.stepCount; i++){
								FinalSamplingPos += float3(0, 0, -ray.step);

								float noiseVal = fbmNoise3D(FinalSamplingPos, _Octaves, _Lacunarity, _Gain);

								accumulation += noiseVal;
								accumulation *= ringMask;
								accumulation *= _AccumulationMultiplier;
									if (accumulation >= 1.0) break;
								}
							float result = saturate(accumulation / (float)ray.stepCount);
							float alpha = max(result, (1-centerMask));
							float3 color = float3(alpha, alpha, alpha);
							_BaseColor *= _AccumulationMultiplier;
							color += _BaseColor;
							color *= centerMask;
							return float4(color, alpha * _Alpha);
						};
            ENDHLSL
        }
    }
}
