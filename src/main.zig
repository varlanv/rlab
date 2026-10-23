const std = @import("std");
const sdl3 = @import("sdl");

const ShaderLoadError = error{ FileLoad, ShaderInit };
const FileOpenError = error{Open};

const SdlFile = struct {
    data: []const u8,

    fn load(path: [:0]const u8) !SdlFile {
        var size: usize = undefined;
        const ptr = sdl3.SDL_LoadFile(
            path.ptr,
            &size,
        ) orelse {
            std.debug.print("Failed to initialize SDL GPU device - {s}", .{sdl3.SDL_GetError()});
            return FileOpenError.Open;
        };

        const bytes: [*]const u8 = @ptrCast(ptr);
        return .{ .data = bytes[0..size] };
    }

    fn close(self: SdlFile) void {
        sdl3.SDL_free(@constCast(self.data.ptr));
    }
};

const ShaderStage = enum(u1) {
    vertex = sdl3.SDL_GPU_SHADERSTAGE_VERTEX,
    fragment = sdl3.SDL_GPU_SHADERSTAGE_FRAGMENT,
};

const GpuInitError = error{Create};

const GpuDevice = struct {
    const Self = @This();
    sdlGpu: ?*sdl3.SDL_GPUDevice,

    fn init(flags: u32, debugMode: bool) !Self {
        const gpu = sdl3.SDL_CreateGPUDevice(
            flags,
            debugMode,
            null,
        );
        if (gpu == null) {
            std.debug.print("Failed to initialize SDL GPU device - {s}", .{sdl3.SDL_GetError()});
            return GpuInitError.Create;
        }
        return .{ .sdlGpu = gpu };
    }

    fn close(self: Self) void {
        sdl3.SDL_DestroyGPUDevice(self.sdlGpu);
    }
};

const Shader = struct {
    sdlFile: SdlFile,
    sdlShader: ?*sdl3.SDL_GPUShader,
    fn load(gpu: GpuDevice, stage: ShaderStage, path: [:0]const u8) !Shader {
        const file = SdlFile.load(path) catch return error.FileLoad;
        errdefer file.close();
        const shader = sdl3.SDL_CreateGPUShader(gpu.sdlGpu, &.{
            .code = file.data.ptr,
            .code_size = file.data.len,
            .entrypoint = "main",
            .format = sdl3.SDL_GPU_SHADERFORMAT_SPIRV,
            .stage = @backingInt(stage),
            .num_samplers = 0,
            .num_storage_textures = 0,
            .num_storage_buffers = 0,
            .num_uniform_buffers = 0,
            .props = 0,
        }) orelse {
            std.debug.print(
                "Failed to create shader: {s}\n",
                .{sdl3.SDL_GetError()},
            );
            return error.ShaderInit;
        };

        return .{
            .sdlFile = file,
            .sdlShader = shader,
        };
    }

    fn close(self: Shader, gpu: GpuDevice) void {
        self.sdlFile.close();
        sdl3.SDL_ReleaseGPUShader(gpu.sdlGpu, self.sdlShader);
    }
};

const InitError = error{Video};

const Color = struct { r: u8, g: u8, b: u8, a: u8 };
const Point2 = struct { x: i32, y: i32 };
const ColoredLine = struct { startPos: Point2, endPos: Point2, color: Color };

const RendererInitError = error{ CommandBufferInit, SwapchainAcquire, CreateGraphicPipeline };
const RenderCommitError = error{SubmitCommandBuffer};
const BufferedColoredLines = std.ArrayList(ColoredLine);

