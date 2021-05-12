/*
    tunes.fx by kingeric1992 (Nov.19.2020)
    A Demo on Image fade/decay.
*/
namespace tunes {

    uniform uint   gRandX   < source = "random"; min = 0; max = BUFFER_WIDTH; >;
    uniform uint   gRandY   < source = "random"; min = 0; max = BUFFER_HEIGHT; >;
    uniform float  gTimer   < source = "timer";>;
    uniform int    gCount   < source = "framecount";>;
    uniform uint   gFreq    < ui_type = "slider"; ui_min=1; ui_max=10;> = 3;
    uniform uint   gDecay   < ui_type = "slider"; ui_min=0; ui_max=100;> = 30;
    uniform float  gFrame   < source = "frametime";>;

    texture texT  { Format = R8; };
    texture texA  { Width = BUFFER_WIDTH/4; Height = BUFFER_HEIGHT/4; };
    texture texB  { Width = BUFFER_WIDTH/4; Height = BUFFER_HEIGHT/4; };
    sampler sampT { Texture = texT; };
    sampler sampA { Texture = texA; };
    sampler sampB { Texture = texB; };


/**********************************************************
 *  shaders
 **********************************************************/

    int getClock() { return (gTimer * gFreq *0.001) % 2; } // 0 or 1

    // random func of unknown origin.
    float3 rnd( float3 tc ) {
        float noise = sin(dot(tc, float3(12.9898, 78.233, 143.4))) * 43758.5453;
        return frac(noise * float4(1.0000, 1.2154, 1.3453, 1.3647)).rgb;
    }
    float4 vs_copy( uint vid : SV_VERTEXID) : SV_POSITION {
        return uint4(2,1,0,0) == vid? float4(3,-3,0,1) : float4(-1,1,0,1);
    }
    float4 ps_copy( float4 pos : SV_POSITION) : SV_TARGET {
        return tex2Dfetch(sampB, pos.xyzz);
    }
    float4 vs_clock() : SV_POSITION { return float4(0,0,0,1); }
    float  ps_clock() : SV_TARGET   { return getClock(); }
    float4 vs_point() : SV_POSITION {
        return float4(gRandX*BUFFER_RCP_WIDTH*2.-1, gRandY*BUFFER_RCP_HEIGHT*2.-1,
            abs(tex2Dfetch(sampT, (0).xxxx).x - getClock()) - .5, 1);
    }
    float3 ps_point( float4 pos : SV_POSITION) : SV_TARGET {
        return pos.w = gTimer, rnd(pos.xyw);
    }
    float4 vs_draw( uint vid : SV_VERTEXID, out float4 uv0 : TEXCOORD0, out float4 uv1 : TEXCOORD1 ) : SV_POSITION {
        float2 uv = (vid.xx == uint2(2,1))? (2.).xx: (0.).xx;
        float4 offset = float2(BUFFER_RCP_WIDTH,BUFFER_RCP_HEIGHT).xyxy * float2(2,sqrt(8.)).xxyy;

        uv0 = uv1 = uv.xyxy;
        [flatten]
        if(gCount % 2) {
            uv0.xz += offset.x, uv0.y = uv1.y += offset.y;
            uv1.xz -= offset.x, uv0.w = uv1.w -= offset.y;
        } else {
            uv0.y -= offset.w, uv0.w += offset.w;
            uv1.x -= offset.z, uv1.z += offset.z;
        }
        return float4( uv.x*2.-1., 1.-uv.y*2., 0, 1);
    }
    float4 ps_draw( float4 pos : SV_POSITION, float4 uv0 : TEXCOORD0, float4 uv1 : TEXCOORD1 ) : SV_TARGET {
        return max(max(tex2D(sampA, uv0.xy),tex2D(sampA, uv0.zw)), max(tex2D(sampA, uv1.xy),tex2D(sampA, uv1.zw)))
            - 0.000005 * gFrame * gDecay;
    }
    void   vs_post( uint vid : SV_VERTEXID, out float4 pos : SV_POSITION, out float4 uv : TEXCOORD ) {
        uv.xy   = (vid.xx == uint2(2,1))? (2.).xx: (0.).xx;
        uv.zw   = float2(BUFFER_RCP_WIDTH,BUFFER_RCP_HEIGHT) * 2;
        pos     = float4( uv.x*2.-1., 1.-uv.y*2., 0, 1);
        uv      = float4( uv.xy + uv.zw, uv.xy - uv.zw);
    }
    float4 ps_post( float4 pos : SV_POSITION, float4 uv : TEXCOORD ) : SV_TARGET {
        return ( tex2D(sampB, uv.xy) + tex2D(sampB, uv.xw) + tex2D(sampB, uv.zy) + tex2D(sampB, uv.zw)) * .25;
    }

/**********************************************************
 *  techniques
 **********************************************************/
    technique tones {
        pass draw {
            VertexShader        = vs_draw;
            PixelShader         = ps_draw;
            RenderTarget        = texB;
        }
        pass copy {
            VertexShader        = vs_copy;
            PixelShader         = ps_copy;
            RenderTarget        = texA;
        }
        pass point {
            VertexCount         = 1;
            PrimitiveTopology   = POINTLIST;
            VertexShader        = vs_point;
            PixelShader         = ps_point;
            RenderTarget        = texA;
        }
        pass clock {
            VertexCount         = 1;
            PrimitiveTopology   = POINTLIST;
            VertexShader        = vs_clock;
            PixelShader         = ps_clock;
            RenderTarget        = texT;
        }
        pass post {
            VertexShader        = vs_post;
            PixelShader         = ps_post;

            BlendEnable         = true;
            SrcBlend            = SRCCOLOR;
            DestBlend           = INVSRCCOLOR;
        }
    }
}