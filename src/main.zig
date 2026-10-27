const std = @import("std");
const GraphicsSystem = @import("./renderer/GraphicsSystem.zig");
const lang = @import("lang.zig");
const Vulkan = @import("vk/Vulkan.zig");

const Self = @This();

pub fn main(_: std.process.Init) !void {
    std.debug.print("started\n", .{});
    var vk = try Vulkan.load();
    vk.close();
    // try exploreGraphics(init);
}

fn exploreGraphics(init: std.process.Init) !void {
    const gpa = init.gpa;
    const initialIo = try lang.InitialIo.init(init.io, gpa);
    defer initialIo.close(gpa);
    const io = initialIo.io;
    var graphicsSystem = try GraphicsSystem.init(gpa, io);
    defer graphicsSystem.close(gpa);
}

test {
    _ = GraphicsSystem;
}
