/*
    falling.fx by kingeric1992 (Dec.4.2020)
*/

#ifndef MAX_INSTANCE_COUNT
    #define MAX_INSTANCE_COUNT 20
#endif

namespace falling {

    uniform float   gTimer   < source = "timer";>;
    uniform uint    gCount   < ui_type = "slider"; ui_min=1; ui_max=MAX_INSTANCE_COUNT;> = 15;
    uniform uint    gSpeed   < ui_type = "slider"; ui_min=1; ui_max=10;> = 3;
    uniform uint    gRotate  < ui_type = "slider"; ui_min=1; ui_max=10;> = 3;
    uniform uint    gSize    < ui_type = "slider"; ui_min=1; ui_max=10;> = 3;

    texture tex <source = "gawrgura.png"; >  { Width = 2400; Height = 600; };
    sampler samp { Texture = tex; };

    /**********************************************************
    *  shader
    **********************************************************/

    // random func of unknown origin.
    float3 rnd( float3 tc ) {
        float noise = sin(dot(tc, float3(12.9898, 78.233, 143.4))) * 43758.5453;
        return frac(noise * float4(1.0000, 1.2154, 1.3453, 1.3647)).rgb;
    }

    float4 vs_draw( uint vid : SV_VERTEXID, out float4 uv : TEXCOORD) : SV_POSITION {
        uint    gid  = vid/3;
        float   t    = gTimer * lerp(gSpeed*.1, gSpeed*.3, gid) * 0.0001;
        uint    tid  = t;
        float3  k    = rnd(float3(gid, tid, tid*gid)); // size, rotate, X pos
        float   size = lerp( gSize*.2, gSize*.5, k.x) * 0.2;

        uv.xy = uv.zw = (vid.xx%3 == uint2(2,1))? (2.).xx: (0.).xx;
        uv.x  = (uv.x + floor(gTimer*lerp(gRotate*.5, gRotate ,k.y) * 0.01) % 4) / 4.;

        return float4(
            (uv.z*2.-1.)*BUFFER_HEIGHT*BUFFER_RCP_WIDTH * size - (k.z*2.-1.),
            (1.-uv.w*2.)*size - (frac(t)*2.-1.),
            (((gid + tid)%MAX_INSTANCE_COUNT) < gCount) - .5, 1. );
    }

    float4 ps_draw( float4 vpos: SV_POSITION, float4 uv : TEXCOORD) : SV_TARGET {
        return any(uv.zw>1)? 0: tex2D(samp, uv.xy);
    }

    /**********************************************************
    *  technique
    **********************************************************/
    technique falling {
        pass draw {
            VertexCount         = 3 * MAX_INSTANCE_COUNT;
            PrimitiveTopology   = TRIANGLELIST;
            VertexShader        = vs_draw;
            PixelShader         = ps_draw;

            BlendEnable         = true;
            SrcBlend            = SRCALPHA;
            DestBlend           = INVSRCALPHA;
        }
    }
}