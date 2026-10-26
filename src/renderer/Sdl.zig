const lang = @import("../lang.zig");
const std = @import("std");
const sdl3 = @import("sdl");
const Fonts = @import("Fonts.zig");

const Self = @This();
initFlags: u32,
gpu: GpuDevice,
window: Window,
shaders: BuiltinShaders,
fonts: Fonts,

pub fn init() !Self {
    const sdlInitFlags = sdl3.SDL_INIT_VIDEO;
    if (!sdl3.SDL_InitSubSystem(sdlInitFlags)) {
        std.debug.print("Failed to initialize SDL video subsystem [ {s} ]", .{sdl3.SDL_GetError()});
        return error.SdlVideoInit;
    }
    errdefer sdl3.SDL_QuitSubSystem(sdlInitFlags);
    const gpu = try GpuDevice.init(sdl3.SDL_GPU_SHADERFORMAT_SPIRV, true);
    errdefer gpu.close();
    const fonts = try Fonts.init(gpu);
    errdefer fonts.close();
    const window = try Window.init(gpu);
    errdefer window.close();
    if (!sdl3.SDL_SetGPUSwapchainParameters(
        gpu.delegate,
        window.delegate,
        sdl3.SDL_GPU_SWAPCHAINCOMPOSITION_SDR,
        sdl3.SDL_GPU_PRESENTMODE_IMMEDIATE,
    )) {
        std.debug.print("Failed to configure presentation: {s}\n", .{
            sdl3.SDL_GetError(),
        });
        return error.SwapchainConfigurationFailed;
    }
    const builtinShaders = try BuiltinShaders.init(gpu);
    return .{
        .initFlags = sdlInitFlags,
        .gpu = gpu,
        .window = window,
        .shaders = builtinShaders,
        .fonts = fonts,
    };
}

pub fn close(self: Self) void {
    self.shaders.close(self.gpu);
    self.window.close();
    self.gpu.close();
    sdl3.SDL_QuitSubSystem(self.initFlags);
    sdl3.TTF_Quit();
}

pub const FileOpenError = error{Open};

pub const Display = sdl3.SDL_DisplayMode;
pub const RectangleSize = struct {
    width: i32,
    height: i32,
};

pub const Window = struct {
    gpu: GpuDevice,
    delegate: *sdl3.SDL_Window,

    pub fn windowSizeInPixels(self: Window) !RectangleSize {
        var h: i32 = 0;
        var w: i32 = 0;
        if (!self.delegate.GetWindowSizeInPixels(&w, &h)) {
            std.debug.print("Failed to get current window size - {s}", .{sdl3.SDL_GetError()});
            return error.GetWindowSize;
        }
        return .{
            .height = h,
            .width = w,
        };
    }

    pub fn currentDisplay(self: Window) !*const Display {
        const displayId = sdl3.SDL_GetDisplayForWindow(self.delegate);
        if (displayId == 0) {
            std.debug.print("Failed to get display for window - {s}", .{sdl3.SDL_GetError()});
            return error.GetDisplyForWindow;
        }
        const res = sdl3.SDL_GetCurrentDisplayMode(displayId) orelse {
            std.debug.print("Failed to get current display mode - {s}", .{sdl3.SDL_GetError()});
            return error.GetCurrentDisplayMode;
        };
        return res;
    }

    pub fn init(gpu: GpuDevice) !Window {
        const window = sdl3.SDL_CreateWindow(
            "win",
            800,
            600,
            sdl3.SDL_WINDOW_RESIZABLE,
        ) orelse {
            std.debug.print("Failed to render window - {s}", .{sdl3.SDL_GetError()});
            return error.SdlWindowInit;
        };
        const res: Window = .{
            .gpu = gpu,
            .delegate = window,
        };
        errdefer res.close();
        try claimForGpu(res, gpu);
        return res;
    }

    fn claimForGpu(self: Window, gpu: GpuDevice) !void {
        if (!sdl3.SDL_ClaimWindowForGPUDevice(gpu.delegate, self.delegate)) {
            std.debug.print("Failed to claim window for GPU - {s}", .{sdl3.SDL_GetError()});
            return error.SdlGpuDeviceClaim;
        }
        if (!sdl3.SDL_WindowSupportsGPUPresentMode(
            gpu.delegate,
            self.delegate,
            sdl3.SDL_GPU_PRESENTMODE_IMMEDIATE,
        )) {
            return error.ImmediatePresentModeUnsupported;
        }
    }

    pub fn close(self: Window) void {
        sdl3.SDL_ReleaseWindowFromGPUDevice(self.gpu.delegate, self.delegate);
        sdl3.SDL_DestroyWindow(self.delegate);
    }
};

