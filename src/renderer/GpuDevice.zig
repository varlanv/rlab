const std = @import("std");
const QueueFamily = @import("QueueFamily.zig");
const VkStructureType = @import("../vk/VkStructureType.zig");
const VkResult = @import("../vk/VkResult.zig");
const Vk = @import("../vk/Vulkan.zig");

const Self = @This();
logicalDevice: *Vk.VkDevice,
physicalDevice: *Vk.VkPhysicalDevice,
physicalDeviceProperties: Vk.VkPhysicalDeviceProperties,
queueFamily: QueueFamily,
queues: []*Vk.VkQueue,
commandPool: *Vk.VkCommandPool,
commandBuffers: []*Vk.VkCommandBuffer,

pub fn init(
    gpa: std.mem.Allocator,
    _: std.Io,
    vkInstance: *Vk.VkInstance,
) !Self {
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
    const logicalDevice = try initLogicalDevice(
        gpa,
        targetDevice,
        &queueFamily,
    );
    errdefer logicalDevice.vkDestroyDevice(null);
    const queues = try initQueues(gpa, logicalDevice, queueFamily);
    errdefer gpa.free(queues);
    const commandPool = try initCommandPool(logicalDevice, queueFamily);
    errdefer logicalDevice.vkDestroyCommandPool(commandPool, null);
    const commandBuffers = try initCommandBuffers(gpa, logicalDevice, commandPool);
    errdefer gpa.free(commandBuffers);
    return .{
        .physicalDevice = targetDevice,
        .physicalDeviceProperties = targetDeviceProperties,
        .logicalDevice = logicalDevice,
        .queueFamily = queueFamily,
        .queues = queues,
        .commandPool = commandPool,
        .commandBuffers = commandBuffers,
    };
}

pub fn close(self: *Self, gpa: std.mem.Allocator) void {
    gpa.free(self.queues);
    gpa.free(self.commandBuffers);
    self.logicalDevice.vkDestroyCommandPool(self.commandPool, null);
    self.logicalDevice.vkDestroyDevice(null);
}

fn resolvePhysicalDevices(gpa: std.mem.Allocator, vkInstance: *Vk.VkInstance) !Vk.VkPhysicalDevices {
    var pPhysicalDeviceCount: u32 = undefined;
    const devicesCountRes = vkInstance.vkEnumeratePhysicalDevices(
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
    const devicesRes = vkInstance.vkEnumeratePhysicalDevices(
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
        device.vkGetPhysicalDeviceProperties(properties);
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
    gpa: std.mem.Allocator,
    physicalDevice: *Vk.VkPhysicalDevice,
    queueFamily: *const QueueFamily,
) !*Vk.VkDevice {
    const queueCount = queueFamily.targetFamily.queueCount;
    const priorities = try gpa.alloc(f32, queueCount);
    defer gpa.free(priorities);
    for (0..queueCount) |idx| {
        priorities[idx] = 1.0;
    }
    const queueCreateInfos = [_]Vk.VkDeviceQueueCreateInfo{.{
        .sType = VkStructureType.VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
        .pNext = null,
        .flags = 0,
        .queueFamilyIndex = queueFamily.targetFamilyIndex,
        .queueCount = queueCount,
        .pQueuePriorities = priorities.ptr,
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
    const createRes = physicalDevice.vkCreateDevice(
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

fn initQueues(
    gpa: std.mem.Allocator,
    logicalDevice: *Vk.VkDevice,
    queueFamily: QueueFamily,
) ![]*Vk.VkQueue {
    const queueCount = queueFamily.targetFamily.queueCount;
    const queues = try gpa.alloc(*Vk.VkQueue, queueCount);
    errdefer gpa.free(queues);
    for (0..queueCount) |idx| {
        logicalDevice.vkGetDeviceQueue(
            queueFamily.targetFamilyIndex,
            @intCast(idx),
            &queues[idx],
        );
    }
    return queues;
}

fn initCommandPool(
    logicalDevice: *Vk.VkDevice,
    queueFamily: QueueFamily,
) !*Vk.VkCommandPool {
    var pool: ?*Vk.VkCommandPool = null;
    const res = logicalDevice.vkCreateCommandPool(
        &.{
            .sType = VkStructureType.VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO,
            .pNext = null,
            .flags = 0, //todo check flags
            .queueFamilyIndex = queueFamily.targetFamilyIndex,
        },
        null,
        &pool,
    );
    if (res != VkResult.VK_SUCCESS) {
        return error.CommandBufferCreate;
    }
    return pool orelse return error.CommandBufferCreate;
}

fn initCommandBuffers(gpa: std.mem.Allocator, logicalDevice: *Vk.VkDevice, commandPool: *Vk.VkCommandPool) ![]*Vk.VkCommandBuffer {
    const commandBufferCount = 1;
    const commandBuffers = try gpa.alloc(*Vk.VkCommandBuffer, commandBufferCount);
    errdefer gpa.free(commandBuffers);
    // todo - figure out is sync needed here based on doc: "Host access to pAllocateInfo -> commandPool must be externally synchronized"
    const allocateInfo: Vk.VkCommandBufferAllocateInfo = .{
        .sType = VkStructureType.VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
        .pNext = null,
        .commandPool = commandPool,
        .level = Vk.VkCommandBufferLevel.VK_COMMAND_BUFFER_LEVEL_PRIMARY,
        .commandBufferCount = commandBufferCount,
    };
    const res = logicalDevice.vkAllocateCommandBuffers(
        &allocateInfo,
        commandBuffers.ptr,
    );
    if (res != VkResult.VK_SUCCESS) {
        return error.AllocateCommandBuffers;
    }
    return commandBuffers;
}
