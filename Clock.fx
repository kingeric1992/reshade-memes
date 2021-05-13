/*
    Clock.fx demo by kingeric1992
*/
float2 gTL = 0. + float2( -0.125, 0.125);
float2 gBR = 0. + float2( 0.125, -0.125); // default to center

uniform float4 gDate < source = "date"; >;

texture texDigits < source = "DigitAtlas.png"; > { Width = 1024; Height = 147; };
sampler sampDigits { Texture = texDigits; };

// id [0,13] 14 pos
float4 getRect(float id) {
    return float4( id / 14.,0, (id+1) / 14.,1 );
}

float2 getUV( float4 rect, uint id) {
    float2 uv_arr[6];
    uv_arr[0] = rect.xy, uv_arr[1] = rect.xw, uv_arr[2] = rect.zy;
    uv_arr[3] = rect.zy, uv_arr[4] = rect.xw, uv_arr[5] = rect.zw;
    return uv_arr[id];
}

float4 vs_clock( uint vid : SV_VERTEXID, out float2 uv : TEXCOORD ) : SV_POSITION {
    float4 pos = 0;
    pos.w = 1;

    float gid = vid % 6; // [0,5]
    float did = vid / 6; // [0,5]

    pos.x = lerp( gTL.x, gBR.x, (did/6.) + (gid == 2 || gid == 3 || gid == 5) / 6. );
    pos.y = (gid == 0 || gid == 2 || gid == 3) ? gTL.y : gBR.y;

    // select number uv by time.
    int hour = gDate.w/60/60;
    int minute = gDate.w/60 % 60;
    float tid[] = {
        hour < 10? 0: (hour/10 + 1),
        (hour % 10) + 1,
        (gDate.w % 2) ?  12 : 13,
        (minute / 10 ) + 1,
        (minute % 10 ) + 1
    };
    uv = getUV(getRect(tid[did]), gid);
    return pos;
}

float4 ps_clock( float4 vpos : SV_POSITION, float2 uv : TEXCOORD ) : SV_TARGET {
    return tex2D(sampDigits, uv);
}

technique clock_demo {
    pass p0 {
        PrimitiveTopology = TRIANGLELIST;
        VertexCount   = 30;
        VertexShader  = vs_clock;
        PixelShader   = ps_clock;

        BlendEnable = true;
        DestBlend = ONE;
    }
}
