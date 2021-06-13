/*
    GroupMag.fx by kingeric1992 (May.28.2021)
*/

namespace groupmag {

    uniform bool   gUI <ui_label="Show Src Area";> = true;

#ifdef FIX_POS
#define UI(a, b) \
    uniform bool   a         <ui_label=b ;> = true; \
    uniform float2 a##_src   <ui_label=b " src pos";   ui_type="slider"; ui_min=-1; ui_max=1; > = 0.; \
    uniform float  a##_zoom  <ui_label=b " src zoom";  ui_type="slider"; ui_min=.1; ui_max=10;> = 2.; \
    uniform float2 a##_dst   <ui_label=b " dst pos";   ui_type="slider"; ui_min=-1; ui_max=1; > = .5; \
    uniform float2 a##_size  <ui_label=b " dst size";  ui_type="slider"; ui_min=.1; ui_max=.5;> = .2;
#else
#define UI(a, b) \
    uniform bool   a         <ui_label=b ;> = true; \
    uniform float2 a##_dst   <ui_label=b " dst pos";   ui_type="slider"; ui_min=-1; ui_max=1; > = .5; \
    uniform float2 a##_size  <ui_label=b " dst size";  ui_type="slider"; ui_min=.1; ui_max=.5;> = .2;
    uniform float2 gPoint    <source="mousepoint"; >;
    uniform float2 gMse      <source="mousedelta"; >;
    uniform float2 gWheel    <source="mousewheel"; >;
    uniform bool   gLMB_d    <source="mousebutton"; keycode=0; >;
    uniform bool   gLMB_p    <source="mousebutton"; keycode=0; mode="press"; >;
#endif
    UI(g3, "W");
    UI(g2, "G");
    UI(g1, "Y");
    UI(g0, "R");
#undef UI

    #define ADDRESS(a) AddressU = a; AddressV = a; AddressW = a
    #define FILTER(a)  MagFilter = a; MinFilter = a; MipFilter = a

    texture2D texIn : COLOR;
    sampler2D sampIn { Texture=texIn; ADDRESS(BORDER); FILTER(POINT); };
#ifndef FIX_POS
    texture2D texA   { Width=4; Format=RGBA32F; };
    texture2D texB   { Width=4; Format=RGBA32F; };
    sampler2D sampA  { Texture=texA; };
    sampler2D sampB  { Texture=texB; };
#endif

/**********************************************************
*  helper
**********************************************************/

    struct sGroup {
        bool    enable, held;
        float2  src, dst, size;
        float   zoom;
        float3  col;
    };
    sGroup cGroup( bool _e, bool _h, float2 _src, float2 _size, float2 _dst, float _zoom, float3 _col) {
        sGroup r;
        r.enable = _e, r.src = _src, r.size = _size, r.dst = _dst, r.zoom = _zoom, r.col = _col;
        return r.held = _h, r;
    }
    sGroup cGroup( bool _e, float2 _src, float2 _size, float2 _dst, float _zoom, float3 _col) {
        sGroup r;
        r.enable = _e, r.src = _src, r.size = _size, r.dst = _dst, r.zoom = _zoom, r.col = _col;
        return r;
    }
    sGroup getGroup( float id) {
        float2 k = float2(.2,1);
    #ifdef FIX_POS
        #define PARAMS(a, b) a, a##_src, a##_size, a##_dst, a##_scale
    #else
        #define PARAMS(a, b) a, (p[b].w > .5), p[b].xy, a##_size, a##_dst, p[b].z
        int4 t = int4(0,1,2,3);
        float4 p[4] = {
            tex2Dfetch(sampA, t.xx),tex2Dfetch(sampA, t.yx),
            tex2Dfetch(sampA, t.zx),tex2Dfetch(sampA, t.wx)
        };
    #endif
        if(id < .5)         return cGroup(PARAMS(g0, 0), k.yxx);
        else if(id < 1.5)   return cGroup(PARAMS(g1, 1), k.yyx);
        else if(id < 2.5)   return cGroup(PARAMS(g2, 2), k.xyx);
        else                return cGroup(PARAMS(g3, 3), k.yyy);
        #undef PARAMS
    }
    bool isHovered(sGroup g, float2 p) {
        return all(abs(p - g.src) < (g.size/g.zoom));
    }
    float fmodf(float x, float d, out float i) { return i = trunc(x/d), x - i*d; }

/**********************************************************
*  shader
**********************************************************/
    float4 vs_ctrl( uint vid : SV_VERTEXID) : SV_POSITION {
        return float4(vid * 2. - 1., 0, 0, 1);
    }
    float4 ps_init( float4 vpos : SV_POSITION) : SV_TARGET  { return float4(.5,1,2,4)[(int)vpos.x]; }
    float4 ps_ctrl( float4 vpos : SV_POSITION) : SV_TARGET  {
        int id = vpos.x;
        float4 mPrev    = tex2Dfetch(sampA, vpos.xy);
        float3 mDelta   = float3(gMse.xy * 2. * float2(BUFFER_RCP_WIDTH, -BUFFER_RCP_HEIGHT), gWheel.y * .1);
        float2 mPoint   = gPoint * float2(BUFFER_RCP_WIDTH, -BUFFER_RCP_HEIGHT) * 2. + float2(-1,1);

        [flatten] if(!gUI) return mPrev;
        [flatten] if(getGroup(id).held)
            mPrev.xy = clamp(mPrev.xy + mDelta.xy, -1,1);

        // set held or zoom if current layer is at top and is hovered.
        bool hovered = false;
        [flatten] for(int i=3; i>=0; i--) {
            [flatten] if(isHovered(getGroup(i), mPoint)) {
                [flatten] if( id == i) hovered = true;
                break;
            }
        }
        [flatten] if(hovered) {
            mPrev.z = clamp(mPrev.z - mPrev.z*mDelta.z, .1,10);
            mPrev.w = mPrev.w || gLMB_p;
        }
        // clear held flag if mse up
        mPrev.w = mPrev.w && gLMB_d;

        return mPrev;
    }
    float4 ps_copy( float4 vpos : SV_POSITION) : SV_TARGET { return tex2Dfetch(sampB, vpos.xy); }