const RendererPass = struct {
    const Self = @This();
    gpu: GpuDevice,
    sdlGpuCommandBuffer: ?*sdl3.struct_SDL_GPUCommandBuffer,
    sdlGpuTexture: ?*sdl3.SDL_GPUTexture,
    sdlTargetInfo: sdl3.SDL_GPUColorTargetInfo,
    sdlRenderPass: ?*sdl3.struct_SDL_GPURenderPass,
    sdlGraphicsPipeline: ?*sdl3.SDL_GPUGraphicsPipeline,
    bufferedColoredLines: *BufferedColoredLines,

    fn drawLine(self: *Self, line: ColoredLine, gpa: std.mem.Allocator) !void {
        try self.bufferedColoredLines.append(gpa, line);
    }

    fn commit(self: *Self) !void {
        const commandBuffer = self.sdlGpuCommandBuffer orelse
            return error.AlreadyCommitted;

        if (self.sdlRenderPass) |renderPass| {
            sdl3.SDL_BindGPUGraphicsPipeline(
                renderPass,
                self.sdlGraphicsPipeline,
            );
            sdl3.SDL_DrawGPUPrimitives(renderPass, 2, 1, 0, 0);
            sdl3.SDL_EndGPURenderPass(renderPass);
            self.sdlRenderPass = null;
        }

        const submitted = sdl3.SDL_SubmitGPUCommandBuffer(commandBuffer);
        self.sdlGpuCommandBuffer = null;

        if (!submitted) {
            std.debug.print("Failed to submit GPU command buffer - {s}\n", .{
                sdl3.SDL_GetError(),
            });
            return RenderCommitError.SubmitCommandBuffer;
        }
    }
};

const Renderer = struct {
    const Self = @This();
    sdl: *const Sdl,
    sdlGraphicsPipeline: ?*sdl3.SDL_GPUGraphicsPipeline,
    bufferedColoredLines: BufferedColoredLines = .empty,

    fn init(sdl: *const Sdl) !Self {
        const colorTarget: sdl3.SDL_GPUColorTargetDescription = .{
            .format = sdl3.SDL_GetGPUSwapchainTextureFormat(sdl.gpu.sdlGpu, sdl.window),
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
        };
        const graphicsPipeline = sdl3.SDL_CreateGPUGraphicsPipeline(
            sdl.gpu.sdlGpu,
            &pipelineInfo,
        );
        if (graphicsPipeline == null) {
            std.debug.print("Failed to create graphics pipeline - {s}", .{
                sdl3.SDL_GetError(),
            });
            return RendererInitError.CreateGraphicPipeline;
        }
        return .{
            .sdl = sdl,
            .sdlGraphicsPipeline = graphicsPipeline,
        };
    }

    fn beginFrame(self: *Self) !RendererPass {
        self.bufferedColoredLines.clearRetainingCapacity();
        const sdl = self.sdl;
        var res: RendererPass = .{
            .gpu = sdl.gpu,
            .sdlGpuCommandBuffer = null,
            .sdlGpuTexture = null,
            .sdlTargetInfo = .{},
            .sdlGraphicsPipeline = self.sdlGraphicsPipeline,
            .sdlRenderPass = null,
            .bufferedColoredLines = &self.bufferedColoredLines,
        };
        res.sdlGpuCommandBuffer = sdl3.SDL_AcquireGPUCommandBuffer(sdl.gpu.sdlGpu);
        if (res.sdlGpuCommandBuffer == null) {
            std.debug.print("Failed to acquire GPU command buffer - {s}", .{sdl3.SDL_GetError()});
            return RendererInitError.CommandBufferInit;
        }

        if (!sdl3.SDL_WaitAndAcquireGPUSwapchainTexture(
            res.sdlGpuCommandBuffer,
            sdl.window,
            &res.sdlGpuTexture,
            null,
            null,
        )) {
            std.debug.print("Failed to acquire GPU swapchain texture - {s}\n", .{
                sdl3.SDL_GetError(),
            });
            _ = sdl3.SDL_CancelGPUCommandBuffer(res.sdlGpuCommandBuffer);
            return RendererInitError.SwapchainAcquire;
        }
        res.sdlTargetInfo = .{
            .texture = res.sdlGpuTexture,
            .clear_color = .{
                .a = 1.0,
                .r = 1.0,
                .g = 1.0,
                .b = 1.0,
            },
            .load_op = sdl3.SDL_GPU_LOADOP_CLEAR,
            .store_op = sdl3.SDL_GPU_STOREOP_STORE,
        };

        res.sdlRenderPass = sdl3.SDL_BeginGPURenderPass(
            res.sdlGpuCommandBuffer,
            &res.sdlTargetInfo,
            1,
            null,
        );
        return res;
    }

    fn close(self: *Self, gpa: std.mem.Allocator) void {
        self.bufferedColoredLines.deinit(gpa);
        sdl3.SDL_ReleaseGPUGraphicsPipeline(
            self.sdl.gpu.sdlGpu,
            self.sdlGraphicsPipeline,
        );
    }
};

