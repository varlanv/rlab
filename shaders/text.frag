#version 450

layout(location = 0) in vec4 vertexColor;
layout(location = 1) in vec2 vertexUV;

// Fragment sampler slot 0: bind the current draw sequence's atlas and sampler.
// Regular SDL_ttf atlas glyphs use alpha coverage; RGBA glyphs retain their color.
// This shader is for regular atlases, not signed-distance-field (SDF) glyphs.
layout(set = 2, binding = 0) uniform sampler2D glyphAtlas;

layout(location = 0) out vec4 outColor;

void main()
{
    // Straight-alpha output. Use SRC_ALPHA / ONE_MINUS_SRC_ALPHA for RGB,
    // and ONE / ONE_MINUS_SRC_ALPHA for alpha, both with ADD blending.
    // No discard: retain antialiased edge coverage and avoid fragment kills.
    outColor = texture(glyphAtlas, vertexUV) * vertexColor;
}
