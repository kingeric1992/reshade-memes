/*
    uvProj.fx by kingeric1992 (July.12.2021)
    demo for 2d projectiong (othogonal)
*/

/******************************************************************
 *  assests
 ******************************************************************/

//uniform float gScale <ui_label="scale"; ui_type="slider"; ui_min=0; ui_max=10; > = 1;
uniform float2 gRot  <source="mousewheel"; min=-180; max=180; step=10; > = 0;


uniform float gScale = 10;
uniform float gFOV = 75;
uniform float gFar = 1000;
uniform float gNear = 1;

namespace proj {

    texture2D texD : DEPTH;
    sampler2D sampD { Texture=texD; MagFilter=POINT; MinFilter=POINT; MipFilter=POINT; };

    texture2D texT  <source = "front.png";> { Width = 512; Height = 512; MipLevels = 4; };
    sampler2D sampT { Texture = texT; };

/******************************************************************
 *  Helper
 ******************************************************************/

    float4x4 mProj(float F, float N, float fov, float H_over_W) // projection matrix (inverse depth)
    {
        float t = N/(F-N);
        float Y = rcp(tan(radians(fov*.5)));
        return float4x4(Y*H_over_W,0,0,0, 0,Y,0,0, 0,0,-t,t*F, 0,0,1,0);
    }
    float4x4 iProj(float F, float N, float fov, float W_over_H) // inverse projection matrix (inverse depth)
    {
        float t = (F-N)/N;
        float Y = tan(radians(fov*.5));
        return float4x4(Y*W_over_H,0,0,0, 0,Y,0,0, 0,0,0,1, 0,0,t/F,1/F);
    }
    float linDepth(float F, float N, float D) { return (F * N) / ( D * (F-N) + N ); }
    float2 sincos(float r) { float2 sc; return sincos(r,sc.x,sc.y), sc; } // sin, cos
    float3x3 rotZ(float r) { float2 sc = sincos(r); return float3x3( sc.y,-sc.x,0, sc.x,sc.y,0, 0,0,1); }

    float4x4 mProj() { return mProj( gFar, gNear, gFOV, BUFFER_HEIGHT*BUFFER_RCP_WIDTH ); }
    float4x4 iProj() { return iProj( gFar, gNear, gFOV, BUFFER_WIDTH*BUFFER_RCP_HEIGHT); }
    float linDepth( float D) { return linDepth(gFar, gNear, D); }
    float3 getView( float3 pos ) { return mul(iProj(), float4(pos, 1)).rgb * linDepth(pos.z); }

/******************************************************************
 *  shader
 ******************************************************************/

    float4 vs_proj( uint vid : SV_VERTEXID, out float3 uv : TEXCOORD0, out float3x3 R : TEXCOORD1) : SV_POSITION
    {
        float4 pos = uint4(2,1,0,0) == vid ? float4(3,-3,0,1) : float4(-1,1,0,1);

        float  dRange = 5.; // sample range for normal.

        float2 c   = .5 * float2(BUFFER_WIDTH, BUFFER_HEIGHT) + .5;
        float3 t   = float3(BUFFER_RCP_WIDTH, -BUFFER_RCP_HEIGHT, 0) * dRange; // flip Y dir.
        float2 k   = float2(1, 0) * dRange;

        // getting ddx & ddy in view space. could simplify this.
        float3 ddx = getView(float3(t.xz * 2, tex2Dfetch(sampD, c + k.xy).x)) - getView(float3(t.xz * -2, tex2Dfetch(sampD, c - k.xy).x));
        float3 ddy = getView(float3(t.zy * 2, tex2Dfetch(sampD, c - k.yx).x)) - getView(float3(t.zy * -2, tex2Dfetch(sampD, c + k.yx).x));

        uv.xy = pos.xy;
        uv.z  = linDepth(tex2Dfetch(sampD, c).x); // center depth in view.

        // building transform matrix for othogonal projection.
        R[2]  = normalize(cross(ddx, ddy)); // center normal in view. (Z'-axis)
        R[1]  = normalize(ddy);             // Y'-axis
        R[0]  = normalize(cross(ddy, R[2]));// X'-axis

        return pos;
    }
    // othogonal projection
    float4 ps_proj( float4 vpos : SV_POSITION, float3 uv : TEXCOORD0, float3x3 R : TEXCOORD1) : SV_TARGET
    {
        vpos.y = BUFFER_HEIGHT - vpos.y; // upside down depth
        //return tex2Dfetch(sampD, vpos.xy).x;

        float3 center   = float3(0, 0, uv.z); // center pixel pos in view/world.
        float3 curr     = getView(float3(uv.xy,tex2Dfetch(sampD, vpos.xy).x) ); // screenspace to view/world
        float3 local    = mul(R, curr - center); // transform from view space to local space. (origin at center pixel)

        local = mul(rotZ(radians(gRot.x)), local) / gScale; // rotate by local Z axis and scale

        if(frac(local.x) < fwidth(local.x)  ) return float4(1,0,0,1);
        else if(frac(local.y) < fwidth(local.y) ) return float4(0,1,0,1);
        else if(frac(local.z) < fwidth(local.z) ) return float4(0,0,1,1);
        else if( all(abs(local.xyz) < 1 ) ) return tex2D(sampT, local.xy * .5 + .5);
        discard;
    }

/******************************************************************
 *  techniques
 ******************************************************************/

    technique uvOthoProj {
        pass proj { VertexShader = vs_proj; PixelShader  = ps_proj; }
    }
}