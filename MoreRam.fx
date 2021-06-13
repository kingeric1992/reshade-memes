/*
    MoreRam.fx by kingeric1992 (May.28.2021)
*/

namespace moreram {

    texture2D texIn  { Format=R8; };
    sampler2D sampIn { Texture=texIn;  };

/**********************************************************
*  shader
**********************************************************/
    float4 vs_point() : SV_POSITION { return float4(0,0,0,1); }
    float4 ps_point() : SV_TARGET   { return 1; }
    float4 ps_clear() : SV_TARGET   { return 0; }

    // had to do some weird fix for dx9, opengl & vulkan.
    float4 vs_main( uint vid : SV_VERTEXID) : SV_POSITION {
        [branch] if(tex2Dfetch(sampIn, 0).x > .5) return float4(0,0,-1,1);
        return uint4(2,1,0,0) == vid ? float4(3, -3, 0, 1):float4( -1, 1, 0, 1);
    }
    float4 ps_main( float4 vpos : SV_POSITION ) : SV_TARGET {
        vpos.zw = vpos.xy *= float2(BUFFER_RCP_WIDTH, BUFFER_RCP_HEIGHT);
        for(int i=0; i<1000; i++) sincos(vpos.xy,vpos.x,vpos.y), vpos.zw = atan2(vpos.zw,vpos.wz);
        return vpos;
    }

/**********************************************************
*  technique
**********************************************************/
    technique MoreRam
    {
        pass more {
            VertexCount         = 1;
            PrimitiveTopology   = POINTLIST;
            VertexShader        = vs_point;
            PixelShader         = ps_point;
            RenderTarget        = texIn;
        }
    }
    technique MoreRam <hidden=true; enabled =true;>
    {
        pass ram {
            VertexShader = vs_main;
            PixelShader  = ps_main;

            BlendEnable    = true;
            SrcBlend       = ZERO;
            SrcBlendAlpha  = ZERO;
            DestBlend      = ONE;
            DestBlendAlpha = ONE;
        }
        pass more {
            VertexCount         = 1;
            PrimitiveTopology   = POINTLIST;
            VertexShader        = vs_point;
            PixelShader         = ps_clear;
            RenderTarget        = texIn;
        }
    }
} //moreram