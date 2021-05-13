/*
    dishes.fx by kingeric1992 for Reshade (Jan.20.2021)

    credit:
        http://momentsingraphics.de/3DBlueNoise.html for 3d blue noise tex
        https://www.ronja-tutorials.com/2018/09/02/white-noise.html for 3d white noise.
*/

namespace dishes
{
    uniform float uS < ui_type="slider"; ui_label="Scale";   ui_min=1;    ui_max=20;  > = 10;
    uniform float zF < ui_type="slider";                     ui_min=100;  ui_max=999; > = 100;
    uniform float zN < ui_type="slider";                     ui_min=0.01; ui_max=1;   > = 1;
    uniform float uB < ui_type="slider"; ui_label="Freq";    ui_min=0;    ui_max=1;   > = .5;
    uniform float uA < ui_type="slider"; ui_label="Feather"; ui_min=0;    ui_max=.5;  > = .5;

/**********************************************************
 *  resources
 **********************************************************/
    #define FILTER(a) 	MagFilter = a; MinFilter = a; MipFilter = a
    #define ADDRESS(a)  AddressU = a; AddressV = a; AddressW = a
    #define NSIZE       32

    texture2D texCol    : COLOR;
    texture2D texDepth  : DEPTH;
    texture2D texNoise  < source = "blue3d.png"; > { Width = NSIZE*NSIZE; Height = NSIZE; Format = R8; };
    texture2D texDish   { Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; Format = R32F; }; // dish depth
    texture2D texPeel   { Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; Format = R32F; }; // dish depth
    texture2D texAccu   { Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; Format = RGBA16F; }; // accu depth
    texture2D texWOIT   { Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; Format = RG32F; }; // with stencil

    sampler2D sampCol   { Texture = texCol; };
    sampler2D sampDepth { Texture = texDepth; FILTER(POINT); };
    sampler2D sampNoise { Texture = texNoise; FILTER(LINEAR); };
    sampler2D sampDish  { Texture = texDish;  FILTER(POINT); };
    sampler2D sampPeel  { Texture = texPeel;  FILTER(POINT); };
    sampler2D sampWOIT  { Texture = texPeel;  FILTER(POINT); };
    sampler2D sampAccu  { Texture = texAccu;  FILTER(LINEAR); };


/**********************************************************
 *  functions
 **********************************************************/

    //https://www.ronja-tutorials.com/2018/09/02/white-noise.html
    float rand3dTo1d(float3 value, float3 dotDir ) {
        //make value smaller to avoid artefacts
        float3 smallValue = sin(value);
        //get scalar value from 3d vector
        float random = dot(smallValue, dotDir);
        //make value more random by making it bigger and then taking the factional part
        random = frac(sin(random) * 143758.5453);
        return random;
    }

    float3 rand3dTo3d(float3 value){
        return float3(
            rand3dTo1d(value, float3(12.989, 78.233, 37.719)),
            rand3dTo1d(value, float3(39.346, 11.135, 83.155)),
            rand3dTo1d(value, float3(73.156, 52.235,  9.151))
        );
    }

    float nlin( float z) { return zF / (zF + z * (zN - zF)); }
    float noises( float3 pos) {
        return lerp(
            tex2Dlod(sampNoise, float4((pos.x + floor(pos.z*NSIZE))/NSIZE, pos.y,0,0)).x,
            tex2Dlod(sampNoise, float4((pos.x + floor(pos.z*NSIZE+1.))/NSIZE, pos.y,0,0)).x, frac(pos.z*NSIZE));
    }
    uint2 split( uint vid, uint r) { return uint2( vid % r, vid / r); }

