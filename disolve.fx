/*
    disolve.fx by kingeric1992 (May.22.2021)
*/
namespace disolve {

    uniform float gCurve < ui_type="slider"; ui_min=-5; ui_max=20; > = 10;
    uniform float gFade < ui_type="slider"; ui_min=0; ui_max=1; > = .5;
    uniform int gRand < source = "random"; >;

    texture2D  texIn   : COLOR;
    texture2D  texOut  { Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; };
    sampler2D  sampIn  { Texture=texIn; };
    sampler2D  sampOut { Texture=texOut; };

/**********************************************************
 *  helpers
 **********************************************************/

    //https://www.ronja-tutorials.com/2018/09/02/white-noise.html
    float randw(float3 value, float3 dotDir ) {
        return frac(sin(dot(sin(value), dotDir)) * 143758.5453);
    }
    float randw(float3 value) {
        return randw(value,float3(12.989, 78.233, 37.719) );
    }

/**********************************************************
 *  shaders
 **********************************************************/

    float4 vs_quad( uint vid : SV_VERTEXID ) : SV_POSITION {
        return uint4(2,1,0,0) == vid ? float4(3, -3, 0, 1):float4( -1, 1, 0, 1);
    }
    float4 ps_main(float4 vpos : SV_POSITION) : SV_TARGET {
        if(pow(randw(float3(vpos.xy, gRand)), gCurve) < .5) discard;
        return tex2Dfetch(sampIn, vpos.xy);
    }
    float4 ps_copy( float4 vpos : SV_POSITION) : SV_TARGET {
        return tex2Dfetch(sampOut, vpos.xy) * gFade;
    }

/**********************************************************
 *  technique
 **********************************************************/
    technique disolve
    {
        pass main {
            VertexShader = vs_quad;
            PixelShader  = ps_main;
            StencilEnable = true;
            StencilPassOp = INCR;
            RenderTarget  = texOut;
        }
        pass copy {
            VertexShader = vs_quad;
            PixelShader  = ps_copy;
            StencilEnable = true;
            StencilFunc   = EQUAL;
        }
    }
}