const Sdl = @import("Sdl.zig");
const lang = @import("../lang.zig");
const std = @import("std");
const sdl3 = @import("sdl");

const Self = @This();
defaultFont: Font,
gpuTextEngine: *sdl3.TTF_TextEngine,

pub fn init(gpu: Sdl.GpuDevice) !Self {
    if (!sdl3.TTF_Init()) {
        std.debug.print("Failed to init TTF lib [ {s} ]", .{sdl3.SDL_GetError()});
    }
    errdefer sdl3.TTF_Quit();
    const defaultFont = sdl3.TTF_OpenFont("assets/fonts/GoogleSansFlex_24pt-Regular.ttf", 24) orelse {
        std.debug.print("Failed to load fonts [ {s} ]", .{sdl3.SDL_GetError()});
        return error.LoadFonts;
    };

    const gpuTextEngine = sdl3.TTF_CreateGPUTextEngine(gpu.delegate) orelse {
        std.debug.print("Failed to create gpu text engine [ {s} ]", .{sdl3.SDL_GetError()});
        return error.CreateGPUTextEngine;
    };
    errdefer gpuTextEngine.DestroyGPUTextEngine();
    return .{
        .defaultFont = .{
            .delegate = defaultFont,
        },
        .gpuTextEngine = gpuTextEngine,
    };
}

pub fn createText(self: *const Self, text: lang.CString) !TTFText {
    const ttfText = sdl3.TTF_CreateText(
        self.gpuTextEngine,
        self.defaultFont.delegate,
        text,
        text.len,
    ) orelse {
        return error.CreateTTFText;
    };
    const drawData = sdl3.TTF_GetGPUTextDrawData(ttfText) orelse {
        return error.GetGPUTextDrawData;
    };
    return .{
        .delegate = ttfText,
        .gpuDrawData = drawData,
    };
}

pub fn close(self: *const Self) void {
    self.defaultFont.close();
    self.gpuTextEngine.DestroyGPUTextEngine();
    sdl3.TTF_Quit();
}

pub const Font = struct {
    delegate: *sdl3.TTF_Font,

    pub fn close(self: Font) void {
        sdl3.TTF_CloseFont(self.delegate);
    }
};

pub const TTFText = struct {
    delegate: *sdl3.TTF_Text,
    gpuDrawData: [*c]const sdl3.TTF_GPUAtlasDrawSequence,

    pub fn close(self: TTFText) void {
        self.delegate.DestroyText();
    }
};

pub const TextVertex = struct {
    xy: [*c]sdl3.SDL_FPoint,
    uv: [*c]sdl3.SDL_FPoint,
    color: Sdl.Color,
};
