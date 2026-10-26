const std = @import("std");
const Vk = @import("../vk/Vulkan.zig");

const Self = @This();
targetFamilyIndex: u32,

pub fn init(gpa: std.mem.Allocator, physicalDevice: *Vk.VkPhysicalDevice) !Self {
    const queueFamilyProperties = try resolveQueueFamilyProperties(gpa, physicalDevice);
    std.debug.print("resolved queue families: {any}\n", .{queueFamilyProperties});
    defer gpa.free(queueFamilyProperties);
    var targetFamilyIndex: u32 = 0;
    for (queueFamilyProperties, 0..) |properties, idx| {
        if ((properties.queueFlags & @backingInt(Vk.VkQueueFlagBits.VK_QUEUE_GRAPHICS_BIT)) != 0) {
            std.debug.print("found graphics queue family at index [ {d} ]\n", .{targetFamilyIndex});
            targetFamilyIndex = @intCast(idx);
            break;
        }
    }
    std.debug.print("picking queue family index [ {d} ]\n", .{targetFamilyIndex});
    return .{
        .targetFamilyIndex = targetFamilyIndex,
    };
}

fn resolveQueueFamilyProperties(gpa: std.mem.Allocator, physicalDevice: *Vk.VkPhysicalDevice) ![]Vk.VkQueueFamilyProperties {
    var propertyCount: u32 = undefined;
    Vk.vkGetPhysicalDeviceQueueFamilyProperties(
        physicalDevice,
        &propertyCount,
        null,
    );
    std.debug.print("vkGetPhysicalDeviceQueueFamilyProperties count call returned {d}\n", .{propertyCount});
    if (propertyCount == 0) {
        return error.QueueFamilyInit;
    }
    const properties = try gpa.alloc(Vk.VkQueueFamilyProperties, propertyCount);
    errdefer gpa.free(properties);
    Vk.vkGetPhysicalDeviceQueueFamilyProperties(
        physicalDevice,
        &propertyCount,
        properties.ptr,
    );
    return properties;
}
