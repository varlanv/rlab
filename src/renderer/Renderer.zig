const Sdl = @import("Sdl.zig");
const std = @import("std");
const sdl3 = @import("sdl");
const RendererPass = @import("RendererPass.zig");

const Self = @This();
pub const DrawBuffers = struct {
    bufferedColoredLines: Sdl.BufferedColoredLines = .empty,
};

pub const DelegateRenderPass = sdl3.SDL_GPURenderPass;

pub const GpuGraphicsPipeline = struct {
    delegate: *sdl3.SDL_GPUGraphicsPipeline,

    pub fn init(sdl: *const Sdl) !GpuGraphicsPipeline {
        const colorTarget: sdl3.SDL_GPUColorTargetDescription = .{
            .format = sdl3.SDL_GetGPUSwapchainTextureFormat(
                sdl.gpu.delegate,
                sdl.window.delegate,
            ),
        };
        const bufferDescriptions = [1]sdl3.SDL_GPUVertexBufferDescription{.{
            .slot = 0,
            .pitch = @sizeOf(Sdl.Vertex),
            .input_rate = sdl3.SDL_GPU_VERTEXINPUTRATE_VERTEX,
            .instance_step_rate = 0,
        }};
        const attributes = [2]sdl3.SDL_GPUVertexAttribute{
            .{
                .location = 0,
                .buffer_slot = 0,
                .format = sdl3.SDL_GPU_VERTEXELEMENTFORMAT_FLOAT2,
                .offset = @offsetOf(Sdl.Vertex, "point"),
            },
            .{
                .location = 1,
                .buffer_slot = 0,
                .format = sdl3.SDL_GPU_VERTEXELEMENTFORMAT_UBYTE4_NORM,
                .offset = @offsetOf(Sdl.Vertex, "color"),
            },
        };
        const pipelineInfo: sdl3.SDL_GPUGraphicsPipelineCreateInfo = .{
            .vertex_shader = sdl.shaders.lineVert.sdlShader,
            .fragment_shader = sdl.shaders.lineFrag.sdlShader,
            .primitive_type = sdl3.SDL_GPU_PRIMITIVETYPE_LINELIST,
            .multisample_state = .{
                .sample_count = sdl3.SDL_GPU_SAMPLECOUNT_1,
            },
            .target_info = .{
                .color_target_descriptions = &colorTarget,
                .num_color_targets = 1,
            },
            .vertex_input_state = .{
                .vertex_buffer_descriptions = &bufferDescriptions,
                .num_vertex_buffers = bufferDescriptions.len,
                .vertex_attributes = &attributes,
                .num_vertex_attributes = attributes.len,
            },
        };
        const graphicsPipeline = sdl3.SDL_CreateGPUGraphicsPipeline(
            sdl.gpu.delegate,
            &pipelineInfo,
        ) orelse {
            std.debug.print("Failed to create graphics pipeline - {s}", .{
                sdl3.SDL_GetError(),
            });
            return error.CreateGraphicPipeline;
        };
        return .{
            .delegate = graphicsPipeline,
        };
    }

    pub fn bind(self: GpuGraphicsPipeline, renderPass: *DelegateRenderPass) void {
        sdl3.SDL_BindGPUGraphicsPipeline(renderPass, self.delegate);
    }
};

pub const FrameState = struct {
    graphicsPipeline: GpuGraphicsPipeline,
    gpuBuffer: Sdl.GpuBuffer,
    gpuTransferBuffer: Sdl.GpuTransferBuffer,
};
sdl: *const Sdl,
frameState: FrameState,
drawBuffers: DrawBuffers = .{},

pub fn init(sdl: *const Sdl) !Self {
    const gpuBufferSize = 2048;
    const gpuBuffer = sdl3.SDL_CreateGPUBuffer(
        sdl.gpu.delegate,
        &.{
            .props = 0,
            .size = gpuBufferSize,
            .usage = sdl3.SDL_GPU_BUFFERUSAGE_VERTEX,
        },
    ) orelse return error.GpuBufferInit;
    errdefer sdl3.SDL_ReleaseGPUBuffer(sdl.gpu.delegate, gpuBuffer);
    const gpuTransferBuffer = try Sdl.GpuTransferBuffer.init(sdl, 2048);
    const graphicsPipeline = try GpuGraphicsPipeline.init(sdl);
    return .{
        .sdl = sdl,
        .frameState = .{
            .graphicsPipeline = graphicsPipeline,
            .gpuTransferBuffer = gpuTransferBuffer,
            .gpuBuffer = .{
                .delegate = gpuBuffer,
            },
        },
    };
}

pub fn beginFrame(self: *Self) !RendererPass {
    self.drawBuffers.bufferedColoredLines.clearRetainingCapacity();
    const sdl = self.sdl;
    const sdlGpuCommandBuffer = sdl3.SDL_AcquireGPUCommandBuffer(sdl.gpu.delegate) orelse {
        std.debug.print("Failed to acquire GPU command buffer - {s}", .{sdl3.SDL_GetError()});
        return error.CommandBufferInit;
    };

    const swapchainTexture = try Sdl.SwapchainGpuTexture.init(sdl, sdlGpuCommandBuffer);

    const targetInfo: sdl3.SDL_GPUColorTargetInfo = .{
        .texture = swapchainTexture.delegate,
        .clear_color = .{
            .a = 1.0,
            .r = 1.0,
            .g = 1.0,
            .b = 1.0,
        },
        .load_op = sdl3.SDL_GPU_LOADOP_CLEAR,
        .store_op = sdl3.SDL_GPU_STOREOP_STORE,
    };

    return .{
        .gpu = sdl.gpu,
        .gpuCommandBuffer = sdlGpuCommandBuffer,
        .targetInfo = targetInfo,
        .frameState = self.frameState,
        .drawBuffers = &self.drawBuffers,
        .swapchainTexture = swapchainTexture,
    };
}

pub fn close(self: *Self, gpa: std.mem.Allocator) void {
    self.drawBuffers.bufferedColoredLines.deinit(gpa);
    sdl3.SDL_ReleaseGPUBuffer(self.sdl.gpu.delegate, self.frameState.gpuBuffer.delegate);
    sdl3.SDL_ReleaseGPUTransferBuffer(self.sdl.gpu.delegate, self.frameState.gpuTransferBuffer.delegate);
    sdl3.SDL_ReleaseGPUGraphicsPipeline(
        self.sdl.gpu.delegate,
        self.frameState.graphicsPipeline.delegate,
    );
}
