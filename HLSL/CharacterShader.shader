Shader "Character Shader"
{
    Properties
    {
        _MainTex("Diffuse", 2D) = "white" {}
        _MaskTex("Mask", 2D) = "white" {}
        _NormalMap("Normal Map", 2D) = "bump" {}
        [MaterialToggle] _ZWrite("ZWrite", Float) = 0

				//加速リングの情報
				_AccelRingPosX("加速リングのX座標", Float) = 0
				_AccelRingPosY("加速リングのY座標", Float) = 0
				_AccelRingRadiusX("加速リングのX半径", Float) = 0
				_AccelRingRadiusY("加速リングのY半径", Float) = 0
				//-1が左, +1が右とする
				_AccelRingFacingLR("加速リングの向き", Int) = 1

        // Legacy properties. They're here so that materials using this shader can gracefully fallback to the legacy sprite shader.
        [HideInInspector] _Color("Tint", Color) = (1,1,1,1)
        [HideInInspector] _RendererColor("RendererColor", Color) = (1,1,1,1)
        [HideInInspector] _AlphaTex("External Alpha", 2D) = "white" {}
        [HideInInspector] _EnableExternalAlpha("Enable External Alpha", Float) = 0
    }

    SubShader
    {
        Tags {"Queue" = "Transparent" "RenderType" = "Transparent" "RenderPipeline" = "UniversalPipeline" }

        Blend SrcAlpha OneMinusSrcAlpha, One OneMinusSrcAlpha
        Cull Off
        ZWrite [_ZWrite]

        Pass
        {
            Tags { "LightMode" = "Universal2D" }

            HLSLPROGRAM
            #include "Packages/com.unity.render-pipelines.universal/Shaders/2D/Include/Core2D.hlsl"

            #pragma vertex LitVertex
            #pragma fragment LitFragment

            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/Shaders/2D/Include/ShapeLightShared.hlsl"

            // GPU Instancing
            #pragma multi_compile_instancing
            #pragma multi_compile _ DEBUG_DISPLAY
            #pragma multi_compile _ SKINNED_SPRITE

            struct Attributes
            {
                COMMON_2D_INPUTS
                half4 color        : COLOR;
                UNITY_SKINNED_VERTEX_INPUTS
            };

            struct Varyings
            {
                COMMON_2D_LIT_OUTPUTS
                half4 color        : COLOR;
								float3 positionWS  : TEXCOORD4;
            };

            #include "Packages/com.unity.render-pipelines.universal/Shaders/2D/Include/Lit2DCommon.hlsl"

            // NOTE: Do not ifdef the properties here as SRP batcher can not handle different layouts.
            CBUFFER_START(UnityPerMaterial)
                half4 _Color;
								float _AccelRingPosX;
								float _AccelRingPosY;
								float _AccelRingRadiusX;
								float _AccelRingRadiusY;
								int _AccelRingFacingLR;
            CBUFFER_END

            Varyings LitVertex(Attributes input)
            {
                UNITY_SKINNED_VERTEX_COMPUTE(input);
                SetUpSpriteInstanceProperties();
                input.positionOS = UnityFlipSprite(input.positionOS, unity_SpriteProps.xy);

                Varyings o = CommonLitVertex(input);
                o.color = input.color * _Color * unity_SpriteColor;
								o.positionWS = TransformObjectToWorld(input.positionOS);

                return o;
            }

            half4 LitFragment(Varyings input) : SV_Target
            {
								//加速リングに相対する位置
								float3 positionRS = input.positionWS - float3(_AccelRingPosX, _AccelRingPosY, 0);
								float RingMask = 0;
								float sum = (positionRS.x * positionRS.x) / (_AccelRingRadiusX * _AccelRingRadiusX) + (positionRS.y * positionRS.y) / (_AccelRingRadiusY * _AccelRingRadiusY);
								sum -= 1;
								//sumが０より大きいならこのフラグメントは楕円の外側にある
								//sum ∈ [-1, inf)
								sum = FastSign(sum);
								sum = saturate(sum);
								uint outsideRing = (uint)sum;
								//正なら手前の方にある
								uint frontSide = (FastSign(positionRS.x * _AccelRingFacingLR) + 1) * 0.5;
								uint mask = outsideRing || frontSide;
								input.color.a *= mask;
                return CommonLitFragment(input, input.color);
            }
            ENDHLSL
        }

        Pass
        {
            Tags { "LightMode" = "NormalsRendering"}

            HLSLPROGRAM
            #include "Packages/com.unity.render-pipelines.universal/Shaders/2D/Include/Core2D.hlsl"

            #pragma vertex NormalsRenderingVertex
            #pragma fragment NormalsRenderingFragment

            // GPU Instancing
            #pragma multi_compile_instancing
            #pragma multi_compile _ SKINNED_SPRITE

            struct Attributes
            {
                COMMON_2D_NORMALS_INPUTS
                float4 color        : COLOR;
                UNITY_SKINNED_VERTEX_INPUTS
            };

            struct Varyings
            {
                COMMON_2D_NORMALS_OUTPUTS
                half4   color           : COLOR;
								float3 positionWS  : TEXCOORD4;
            };

            #include "Packages/com.unity.render-pipelines.universal/Shaders/2D/Include/Normals2DCommon.hlsl"

            // NOTE: Do not ifdef the properties here as SRP batcher can not handle different layouts.
            CBUFFER_START( UnityPerMaterial )
                half4 _Color;
								float _AccelRingPosX;
								float _AccelRingPosY;
								float _AccelRingRadiusX;
								float _AccelRingRadiusY;
								int _AccelRingFacingLR;
            CBUFFER_END

            Varyings NormalsRenderingVertex(Attributes input)
            {
                UNITY_SKINNED_VERTEX_COMPUTE(input);
                SetUpSpriteInstanceProperties();
                input.positionOS = UnityFlipSprite(input.positionOS, unity_SpriteProps.xy);

                Varyings o = CommonNormalsVertex(input);
                o.color = input.color * _Color * unity_SpriteColor;
								o.positionWS = TransformObjectToWorld(input.positionOS);

                return o;
            }

            half4 NormalsRenderingFragment(Varyings input) : SV_Target
            {
                return CommonNormalsFragment(input, input.color);
            }
            ENDHLSL
        }

        Pass
        {
            Tags { "LightMode" = "UniversalForward" "Queue"="Transparent" "RenderType"="Transparent"}

            HLSLPROGRAM
            #include "Packages/com.unity.render-pipelines.universal/Shaders/2D/Include/Core2D.hlsl"

            #pragma vertex UnlitVertex
            #pragma fragment UnlitFragment

            struct Attributes
            {
                COMMON_2D_INPUTS
                half4 color : COLOR;
                UNITY_SKINNED_VERTEX_INPUTS
            };

            struct Varyings
            {
                COMMON_2D_OUTPUTS
                half4 color : COLOR;
								float3 positionWS  : TEXCOORD4;
            };

            #include "Packages/com.unity.render-pipelines.universal/Shaders/2D/Include/2DCommon.hlsl"
          
            // GPU Instancing
            #pragma multi_compile_instancing
            #pragma multi_compile _ DEBUG_DISPLAY SKINNED_SPRITE

            // NOTE: Do not ifdef the properties here as SRP batcher can not handle different layouts.
            CBUFFER_START(UnityPerMaterial)
                half4 _Color;
								float _AccelRingPosX;
								float _AccelRingPosY;
								float _AccelRingRadiusX;
								float _AccelRingRadiusY;
								int _AccelRingFacingLR;
            CBUFFER_END

            Varyings UnlitVertex(Attributes input)
            {
                UNITY_SKINNED_VERTEX_COMPUTE(input);
                SetUpSpriteInstanceProperties();
                input.positionOS = UnityFlipSprite(input.positionOS, unity_SpriteProps.xy);

                Varyings o = CommonUnlitVertex(input);
                o.color = input.color *_Color * unity_SpriteColor;
								o.positionWS = TransformObjectToWorld(input.positionOS);
                return o;
            }

            half4 UnlitFragment(Varyings input) : SV_Target
            {
                return CommonUnlitFragment(input, input.color);
            }
            ENDHLSL
        }
    }
}
