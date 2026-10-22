const std = @import("std");
const sdl = @import("sdl");

pub fn main(_: std.process.Init) !void {
    std.debug.print("123 {}", .{sdl.SDL_IsMainThread()});
}

test "simple test" {
    const gpa = std.testing.allocator;
    var list: std.ArrayList(i32) = .empty;
    defer list.deinit(gpa); // Try commenting this out and see if zig detects the memory leak!
    try list.append(gpa, 42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
