Shader "Custom/BeamHitShader"
{
    Properties
    {
        [MainColor] _BeamHitColor("ビームの色", Color) = (1, 1, 1, 1)
        [MainTexture] _BeamHitTexture("ビームのテクスチャ", 2D) = "white" {}
				[Brightness] _Brightness("明るさ", Float) = 1
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

            TEXTURE2D(_BeamHitTexture); SAMPLER(sampler_BeamHitTexture);
						float4 _BeamHitColor;
						float _Brightness;


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
							float4 texSample = SAMPLE_TEXTURE2D(_BeamHitTexture, sampler_BeamHitTexture, IN.uv);
							float4 color = float4(_Brightness * _BeamHitColor.xyz, texSample.a);
							return color;
            }
            ENDHLSL
        }
    }
}
