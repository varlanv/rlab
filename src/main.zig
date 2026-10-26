const std = @import("std");
const GraphicsSystem = @import("./renderer/GraphicsSystem.zig");
const lang = @import("lang.zig");

pub fn main(init: std.process.Init) !void {
    std.debug.print("started\n", .{});
    const gpa = init.gpa;
    var graphicsSystem = try GraphicsSystem.init(gpa);
    defer graphicsSystem.close();
}

fn calc(other: u32) u32 {
    return 42 * other;
}

fn exploreAsync(init: std.process.Init) !void {
    const gpa = init.gpa;
    const initialIo = try lang.InitialIo.init(init.io, gpa);
    defer initialIo.close(gpa);
    const io = initialIo.io;
    var fut = io.async(calc, .{2});
    const res = fut.await(io);
    std.debug.print("Core count: {d}\n", .{initialIo.coreCount});
    std.debug.print("Worker res: {d}\n", .{res});
}

//
// fn handleVideo(gpa: std.mem.Allocator) !void {
//     const sdl = try Sdl.init();
//     defer sdl.close();
//     const initialDisplay = try sdl.window.currentDisplay();
//     const maxFps: f64 = if (initialDisplay.refresh_rate > 0) initialDisplay.refresh_rate else 60.0;
//     const nsFrameBudget: u64 = @intFromFloat(@as(f64, std.time.ns_per_s) / maxFps);
//     var renderer = try Renderer.init(&sdl);
//     defer renderer.close(gpa);
//     var done = false;
//     var line1: Sdl.ColoredLine = .{
//         .startPos = .{
//             .x = 200,
//             .y = 250,
//         },
//         .endPos = .{
//             .x = 300,
//             .y = 350,
//         },
//         .color = .{
//             .a = 255,
//             .r = 0,
//             .g = 0,
//             .b = 0,
//         },
//     };
//     var line2: Sdl.ColoredLine = .{
//         .startPos = .{
//             .x = 200,
//             .y = 250,
//         },
//         .endPos = .{
//             .x = 300,
//             .y = 350,
//         },
//         .color = .{
//             .a = 255,
//             .r = 0,
//             .g = 0,
//             .b = 0,
//         },
//     };
//
//     const text = try sdl.fonts.createText("hello");
//     defer text.close();
//     var event: sdl3.SDL_Event = undefined;
//     while (!done) {
//         const frameTimeStart = sdl3.SDL_GetTicksNS();
//         while (sdl3.SDL_PollEvent(&event)) {
//             if (event.type == sdl3.SDL_EVENT_QUIT) {
//                 done = true;
//             }
//         }
//         var renderPass = try renderer.beginFrame();
//         try renderPass.drawLine(line1, gpa);
//         try renderPass.drawLine(line2, gpa);
//         line1.endPos.x -= 1;
//         line2.endPos.y -= 1;
//         if (line1.endPos.x <= 0) {
//             line1.endPos.x = 300;
//         }
//         if (line2.endPos.y <= 0) {
//             line2.endPos.y = 350;
//         }
//         try renderPass.commit();
//         const frameElapsed = sdl3.SDL_GetTicksNS() - frameTimeStart;
//         if (frameElapsed < nsFrameBudget) {
//             sdl3.SDL_DelayPrecise(nsFrameBudget - frameElapsed);
//         }
//     }
// }

test "simple test" {
    const gpa = std.testing.allocator;
    var list: std.ArrayList(i32) = .empty;
    defer list.deinit(gpa); // Try commenting this out and see if zig detects the memory leak!
    try list.append(gpa, 42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
