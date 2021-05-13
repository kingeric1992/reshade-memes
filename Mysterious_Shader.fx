
/********************************************************************************************
 *
 * mysterious shader by kingeric1992 
 *                                               for lol. ( Oct.30.2019 )
 ********************************************************************************************/

//#include "vkmap.fxh" 
#include "DrawText.fxh"

#define MAP_WIDTH  64 //max 128, min 16
#define MAP_HEIGHT 64
#define TIME_MIN  100 //ms
#define TIME_MAX  500 //ms

#define KEY_RUN    0x20 //0x20 space
#define KEY_PAUSE  0x13 //0x13 pause
#define KEY_LEFT   0x25 //0x25 arrow left
#define KEY_UP     0x26 //0x26 arrow up
#define KEY_RIGHT  0x27 //0x27 arrow right
#define KEY_DOWN   0x28 //0x28 arrow down


 /********************************************************************************************
 *
 * resources
 *
 ********************************************************************************************/

texture t_bufA { Width = MAP_WIDTH; Height = (MAP_HEIGHT+1); Format = R8; };
texture t_bufB { Width = MAP_WIDTH; Height = (MAP_HEIGHT+1); Format = R8; };
sampler s_bufA { Texture = t_bufA; AddressU = BORDER; AddressV = BORDER; MagFilter = POINT;	MinFilter = POINT; MipFilter = POINT;};
sampler s_bufB { Texture = t_bufB; AddressU = BORDER; AddressV = BORDER; MagFilter = POINT;	MinFilter = POINT; MipFilter = POINT;};

uniform bool  key_start_t < source = "key"; keycode = KEY_RUN;   mode = "toggle"; >;
uniform bool  key_start   < source = "key"; keycode = KEY_RUN;   mode = "press";  >;
uniform bool  key_pause   < source = "key"; keycode = KEY_PAUSE; mode = "toggle"; >;
uniform bool  key_up      < source = "key"; keycode = KEY_UP;    mode = "press";  >;
uniform bool  key_left    < source = "key"; keycode = KEY_LEFT;  mode = "press";  >;
uniform bool  key_right   < source = "key"; keycode = KEY_RIGHT; mode = "press";  >;
uniform bool  key_down    < source = "key"; keycode = KEY_DOWN;  mode = "press";  >;
uniform int   food_X      < source = "random"; min = 0; max = (MAP_WIDTH-1);      >;
uniform int   food_Y      < source = "random"; min = 0; max = (MAP_HEIGHT-1);     >;
uniform float g_timer     < source = "timer"; >;

/********************************************************************************************
*
* utils
*
********************************************************************************************/

//( abs(a-b)<.01 ) rename to isClosely?
#define isRoughly(type, a, b)  (abs((type)(a)-(type)(b))<(type)0.01)  

float4 getPos(uint vid, out float2 uv) {
    uv = (vid.xx == uint2(2,1))?(float2)2:0;
    return float4(uv.x*2.-1.,1.-uv.y*2.,0,1);
}

float4 getPos(uint vid) {
    return float4((vid>1.5)*4.-1.,1.-(vid%2.)*4.,0,1);
}

//rect ( tl, br )
float4 getPos( uint vid, uint4 rect, out float2 uv ) {
    float2 size = float2(MAP_WIDTH, MAP_HEIGHT+1);
    float4 tlbr = float4(rect.xy,rect.zw+1.)/size.xyxy*2.-1.;
           tlbr.yw = -tlbr.yw;
           uv   = float2(vid>1.5,vid%2.)*2.;
    return float4(lerp(tlbr.xy,tlbr.zw,uv),0,1);
}

float4 getPos( uint vid, uint4 rect ) {
    float2 uv; return getPos( vid, rect, uv );
}

//pt <- [(0,0), (w-1,h-1)]
float4 getPos( uint vid, uint2 pt ) {
    float2 size = float2(MAP_WIDTH,MAP_HEIGHT+1);
    float4 tlbr = float4(pt,pt+1)/size.xyxy*2.-1.;
           tlbr.yw = -tlbr.yw;
    return float4(lerp(tlbr.xy,tlbr.zw,float2(vid>1.5,vid%2.)*1.1),0,1);
}

