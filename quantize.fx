/*
    quantize.fx by kingeric1992 (June.4.2021)
*/

/******************************************************************
 *  assests
 ******************************************************************/

#define ui_slider(l, a, b) ui_type="slider"; ui_label= l ; ui_min= a; ui_max= b

uniform uint  gStepR  < ui_slider( "R depth", 1, BUFFER_COLOR_BIT_DEPTH); > = BUFFER_COLOR_BIT_DEPTH;
uniform uint  gStepG  < ui_slider( "G depth", 1, BUFFER_COLOR_BIT_DEPTH); > = BUFFER_COLOR_BIT_DEPTH;
uniform uint  gStepB  < ui_slider( "B depth", 1, BUFFER_COLOR_BIT_DEPTH); > = BUFFER_COLOR_BIT_DEPTH;
uniform float gDither < ui_slider( "Dither", 0, 5); > = 1;

namespace quantize
{
    texture2D texIn : COLOR;
    sampler2D sampIn { Texture=texIn; };

/******************************************************************
 *  shaders
 ******************************************************************/

    float3 rnd( float3 tc ) {
        float n = sin(dot(tc, float3(12.9898, 78.233, 143.4))) * 43758.5453;
        return frac(n * float4(1.0000, 1.2154, 1.3453, 1.3647)).rgb;
    }
    // avg rnd cause triangular PDF
    float3 trnd( float3 tc ) {
        return (rnd(tc++) + rnd(tc++) + rnd(tc++))/3.;
    }

    float4 vs_main( uint vid : SV_VERTEXID ) : SV_POSITION {
        return uint4(2,1,0,0) == vid ? float4(3, -3, 0, 1):float4( -1, 1, 0, 1);
    }
    float3 ps_main( float4 vpos : SV_POSITION ) : SV_TARGET {
        // manual gamma correction, pairing with manual gamma curve.
        float3 res = pow(tex2Dfetch(sampIn, vpos.xy).rgb, 2.2);
        float3 steps = exp2(float3(gStepR, gStepG, gStepB));

        // linear space.
        float3 s = 1./ (steps - 1.);
        float3 n = (steps < 3.? trnd(vpos.xyz) : rnd(vpos.xyz)) - .5;

        // [gdc16] Advanced Techniques and Optimization of HDR Color Pipelines
        // https://gpuopen.com/wp-content/uploads/2016/03/GdcVdrLottes.pdf
        res += n * gDither * min(res + pow(s,2.2) * .5, pow(1. + s, 2.2) * .75 - .75);

        // quantize after gamma curve
        return res <= 0.001 ? 0: floor(pow(res,1./2.2) * steps) * s;
    }

/******************************************************************
 *  techniques
 ******************************************************************/
    technique Quantize {
        pass main {
            VertexShader    = vs_main;
            PixelShader     = ps_main;
            RenderTargetWriteMask = 7;
        }
    }
}