const BuiltinShaders = struct {
    const Self = @This();
    lineFrag: Shader,
    lineVert: Shader,

    fn init(gpu: GpuDevice) !Self {
        const lineFragShader = try Shader.load(
            gpu,
            ShaderStage.fragment,
            "shaders/compiled/line.frag.spv",
        );
        errdefer lineFragShader.close(gpu);
        const lineVertShader = try Shader.load(
            gpu,
            ShaderStage.vertex,
            "shaders/compiled/line.vert.spv",
        );
        return .{
            .lineFrag = lineFragShader,
            .lineVert = lineVertShader,
        };
    }

    fn close(self: Self, gpu: GpuDevice) void {
        self.lineFrag.close(gpu);
        self.lineVert.close(gpu);
    }
};

const Sdl = struct {
    const Self = @This();
    initFlags: u32,
    gpu: GpuDevice,
    window: ?*sdl3.SDL_Window,
    shaders: BuiltinShaders,

    fn init() !Self {
        const sdlInitFlags = sdl3.SDL_INIT_VIDEO;
        if (!sdl3.SDL_InitSubSystem(sdlInitFlags)) {
            std.debug.print("Failed to initialize SDL video subsystem [{s}]", .{sdl3.SDL_GetError()});
            return InitError.Video;
        }
        errdefer sdl3.SDL_QuitSubSystem(sdlInitFlags);
        const gpu = try GpuDevice.init(sdl3.SDL_GPU_SHADERFORMAT_SPIRV, true);
        errdefer gpu.close();
        const window = sdl3.SDL_CreateWindow(
            "win",
            800,
            600,
            sdl3.SDL_WINDOW_RESIZABLE,
        );
        if (window == null) {
            std.debug.panic("Failed to render window - {s}", .{sdl3.SDL_GetError()});
            return;
        }
        errdefer sdl3.SDL_DestroyWindow(window);
        if (!sdl3.SDL_ClaimWindowForGPUDevice(gpu.sdlGpu, window)) {
            std.debug.panic("Failed to claim window for GPU - {s}", .{sdl3.SDL_GetError()});
            return;
        }
        const builtinShaders = try BuiltinShaders.init(gpu);
        return .{
            .initFlags = sdlInitFlags,
            .gpu = gpu,
            .window = window,
            .shaders = builtinShaders,
        };
    }

    fn close(self: Self) void {
        self.shaders.close(self.gpu);
        sdl3.SDL_ReleaseWindowFromGPUDevice(self.gpu.sdlGpu, self.window);
        sdl3.SDL_DestroyWindow(self.window);
        self.gpu.close();
        errdefer sdl3.SDL_QuitSubSystem(self.initFlags);
    }
};

pub fn main(_: std.process.Init) !void {
    const sdl = try Sdl.init();
    defer sdl.close();
    var gpa = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer gpa.deinit();
    var renderer = try Renderer.init(&sdl);
    defer renderer.close(gpa.allocator());
    var done = false;
    var event: sdl3.SDL_Event = undefined;
    while (!done) {
        var renderPass = try renderer.beginFrame();
        try renderPass.drawLine(
            .{
                .startPos = .{
                    .x = 0,
                    .y = 0,
                },
                .endPos = .{
                    .x = 0,
                    .y = 0,
                },
                .color = .{
                    .a = 0,
                    .r = 0,
                    .g = 0,
                    .b = 0,
                },
            },
            gpa.allocator(),
        );
        try renderPass.commit();
        if (!sdl3.SDL_WaitEvent(&event)) {
            std.debug.panic("Failed to wait for event - {s}", .{sdl3.SDL_GetError()});
            return;
        }
        if (event.type == sdl3.SDL_EVENT_QUIT) {
            done = true;
        }
    }
}

test "simple test" {
    const gpa = std.testing.allocator;
    var list: std.ArrayList(i32) = .empty;
    defer list.deinit(gpa); // Try commenting this out and see if zig detects the memory leak!
    try list.append(gpa, 42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
