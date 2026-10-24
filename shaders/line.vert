#version 450

layout(location = 0) in vec2 inPosition;
layout(location = 1) in vec4 inColor;

layout(std140, set = 1, binding = 0) uniform Camera
{
    mat4 projection;
};

layout(location = 0) out vec4 vertexColor;

void main()
{
    gl_Position = projection * vec4(inPosition, 0.0, 1.0);
    vertexColor = inColor;
}