Shader "Custom/BeamShader"
{
    Properties
    {
        [MainColor] _BeamColor("ビームの色", Color) = (1, 1, 1, 1)
        [MainTexture] _BeamTexture("ビームのテクスチャ", 2D) = "white" {}
        [MainColor] _ParticleColor("粒子の色", Color) = (1, 1, 1, 1)
        [MainTexture] _ParticleTexture("粒子のテクスチャ", 2D) = "white" {}
				[Brightness] _Brightness("明るさ", Float) = 1
				[StartFadePosition] _StartFadePosition("始点フェードの位置（正規化済み）", Float) = 0.1
				[EndFadePosition] _EndFadePosition("終点フェードの位置（正規化済み）", Float) = 0.9
				[VerticalScale] _HorizontalScale("横方向の伸縮（正規化済み）", Float) = 1.0
				[ScrollSpeed] _ScrollSpeed("テクスチャのスクロール速度（メートル毎秒）", Float) = 10.0
				[AlphaOffset] _AlphaOffset("アルファ値を調整用", Float) = 0
    }

    SubShader
    {
        Tags { "RenderType" = "Transparent" "RenderPipeline" = "UniversalPipeline" }
        Blend SrcAlpha OneMinusSrcAlpha
        Cull Off
        ZWrite Off

        Pass
        {
            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

						//パラメーター宣言
            TEXTURE2D(_BeamTexture); SAMPLER(sampler_BeamTexture);
            TEXTURE2D(_ParticleTexture); SAMPLER(sampler_ParticleTexture);
						float4 _BeamColor, _ParticleColor;
						float _StartFadePosition, _EndFadePosition, _HorizontalScale, _ScrollSpeed, _Brightness, _AlphaOffset;

            struct VSInput
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct VSOutput
            {
                float4 positionHCS : SV_POSITION;
                float2 uv : TEXCOORD0;
            };

            VSOutput vert(VSInput IN)
            {
                VSOutput OUT;
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.uv = IN.uv;
                return OUT;
            }

            float4 frag(VSOutput IN) : SV_Target
            {
								float startFadeMask = smoothstep(_StartFadePosition, _StartFadePosition + 0.1, IN.uv.x);
								float endFadeMask = smoothstep(_EndFadePosition + 0.05, _EndFadePosition - 0.05, IN.uv.x);

								IN.uv.x += _Time.y * _ScrollSpeed;
								float4 beamIntensityTex = SAMPLE_TEXTURE2D(_BeamTexture, sampler_BeamTexture, float2(IN.uv.x * _HorizontalScale, IN.uv.y));
								float4 beamColor = beamIntensityTex.a * _Brightness * _Brightness * _Brightness * _BeamColor;

								//背景が明るいので端を少し黒くする
								beamColor -= float4(1,1,1,0) * 100 * (0.5 - IN.uv.y) * (0.5 - IN.uv.y) * (0.5 - IN.uv.y) * (0.5 - IN.uv.y);

								beamColor.a = beamIntensityTex.a;
								float4 particleIntensityTex = SAMPLE_TEXTURE2D(_ParticleTexture, sampler_ParticleTexture, float2(IN.uv.x * _HorizontalScale, IN.uv.y));
								float4 particleColor = particleIntensityTex.a * _Brightness * _Brightness * _ParticleColor;
								particleColor.a = particleIntensityTex.a;

								float4 finalColor = beamColor + particleColor;
								finalColor.a += _AlphaOffset;
                return finalColor * startFadeMask * endFadeMask;
            }
            ENDHLSL
        }
    }
}
