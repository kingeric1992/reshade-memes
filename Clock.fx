/*
    Clock.fx demo for ReShade by kingeric1992
    DigitAtlas.png Created by TreyM
                                        update: May/22/2021
*/

namespace clock {
    uniform float2 gTL < ui_type="slider"; ui_label="Top Left";     ui_min=-1; ui_max=1; > = 0. + float2( -0.125, 0.125);
    uniform float2 gBR < ui_type="slider"; ui_label="Bottom Right"; ui_min=-1; ui_max=1; > = 0. + float2( 0.125, -0.125); // default to center
    uniform float4 gDate < source = "date"; >;

    texture texDigits < source = "DigitAtlas.png"; > { Width = 1024; Height = 147; };
    sampler sampDigits { Texture = texDigits; };

/**********************************************************
*  shader
**********************************************************/
    uint2 getID(uint k, uint m) { return uint2(k/m, k%m); }

    float4 vs_main( uint id : SV_VERTEXID, out float2 uv : TEXCOORD ) : SV_POSITION
    {
        int2 gid = getID(id,   4); //[0,4], [0,3]
        int2 vid = getID(gid.y,2); //[0,1], [0,1]
        int2 hm  = getID(gDate.w/60, 60);
        int2 hh  = getID(hm.x, 10) + 1;
        int2 mm  = getID(hm.y, 10) + 1;

        int  did[] = { hh.x, hh.y , (gDate.w % 2) ?  12 : 13, mm.x, mm.y };
        uv = float2((did[gid.x] + vid.x)/14., vid.y);
        return float4( lerp( gTL, gBR, float2((gid.x + (gid.y > 1.5)) / 5., uv.y)), 0, 1 );
    }
    float4 ps_main( float4 vpos : SV_POSITION, float2 uv : TEXCOORD ) : SV_TARGET {
        return tex2D(sampDigits, uv);
    }
/**********************************************************
 *  technique
 **********************************************************/
    technique clock {
        pass p0 {
            PrimitiveTopology   = TRIANGLESTRIP;
            VertexCount         = 20;
            VertexShader        = vs_main;
            PixelShader         = ps_main;
            BlendEnable         = true;
            DestBlend           = ONE;
        }
    }
} // clock