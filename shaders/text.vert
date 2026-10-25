#version 450

// Vertex inputs: FLOAT2 position, UBYTE4_NORM (or FLOAT4) color, FLOAT2 UV.
// Positions and UVs come directly from TTF_GetGPUTextDrawData.
layout(location = 0) in vec2 inPosition;
layout(location = 1) in vec4 inColor;
layout(location = 2) in vec2 inUV;

// Vertex uniform slot 0: 80 bytes, std140, column-major.
// projection: offset 0, the existing pixel-space projection (64 bytes).
// placement: offset 64, pixel origin in xy and scale in zw (16 bytes).
// For unscaled text at (x, y), placement is (x, y, 1, 1).
layout(std140, set = 1, binding = 0) uniform TextUniforms
{
    mat4 projection;
    vec4 placement;
};

layout(location = 0) out vec4 vertexColor;
layout(location = 1) out vec2 vertexUV;

void main()
{
    // SDL_ttf geometry is Y-up; the application's pixel coordinates are Y-down.
    // Keep atlas UVs unchanged: they already correspond to these glyph vertices.
    vec2 pixelPosition = placement.xy
        + vec2(inPosition.x, -inPosition.y) * placement.zw;

    gl_Position = projection * vec4(pixelPosition, 0.0, 1.0);
    vertexColor = inColor;
    vertexUV = inUV;
}