/********************************************************************************************
*
* helpers
*
********************************************************************************************/

static const float4 g_dirs = float4(1,2,3,4); //top left right down

//top-left-right-down
bool4 isIn(sampler2D texIn, float2 c ) {
    float4 dirs = float4(
        tex2Dfetch(texIn,int4(c.x,c.y-1,0,0)).r, tex2Dfetch(texIn,int4(c.x-1,c.y,0,0)).r,
        tex2Dfetch(texIn,int4(c.x+1,c.y,0,0)).r, tex2Dfetch(texIn,int4(c.x,c.y+1,0,0)).r 
    );
    return isRoughly(float4,g_dirs+round(dirs*4.),5);
}

bool4 isOut(sampler2D texIn, float2 c ) {
    float4 dirs = float4(
        tex2Dfetch(texIn,int4(c.x,c.y-1,0,0)).r, tex2Dfetch(texIn,int4(c.x-1,c.y,0,0)).r,
        tex2Dfetch(texIn,int4(c.x+1,c.y,0,0)).r, tex2Dfetch(texIn,int4(c.x,c.y+1,0,0)).r 
    );
    return isRoughly(float4,g_dirs,round(dirs*4.));
}


float2 foodPos(sampler2D texIn) {
    return float2( tex2Dfetch(texIn,int4(4,MAP_HEIGHT,0,0)).x,
        tex2Dfetch(texIn,int4(5,MAP_HEIGHT,0,0)).x) * 255.;
}
float2 headPos(sampler2D texIn) {
    return float2( tex2Dfetch(texIn,int4(0,MAP_HEIGHT,0,0)).x,
        tex2Dfetch(texIn,int4(1,MAP_HEIGHT,0,0)).x) * 255.;
}
float2 tailPos(sampler2D texIn) {
    return float2( tex2Dfetch(texIn,int4(2, MAP_HEIGHT,0,0)).x,
        tex2Dfetch(texIn,int4(3,MAP_HEIGHT,0,0)).x) * 255.;
}


//is current frame should run? used with degenerate triangle for now
bool isCycle(sampler2D texIn, out float4 var ) {
    var = float4( 
        tex2Dfetch(texIn,int4( 8,MAP_HEIGHT,0,0)).x, tex2Dfetch(texIn,int4( 9,MAP_HEIGHT,0,0)).x,
        tex2Dfetch(texIn,int4(10,MAP_HEIGHT,0,0)).x, tex2Dfetch(texIn,int4(11,MAP_HEIGHT,0,0)).x
    );
    return frac(g_timer/lerp((float)TIME_MAX,(float)TIME_MIN,var.x))>0.51 && var.z>0.125 && var.w>0.5;
}
bool isCycle(sampler2D texIn) { float4 o; return isCycle(texIn, o); }


bool isWall(float2 pos) { return any( pos<-0.5 || pos>float2(MAP_WIDTH-0.5,MAP_HEIGHT+0.5) ); }
bool isRunning()  { return key_start_t && !key_pause; }
bool isStarting() { return key_start && key_start_t; } //use this to populate initial data

/********************************************************************************************
 *
 * shaders
 *
 ********************************************************************************************/
/*
    data zone layout:
        t_vars[0] headpos.x   t_vars[4] foodpos.x   t_vars[8]  score   
        t_vars[1] headpos.y   t_vars[5] foodpos.x   t_vars[9]  didScored
        t_vars[2] tailpos.x   t_vars[6]             t_vars[10] headDir: 0->gameover
        t_vars[3] tailpos.y   t_vars[7]             t_vars[11] syncFlag:
*/

