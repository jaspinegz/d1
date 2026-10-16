struct VertexInput {
    float2 position : POSITION;
}

struct VertexOutput {
    float4 position : SV_Position;
}

uniform Texture2D texture_vscreen;
uniform SamplerState sampler_vscreen;

[shader("vertex")]
VertexOutput v_main(VertexInput input) {
    VertexOutput output;
    output.position = float4(input.position, 0.0, 1.0);
    return output;
}

[shader("fragment")]   
float4 f_main(VertexOutput input) : SV_Target {
    float4 colour = texture_vscreen[input.position.xy];
    return float4(colour.xyz, 1.0);
}