    float4 draw( uint vid, out float2 uv, out float4 col) {
        float2 psize  = float2(BUFFER_RCP_WIDTH, BUFFER_RCP_HEIGHT)*2;
        uint2  sub    = split(vid, 3);
        float2 offset = split(sub.y, BUFFER_WIDTH / 2);
        float  depth  = tex2Dfetch(sampDepth, offset * 2).x;
        float  lin    = nlin(1. - depth);

        col = tex2Dlod(sampCol, float4(offset.x*psize.x, 1.-offset.y*psize.y,0,0));
        uv  = float2( sub.x*sqrt(.75) - sqrt(.75), sub.x == 1? -1:.5 );

        float4 pos = float4((uv * (lin*zN > zF *.99 ? 0:max(uS*10/lin,3.)) + offset) * psize * 2. - 1, depth, 1);
        //float4 pos = float4((uv + offset) * psize * 2. - 1, depth, 1);
        // return noises(frac(float3(normalize(offset*psize)*lin , lin) * 100 / uS ) ) > uB ? 0: pos;
        lin = (lin-1)/(zF/zN - 1);
        return noises(rand3dTo3d(float3(offset*psize,lin))) > pow(lin,.5)*uB ? 0: pos;
    }

/**********************************************************
 *  shaders
 **********************************************************/

    float4 vs_depth( uint vid : SV_VERTEXID, out float2 uv : TEXCOORD0 ) : SV_POSITION {
        float4 col; return draw(vid, uv, col);
    }
    float  ps_depth(float4 pos : SV_POSITION, float2 uv : TEXCOORD0 ) : SV_TARGET {
        return length(uv) < .5 ? pos.z : 0; // 1 -> not blend
    }
    float4 vs_draw( uint vid : SV_VERTEXID, out float2 uv : TEXCOORD0, out float4 col : TEXCOORD1 ) : SV_POSITION {
        return draw(vid, uv, col);
    }
    float4 ps_draw(float4 pos : SV_POSITION, float2 uv : TEXCOORD0, float4 col : TEXCOORD1 ) : SV_TARGET {
        return col.w = step(length(uv), .5) * step(tex2Dfetch(sampDish, pos.xy).r, pos.z), col;
    }
    // float4 vs_front( uint vid : SV_VERTEXID, out float2 uv : TEXCOORD0, out float4 col : TEXCOORD1 ) : SV_POSITION {
    //     return draw(vid, uv, col);
    // }
    // float4 ps_front(float4 pos : SV_POSITION, float2 uv : TEXCOORD0, float4 col : TEXCOORD1 ) : SV_TARGET {
    //     if(pos.z < tex2Dfetch(sampDish, pos.xy).r || .5 < (col.w = length(uv))) discard;
    //     return col.rgb *= (col.w = smoothstep(.5, .1, col.w)), col;
    // }
    // float4 vs_peel( uint vid : SV_VERTEXID, out float2 uv : TEXCOORD0 ) : SV_POSITION {
    //     float4 col; return draw(vid, uv, col);
    // }
    // float  ps_peel(float4 pos : SV_POSITION, float2 uv : TEXCOORD0 ) : SV_TARGET {
    //     return length(uv) < .5 && pos.z < tex2Dfetch(sampDish, pos.xy).r ? pos.z : 0;
    // }
    // float4 vs_back( uint vid : SV_VERTEXID, out float2 uv : TEXCOORD0, out float4 col : TEXCOORD1 ) : SV_POSITION {
    //     return draw(vid, uv, col);
    // }
    // float4 ps_back(float4 pos : SV_POSITION, float2 uv : TEXCOORD0, float4 col : TEXCOORD1 ) : SV_TARGET {
    //     if(pos.z < tex2Dfetch(sampPeel, pos.xy).r || .5 < (col.w = length(uv)) || tex2Dfetch(sampDish, pos.xy).r <= pos.z) discard;
    //     return col.rgb *= (col.w = smoothstep(.5, .1, col.w)), col;
    // }
    float4 vs_accu( uint vid : SV_VERTEXID, out float2 uv : TEXCOORD0, out float4 col : TEXCOORD1 ) : SV_POSITION {
        return draw(vid, uv, col);
    }
    float4 ps_accu(float4 pos : SV_POSITION, float2 uv : TEXCOORD0, float4 col : TEXCOORD1 ) : SV_TARGET {
        return col.w = smoothstep(.5,uA,length(uv)), col;
    }
    float4 vs_norm( uint vid : SV_VERTEXID) : SV_POSITION {
        return float4((vid.xx == uint2(2,1))?float2(3,-3):float2(-1,1), 0, 1);
    }
    float4 ps_norm( float4 pos : SV_POSITION) : SV_TARGET {
        return pos = tex2Dfetch(sampAccu, pos.xy), pos.a > 0 ? pos/pos.a: 0;
    }
    float4 vs_weight( uint vid : SV_VERTEXID, out float2 uv : TEXCOORD0, out float4 col : TEXCOORD1 ) : SV_POSITION {
        return draw(vid, uv, col);
    }
    float4 ps_weight(float4 pos : SV_POSITION, float2 uv : TEXCOORD0, float4 col : TEXCOORD1 ) : SV_TARGET {
        return col.rgb *= (col.w = smoothstep(.5,uA,length(uv)) * pos.z * pos.z ), col;
    }


/**********************************************************
 *  technique
 **********************************************************/

