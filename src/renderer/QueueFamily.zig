const std = @import("std");
const Vk = @import("../vk/Vulkan.zig");

const Self = @This();
targetFamilyIndex: u32,

pub fn init(gpa: std.mem.Allocator, physicalDevice: *Vk.VkPhysicalDevice) !Self {
    const queueFamilyProperties = try resolveQueueFamilyProperties(gpa, physicalDevice);
    std.debug.print("resolved queue families: {any}", .{queueFamilyProperties});
    defer gpa.free(queueFamilyProperties);
    const queueFamilyIdx: u32 = @intCast(if (queueFamilyProperties.len > 1) 1 else queueFamilyProperties.len - 1);
    std.debug.print("picking queue family index [ {d} ]", .{queueFamilyIdx});
    return .{
        .targetFamilyIndex = queueFamilyIdx,
    };
}

fn resolveQueueFamilyProperties(gpa: std.mem.Allocator, physicalDevice: *Vk.VkPhysicalDevice) ![]Vk.VkQueueFamilyProperties {
    // todo figure out what queue family is used for in Vulkan; is is common concept e.g. in something like OpenGL ?
    var propertyCount: u32 = undefined;
    Vk.vkGetPhysicalDeviceQueueFamilyProperties(
        physicalDevice,
        &propertyCount,
        null,
    );
    std.debug.print("vkGetPhysicalDeviceQueueFamilyProperties count call returned {d}\n", .{propertyCount});
    if (propertyCount == 0) {
        return error.Todo;
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
