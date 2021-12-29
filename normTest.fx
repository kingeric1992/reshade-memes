/*
    normTest.fx by kingeric1992 (Dec.29.2021)
*/
namespace normTest {

    uniform bool  gLog  < ui_label="Log Scale";> = false;
    uniform uint  gTex  < ui_label="Storage"; ui_type = "combo"; ui_items= "RGBA32F\0RGB10A2\0RG16F\0RG16\0"; > = 0;
    uniform float gMinX < ui_label="MinX"; ui_type="slider"; ui_min=-1;  ui_max=1; > = -1;
    uniform float gMinY < ui_label="MinY"; ui_type="slider"; ui_min=-1;  ui_max=1; > = -1;
    uniform float gMaxX < ui_label="MaxX"; ui_type="slider"; ui_min=-1;  ui_max=1; > = 1;
    uniform float gMaxY < ui_label="MaxY"; ui_type="slider"; ui_min=-1;  ui_max=1; > = 1;

    texture2D texF  { Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; Format = RG16F; };
    texture2D texU  { Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; Format = RG16; };
    texture2D texA  { Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; Format = RGB10A2; };
    texture2D texQ  { Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; Format = RGBA32F; };
    sampler2D sampF { Texture=texF; };
    sampler2D sampU { Texture=texU; };
    sampler2D sampA { Texture=texA; };
    sampler2D sampQ { Texture=texQ; };

/**********************************************************
 *  shaders
 **********************************************************/
    float2 vs_main( uint vid : SV_VERTEXID, out float4 pos : SV_POSITION) : TEXCOORD
    {
        pos = uint4(2,1,0,0) == vid ? float4(3, -3, 0, 1):float4( -1, 1, 0, 1);
        return lerp(float2(gMinX, gMinY), float2(gMaxX,gMaxY), pos.xy * .5 + .5);
    }
    float2 ps_main( float3 uv : TEXCOORD, float4 vpos : SV_POSITION,
        out float2 fout : SV_TARGET1, out float3 aout : SV_TARGET2, out float3 f3out : SV_TARGET3 ) : SV_TARGET0
    {
        float d = length(uv.xy);
        uv.xy = gLog?  uv.xy/d * pow(d,.2) : uv.xy;
        uv.z  = sqrt(1. - dot(uv.xy,uv.xy));

        aout = (f3out = uv) * .5 + .5;
        return (fout = uv.xy ) * .5 + .5;
    }
    float3 ps_view( float3 uv : TEXCOORD, float4 vpos : SV_POSITION) : SV_TARGET
    {
        float d = length(uv.xy);
        if(gLog)
            uv.xy = uv.xy/d * pow(d,.2);

        if(dot(uv.xy,uv.xy) > 1)
            return float3(0,1,0);

        uv.z = sqrt(1. - dot(uv.xy,uv.xy));

        float3 vec;
        switch(gTex)
        {
            case 0: // RGBA32F
                vec = tex2Dfetch(sampQ, vpos.xy).xyz;
            break;
            case 1: //
                vec = tex2Dfetch(sampA, vpos.xy).xyz * 2. - 1.;
            break;
            case 2: // RG16F
                vec.xy = tex2Dfetch(sampF, vpos.xy).xy;
                vec.z  = sqrt(1. - dot(vec.xy, vec.xy));
            break;
            case 3: // RG16
                vec.xy = tex2Dfetch(sampU, vpos.xy).xy * 2. - 1.;
                vec.z  = sqrt(1. - dot(vec.xy, vec.xy));
            break;
        }
        return abs(uv - vec) * 1000;
    }
/**********************************************************
 *  technique
 **********************************************************/
    technique NormTest
    {
        pass main {
            VertexShader  = vs_main;
            PixelShader   = ps_main;
            RenderTarget0 = texU;
            RenderTarget1 = texF;
            RenderTarget2 = texA;
            RenderTarget3 = texQ;
        }
        pass view {
            VertexShader  = vs_main;
            PixelShader   = ps_view;
        }
    }
}