const Renderer = @import("renderer/Renderer.zig");
const std = @import("std");
const Sdl = @import("renderer/Sdl.zig");
const sdl3 = @import("sdl");
const lang = @import("lang.zig");

fn calc(other: u32) u32 {
    return 42 * other;
}

pub fn main(init: std.process.Init) !void {
    const gpa = init.gpa;
    const initialIo = try lang.InitialIo.init(init.io, gpa);
    defer initialIo.close(gpa);
    const io = initialIo.io;
    var fut = io.async(calc, .{2});
    const res = fut.await(io);

    std.debug.print("Worker: {d}\n", .{initialIo.coreCount});
    std.debug.print("Worker: {d}\n", .{res});
    try handleVideo(gpa);
}

fn handleVideo(gpa: std.mem.Allocator) !void {
    const sdl = try Sdl.init();
    defer sdl.close();
    var renderer = try Renderer.init(&sdl);
    defer renderer.close(gpa);
    var done = false;
    var event: sdl3.SDL_Event = undefined;
    while (!done) {
        var renderPass = try renderer.beginFrame();
        try renderPass.drawLine(
            .{
                .startPos = .{
                    .x = 400,
                    .y = 500,
                },
                .endPos = .{
                    .x = 600,
                    .y = 700,
                },
                .color = .{
                    .a = 255,
                    .r = 0,
                    .g = 0,
                    .b = 0,
                },
            },
            gpa,
        );
        try renderPass.drawLine(
            .{
                .startPos = .{
                    .x = 200,
                    .y = 250,
                },
                .endPos = .{
                    .x = 300,
                    .y = 350,
                },
                .color = .{
                    .a = 255,
                    .r = 0,
                    .g = 0,
                    .b = 0,
                },
            },
            gpa,
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
