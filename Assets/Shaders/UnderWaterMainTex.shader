Shader "Unlit/UnderWaterMainTex"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        [HDR]_Tint("Tint",Color)= (1,1,1,1)
        _Intensity("Intensity",Float) = 1
        _NoiseScale("Noise Scale", Float) = 1
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            #pragma multi_compile_fog

            #include "UnityCG.cginc"
            #include "Noise.cginc"
            
            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float4 normalOS :NORMAL;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float3 posOS: TEXCOORD1;
                float3 normalWS:TEXCOORD2;
                float3 posWS:TEXCOORD3;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;

            float _Intensity;
            float4 _Tint;

            float _NoiseScale;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                o.posOS = v.vertex.xyz;
                o.normalWS = UnityObjectToWorldNormal(v.normalOS);
                o.posWS = mul(unity_ObjectToWorld,v.vertex);
                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
                float4 col = tex2D(_MainTex, i.uv);
                
                float uvScale = _NoiseScale;
                float caustic = Voronoi3D(i.posOS*uvScale +float3(0.2,0,0.2) - float3(1,0,1)*_Time.y);
                float caustic2 = Voronoi3D(i.posOS*uvScale +float3(0.1,0,0.1) - float3(1,0,1)*_Time.y);
                float caustic3 = Voronoi3D(i.posOS*uvScale - float3(0.1,0,0.1)- float3(1,0,1)*_Time.y);
                float3 c = float3(caustic,caustic2,caustic3);
                c = pow(c,5);
                
                float3 L = normalize(_WorldSpaceLightPos0.xyz);
                float3 N = normalize(i.normalWS.xyz);
                float NL = dot(N,L);
                float NL01 = NL*0.5+0.5;
                                   
                return col*_Intensity*_Tint*10 +c.xyzz*100*NL01;
            }
            ENDCG
        }
    }
}
