struct VertexInput {
    float2 position : POSITION;
}

struct VertexOutput {
    float4 position : SV_Position;
}

[shader("vertex")]
VertexOutput v_main(VertexInput input) {
    VertexOutput output;
    output.position = float4(input.position, 0.0, 1.0);
    return output;
}

[shader("fragment")]   
float4 f_main(VertexOutput input) : SV_Target1 {
    return float4(1.0, 0.0, 0.0, 1.0);
}
