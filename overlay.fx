/*
    overlay.fx by kingeric1992 (Jan.9.2021)

    Setup PATH, WIDTH, HEIGHT accordinly to image overlay.
*/

#define IMG_PATH   "front.png"
#define IMG_WIDTH  639
#define IMG_HEIGHT 681

/**********************************************************
 *
 **********************************************************/

namespace overlay
{
    uniform float   IMG_Deg   < ui_label="Degree"; ui_type="slider"; ui_min=-180; ui_max=180; ui_step=5;    > = 0;
    uniform float2  IMG_Off   < ui_label="Offset"; ui_type="slider"; ui_min=-1;   ui_max=1;   ui_step=0.01; > = 0;
    uniform float   IMG_Scale < ui_label="Scale";  ui_type="slider"; ui_min=0;    ui_max=1;                 > = 0.2;
    uniform float   IMG_Trans < ui_label="Alpha";  ui_type="slider"; ui_min=0;    ui_max=1;   ui_step=0.01; > = 1;

    texture texIn <source = IMG_PATH;> { Width = IMG_WIDTH; Height = IMG_HEIGHT; MipLevels = 4; };
    sampler2D sampIn { Texture = texIn; };

/**********************************************************
 *  shaders
 **********************************************************/

    float2 rot(float vx, float vy, float deg)
    {
        float2 o;
        sincos(radians(deg), o.y, o.x);
        return float2(vx*o.x-vy*o.y, vx*o.y+vy*o.x);
    }
    float4 vs_main( uint vid : SV_VERTEXID, out float2 uv : TEXCOORD) : SV_POSITION
    {
        uv = vid.xx == uint2(2,1)? (2.).xx:(0.).xx;
        float2 pos = rot((uv.x*2-1) * IMG_WIDTH/IMG_HEIGHT, 1.-uv.y*2, IMG_Deg) * IMG_Scale;
        return pos.x *= BUFFER_HEIGHT * BUFFER_RCP_WIDTH, float4(pos + IMG_Off, 0, 1);
    }
    float4 ps_main( float4 pos : SV_POSITION, float2 uv : TEXCOORD) : SV_TARGET
    {
        return all(uv<1) * tex2D(sampIn, uv) * IMG_Trans;
    }
    float4 vs_quad( uint vid : SV_VERTEXID, out float2 uv : TEXCOORD) : SV_POSITION
    {
        uv.y = vid % 2, uv.x = vid / 2;
        float2 pos = rot( (uv.x*2-1) * IMG_WIDTH, (1.-uv.y*2) * IMG_HEIGHT, IMG_Deg) * IMG_Scale;
        return pos.x *= BUFFER_RCP_WIDTH, pos.y *= BUFFER_RCP_HEIGHT, float4(pos + IMG_Off, 0, 1);
    }
    float4 ps_quad( float4 pos : SV_POSITION, float2 uv : TEXCOORD) : SV_TARGET
    {
        return tex2D(sampIn, uv) * IMG_Trans;
    }

/**********************************************************
 *  technique
 **********************************************************/
    technique overlay
    {
        pass p0 {
            VertexShader = vs_main;
            PixelShader = ps_main;

            BlendEnable = true;
            SrcBlend = SRCALPHA;
            DestBlend = INVSRCALPHA;
        }
    }
    technique quad_overlay
    {
        pass p0 {
            VertexCount = 4;
            PrimitiveTopology = TRIANGLESTRIP;

            VertexShader = vs_quad;
            PixelShader = ps_quad;

            BlendEnable = true;
            SrcBlend = SRCALPHA;
            DestBlend = INVSRCALPHA;
        }
    }
} // overlay