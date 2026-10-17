struct VertexInput {
    float2 position : POSITION;
}

struct VertexOutput {
    float4 position : SV_Position;
}

uniform Texture2D texture_vscreen;

//bool closest(int x, int y, float c0) {
//    int dither[8*8] = {
//        0, 32, 8, 40, 2, 34, 10, 42,    /* 8x8 Bayer ordered dithering */
//        48, 16, 56, 24, 50, 18, 58, 26, /* pattern. Each input pixel */
//        12, 44, 4, 36, 14, 46, 6, 3,    /* is scaled to the 0..63 range */
//        60, 28, 52, 20, 62, 30, 54, 22, /* before looking in this table */
//        3, 35, 11, 43, 1, 33, 9, 41,    /* to determine the action. */
//        51, 19, 59, 27, 49, 17, 57, 25,
//        15, 47, 7, 39, 13, 45, 5, 37,
//        63, 31, 55, 23, 61, 29, 53, 21 };
//
//    float limit = 0.0;
//    if(x < 8)
//    {
//        limit = (dither[x*8+y]+1)/64.0;
//    }
//
//    if(c0 < limit)
//        return false;
//    return true;
//}

float _8b(float c) {
    return (floor((c*255.0)/8.0)*8.0)/255.0;
}

float3 _8b(float3 c) {
    return float3(_8b(c.r), _8b(c.g), _8b(c.b));
}

static const float3 water1 = float3(68/255.0,114/255.0,222/255.0);
static const float3 water2 = float3(8/255.0,69/255.0,94/255.0);
static const float3 water1_8b = _8b(water1);
static const float3 water2_8b = _8b(water2);

float3 closest(int x, int y, float3 colour) {
    int dither[8*8] = {
        0, 32, 8, 40, 2, 34, 10, 42,    /* 8x8 Bayer ordered dithering */
        48, 16, 56, 24, 50, 18, 58, 26, /* pattern. Each input pixel */
        12, 44, 4, 36, 14, 46, 6, 3,    /* is scaled to the 0..63 range */
        60, 28, 52, 20, 62, 30, 54, 22, /* before looking in this table */
        3, 35, 11, 43, 1, 33, 9, 41,    /* to determine the action. */
        51, 19, 59, 27, 49, 17, 57, 25,
        15, 47, 7, 39, 13, 45, 5, 37,
        63, 31, 55, 23, 61, 29, 53, 21 };

    float limit = 0.0;
    if(x < 8)
    {
        limit = (dither[x*8+y]+1)/64.0;
    }

    float mag = (colour.r+colour.g+colour.b)/3.0;
    if (mag < limit) {
        //darken by picking a darker 8-bit shade
        float r = water1_8b.r;
        float g = water1_8b.g;
        float b = water1_8b.b;
        while(r <= (colour.r-1.0/8))
            r += 1.0/8;
        while(g <= (colour.g-1.0/8))
            g += 1.0/8;
        while(b <= (colour.b-1.0/8))
            b += 1.0/8;
        return float3(r, g, b);
    }
    return colour;
}

[shader("vertex")]
VertexOutput v_main(VertexInput input) {
    VertexOutput output;
    output.position = float4(input.position, 0.0, 1.0);
    return output;
}

[shader("fragment")]   
float4 f_main(VertexOutput input) : SV_Target {
    float4 colour = texture_vscreen[input.position.xy];

    float r = (floor((colour.r*255.0)/8.0)*8.0)/255.0;
    float g = (floor((colour.g*255.0)/8.0)*8.0)/255.0;
    float b = (floor((colour.b*255.0)/8.0)*8.0)/255.0;

    // dither
    int x = int(fmod(input.position.x, 8));
    int y = int(fmod(input.position.y, 8));
    float3 dithered = closest(x, y, float3(r, g, b));
    return float4(dithered, 1.0);
}
