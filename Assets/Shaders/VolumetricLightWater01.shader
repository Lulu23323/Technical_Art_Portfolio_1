Shader "Unlit/VolumetricLightWater01"
{
    Properties
    {
        _CausticMap ("_Caustic", 2D) = "black" {}
        _Noise("Noise",2D) = "black"{}
        _BlueNoise("Blue Noise",2D) = "black"{}
        _RainbowMask("Rainbow Mask",2D) = "black"{}

        _Glaxy("Glaxy ",2D) = "white"{}

        _Color1("Color 1",Color)= (1,1,1,1)
        _Color2("Color 2",Color)= (1,1,1,1)
        _ColorGround("Color Ground",Color)= (0,0,0,0)

        [Space(20)]
        _Density("Density",Float) = 1
        _Absorption("_Absorption",Float) = 1
        _AbsorptionLerp("_AbsorptionLerp",Range(0,1)) = 1

        [Space(20)]
        _RainbowIntensity("_RainbowIntensity",Range(0,1)) = 0
        _RainbowScale("_RainbowScale",Range(0,100)) = 1
        _RainbowOffset("_RainbowOffset",Range(0,5)) = 0

        [Space(20)]
        [Toggle(ENABLE_CUT_BOTTOM)]_CutBottom("Cut Bottom",Float) =0
    }

    SubShader
    {
        Tags
        {
            "Queue"="Transparent"
        }
        LOD 100

        Pass
        {
            Blend SrcAlpha OneMinusSrcAlpha

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            #pragma shader_feature _ ENABLE_CUT_BOTTOM

            #include "Noise.cginc"
            #include "UnityCG.cginc"

            bool intersectAABB(float3 rayOrigin, float3 rayDir, float3 boxMin,
                               float3 boxMax, out float2 tNearFar)
            {
                float3 tMin = (boxMin - rayOrigin) / rayDir;
                float3 tMax = (boxMax - rayOrigin) / rayDir;
                float3 t1 = min(tMin, tMax);
                float3 t2 = max(tMin, tMax);
                float tNear = max(max(t1.x, t1.y), t1.z);
                float tFar = min(min(t2.x, t2.y), t2.z);
                tNearFar = float2(tNear, tFar);

                return tFar > tNear;
            }

            float iPlane(in float3 ro, in float3 rd, in float4 p, out float distance)
            {
                float3 normal = normalize(p.xyz);
                distance = -(dot(ro, normal) + p.w) / dot(rd, normal);
                return distance >= 0;
            }

            struct MeshData
            {
                float4 posOS : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct V2FData
            {
                float4 posCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 posOS : TEXCOORD1;
                float3 posWS : TEXCOORD2;
                float4 screenPos: TEXCOORD3;
            };


            sampler2D _CausticMap, _Noise, _RainbowMask, _Glaxy;

            V2FData vert(MeshData input)
            {
                V2FData output;
                output.posCS = UnityObjectToClipPos(input.posOS);
                output.posWS = mul(unity_ObjectToWorld, input.posOS).xyz;
                output.posOS = input.posOS;
                output.uv = input.uv;
                output.screenPos = ComputeScreenPos(output.posCS);

                return output;
            }

            float GetCaustic(float2 uv)
            {
                // float v1 = voronoi1(uv* 20 + float2(0.1, 0), _Time.y, 0, 1, 10);
                // return v1*0.75;
                
                float2 noise = tex2D(_Noise, uv + _Time.y * 0.1);
                float blueNoise = tex2D(_BlueNoise, uv * 5);
                float caustic_d1 = tex2D(_CausticMap, uv * 0.8 + _Time.y * 0.02 + noise * 0.2);
                float caustic_d2 = tex2D(_CausticMap, uv * 0.8 - _Time.y * 0.02 + caustic_d1 * 0.05);
                float caustic2 = tex2D(_CausticMap, uv * 0.5 - _Time.y * 0.02 + caustic_d2);
                return caustic2 * blueNoise * 5; //*caustic2*5;
                // return  tex2D(_CausticMap, uv +0.5,); //*caustic2*5;
            }

            float GetCausticGround(float2 uv)
            {
                float2 noise = tex2D(_Noise, uv - _Time.y * 0.01);
                float blueNoise = tex2D(_BlueNoise, uv * 5);
                // float caustic_d1 = tex2D(_CausticMap, uv * 0.8 + _Time.y * 0.02 + noise * 0.2);
                float caustic_d2 = tex2D(_CausticMap, uv * 0.8 - _Time.y * 0.01 + noise * 0.05);
                // float caustic2 = tex2D(_CausticMap, uv * 0.5 - _Time.y * 0.02 +caustic_d2);
                return caustic_d2 * blueNoise * 5;
                // return  tex2D(_CausticMap, uv +0.5,); //*caustic2*5;
            }

            bool intersectPlane(float3 n, float3 p0, float3 rayPos, float3 rayDir, out float t)
            {
                // assuming vectors are all normalized
                float denom = dot(-n, rayDir);
                if (denom > 1e-6)
                {
                    float3 difference = p0 - rayPos;
                    t = dot(difference, -n) / denom;
                    return (t >= 0);
                }

                return false;
            }

            float3 hsv2rgb(float3 c)
            {
                float3 rgb = clamp(abs(fmod(c.x * 6. + float3(0., 4., 2.), 6.) - 3.) - 1., 0., 1.);
                rgb = rgb * rgb * (3. - 2. * rgb);
                return c.z * lerp((float3)(1.), rgb, c.y);
            }

            float3 hsv2rgb(float h, float s, float v)
            {
                return hsv2rgb(float3(h, s, v));
            }
            
            #define _G0 -0.1
            #define _G1 0.1
            float _Absorption, _AbsorptionLerp;
            float _RainbowIntensity, _RainbowScale, _RainbowOffset;
            
            // Henyey-Greenstein 相函数
            // 夹角余弦，相函数参数值
            float hg(float a, float g)
            {
                float g2 = g * g;
                return (1 - g2) / (4 * 3.1415 * pow(1 + g2 - 2 * g * (a), 1.5));
            }

            float hg2(float a)
            {
                return lerp(hg(a, _G0), hg(a, _G1), _AbsorptionLerp);
            }

            // http://magnuswrenninge.com/wp-content/uploads/2010/03/Wrenninge-OzTheGreatAndVolumetric.pdf
            // 模拟多次散射的效果
            float multipleOctaves(float depth, float mu)
            {
                float luminance = 0;
                int octaves = 8;
                // Attenuation
                float a = 1;
                // Contribution
                float b = 1;
                // Phase attenuation
                float c = 1;

                float phase;

                for (int i = 0; i < octaves; ++i)
                {
                    phase = lerp(hg(mu, _G0 * c), hg(mu, _G1 * c), _AbsorptionLerp);
                    luminance += b * phase * exp(-depth * a * _Absorption);
                    a *= 0.2f;
                    b *= 0.5f;
                    c *= 0.5f;
                }
                // return hg2(mu) * Transmittance(depth, _Absorption);
                return luminance;
            }

            float4 _Color1, _Color2, _ColorGround;
            float _Density;

            /*
            float sdSphere(float3 p, float radius)
            {
                return length(p) - radius;
            }

            float opRep_sdSphere(in float3 p, in float3 c, float radius, float3 id)
            {
                float3 q = fmod(p + 0.5 * c, c) - 0.5 * c;
                id = floor(q * 10);
                float rd = hash(id);
                return sdSphere(q, radius * rd);
            }

            float map(float3 p)
            {
                float sdf = 10086.0;

                // float sdf_sphere1 = sdSphere(p,0.05);
                p += 0.5;
                float3 id;
                float sdf_sphere1 = opRep_sdSphere(p, float3(0.1, 0.1, 0.1), 0.005, id);

                return sdf_sphere1;
            }

            float3 calcNormal(in float3 pos)
            {
                float2 e = float2(1.0, -1.0) * 0.5773;
                const float eps = 0.0005;
                return normalize(e.xyy * map(pos + e.xyy * eps) +
                    e.yyx * map(pos + e.yyx * eps) +
                    e.yxy * map(pos + e.yxy * eps) +
                    e.xxx * map(pos + e.xxx * eps));
            }

            float3 Bubbles(float3 rayPos, float3 rayDir, float maxDistance)
            {
                float rayDepth = 0;
                float3 pos = 0;

                //将光线防线转到局部空间坐标，_WorldSpaceLightPos0.xyz是存储着平行光的方向
                float3 L = normalize(mul((float3x3)unity_WorldToObject, _WorldSpaceLightPos0.xyz));
                float3 H = normalize(L - rayDir);
                // rayPos = frac( rayPos*2) + rayDir*0.1;

                UNITY_LOOP
                for (int i = 0; i < 256; i++)
                {
                    pos = rayPos + rayDir * rayDepth;
                    float sdf = map(pos);

                    //来到了sdf的表面
                    if (sdf < 0.01f)
                    {
                        float3 N = normalize(calcNormal(pos));
                        float NH = saturate(dot(N, H));
                        float specular = pow(NH, 200);
                        return pow(saturate(1 - saturate(dot(N, -rayDir))), 2) * 0.2 + specular;
                    }

                    rayDepth += sdf;

                    if (rayDepth >= maxDistance)
                    {
                        return 0;
                    }
                }

                return 0;
            }
            */
  
            
            float4 frag(V2FData input) : SV_Target
            {
                //AABB
                float3 aabbMin = float3(-0.5, -0.5, -0.5);
                float3 aabbMax = float3(0.5, 0.5, 0.5);

                float3 cameraPosOS = mul(unity_WorldToObject, float4(_WorldSpaceCameraPos.xyz, 1));
                float3 rayPos = cameraPosOS;
                float3 rayDir = normalize(input.posOS - cameraPosOS);

                float2 aabbNearFar = (float2)0;
                bool isHit = intersectAABB(rayPos, rayDir, aabbMin, aabbMax, aabbNearFar);
                
                float tNear = max(aabbNearFar.x, 0);
                float tFar = aabbNearFar.y;
                //最大的步进距离
                float rayMaxDistance = tFar - tNear;

                float2 screenPos = input.screenPos.xy / input.screenPos.w;
                InitRandSeed(screenPos);

                //将光线防线转到局部空间坐标，_WorldSpaceLightPos0.xyz是存储着平行光的方向
                float3 L = normalize(mul((float3x3)unity_WorldToObject, _WorldSpaceLightPos0.xyz));

                float cosTheta = dot(L, rayDir);
                float phase = hg2(cosTheta);
                
                //体积光 核心算法 =======================================================
                float3 startPos = rayPos + tNear * rayDir;
                float3 endPos = rayPos + tFar * rayDir;

                float vlSamples = 50;
                float add = 1.0 / vlSamples;
                float3 vlLight = 0;
                
                // float3 LightPos = float3(1, 1, 1);

                UNITY_LOOP
                for (float k = 0; k < vlSamples; k++)
                {
                    float f = saturate((k + rand()) / vlSamples);
                    float3 p = lerp(startPos, endPos, f);
                    
                    //射线与平面求交
                    float distance;
                    // float3 lightDir = normalize(LightPos - p);
                    // iPlane(p,L,float4(0,-1,0,0.5),distance);
                    intersectPlane(float3(0, -1, 0), float3(0, 0.5, 0), p, L, distance);
                    float3 hitPos = p + L * distance;

                    //白色体积光
                    float3 caustic = GetCaustic(hitPos.xz);
                    //*hsv2rgb(float3((p.y+_RainbowOffset + dot(L,-rayDir))*_RainbowScale+0.5,_RainbowIntensity,1));//*spectral_zucconi6(p.y+0.5);
                    //彩色体积光
                    float noise = tex2D(_Noise, hitPos.xz).r;
                    noise = lerp(1, 1.3, noise);
                    float3 causticColorful = 5 * GetCaustic(hitPos.xz) *
                        hsv2rgb(float3(
                        (p.y + _RainbowOffset + dot(L, -rayDir) * 0.1) * _RainbowScale * noise + 0.5,
                        _RainbowIntensity, 1)); 
                    float rinbowMask = tex2D(_RainbowMask, hitPos.xz * 3);
                    caustic = lerp(caustic, causticColorful*1.5, rinbowMask) * 1.5;
                    // caustic = (causticColorful) * 1.5;
                    
                    vlLight += caustic * add;
                }

                //体积光 核心算法 =======================================================
                
                float height = input.posOS.y + 0.5;
                float noise = tex2D(_Noise, input.posOS.xz).r;

                vlLight = vlLight * smoothstep(0.2, 1.1 + noise, height) * 20;
                vlLight = vlLight * multipleOctaves(height, cosTheta);

                float3 color = lerp(_Color1, _Color2, height) * 0.5 + vlLight ;
                //水体边缘的透明度
                float alpha = exp(-rayMaxDistance * _Density);
                
                #ifndef  ENABLE_CUT_BOTTOM
                //=======水底=======================================================
                float dis; 
                float fog = exp(-4 * distance(input.posOS.xyz, cameraPosOS.xyz));
                float speed = _Time.y * 0.7;
                
                if (intersectPlane(float3(0, 1, 0), float3(0, -0.5, 0), rayPos, rayDir, dis))
                {
                    float3 groundPos = rayPos + dis * rayDir;
                    //这个判断防止地面无穷大，要限制在cube里面
                    if (groundPos.x < 0.5 && groundPos.x > -0.5 && groundPos.z < 0.5 && groundPos.z > -0.5)
                    // if (groundPos.x < 5 && groundPos.x > -5 && groundPos.z < 5 && groundPos.z > -5)
                    {//c1效果没有用ASE扰动之后效果好
                        float3 c1 = GetCausticGround(groundPos.xz) *5;
                        //ASE 噪音 voronoi1
                        float v1 = voronoi1(groundPos.xz * 10 + float2(0.1, 0), speed, 0, 1, 10);
                        float v2 = voronoi1(groundPos.xz * 10, speed, 0, 1, 10);
                        float v3 = voronoi1(groundPos.xz * 10 + float2(-0.1, 0.1), speed, 0, 1, 10);
                        float3 c2 = float3(v1, v2, v3) ;
                        // color.rgb += lerp(c1,c2,0.5);
                        color.rgb += (_ColorGround + c2*c2*12.25*0.75) * fog;

                        //扩展：用深度图判断是否需要显示
                        //地上的星星
                        //ASE 噪音 snoise
                        float s1 = snoise(groundPos * 100) * 0.5 + 0.5;
                        s1 = pow(s1, 50) * 200;

                        //视差
                        float3 pos = groundPos + rayDir * 0.1;
                        float s2 = snoise(pos * 75) * 0.5 + 0.5;
                        s2 = pow(s2, 50) * 100;

                        pos = groundPos + rayDir * 0.2;
                        float s3 = snoise(pos * 50) * 0.5 + 0.5;
                        s3 = pow(s3, 50) * 50;

                        float s = max(s1, s2);
                        s = max(s, s3);

                        float3 Glaxy = tex2D(_Glaxy, groundPos.xz * 0.5 + 0.5);
                        
                         color.rgb += saturate(s) * 3.5 * saturate(-rayDir.y)*Glaxy* hsv2rgb(
                             float3(groundPos.x + groundPos.z + _Time.y * 0.2, 1, 1));

                     
                    }
                }
                #endif
                //=======水底=======================================================
                //=======泡泡
                // float3 bubbles = Bubbles(startPos,rayDir,rayMaxDistance);
                // color.rgb+=bubbles;

                // color = lerp(lerp(1,color,0.5),color, (height<0.98));

                return float4(color.rgb + alpha * 0.05, saturate(1 - alpha - 0.02));
                // return float4(color.rgb, saturate(1 - alpha - 0.02));
            }
            ENDCG
        }
    }
}