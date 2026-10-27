const std = @import("std");
const GpuDevice = @import("GpuDevice.zig");
const VkStructureType = @import("../vk/VkStructureType.zig");
const VkResult = @import("../vk/VkResult.zig");
const Vk = @import("../vk/Vulkan.zig");

const Self = @This();
vk: *Vk.VkInstance,
gpuDevice: GpuDevice,

pub fn init(gpa: std.mem.Allocator, io: std.Io) !Self {
    var vkInstance: ?*Vk.VkInstance = null;
    const createInstanceRes = Vk.VkInstance.vkCreateInstance(
        &.{
            .sType = VkStructureType.VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
            .pNext = null,
            .flags = 0,
            .pApplicationInfo = null,
            .enabledLayerCount = 0,
            .ppEnabledLayerNames = null,
            .enabledExtensionCount = 0,
            .ppEnabledExtensionNames = null,
        },
        null,
        &vkInstance,
    );
    std.debug.print("vkCreateInstance result -> {d}\n", .{createInstanceRes});
    if (createInstanceRes != VkResult.VK_SUCCESS) {
        return error.VulkanInstanceCreate;
    }
    const resolvedInstance = vkInstance orelse return error.VulkanInstanceCreate;
    errdefer resolvedInstance.vkDestroyInstance(null);
    const gpuDevice = try GpuDevice.init(gpa, io, resolvedInstance);
    errdefer gpuDevice.close();
    return .{
        .vk = resolvedInstance,
        .gpuDevice = gpuDevice,
    };
}

pub fn close(self: *Self, gpa: std.mem.Allocator) void {
    self.gpuDevice.close(gpa);
    self.vk.vkDestroyInstance(null);
}

test "should init" {
    const gpa = std.testing.allocator;
    const io = std.testing.io;
    var subject = try init(gpa, io);
    defer subject.close(gpa);
}