pub const File = struct {
    pub const FileOpenError = error{Open};

    data: []const u8,

    pub fn load(path: lang.CString) !File {
        var size: usize = undefined;
        const ptr = sdl3.SDL_LoadFile(
            path.ptr,
            &size,
        ) orelse {
            std.debug.print("Failed to initialize SDL GPU device - {s}", .{sdl3.SDL_GetError()});
            return File.FileOpenError.Open;
        };

        const bytes: [*]const u8 = @ptrCast(ptr);
        return .{ .data = bytes[0..size] };
    }

    pub fn close(self: File) void {
        sdl3.SDL_free(@constCast(self.data.ptr));
    }
};

pub const ShaderStage = enum(u1) {
    vertex = sdl3.SDL_GPU_SHADERSTAGE_VERTEX,
    fragment = sdl3.SDL_GPU_SHADERSTAGE_FRAGMENT,
};

pub const ShaderProps = struct {
    numSamplers: u32 = 0,
    numStorageTextures: u32 = 0,
    numStorageBuffers: u32 = 0,
    numUniformBuffers: u32 = 0,
    stage: ShaderStage,
};

pub const GpuInitError = error{Create};

pub const GpuDevice = struct {
    delegate: *sdl3.SDL_GPUDevice,

    pub fn init(flags: u32, debugMode: bool) !GpuDevice {
        const gpu = sdl3.SDL_CreateGPUDevice(
            flags,
            debugMode,
            null,
        ) orelse {
            std.debug.print("Failed to initialize SDL GPU device - {s}", .{sdl3.SDL_GetError()});
            return GpuInitError.Create;
        };
        return .{
            .delegate = gpu,
        };
    }

    pub fn close(self: GpuDevice) void {
        sdl3.SDL_DestroyGPUDevice(self.delegate);
    }
};