//wAB, populate variable & buffer at game starts
float4 vs_init( uint vid:SV_VertexID, inout float2 head:TEXCOORD0, inout float4 val[3]:TEXCOORD1) :SV_Position {
    if (!isStarting()) return (float4)0;
    head = round(float2(MAP_WIDTH,MAP_HEIGHT)*.5);

    val[0]    = head.xyxy;
    val[0].z -= 3;
    val[0]   /= 255.;
    val[1].xy = float2(food_X,food_Y)/255.;
    val[2].z  = 0.75; //going right

    return getPos(vid);
}
float ps_init( float4 pos:SV_Position, float2 head:TEXCOORD0, float4 val[3]:TEXCOORD1, out float res:SV_Target0 ) :SV_target1 {
    pos = floor(pos); res = 0;
    if (pos.y>(MAP_HEIGHT-0.5) && pos.x<11.5) 
        res = val[uint(pos.x/4.0)][uint(pos.x%4.0)]; //last line
    else if (isRoughly(float, head.y, pos.y) && (pos.x-0.5<head.x && head.x<pos.x+3.5))
        res = 0.75; //draw body & head (4 length)
    return res;
}



//cycle timer
float4 vs_syncA( uint vid:SV_VertexID ) :SV_Position {  //rBwA
    float score = tex2Dfetch(s_bufB,int4(8,MAP_HEIGHT,0,0)).x;
    if (!isRunning() || frac(g_timer/lerp((float)TIME_MAX,(float)TIME_MIN,score))>0.49 ) return (float4)0;
    else return getPos(vid,uint2(11,MAP_HEIGHT));
}
float4 vs_syncB( uint vid:SV_VertexID ) :SV_Position { //wB
    if (!isRunning()) return (float4)0; else return getPos(vid,uint2(11,MAP_HEIGHT));
}
float ps_sync( float4 pos:SV_Position ) :SV_Target {
    return 1;
}



//rBwA, write head direction by input @ headpos
float4 vs_head( uint vid:SV_VertexID ) :SV_Position {
    bool4 dirs = bool4(key_up,key_left,key_right,key_down);
    if (!isRunning() || !isRoughly(float,dot(dirs,1.),1) ) return (float4)0;
    
    float prevDir = tex2Dfetch(s_bufB,int4(10,MAP_HEIGHT,0,0)).x * 4.; //last cycle dir 
    float nextDir = dot(dirs,g_dirs); //curr frame

    // if nextDir is in oppside direction to prevDir, ignore changes
    float4 pos = getPos(vid,uint2(headPos(s_bufB)));
    return pos * !isRoughly(float,nextDir+prevDir,5);
}
float ps_head( float4 pos:SV_Position ) : SV_Target {
    return dot(bool4(key_up,key_left,key_right,key_down), g_dirs) * 0.25;
}


/********************************************************************************************
 *
 * shaders - main update cycle
 *
 ********************************************************************************************/


//rAwB; calc & update map & vars
float4 vs_calc( uint vid:SV_VertexID, inout float3 prevTail:TEXCOORD0, inout float4 val[3]:TEXCOORD1 ) :SV_Position { 
    if (!isRunning() || !isCycle(s_bufA, val[2])) return (float4)0;

    float2 head = headPos(s_bufA), food = foodPos(s_bufA), tail = tailPos(s_bufA);
    float  hdir = tex2Dfetch(s_bufA,int4(head,0,0)).x;
    float  tdir = tex2Dfetch(s_bufA,int4(tail,0,0)).x;

    //update headdir, score and copy flag (syncB)
    val[2].z = hdir; val[2].x += val[2].y/255.; val[2].yw = 0; 

    //new head
    hdir  = round(hdir*4.);
    head += float2(hdir%2.-(hdir<2.5), floor(hdir/2.)-1.);

    //old tail
    prevTail.xy = tail; prevTail.z = tdir;
    
        //more then one bodyparts going into next head location or hit the wall -> gameover  
    if (  dot(isIn(s_bufA,head),1)>1.5  || isWall(head)) { // cannot use
        val[2].z = 0;
    } else if (all(isRoughly(float2,food,head))) {
        val[2].y = 1; //ate food, increase speed after next cycle
        food = float2(food_X, food_Y);
    } else {
        tdir  = round(tdir*4.);
        tail += float2(tdir%2.-(tdir<2.5), floor(tdir/2.)-1.);
        prevTail.z = 0; //nothing happened, clear old tail.
    }




    val[0].xy = head/255.; val[0].zw = tail/255.; val[1].xy = food/255.;
    return getPos(vid);
}
float ps_calc( float4 pos:SV_Position, float3 prevTail:TEXCOORD0, float4 val[3]:TEXCOORD1 ) :SV_Target {
    pos = floor(pos); pos.zw = 0; 
    if (pos.y>(MAP_HEIGHT-0.5) && pos.x<11.5) return val[uint(pos.x/4.0)][uint(pos.x%4.0)]; //last line
    else if (val[2].z < .125) discard; //gameover
    else if (all(isRoughly(float2, val[0].xy*255., pos.xy))) return val[2].z; //new head position, writes last headdir 
    else if (all(isRoughly(float2, prevTail.xy,    pos.xy))) return prevTail.z; //no need to clear tail if new head == old tail
    return tex2Dfetch(s_bufA,pos).x; //needed for update body with last headdir. 
    //may or may not be a good choice for excessive use of if.
}



