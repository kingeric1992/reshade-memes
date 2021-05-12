/*
    iColor.fx by kingeric1992 (march.10.2021)
    Simply invert color b4 someone losing it
*/

/**********************************************************
 *  shaders
 **********************************************************/

float4 vs_main( uint vid : SV_VERTEXID ) : SV_POSITION {
    return uint4(2,1,0,0) == vid ? float4(3, -3, 0, 1):float4( -1, 1, 0, 1);
}
float4 ps_main() : SV_TARGET { return 1; }

/**********************************************************
 *  technique
 **********************************************************/
technique iColor
{
    pass p0 {
        VertexShader = vs_main;
        PixelShader = ps_main;

        BlendEnable = true;
        SrcBlend = INVDESTCOLOR;
    }
}