    float4 vs_cursor( uint vid : SV_VERTEXID, out float2 uv : TEXCOORD) : SV_POSITION {
        float2 mPoint   = gPoint * float2(BUFFER_RCP_WIDTH, -BUFFER_RCP_HEIGHT) * 2. + float2(-1,1);
        float2 v[3] = { float2(0,0), float2(.5,-1), float2(1,-.5) };
        float2 uvs[3] = { float2(0,0), float2(0,1), float2(1,0) };

        uv = uvs[vid];
        return float4(v[vid] * float2(1., BUFFER_WIDTH * BUFFER_RCP_HEIGHT) * .05 + mPoint, gUI? .5 : -.5, 1);
    }
    float4 ps_cursor( float4 vpos : SV_POSITION, float2 uv : TEXCOORD) : SV_TARGET {
        return all(uv > .1) && (uv.x + uv.y < .95);
    }

    // had to do some weird fix for dx9, opengl & vulkan.
    float4 vs_trigs(    uint    vid : SV_VERTEXID,
                    out float4  uv  : TEXCOORD0,
                    out float3  col : TEXCOORD1) : SV_POSITION
    {
        float gid, id = fmodf(vid, 5, gid);
        sGroup g = getGroup(gid);
        col = g.col;

        [branch] if( id > 3.5 || !g.enable) return uv = 0, float4(0,0,-1,1);

        bool2  k = bool2(id < 2., frac(id / 2.) < .5);
        float2 rect = k? -g.size : g.size;
        uv.xy  = (g.src + rect / g.zoom) * .5 + .5;
        uv.y   = 1.- uv.y;
        uv.zw  = k - .5;

        return float4( g.dst + rect, 0, 1);
    }
    float3 ps_trigs( float4 vpos: SV_POSITION, float4 uv : TEXCOORD0, float3 col : TEXCOORD1) : SV_TARGET {
        float2 d = abs(uv.zw), r = float2(-ddx(uv.z), ddy(uv.w));
        return tex2D(sampIn, uv.xy).rgb * all(d < (.5 - r*6.)) + any(d > (.5 - r*2.)) * col;
    }
    float4 vs_lines( uint vid : SV_VERTEXID, out float3 col : TEXCOORD) : SV_POSITION {
        uint id  = vid % 6;
        sGroup g = getGroup(vid / 6);
        col = g.col;

        [branch] if( !gUI || id == 5 || !g.enable) return float4(0,0,-1,1);

        return float4( g.src + ( id.xx == 2 || id.xx == bool2(3,1) ? -g.size : g.size) / g.zoom, 0, 1);
    }
    float3 ps_lines( float4 vpos : SV_POSITION, float3 col : TEXCOORD ) : SV_TARGET { return col; }

/**********************************************************
*  technique
**********************************************************/
    #ifndef FIX_POS
    technique GroupMagInit < hidden=true; enabled=true; timeout=1; >
    {
        pass init {
            VertexCount         = 2;
            PrimitiveTopology   = LINELIST;
            VertexShader        = vs_ctrl;
            PixelShader         = ps_init;
            RenderTarget0       = texA;
            RenderTargetWriteMask = 4;
        }
    }
    #endif
    technique GroupMag
    {
        #ifndef FIX_POS
        pass ctrl {
            VertexCount         = 2;
            PrimitiveTopology   = LINELIST;
            VertexShader        = vs_ctrl;
            PixelShader         = ps_ctrl;
            RenderTarget        = texB;
        }
        pass copy {
            VertexCount         = 2;
            PrimitiveTopology   = LINELIST;
            VertexShader        = vs_ctrl;
            PixelShader         = ps_copy;
            RenderTarget        = texA;
        }
        #endif
        pass trigs {
            VertexCount         = 5*4 - 1;
            PrimitiveTopology   = TRIANGLESTRIP;
            VertexShader        = vs_trigs;
            PixelShader         = ps_trigs;
            RenderTargetWriteMask = 7;
        }
        pass lines {
            VertexCount         = 6*4 - 1;
            PrimitiveTopology   = LINESTRIP;
            VertexShader        = vs_lines;
            PixelShader         = ps_lines;
            RenderTargetWriteMask = 7;
        }
        #ifndef FIX_POS
        pass cursor {
            VertexShader        = vs_cursor;
            PixelShader         = ps_cursor;
            RenderTargetWriteMask = 7;
        }
        #endif
    }
} //groupmag