//rBwA; Only copy B to A after calc ( flag set by calc & clear by syncB )
// ( stencil only works with rtv size == framebuffer size )
float4 vs_copy( uint vid:SV_VertexID ) :SV_Position { 
    if  (!isRunning() || tex2Dfetch(s_bufB,int4(11,MAP_HEIGHT,0,0)).x>.5 ) return (float4)0; 
    else return getPos(vid);
}
float ps_copy( float4 pos:SV_Position ) :SV_Target {
    return tex2Dfetch(s_bufB, int4(pos.xy,0,0)).r;
}



/********************************************************************************************
 *
 * shaders - draw
 *
 ********************************************************************************************/

static const int msg00[8] = { //You DEAD
    __Y, __o, __u, __Space, __D, __E, __A, __D
};
static const int msg01[23] = { //Press space to continue
    __P, __r, __e, __s, __s, __Space, __s, __p, __a, __c, __e, __Space,
    __t, __o, __Space, __c, __o, __n, __t, __i, __n, __u, __e 
};
static const int msg10[11] = { //Game Paused
    __G, __a, __m, __e, __Space, __p, __a, __u, __s, __e, __d
};
static const int msg11[23] = { //Press pause to continue
    __P, __r, __e, __s, __s, __Space, __p, __a, __u, __s, __e, __Space,
    __t, __o, __Space, __c, __o, __n, __t, __i, __n, __u, __e
};
static const int msg2[20] = { //Press space to start
    __P, __r, __e, __s, __s, __Space, __s, __p, __a, __c, __e, __Space,
    __t, __o, __Space, __s, __t, __a, __r, __t
};
static const int msg3[34] = { //Created by kingeric1992 \(' w ' #)
    __C, __r, __e, __a, __t, __e, __d, __Space, __b, __y, __Space,
    __k, __i, __n, __g, __e, __r, __i, __c, __1, __9, __9, __2, __Space,
    __Backslash, __rBrac_O, __sQuote, __Space, __w, __Space, __sQuote, __Space, __Pound, __rBrac_C
};
static const int msg4[6] = { //Score:
    __S, __c, __o, __r, __e, __Colon
};

