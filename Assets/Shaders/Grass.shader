Shader "URP/Grass"
{
    Properties
    {
        _TopColor("Top Color", Color) = (1,1,1,1)
        _BottomColor("Bottom Color", Color) = (1,1,1,1)
        _TranslucentGain("Translucent Gain", Range(0,1)) = 0.5
        _BladeWidth("Blade Width", Float) = 0.05
        _BladeWidthRandom("Blade Width Random", Float) = 0.02
        _BladeHeight("Blade Height", Float) = 0.5
        _BladeHeightRandom("Blade Height Random", Float) = 0.3
        _BladeForward("Blade Forward Amount", Float) = 0.38
        _BladeCurve("Blade Curvature Amount", Range(1, 4)) = 2
        _BendRotationRandom("Bend Rotation Random", Range(0, 1)) = 0.2
        _WindDistortionMap("Wind Distortion Map", 2D) = "white" {}
        _WindStrength("Wind Strength", Float) = 1
        _WindFrequency("Wind Frequency", Vector) = (0.05, 0.05, 0, 0)
    }

    SubShader
    {
        Tags { "RenderPipeline" = "UniversalRenderPipeline" "RenderType"="Opaque" }
        Pass
        {
            Name "ForwardLit"
            Tags{"LightMode" = "UniversalForward"}

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            // Vertex structure
            struct Attributes
            {
                float3 positionOS : POSITION;
                float3 normalOS : NORMAL;
                float2 uv : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float3 posWS : TEXCOORD0;
                float2 uv : TEXCOORD1;
                float3 normalWS : TEXCOORD2;
            };

            // Uniforms
            float4 _TopColor;
            float4 _BottomColor;
            float _TranslucentGain;

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                // Transform the vertex position to clip space
                OUT.positionCS = TransformObjectToHClip(IN.positionOS);
                OUT.posWS = TransformObjectToWorld(IN.positionOS);
                OUT.uv = IN.uv;
                OUT.normalWS = TransformObjectToWorldNormal(IN.normalOS);
                return OUT;
            }

            float4 frag(Varyings IN) : SV_Target
            {
                // Simple unlit shading based on vertex height (y-coordinate in UV space)
                float4 color = lerp(_BottomColor, _TopColor, IN.uv.y);
                return color;
            }
            ENDHLSL
        }
    }
    FallBack "Unlit"
}