pub const Shader = struct {
    sdlFile: File,
    sdlShader: *sdl3.SDL_GPUShader,

    pub fn load(
        gpu: GpuDevice,
        path: lang.CString,
        props: ShaderProps,
    ) !Shader {
        const file = File.load(path) catch return error.FileLoad;
        errdefer file.close();
        const shader = sdl3.SDL_CreateGPUShader(gpu.delegate, &.{
            .code = file.data.ptr,
            .code_size = file.data.len,
            .entrypoint = "main",
            .format = sdl3.SDL_GPU_SHADERFORMAT_SPIRV,
            .stage = @backingInt(props.stage),
            .num_samplers = props.numSamplers,
            .num_storage_textures = props.numStorageTextures,
            .num_storage_buffers = props.numStorageBuffers,
            .num_uniform_buffers = props.numUniformBuffers,
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

    pub fn close(self: Shader, gpu: GpuDevice) void {
        self.sdlFile.close();
        sdl3.SDL_ReleaseGPUShader(gpu.delegate, self.sdlShader);
    }
};

pub const Color = extern struct { r: u8, g: u8, b: u8, a: u8 };
pub const Point2 = extern struct { x: f32, y: f32 };
pub const ColoredLine = struct { startPos: Point2, endPos: Point2, color: Color };
pub const Vertex = extern struct { point: Point2, color: Color };

pub const RenderCommitError = error{SubmitCommandBuffer};
pub const BufferedColoredLines = std.ArrayList(ColoredLine);

pub const GpuBuffer = struct {
    delegate: *sdl3.SDL_GPUBuffer,
};

pub const BuiltinShaders = struct {
    lineFrag: Shader,
    lineVert: Shader,

    fn init(gpu: GpuDevice) !BuiltinShaders {
        const lineFragShader = try Shader.load(
            gpu,
            "shaders/compiled/line.frag.spv",
            .{
                .stage = ShaderStage.fragment,
            },
        );
        errdefer lineFragShader.close(gpu);
        const lineVertShader = try Shader.load(
            gpu,
            "shaders/compiled/line.vert.spv",
            .{
                .stage = ShaderStage.vertex,
                .numUniformBuffers = 1,
            },
        );
        return .{
            .lineFrag = lineFragShader,
            .lineVert = lineVertShader,
        };
    }

    fn close(self: BuiltinShaders, gpu: GpuDevice) void {
        self.lineFrag.close(gpu);
        self.lineVert.close(gpu);
    }
};

pub const SwapchainGpuTexture = struct {
    delegate: *sdl3.SDL_GPUTexture,
    width: u32,
    height: u32,

    pub fn init(sdl: *const Self, commandBuffer: *sdl3.SDL_GPUCommandBuffer) !SwapchainGpuTexture {
        var gpuTexture: ?*sdl3.SDL_GPUTexture = null;
        var width: u32 = 0;
        var height: u32 = 0;
        if (!sdl3.SDL_WaitAndAcquireGPUSwapchainTexture(
            commandBuffer,
            sdl.window.delegate,
            &gpuTexture,
            &width,
            &height,
        )) {
            std.debug.print("Failed to acquire GPU swapchain texture - {s}\n", .{
                sdl3.SDL_GetError(),
            });
            // window may be minimized
            _ = sdl3.SDL_CancelGPUCommandBuffer(commandBuffer);
            return error.SwapchainAcquire;
        }
        return .{
            .delegate = gpuTexture orelse return error.SwapchainAcquire,
            .width = width,
            .height = height,
        };
    }
};

pub const MappedGpuTransferBuffer = struct {
    gpu: Self.GpuDevice,
    delegate: *sdl3.SDL_GPUTransferBuffer,
    addr: *anyopaque,

    pub fn castAddress(self: MappedGpuTransferBuffer, target: type) [*]target {
        return @ptrCast(@alignCast(self.addr));
    }

    pub fn unmap(self: MappedGpuTransferBuffer) void {
        sdl3.SDL_UnmapGPUTransferBuffer(self.gpu.delegate, self.delegate);
    }
};

pub const GpuTransferBuffer = struct {
    gpu: Self.GpuDevice,
    delegate: *sdl3.SDL_GPUTransferBuffer,

    pub fn mapBuffer(self: GpuTransferBuffer) !MappedGpuTransferBuffer {
        const addr = sdl3.SDL_MapGPUTransferBuffer(
            self.gpu.delegate,
            self.delegate,
            true,
        ) orelse return error.MapGpuTransferBuffer;
        return .{
            .gpu = self.gpu,
            .delegate = self.delegate,
            .addr = addr,
        };
    }

    pub fn init(sdl: *const Self, size: u32) !GpuTransferBuffer {
        const gpuTransferBuffer = sdl3.SDL_CreateGPUTransferBuffer(
            sdl.gpu.delegate,
            &.{
                .props = 0,
                .size = size,
                .usage = sdl3.SDL_GPU_TRANSFERBUFFERUSAGE_UPLOAD,
            },
        ) orelse return error.GpuBufferInit;
        errdefer sdl3.SDL_ReleaseGPUTransferBuffer(sdl.gpu.delegate, gpuTransferBuffer);

        return .{
            .gpu = sdl.gpu,
            .delegate = gpuTransferBuffer,
        };
    }
};

pub const Monitor = struct {
    pub fn init() void {
        _ = sdl3.SDL_GetDisplayForWindow();
    }
};
