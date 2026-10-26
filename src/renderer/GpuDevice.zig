const std = @import("std");
const QueueFamily = @import("QueueFamily.zig");
const VkStructureType = @import("../vk/VkStructureType.zig");
const VkResult = @import("../vk/VkResult.zig");
const Vk = @import("../vk/Vulkan.zig");

const Self = @This();
logicalDevice: *Vk.VkDevice,
physicalDevice: *Vk.VkPhysicalDevice,
physicalDeviceProperties: Vk.VkPhysicalDeviceProperties,

pub fn init(gpa: std.mem.Allocator, vkInstance: *Vk.VkInstance) !Self {
    const physicalDevices = try resolvePhysicalDevices(gpa, vkInstance);
    defer gpa.free(physicalDevices.devices);
    defer gpa.free(physicalDevices.properties);
    const suitableGpu = findMostSuitableGpu(physicalDevices);
    const targetDevice = suitableGpu.@"0";
    const targetDeviceProperties = suitableGpu.@"1".*;
    std.debug.print("chose target GPU: [ {s} ] vendor [ {d} ]\n", .{
        targetDeviceProperties.deviceName,
        targetDeviceProperties.vendorID,
    });
    const queueFamily = try QueueFamily.init(gpa, targetDevice);
    const logicalDevice = try initLogicalDevice(targetDevice, queueFamily.targetFamilyIndex);
    errdefer Vk.vkDestroyDevice(logicalDevice, null);
    return .{
        .physicalDevice = targetDevice,
        .physicalDeviceProperties = targetDeviceProperties,
        .logicalDevice = logicalDevice,
    };
}

pub fn close(self: *Self) void {
    Vk.vkDestroyDevice(self.logicalDevice, null);
}

fn resolvePhysicalDevices(gpa: std.mem.Allocator, vkInstance: *Vk.VkInstance) !Vk.VkPhysicalDevices {
    var pPhysicalDeviceCount: u32 = undefined;
    const devicesCountRes = Vk.vkEnumeratePhysicalDevices(
        vkInstance,
        &pPhysicalDeviceCount,
        null,
    );
    std.debug.print("vkEnumeratePhysicalDevices count result -> {d}\n", .{devicesCountRes});
    if (devicesCountRes != VkResult.VK_SUCCESS) {
        return error.VulkanEnumerateDevices;
    } else if (pPhysicalDeviceCount == 0) {
        return error.NoVulkanDevices;
    }
    std.debug.print("pPhysicalDeviceCount -> {d}\n", .{pPhysicalDeviceCount});
    const devices = try gpa.alloc(*Vk.VkPhysicalDevice, pPhysicalDeviceCount);
    errdefer gpa.free(devices);
    const devicesRes = Vk.vkEnumeratePhysicalDevices(
        vkInstance,
        &pPhysicalDeviceCount,
        devices.ptr,
    );
    if (devicesRes != VkResult.VK_SUCCESS) {
        return error.VulkanEnumerateDevices;
    }
    const deviceProperties = try gpa.alloc(Vk.VkPhysicalDeviceProperties, pPhysicalDeviceCount);
    errdefer gpa.free(deviceProperties);
    // todo this may need revisit to strictly guarantee that count is same as returned array
    for (0..pPhysicalDeviceCount) |idx| {
        const device = devices[idx];
        const properties = &deviceProperties[idx];
        Vk.vkGetPhysicalDeviceProperties(device, properties);
        std.debug.print("vkGetPhysicalDeviceProperties loaded device [ {s} ] vendor [ {d} ]\n", .{
            properties.deviceName,
            properties.vendorID,
        });
    }
    return .{
        .devices = devices,
        .properties = deviceProperties,
    };
}

fn findMostSuitableGpu(physicalDevices: Vk.VkPhysicalDevices) struct { *Vk.VkPhysicalDevice, *Vk.VkPhysicalDeviceProperties } {
    std.debug.assert(physicalDevices.properties.len > 0);
    std.debug.assert(physicalDevices.properties.len == physicalDevices.devices.len);
    var resProperties = &physicalDevices.properties[0];
    var resDevice = physicalDevices.devices[0];
    // todo this needs more strict implementation
    for (1..physicalDevices.properties.len) |idx| {
        const properties = physicalDevices.properties[idx];
        if (properties.deviceType.priority() < resProperties.deviceType.priority()) {
            resDevice = physicalDevices.devices[idx];
            resProperties = &physicalDevices.properties[idx];
        }
    }
    return .{ resDevice, resProperties };
}

fn initLogicalDevice(
    physicalDevice: *Vk.VkPhysicalDevice,
    queueFamilyIndex: u32,
) !*Vk.VkDevice {
    const priorities = [_]f32{1.0};
    const queueCreateInfos = [_]Vk.VkDeviceQueueCreateInfo{.{
        .sType = VkStructureType.VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
        .pNext = null,
        .flags = 0,
        .queueFamilyIndex = queueFamilyIndex,
        .queueCount = priorities.len,
        .pQueuePriorities = &priorities,
    }};
    const createInfo: Vk.VkDeviceCreateInfo = .{
        .sType = VkStructureType.VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
        .pNext = null,
        .flags = 0,
        .queueCreateInfoCount = 1,
        .pQueueCreateInfos = &queueCreateInfos,
        .enabledLayerCount = 0,
        .ppEnabledLayerNames = null,
        .enabledExtensionCount = 0,
        .ppEnabledExtensionNames = null,
        .pEnabledFeatures = null,
    };
    var device: ?*Vk.VkDevice = null;
    const createRes = Vk.vkCreateDevice(
        physicalDevice,
        &createInfo,
        null,
        &device,
    );
    std.debug.print("vkCreateDevice result -> {d}\n", .{createRes});
    if (createRes != VkResult.VK_SUCCESS) {
        return error.CreateVkDevice;
    }
    return device orelse return error.CreateVkDevice;
}
