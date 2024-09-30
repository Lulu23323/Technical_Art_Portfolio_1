#ifndef NOISE
#define NOISE

#include "UnityCG.cginc"
//=========Noise ====================================================================================================//
sampler2D _BlueNoise;
float2 _Pixel;
float _Seed;

void InitRandSeed(float2 uv)
{
    _Seed = _Time.y;
    float blueNoise = tex2D(_BlueNoise, uv * 10);
    _Pixel = blueNoise + uv;
}

float rand()
{
    float result = frac(sin(_Seed / 100.0f * dot(_Pixel, float2(12.9898f, 78.233f))) * 43758.5453f);
    _Seed += 1.0f;
    return result;
}

// float hash(float3 seed)
// {
//     float result = frac(sin(seed / 100.0f * dot(_Pixel, float3(12.9898f, 78.233f, 78.9898f))) * 43758.5453f);
//     return result;
// }

float hash(float x) { return frac(x + 1.3215 * 1.8152); }
float hash3(float3 a) { return frac((hash(a.z * 42.8883) + hash(a.y * 36.9125) + hash(a.x * 65.4321)) * 291.1257); }

float3 rehash3(float x)
{
    return float3(hash(((x + 0.5283) * 59.3829) * 274.3487), hash(((x + 0.8192) * 83.6621) * 345.3871),
                  hash(((x + 0.2157f) * 36.6521f) * 458.3971f));
}

float sqr(float x) { return x * x; }
float fastdist(float3 a, float3 b) { return sqr(b.x - a.x) + sqr(b.y - a.y) + sqr(b.z - a.z); }

float2 Voronoi3D(float3 xyz)
{
    float x = xyz.x;
    float y = xyz.y;
    float z = xyz.z;
    float4 p[27];
    for (int _x = -1; _x < 2; _x++)
        for (int _y = -1; _y < 2; _y++)
            for (int _z = -1; _z < 2; _z++)
            {
                float3 _p = float3(floor(x), floor(y), floor(z)) + float3(_x, _y, _z);
                float h = hash3(_p);
                p[(_x + 1) + ((_y + 1) * 3) + ((_z + 1) * 3 * 3)] = float4((rehash3(h) + _p).xyz, h);
            }
    float m = 9999.9999, w = 0.0;
    for (int i = 0; i < 27; i++)
    {
        float d = fastdist(float3(x, y, z), p[i].xyz);
        if (d < m)
        {
            m = d;
            w = p[i].w;
        }
    }
    return float2(m, w);
}

float2 voronoihash1(float2 p)
{
    p = float2(dot(p, float2(127.1, 311.7)), dot(p, float2(269.5, 183.3)));
    return frac(sin(p) * 43758.5453);
}

float voronoi1(float2 v, float time, float2 id, float2 mr, float smoothness)
{
    float2 n = floor(v);
    float2 f = frac(v);
    float F1 = 8.0;
    float F2 = 8.0;
    float2 mg = 0;
    for (int j = -1; j <= 1; j++)
    {
        for (int i = -1; i <= 1; i++)
        {
            float2 g = float2(i, j);
            float2 o = voronoihash1(n + g);
            o = (sin(time + o * 6.2831) * 0.5 + 0.5);
            float2 r = f - g - o;
            float d = 0.5 * dot(r, r);
            if (d < F1)
            {
                F2 = F1;
                F1 = d;
                mg = g;
                mr = r;
                id = o;
            }
            else if (d < F2)
            {
                F2 = d;
            }
        }
    }
    return (F2 + F1) * 0.5;
}

float3 mod3D289(float3 x) { return x - floor(x / 289.0) * 289.0; }
float4 mod3D289(float4 x) { return x - floor(x / 289.0) * 289.0; }
float4 permute(float4 x) { return mod3D289((x * 34.0 + 1.0) * x); }
float4 taylorInvSqrt(float4 r) { return 1.79284291400159 - r * 0.85373472095314; }

float snoise(float3 v)
{
    const float2 C = float2(1.0 / 6.0, 1.0 / 3.0);
    float3 i = floor(v + dot(v, C.yyy));
    float3 x0 = v - i + dot(i, C.xxx);
    float3 g = step(x0.yzx, x0.xyz);
    float3 l = 1.0 - g;
    float3 i1 = min(g.xyz, l.zxy);
    float3 i2 = max(g.xyz, l.zxy);
    float3 x1 = x0 - i1 + C.xxx;
    float3 x2 = x0 - i2 + C.yyy;
    float3 x3 = x0 - 0.5;
    i = mod3D289(i);
    float4 p = permute(
        permute(permute(i.z + float4(0.0, i1.z, i2.z, 1.0)) + i.y + float4(0.0, i1.y, i2.y, 1.0)) + i.x + float4(
            0.0, i1.x, i2.x, 1.0));
    float4 j = p - 49.0 * floor(p / 49.0); // mod(p,7*7)
    float4 x_ = floor(j / 7.0);
    float4 y_ = floor(j - 7.0 * x_); // mod(j,N)
    float4 x = (x_ * 2.0 + 0.5) / 7.0 - 1.0;
    float4 y = (y_ * 2.0 + 0.5) / 7.0 - 1.0;
    float4 h = 1.0 - abs(x) - abs(y);
    float4 b0 = float4(x.xy, y.xy);
    float4 b1 = float4(x.zw, y.zw);
    float4 s0 = floor(b0) * 2.0 + 1.0;
    float4 s1 = floor(b1) * 2.0 + 1.0;
    float4 sh = -step(h, 0.0);
    float4 a0 = b0.xzyw + s0.xzyw * sh.xxyy;
    float4 a1 = b1.xzyw + s1.xzyw * sh.zzww;
    float3 g0 = float3(a0.xy, h.x);
    float3 g1 = float3(a0.zw, h.y);
    float3 g2 = float3(a1.xy, h.z);
    float3 g3 = float3(a1.zw, h.w);
    float4 norm = taylorInvSqrt(float4(dot(g0, g0), dot(g1, g1), dot(g2, g2), dot(g3, g3)));
    g0 *= norm.x;
    g1 *= norm.y;
    g2 *= norm.z;
    g3 *= norm.w;
    float4 m = max(0.6 - float4(dot(x0, x0), dot(x1, x1), dot(x2, x2), dot(x3, x3)), 0.0);
    m = m * m;
    m = m * m;
    float4 px = float4(dot(x0, g0), dot(x1, g1), dot(x2, g2), dot(x3, g3));
    return 42.0 * dot(m, px);
}

//=========Noise ====================================================================================================//


#endif
