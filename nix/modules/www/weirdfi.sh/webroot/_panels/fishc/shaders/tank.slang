//TODO: if want noise on GPU, use efficient hashing function 
//jaina uses PCG hash
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
float4 f_main(VertexOutput input) : SV_Target {
    float4 color = float4(((input.position.x * 10.0) % 100.0) / 100.0f, 0.0, 0.0, 1.0);
    return color;
}