    technique dishes
    {
        pass depth
        {
            VertexCount     = BUFFER_WIDTH * BUFFER_HEIGHT * 3 / 4;
            VertexShader    = vs_depth;
            PixelShader     = ps_depth;
            RenderTarget    = texDish;

            BlendEnable     = true;
            BlendOp         = MAX; // large value -> near
            DestBlend       = ONE;

            ClearRenderTargets = true;
        }
        pass draw
        {
            VertexCount     = BUFFER_WIDTH * BUFFER_HEIGHT * 3 / 4;
            VertexShader    = vs_draw;
            PixelShader     = ps_draw;

            BlendEnable     = true;
            SrcBlend        = SRCALPHA;
            DestBlend       = INVSRCALPHA;

            ClearRenderTargets = true;
        }
    }

    // depth peeling doesn't work well with particles.
    // technique peel
    // {
    //     pass depth
    //     {
    //         VertexCount     = BUFFER_WIDTH * BUFFER_HEIGHT * 3 / 4;
    //         VertexShader    = vs_depth;
    //         PixelShader     = ps_depth;
    //         RenderTarget    = texDish;

    //         BlendEnable     = true;
    //         BlendOp         = MAX; // large value -> near
    //         DestBlend       = ONE;

    //         ClearRenderTargets = true;
    //     }
    //     pass front
    //     {
    //         VertexCount     = BUFFER_WIDTH * BUFFER_HEIGHT * 3 / 4;
    //         VertexShader    = vs_front;
    //         PixelShader     = ps_front;

    //         ClearRenderTargets = true;
    //     }
    //     pass peel
    //     {
    //         VertexCount     = BUFFER_WIDTH * BUFFER_HEIGHT * 3 / 4;
    //         VertexShader    = vs_peel;
    //         PixelShader     = ps_peel;
    //         RenderTarget    = texPeel;

    //         BlendEnable     = true;
    //         BlendOp         = MAX; // large value -> near
    //         DestBlend       = ONE;

    //         ClearRenderTargets = true;
    //     }
    //     pass back
    //     {
    //         VertexCount     = BUFFER_WIDTH * BUFFER_HEIGHT * 3 / 4;
    //         VertexShader    = vs_back;
    //         PixelShader     = ps_back;

    //         BlendEnable     = true;
    //         SrcBlend        = INVDESTALPHA;
    //         DestBlend       = ONE;
    //         DestBlendAlpha  = ONE;
    //         SrcBlendAlpha   = INVDESTALPHA;
    //     }
    // }

    technique accu
    {
        pass accu
        {
            VertexCount     = BUFFER_WIDTH * BUFFER_HEIGHT * 3 / 4;
            VertexShader    = vs_accu;
            PixelShader     = ps_accu;
            RenderTarget    = texAccu;

            BlendEnable     = true;
            SrcBlend        = SRCALPHA;
            DestBlend       = ONE;
            DestBlendAlpha  = ONE;

            ClearRenderTargets = true;
        }
        pass norm
        {
            VertexShader    = vs_norm;
            PixelShader     = ps_norm;
        }
    }

    technique weighted
    {
        pass weight
        {
            VertexCount     = BUFFER_WIDTH * BUFFER_HEIGHT * 3 / 4;
            VertexShader    = vs_weight;
            PixelShader     = ps_weight;
            RenderTarget    = texAccu;

            BlendEnable     = true;
            DestBlend       = ONE;
            DestBlendAlpha  = ONE;

            ClearRenderTargets = true;
        }
        pass norm
        {
            VertexShader    = vs_norm;
            PixelShader     = ps_norm;
        }
    }
}


