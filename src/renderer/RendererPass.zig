const sdl3 = @import("sdl");
const Sdl = @import("Sdl.zig");
const Renderer = @import("Renderer.zig");
const std = @import("std");

const Self = @This();
gpu: Sdl.GpuDevice,
frameState: Renderer.FrameState,
drawBuffers: *Renderer.DrawBuffers,
gpuCommandBuffer: *sdl3.struct_SDL_GPUCommandBuffer,
targetInfo: sdl3.SDL_GPUColorTargetInfo,
swapchainTexture: Sdl.SwapchainGpuTexture,

pub fn drawLine(self: *Self, line: Sdl.ColoredLine, gpa: std.mem.Allocator) !void {
    try self.drawBuffers.bufferedColoredLines.append(gpa, line);
}

pub fn commit(self: *Self) !void {
    {
        const mappedGpuTransferButter = try self.frameState.gpuTransferBuffer.mapBuffer();
        defer mappedGpuTransferButter.unmap();
        const vertices = mappedGpuTransferButter.castAddress(Sdl.Vertex);
        for (self.drawBuffers.bufferedColoredLines.items, 0..) |line, idx| {
            vertices[idx * 2] = .{
                .point = line.startPos,
                .color = line.color,
            };
            vertices[idx * 2 + 1] = .{
                .point = line.endPos,
                .color = line.color,
            };
        }
    }

    const commandBuffer = self.gpuCommandBuffer;
    {
        const copyPass = sdl3.SDL_BeginGPUCopyPass(commandBuffer) orelse {
            return error.BeginCopyPass;
        };
        defer copyPass.EndGPUCopyPass();
        const source: sdl3.SDL_GPUTransferBufferLocation = .{
            .transfer_buffer = self.frameState.gpuTransferBuffer.delegate,
            .offset = 0,
        };

        const destination: sdl3.SDL_GPUBufferRegion = .{
            .buffer = self.frameState.gpuBuffer.delegate,
            .offset = 0,
            .size = @intCast(self.drawBuffers.bufferedColoredLines.items.len * 2 * @sizeOf(Sdl.Vertex)),
        };

        sdl3.SDL_UploadToGPUBuffer(copyPass, &source, &destination, true);
    }
    {
        const renderPass = sdl3.SDL_BeginGPURenderPass(
            commandBuffer,
            &self.targetInfo,
            1,
            null,
        ) orelse return error.AlreadyCommitted;
        defer sdl3.SDL_EndGPURenderPass(renderPass);
        self.frameState.graphicsPipeline.bind(renderPass);
        const binding: sdl3.SDL_GPUBufferBinding = .{
            .buffer = self.frameState.gpuBuffer.delegate,
            .offset = 0,
        };
        sdl3.SDL_BindGPUVertexBuffers(
            renderPass,
            0,
            &binding,
            1,
        );
        const width: f32 = @floatFromInt(self.swapchainTexture.width);
        const height: f32 = @floatFromInt(self.swapchainTexture.height);

        // Column-major layout, matching GLSL's mat4.
        const projection: [16]f32 align(16) = .{
            2.0 / width, 0,             0, 0,
            0,           -2.0 / height, 0, 0,
            0,           0,             1, 0,
            -1,          1,             0, 1,
        };

        sdl3.SDL_PushGPUVertexUniformData(
            commandBuffer,
            0,
            &projection,
            @sizeOf(@TypeOf(projection)),
        );
        sdl3.SDL_DrawGPUPrimitives(
            renderPass,
            @intCast(self.drawBuffers.bufferedColoredLines.items.len * 2),
            1,
            0,
            0,
        );
    }
    const submitted = sdl3.SDL_SubmitGPUCommandBuffer(commandBuffer);
    if (!submitted) {
        std.debug.print("Failed to submit GPU command buffer - {s}\n", .{
            sdl3.SDL_GetError(),
        });
        return Sdl.RenderCommitError.SubmitCommandBuffer;
    }
}
