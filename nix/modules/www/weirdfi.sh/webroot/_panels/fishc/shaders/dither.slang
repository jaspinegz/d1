struct VertexInput {
    float2 position : POSITION;
}

struct VertexOutput {
    float4 position : SV_Position;
}

uniform Texture2D texture_vscreen;

float closest(int x, int y, float c0) {
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

    if(c0 < limit)
        return 0.0;
    return 1.0;
}

[shader("vertex")]
VertexOutput v_main(VertexInput input) {
    VertexOutput output;
    output.position = float4(input.position, 0.0, 1.0);
    return output;
}

[shader("fragment")]   
float4 f_main(VertexOutput input) : SV_Target {
    float4 colour = texture_vscreen[input.position.xy * 2.0];

    // dither
    float2 xy = input.position.xy;
    int x = int(fmod(xy.x, 4));
    int y = int(fmod(xy.y, 4));
    float r = closest(x, y, colour.r);
    float g = closest(x, y, colour.g);
    float b = closest(x, y, colour.b);

    return float4(r, g, b, 1.0);
}