//also fetch uniforms from texture
float4 vs_draw( uint vid:SV_VertexID, out float4 pos:SV_Position, out float4 uv:TEXCOORD0) :TEXCOORD1 { 
    float ratio = (float)BUFFER_WIDTH*BUFFER_RCP_HEIGHT*(float)MAP_HEIGHT/(float)MAP_WIDTH;

    pos = getPos(vid, uv.xy);
    uv.zw = (uv.xy-.5)*max(1.,float2(ratio,1./ratio))+.5;
    uv.w *= (float)MAP_HEIGHT/float(MAP_HEIGHT+1); //data line

    float4 stat;
    isCycle(s_bufA, stat); 
    stat.w = stat.x*255.; stat.xy = foodPos(s_bufA); //foodPos.xy, isGameover/lastDir, score
    return stat;
}
float4 ps_draw(float4 stat:TEXCOORD1, float4 pos:SV_Position, float4 uv:TEXCOORD0 ) :SV_Target { //too many if-else
    float4 res  = 0; 
    float  mask = 0;
    float2 fmap = uv.zw*float2(MAP_WIDTH,MAP_HEIGHT+1); //to texel coord
    float2 map  = floor(fmap);

    if (key_start_t) { //running
        mask = all(abs(uv.zw-.5)<=.5);
        if (stat.z<.125) { //You Dead. press space to continue
            DrawText_String(float2(24, 8), 72, 1, uv.xy, msg00, 8,res.a);
            DrawText_String(float2(24,80), 32, 1, uv.xy, msg01,23,res.a);
            mask = 0;
        } else if (key_pause) { //Game Paused, press pause to continue
            DrawText_String(float2(24, 8), 72, 1, uv.xy, msg10,11,res.a);
            DrawText_String(float2(24,80), 32, 1, uv.xy, msg11,23,res.a);
            mask = 0;
        }

        res.rgb = (bool)tex2D(s_bufA,uv.zw).x; //body
        if (all(isRoughly(float2,stat.xy,map))) res.rgb = float3(1,0,0); // so that we can have food apear insides body
        res.rgb *= all((frac(fmap)-0.5)<0.4);

    } else {
        DrawText_String((float2)24, 72, 1, uv.xy, msg2, 20, res.a); //press space to start
    }

    DrawText_String(float2(8, BUFFER_HEIGHT-32.), 24, 1, uv.xy, msg3, 23, res.a);
    DrawText_String(float2(24,BUFFER_HEIGHT*0.5-32), 32, 1, uv.xy, msg4, 6, res.a); //Score:
    DrawText_Digit(float2(128,BUFFER_HEIGHT*0.5),    72, 1, uv.xy, -1, stat.w+0.001, res.a);

    res.xyz += res.a; res.a += 0.75 + mask;
    return saturate(res);
}



/********************************************************************************************
 *
 * passes
 *
 ********************************************************************************************/

//missing closing bracket for pass will failed silently
technique Mysterious_Shader < ui_tooltip = "A mysterious shader apeared in my library, should I enable it?";> {
//if running
    //per start input, init buffer.
    pass init { VertexShader = vs_init; PixelShader = ps_init; ClearRenderTargets = false; RenderTarget = t_bufA; RenderTarget1 = t_bufB; }
    //per frame in first half of cycle, set syncA flag for calc.
    pass sync { VertexShader = vs_syncA;PixelShader = ps_sync; ClearRenderTargets = false; RenderTarget = t_bufA; }
    //per frame, clears syncB flag.
    pass sync { VertexShader = vs_syncB;PixelShader = ps_sync; ClearRenderTargets = false; RenderTarget = t_bufB; }
    //per dir input, writes head direction to headpos.
    pass head { VertexShader = vs_head; PixelShader = ps_head; ClearRenderTargets = false; RenderTarget = t_bufA; }
    //run once per cycle if syncB is set, full buffer copy & set syncB
    pass calc { VertexShader = vs_calc; PixelShader = ps_calc; ClearRenderTargets = false; RenderTarget = t_bufB; } 
    //runs if syncB is set, clears syncA
    pass copy { VertexShader = vs_copy; PixelShader = ps_copy; ClearRenderTargets = false; RenderTarget = t_bufA; }
//endif
    //per frame, alpha blend the interface to framebuffer. 
    //Alternative would be seperate each view to different pass. Other direction including render static text to buffer for init.
    pass draw { VertexShader = vs_draw; PixelShader = ps_draw; ClearRenderTargets = false;
        BlendEnable = true; SrcBlend = SRCALPHA; DestBlend = INVSRCALPHA; }
}