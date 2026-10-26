const std = @import("std");
const GpuDevice = @import("GpuDevice.zig");
const VkStructureType = @import("../vk/VkStructureType.zig");
const VkResult = @import("../vk/VkResult.zig");
const Vk = @import("../vk/Vulkan.zig");

const Self = @This();
vk: *Vk.VkInstance,
gpuDevice: GpuDevice,

pub fn init(gpa: std.mem.Allocator) !Self {
    var vkInstance: ?*Vk.VkInstance = null;
    const createInstanceRes = Vk.vkCreateInstance(
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
    errdefer Vk.vkDestroyInstance(resolvedInstance, null);
    const gpuDevice = try GpuDevice.init(gpa, resolvedInstance);
    errdefer gpuDevice.close();
    return .{
        .vk = resolvedInstance,
        .gpuDevice = gpuDevice,
    };
}

pub fn close(self: *Self) void {
    self.gpuDevice.close();
    Vk.vkDestroyInstance(self.vk, null);
}
