/******************************************************************
 *  WobblyWob.fx for Reshade 4.7 by kingeric1992
 *      demo on affine vs projective texture mapping
 *                                      update: Aug.4.2020
 ******************************************************************/

uniform float   g_angleH  < ui_type="slider"; ui_min=0;   ui_max=360; ui_step=1;>   = 45;
uniform float   g_angleV  < ui_type="slider"; ui_min=-90; ui_max=90;  ui_step=1;>   = 45;
uniform float   g_dist    < ui_type="slider"; ui_min=1;   ui_max=10; >              = 3.;
uniform float   g_wobble  < ui_type="slider"; ui_min=0;   ui_max=1;>                = 1;
uniform bool    g_affine = true;
uniform float   g_fov     < ui_type="slider"; ui_min=1;   ui_max=179; ui_step=1;>   = 75;

float4x4 mWorld() {
    return float4x4( 1,0,0,0, 0,1,0,0, 0,0,1,0, 0,0,0,1);
}

float4x4 mView() {
    float2 t,p;
    sincos(radians(g_angleH),t.x,t.y), sincos(radians(-g_angleV),p.x,p.y);
    return mul(mul(float4x4( 1,0,0,0, 0,1,0,0, 0,0,-1,g_dist, 0,0,0,1),
        float4x4(1,0,0,0, 0,p.y,-p.x,0, 0,p.x,p.y,0, 0,0,0,1)),
        float4x4(t.y,-t.x,0,0, t.x,t.y,0,0, 0,0,1,0, 0,0,0,1)
    );
}

float4x4 mProj() {
    float zF = 20;
    float zN = 0.01;
    float t  = zN/(zF-zN);
    float sY = rcp(tan(radians(g_fov*.5)));
    float sX = sY * BUFFER_HEIGHT * BUFFER_RCP_WIDTH;
    return float4x4(sX,0,0,0, 0,sY,0,0, 0,0,-t,t*zF, 0,0,1,0);
}

/******************************************************************
 *  shaders
 ******************************************************************/

float4 vs_pre( uint vid : SV_VERTEXID ) : SV_POSITION {
    return float4((vid.xx == uint2(2,1))? float2(3,-3):float2(-1,1), 0, 1);
}
float4 ps_pre(float4 vpos : SV_POSITION) : SV_TARGET {
    return .5;
}
float4 vs_proj(uint vid : SV_VERTEXID, out float2 uv : TEXCOORD0) : SV_POSITION {
    // quad primitive
    const float3 vertices[4] = {
        float3(-1,1,0), float3(-1,-1,0), float3(1,1,0), float3(1,-1,0)
    };
    float4 pos = float4(vertices[vid],1);
    pos = mul(mProj(),mul(mView(),pos));

    uv.x = vid / 2;
    uv.y = vid % 2;
    return g_affine? pos/lerp(1,pos.w,sqrt(g_wobble)):pos;
}
float4 ps_grid( float4 pos : SV_POSITION, float2 uv : TEXCOORD0) : SV_TARGET {
    uv = floor(uv * 5);
    return (uv.x+uv.y)%2;
}

/******************************************************************
 *  technique
 ******************************************************************/

technique wobblywob {
    pass pre {
        VertexShader  = vs_pre;
        PixelShader   = ps_pre;
    }

    pass proj {
        PrimitiveTopology = TRIANGLESTRIP;
        VertexCount   = 4;
        VertexShader  = vs_proj;
        PixelShader   = ps_grid;
    }
}
