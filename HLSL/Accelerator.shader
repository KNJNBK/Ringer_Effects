Shader "Custom/Accelerator"
{
    Properties
    {
        [MainColor] _BaseColor("Base Color", Color) = (1, 1, 1, 1)
				[OutlineColor] _OutlineColor("Outline Color", Color) = (0, 0, 0, 1)
				[LitColor] _LitColor("Lit Color", Color) = (1, 1, 1, 1)
				[Brightness] _Brightness("Brightness", float) = 5
        [MainTexture] _BaseMap("Base Map", 2D) = "white" {}
				[SpeedOfAnimation] _Speed("Speed of Animation", float) = 10
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


            TEXTURE2D(_BaseMap); SAMPLER(sampler_BaseMap);
            half4 _BaseColor, _OutlineColor, _LitColor;
						float _Speed, _Brightness;

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


            VSOutput vert(VSInput input)
            {
                VSOutput output;
                output.positionHCS = TransformObjectToHClip(input.positionOS.xyz);
                output.uv = input.uv;
                return output;
            }

            half4 frag(VSOutput input) : SV_Target
            {
                float4 lutTex = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv);

								//chevron's blue channel values are 0x10 0x20 0x30 0x40 respectively
								float wrappedTime = fmod(16 * _Time.y * _Speed, 80 -16);
								float mask = step(lutTex.b * 255, wrappedTime + 16);
								float maskPrev = 1 - step(255 * lutTex.b + 16, wrappedTime + 16);
								float alphaMask = step(0.1, lutTex.a);
								float lit_color_mask = mask * maskPrev;

								float outline_mask = step(0.1, 1 - lutTex.b) * (1-lit_color_mask) * lutTex.a;

								float4 color = _BaseColor * (1-lit_color_mask) * (1-outline_mask) + _Brightness * _LitColor * lit_color_mask + _OutlineColor * outline_mask;

                return color *= lutTex.a;
            }
            ENDHLSL
        }
    }
}
