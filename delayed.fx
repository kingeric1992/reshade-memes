
/*
    delayed.fx by kingeric1992 (Dec.6.2020)
*/


uniform float gDelay < ui_type = "slider"; ui_min=0; ui_max=60; ui_step=1; > = 1;
uniform float gTimer < source  = "timer"; >;
uniform int   gCount < source  = "framecount"; >;

namespace delay
{
    texture texT { Format  = R32F; }; sampler2D sampT { Texture = texT; };
    texture texC { Format  = R32F; }; sampler2D sampC { Texture = texC; };

/**********************************************************
 *  shaders
 **********************************************************/
// update timer on discontinuous frame count.

    float4 vs_timer( uint vid : SV_VERTEXID) : SV_POSITION  { return float4(0, 0, (gCount - 1.5 > tex2Dfetch(sampC,0).x) - .5, 1); }
    float  ps_timer( float4 vpos : SV_POSITION) : SV_TARGET { return gTimer; }
    float4 vs_count( uint vid : SV_VERTEXID) : SV_POSITION  { return float4(0, 0, 0, 1); }
    float4 ps_count( float4 vpos : SV_POSITION) : SV_TARGET { return gCount; }


    float4 vs_main( uint vid : SV_VERTEXID) : SV_POSITION {
        return float4( vid.xx == uint2(2,1)? float2(3,-3) : float2(-1,1),
            (tex2Dfetch(sampT,0).x + gDelay*1000. < gTimer) - .5, 1);
    }
    float4 ps_main( float4 vpos : SV_POSITION) : SV_TARGET { return 1; }

/**********************************************************
 *  technique
 **********************************************************/

    technique delay < toggle = 0x20; >
    {
        pass timer {
            PrimitiveTopology   = POINTLIST;
            VertexCount         = 1;
            VertexShader        = vs_timer;
            PixelShader         = ps_timer;
            RenderTarget        = texT;
        }
        pass count {
            PrimitiveTopology   = POINTLIST;
            VertexCount         = 1;
            VertexShader        = vs_count;
            PixelShader         = ps_count;
            RenderTarget        = texC;
        }
        pass main {
            VertexShader        = vs_main;
            PixelShader         = ps_main;
        }
    }
}