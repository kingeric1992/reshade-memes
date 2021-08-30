/*
    Clock.fx demo for ReShade by kingeric1992
    DigitAtlas.png Created by TreyM
                                        update: May/22/2021
*/

namespace clock
{
    #define SLIDER(a, b) ui_type="slider"; ui_min= a; ui_max= b

    uniform float2 gPos     < ui_label="pos";   SLIDER(-1,1);  > = 0;
    uniform float  gScale   < ui_label="scale"; SLIDER(.1,1); > = .1;
    uniform float4 gDate    < source = "date"; >;

    texture2D texDigits  < source = "DigitAtlas.png"; > { Width = 1024; Height = 147; };
    sampler2D sampDigits { Texture=texDigits; };

/**********************************************************
*  shader
**********************************************************/

    float2 gAspect() { return float2(1024*5, -137*14); }
    uint2  getID(float k, float m) { float r = trunc(k/m); return float2(r, k - r*m); }

    float4 vs_main( uint id : SV_VERTEXID, out float2 uv : TEXCOORD ) : SV_POSITION
    {
        int2 gid = getID(id,   4); //[0,4], [0,3]
        int2 vid = getID(gid.y,2); //[0,1], [0,1]
        int2 hm  = getID(gDate.w/60, 60);
        int2 hh  = getID(hm.x, 10) + 1;
        int2 mm  = getID(hm.y, 10) + 1;

        int  did[] = { hh.x, hh.y , (gDate.w % 2) ?  12 : 13, mm.x, mm.y };
        uv = float2((did[gid.x] + vid.x)/14., vid.y);

        float2 size = float2(BUFFER_RCP_WIDTH, BUFFER_RCP_HEIGHT) * gAspect() * gScale * .1;
        size = lerp(-size, size, float2((gid.x + (gid.y > 1.5)) / 5., uv.y));
        return float4(gPos + size, 0, 1);
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