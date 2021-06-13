/*
    lsd.fx by kingeric1992 (June.11.2021 hotfix)
    apply hueshift by perlin noise overtime.
    !! epilepsy warning !!
*/

uniform float gSpeed <ui_type="slider"; ui_min=0; ui_max=100;> = 10.;
uniform float gScale <ui_type="slider"; ui_min=1; ui_max=10; > = 5.;
uniform float gRange <ui_type="slider"; ui_min=0; ui_max=1;  > = .3;
uniform float gTimer <source="timer"; >;

texture2D tex : COLOR;
sampler2D samp { Texture=tex; };

/**********************************************************
 *  helpers
 **********************************************************/

// random func of unknown origin.
float3 rnd( float3 tc ) {
    float n = sin(dot(tc, float3(12.9898, 78.233, 143.4))) * 43758.5453;
    return frac(n * float4(1.0000, 1.2154, 1.3453, 1.3647)).rgb;
}
// https://en.wikipedia.org/wiki/Perlin_noise
float perlin( float3 uv ) {
    float3 b = floor(uv), k = float3(1,0,-1);
    float3 d = frac(uv), d2 = d*d, d3 = d*d2, w = 6*d2*d3 - 15*d2*d2 + 10*d3;
    float3 g[12] = {k.yxx, k.yxz, k.yzx, k.yzz, k.xyx, k.xyz,
                    k.zyx, k.zyz, k.xxy, k.xzy, k.zxy, k.zzy };  //len = sqrt(2)
    float4 l = lerp(
        float4( dot(d - k.yyy, g[int(rnd(b + k.yyy).x*11.999)]),
                dot(d - k.xyy, g[int(rnd(b + k.xyy).x*11.999)]),
                dot(d - k.yxy, g[int(rnd(b + k.yxy).x*11.999)]),
                dot(d - k.xxy, g[int(rnd(b + k.xxy).x*11.999)])),
        float4( dot(d - k.yyx, g[int(rnd(b + k.yyx).x*11.999)]),
                dot(d - k.xyx, g[int(rnd(b + k.xyx).x*11.999)]),
                dot(d - k.yxx, g[int(rnd(b + k.yxx).x*11.999)]),
                dot(d - k.xxx, g[int(rnd(b + k.xxx).x*11.999)])), w.z );
    return l.xy = lerp(l.xy, l.zw, w.y), lerp(l.x, l.y, w.x) / sqrt(2.);   // [-1, 1]
}
float3 rgb2hsl(float3 c) {
    float3 o   = 0.;
    float  M   = max(c.r, max(c.g, c.b));
    float  d   = M - min(c.r, min(c.g, c.b));
           o.z = M - .5 * d;
    [flatten] if (d != 0.) {
        float3 k = c.gbr < M? 0: ((c.brg - c.rgb) / d + float3(2, 4, 6));
        o.x = frac(max(k.r, max(k.g, k.b)) / 6.);
        o.y = o.z == 1. ? 0: d / (1. - abs( 2 * o.z - 1));
    }
    return o;
}
float3 h2rgb( float h) {
    float3 t = abs(h * 6. - float3(3, 2, 4));
    return t.yz = -t.yz, saturate( t + float3(-1,2,2));
}
float3 hsl2rgb( float3 HSL) {
    return (h2rgb(HSL.x) - .5) * (1. - abs(2. * HSL.z - 1)) * HSL.y + HSL.z;
}
/**********************************************************
 *  shader
 **********************************************************/

float4 vs_main( uint vid : SV_VERTEXID, out float2 uv : TEXCOORD0, out float3 seed : TEXCOORD1) : SV_POSITION {
    seed.xy = (uv = int2(2,1) == vid? (2.).xx:0) * gScale;
    seed.x *= BUFFER_WIDTH * BUFFER_RCP_HEIGHT;
    seed.z  = gTimer * gSpeed * 0.00003;
    return float4(uv * float2(2,-2) + float2(-1,1), 0, 1);
}
float3 ps_main(float4 vpos : SV_POSITION, float2 uv : TEXCOORD, float3 seed : TEXCOORD1) : SV_TARGET {
    float3 hsl = rgb2hsl(tex2D(samp, uv).rgb);
    hsl.x = frac(hsl.x + seed.z + perlin(seed) * gRange);
    return hsl2rgb(hsl);
}
/**********************************************************
 *  technique
 **********************************************************/
technique lSD < ui_label="lSD (epilepsy warning)"; >
{
    pass main {
        VertexShader = vs_main;
        PixelShader  = ps_main;
        RenderTargetWriteMask = 7;
    }
}