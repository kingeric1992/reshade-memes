
/*
    mapping.fx by kingeric1992 for ReShade ( Sep.29.2020 )
*/


/**********************************************************
*  helper func
**********************************************************/
// mode(0) fill/stretch
// mode(1) fit
// mode(2) crop
// mode(3) center
// mode(4) repeat
//
// rUV:   normalize renderTarget uv
// rSize: renderTarget size
// tTect: target fitting area
// sRect: source area
float4 imageMapEX( sampler2D texIn, float2 rUV, float2 rSize,
    float4 rRect, float4 sRect, uint mode, float3 col )
{
    float4 src;
    float2 sUV = sRect.zw - sRect.xy;
    float2 cUV = rUV - (rRect.xy + rRect.zw)*.5;
    float2 tUV = cUV/(rRect.zw - rRect.xy);

    src.xy = tex2Dsize(texIn, 0);
    src.z  = src.x/src.y * sUV.y/sUV.x;
    src.w  = rSize.y/rSize.x;

    src.wz = tUV * src.wz/src.zw;
    src.xy = cUV * rSize / (sUV * src.xy);

    // using turnery might make the compiler opt for using
    switch(mode) {
    case 1:  tUV = (tUV > src.zw? tUV:src.zw) + .5; break; // fit
    case 2:  tUV = (tUV < src.zw? tUV:src.zw) + .5; break; // crop
    case 3:  tUV = src.xy + .5;                     break; // centered
    case 4:  tUV = frac(src.xy + .5);               break; // repeat
    default: tUV = tUV + .5;                        break; // fill/stretch
    }
    rRect.zw *= -1;
    return (all(0 < float4(tUV,1.-tUV))? tex2D(texIn, lerp(sRect.xy,sRect.zw,tUV)) : float4(col,0)) *
            all(rRect < float4(rUV,-rUV));
}

namespace mapping {
    /**********************************************************
    *  shader
    **********************************************************/
    texture     tex  < source = "thumb.png";> { Width = 128; Height = 128; };
    sampler2D   samp { Texture = tex; };

    uniform uint    gMode   < ui_type = "radio"; ui_items = "fill\0fit\0crop\0centered\0repeat\0"; > = 0;
    uniform float4  gTRect  < ui_type = "slider"; ui_min = 0; ui_max = 1; > = float4(0,0,1,1);
    uniform float4  gSRect  < ui_type = "slider"; ui_min = 0; ui_max = 1; > = float4(0,0,1,1);
    uniform float3  gCol    < ui_type = "color"; > = float3(1,0,0);

    // uv for different mapping mode. stretch, crop, fit, centered, repeat
    float4 vs_main( uint vid : SV_VERTEXID, out float2 uv : TEXCOORD0 ) : SV_POSITION {
        uv = vid.xx == uint2(2,1)? (2.).xx:(0.).xx;
        return float4( uv.x*2-1, 1.-uv.y*2,0,1);
    }
    float4 ps_main( float4 vpos : SV_POSITION, float2 uv : TEXCOORD0 ) : SV_TARGET {
        return imageMapEX( samp, uv, float2(BUFFER_WIDTH,BUFFER_HEIGHT), gTRect, gSRect, gMode, gCol);
    }
    /**********************************************************
    *  technique
    **********************************************************/
    technique mapping {
        pass p {
            VertexShader    = vs_main;
            PixelShader     = ps_main;
        }
    }
} // namespace