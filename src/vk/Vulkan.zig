const std = @import("std");
const VkStructureType = @import("VkStructureType.zig");
const VkResult = @import("VkResult.zig");

const Self = @This();
instance: *VkInstance,
targetPhysicalDevice: *VkPhysicalDevice,
targetDeviceProperties: VkPhysicalDeviceProperties,
device: *VkDevice,

pub const VkPhysicalDevices = struct {
    devices: []*VkPhysicalDevice,
    properties: []VkPhysicalDeviceProperties,
};

pub fn init(gpa: std.mem.Allocator) !Self {
    var vkInstance: ?*VkInstance = null;
    const createInstanceRes = vkCreateInstance(
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
    errdefer vkDestroyInstance(resolvedInstance, null);
    const physicalDevices = try resolvePhysicalDevices(gpa, resolvedInstance);
    defer gpa.free(physicalDevices.devices);
    defer gpa.free(physicalDevices.properties);
    const suitableGpu = findMostSuitableGpu(physicalDevices);
    const targetDevice = suitableGpu.@"0";
    const targetDeviceProperties = suitableGpu.@"1".*;
    std.debug.print("chose target GPU: [ {s} ] vendor [ {d} ]\n", .{
        targetDeviceProperties.deviceName,
        targetDeviceProperties.vendorID,
    });
    const queueFamilyProperties = try resolveQueueFamilyProperties(gpa, targetDevice);
    defer gpa.free(queueFamilyProperties);
    const queueFamilyIdx: u32 = @intCast(if (queueFamilyProperties.len > 1) 1 else queueFamilyProperties.len - 1);
    const device = try initLogicalDevice(targetDevice, queueFamilyIdx);
    errdefer vkDestroyDevice(device, null);
    return .{
        .instance = resolvedInstance,
        .targetPhysicalDevice = targetDevice,
        .targetDeviceProperties = targetDeviceProperties,
        .device = device,
    };
}

fn initLogicalDevice(
    physicalDevice: *VkPhysicalDevice,
    queueFamilyIndex: u32,
) !*VkDevice {
    const priorities = [_]f32{1.0};
    const queueCreateInfos = [_]VkDeviceQueueCreateInfo{.{
        .sType = VkStructureType.VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
        .pNext = null,
        .flags = 0,
        .queueFamilyIndex = queueFamilyIndex,
        .queueCount = priorities.len,
        .pQueuePriorities = &priorities,
    }};
    const createInfo: VkDeviceCreateInfo = .{
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
    var device: ?*VkDevice = null;
    const createRes = vkCreateDevice(
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

fn resolveQueueFamilyProperties(gpa: std.mem.Allocator, physicalDevice: *VkPhysicalDevice) ![]VkQueueFamilyProperties {
    // todo figure out what queue family is used for in Vulkan
    var propertyCount: u32 = undefined;
    vkGetPhysicalDeviceQueueFamilyProperties(
        physicalDevice,
        &propertyCount,
        null,
    );
    std.debug.print("vkGetPhysicalDeviceQueueFamilyProperties count call returned {d}\n", .{propertyCount});
    if (propertyCount == 0) {
        return error.Todo;
    }
    const properties = try gpa.alloc(VkQueueFamilyProperties, propertyCount);
    errdefer gpa.free(properties);
    vkGetPhysicalDeviceQueueFamilyProperties(
        physicalDevice,
        &propertyCount,
        properties.ptr,
    );
    return properties;
}

fn resolvePhysicalDevices(gpa: std.mem.Allocator, vkInstance: *VkInstance) !VkPhysicalDevices {
    var pPhysicalDeviceCount: u32 = undefined;
    const devicesCountRes = vkEnumeratePhysicalDevices(
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
    const devices = try gpa.alloc(*VkPhysicalDevice, pPhysicalDeviceCount);
    errdefer gpa.free(devices);
    const devicesRes = vkEnumeratePhysicalDevices(
        vkInstance,
        &pPhysicalDeviceCount,
        devices.ptr,
    );
    if (devicesRes != VkResult.VK_SUCCESS) {
        return error.VulkanEnumerateDevices;
    }
    const deviceProperties = try gpa.alloc(VkPhysicalDeviceProperties, pPhysicalDeviceCount);
    errdefer gpa.free(deviceProperties);
    // todo this may need revisit to strictly guarantee that count is same as returned array
    for (0..pPhysicalDeviceCount) |idx| {
        const device = devices[idx];
        const properties = &deviceProperties[idx];
        vkGetPhysicalDeviceProperties(device, properties);
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

fn findMostSuitableGpu(physicalDevices: VkPhysicalDevices) struct { *VkPhysicalDevice, *VkPhysicalDeviceProperties } {
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

pub fn close(self: *const Self, _: std.mem.Allocator) void {
    vkDestroyDevice(self.device, null);
    vkDestroyInstance(self.instance, null);
    std.debug.print("vkDestroyInstance finished\n", .{});
}

pub const VkVendorId = enum(u16) {
    nvidia = 4318,
    amd = 4098,
    intel = 32902,
    other = 0,
};

const VkInstanceCreateInfo = extern struct {
    sType: i32,
    pNext: ?*const anyopaque,
    flags: u32,
    pApplicationInfo: ?*const anyopaque,
    enabledLayerCount: u32,
    ppEnabledLayerNames: ?[*]const [*:0]const u8,
    enabledExtensionCount: u32,
    ppEnabledExtensionNames: ?[*]const [*:0]const u8,
};

pub const VkPhysicalDeviceType = enum(u32) {
    VK_PHYSICAL_DEVICE_TYPE_OTHER = 0,
    VK_PHYSICAL_DEVICE_TYPE_INTEGRATED_GPU = 1,
    VK_PHYSICAL_DEVICE_TYPE_DISCRETE_GPU = 2,
    VK_PHYSICAL_DEVICE_TYPE_VIRTUAL_GPU = 3,
    VK_PHYSICAL_DEVICE_TYPE_CPU = 4,

    pub fn priority(self: VkPhysicalDeviceType) u3 {
        return switch (self) {
            .VK_PHYSICAL_DEVICE_TYPE_OTHER => 4,
            .VK_PHYSICAL_DEVICE_TYPE_INTEGRATED_GPU => 1,
            .VK_PHYSICAL_DEVICE_TYPE_DISCRETE_GPU => 0,
            .VK_PHYSICAL_DEVICE_TYPE_VIRTUAL_GPU => 2,
            .VK_PHYSICAL_DEVICE_TYPE_CPU => 3,
        };
    }
};

pub const VkBool32 = enum(u32) {
    VK_FALSE = 0,
    VK_TRUE = 1,
};

pub const VkPhysicalDeviceLimits = extern struct {
    maxImageDimension1D: u32,
    maxImageDimension2D: u32,
    maxImageDimension3D: u32,
    maxImageDimensionCube: u32,
    maxImageArrayLayers: u32,
    maxTexelBufferElements: u32,
    maxUniformBufferRange: u32,
    maxStorageBufferRange: u32,
    maxPushConstantsSize: u32,
    maxMemoryAllocationCount: u32,
    maxSamplerAllocationCount: u32,
    bufferImageGranularity: u64,
    sparseAddressSpaceSize: u64,
    maxBoundDescriptorSets: u32,
    maxPerStageDescriptorSamplers: u32,
    maxPerStageDescriptorUniformBuffers: u32,
    maxPerStageDescriptorStorageBuffers: u32,
    maxPerStageDescriptorSampledImages: u32,
    maxPerStageDescriptorStorageImages: u32,
    maxPerStageDescriptorInputAttachments: u32,
    maxPerStageResources: u32,
    maxDescriptorSetSamplers: u32,
    maxDescriptorSetUniformBuffers: u32,
    maxDescriptorSetUniformBuffersDynamic: u32,
    maxDescriptorSetStorageBuffers: u32,
    maxDescriptorSetStorageBuffersDynamic: u32,
    maxDescriptorSetSampledImages: u32,
    maxDescriptorSetStorageImages: u32,
    maxDescriptorSetInputAttachments: u32,
    maxVertexInputAttributes: u32,
    maxVertexInputBindings: u32,
    maxVertexInputAttributeOffset: u32,
    maxVertexInputBindingStride: u32,
    maxVertexOutputComponents: u32,
    maxTessellationGenerationLevel: u32,
    maxTessellationPatchSize: u32,
    maxTessellationControlPerVertexInputComponents: u32,
    maxTessellationControlPerVertexOutputComponents: u32,
    maxTessellationControlPerPatchOutputComponents: u32,
    maxTessellationControlTotalOutputComponents: u32,
    maxTessellationEvaluationInputComponents: u32,
    maxTessellationEvaluationOutputComponents: u32,
    maxGeometryShaderInvocations: u32,
    maxGeometryInputComponents: u32,
    maxGeometryOutputComponents: u32,
    maxGeometryOutputVertices: u32,
    maxGeometryTotalOutputComponents: u32,
    maxFragmentInputComponents: u32,
    maxFragmentOutputAttachments: u32,
    maxFragmentDualSrcAttachments: u32,
    maxFragmentCombinedOutputResources: u32,
    maxComputeSharedMemorySize: u32,
    maxComputeWorkGroupCount: [3]u32,
    maxComputeWorkGroupInvocations: u32,
    maxComputeWorkGroupSize: [3]u32,
    subPixelPrecisionBits: u32,
    subTexelPrecisionBits: u32,
    mipmapPrecisionBits: u32,
    maxDrawIndexedIndexValue: u32,
    maxDrawIndirectCount: u32,
    maxSamplerLodBias: f32,
    maxSamplerAnisotropy: f32,
    maxViewports: u32,
    maxViewportDimensions: [2]u32,
    viewportBoundsRange: [2]f32,
    viewportSubPixelBits: u32,
    minMemoryMapAlignment: isize,
    minTexelBufferOffsetAlignment: u64,
    minUniformBufferOffsetAlignment: u64,
    minStorageBufferOffsetAlignment: u64,
    minTexelOffset: i32,
    maxTexelOffset: u32,
    minTexelGatherOffset: i32,
    maxTexelGatherOffset: u32,
    minInterpolationOffset: f32,
    maxInterpolationOffset: f32,
    subPixelInterpolationOffsetBits: u32,
    maxFramebufferWidth: u32,
    maxFramebufferHeight: u32,
    maxFramebufferLayers: u32,
    framebufferColorSampleCounts: u32,
    framebufferDepthSampleCounts: u32,
    framebufferStencilSampleCounts: u32,
    framebufferNoAttachmentsSampleCounts: u32,
    maxColorAttachments: u32,
    sampledImageColorSampleCounts: u32,
    sampledImageIntegerSampleCounts: u32,
    sampledImageDepthSampleCounts: u32,
    sampledImageStencilSampleCounts: u32,
    storageImageSampleCounts: u32,
    maxSampleMaskWords: u32,
    timestampComputeAndGraphics: VkBool32,
    timestampPeriod: f32,
    maxClipDistances: u32,
    maxCullDistances: u32,
    maxCombinedClipAndCullDistances: u32,
    discreteQueuePriorities: u32,
    pointSizeRange: [2]f32,
    lineWidthRange: [2]f32,
    pointSizeGranularity: f32,
    lineWidthGranularity: f32,
    strictLines: VkBool32,
    standardSampleLocations: VkBool32,
    optimalBufferCopyOffsetAlignment: u64,
    optimalBufferCopyRowPitchAlignment: u64,
    nonCoherentAtomSize: u64,
};

pub const VkPhysicalDeviceSparseProperties = extern struct {
    residencyStandard2DBlockShape: VkBool32,
    residencyStandard2DMultisampleBlockShape: VkBool32,
    residencyStandard3DBlockShape: VkBool32,
    residencyAlignedMipSize: VkBool32,
    residencyNonResidentStrict: VkBool32,
};

const VK_MAX_PHYSICAL_DEVICE_NAME_SIZE = 256;
const VK_UUID_SIZE = 16;

pub const VkPhysicalDeviceProperties = extern struct {
    apiVersion: u32,
    driverVersion: u32,
    vendorID: u32,
    deviceID: u32,
    deviceType: VkPhysicalDeviceType,
    deviceName: [VK_MAX_PHYSICAL_DEVICE_NAME_SIZE]u8,
    pipelineCacheUUID: [VK_UUID_SIZE]u8,
    limits: VkPhysicalDeviceLimits,
    sparseProperties: VkPhysicalDeviceSparseProperties,

    pub fn resolveVendorId(self: VkPhysicalDeviceProperties) VkVendorId {
        return std.enums.fromInt(VkVendorId, self.vendorID) orelse .other;
    }
};

pub const VkPhysicalDeviceFeatures = extern struct {
    robustBufferAccess: VkBool32,
    fullDrawIndexUint32: VkBool32,
    imageCubeArray: VkBool32,
    independentBlend: VkBool32,
    geometryShader: VkBool32,
    tessellationShader: VkBool32,
    sampleRateShading: VkBool32,
    dualSrcBlend: VkBool32,
    logicOp: VkBool32,
    multiDrawIndirect: VkBool32,
    drawIndirectFirstInstance: VkBool32,
    depthClamp: VkBool32,
    depthBiasClamp: VkBool32,
    fillModeNonSolid: VkBool32,
    depthBounds: VkBool32,
    wideLines: VkBool32,
    largePoints: VkBool32,
    alphaToOne: VkBool32,
    multiViewport: VkBool32,
    samplerAnisotropy: VkBool32,
    textureCompressionETC2: VkBool32,
    textureCompressionASTC_LDR: VkBool32,
    textureCompressionBC: VkBool32,
    occlusionQueryPrecise: VkBool32,
    pipelineStatisticsQuery: VkBool32,
    vertexPipelineStoresAndAtomics: VkBool32,
    fragmentStoresAndAtomics: VkBool32,
    shaderTessellationAndGeometryPointSize: VkBool32,
    shaderImageGatherExtended: VkBool32,
    shaderStorageImageExtendedFormats: VkBool32,
    shaderStorageImageMultisample: VkBool32,
    shaderStorageImageReadWithoutFormat: VkBool32,
    shaderStorageImageWriteWithoutFormat: VkBool32,
    shaderUniformBufferArrayDynamicIndexing: VkBool32,
    shaderSampledImageArrayDynamicIndexing: VkBool32,
    shaderStorageBufferArrayDynamicIndexing: VkBool32,
    shaderStorageImageArrayDynamicIndexing: VkBool32,
    shaderClipDistance: VkBool32,
    shaderCullDistance: VkBool32,
    shaderFloat64: VkBool32,
    shaderInt64: VkBool32,
    shaderInt16: VkBool32,
    shaderResourceResidency: VkBool32,
    shaderResourceMinLod: VkBool32,
    sparseBinding: VkBool32,
    sparseResidencyBuffer: VkBool32,
    sparseResidencyImage2D: VkBool32,
    sparseResidencyImage3D: VkBool32,
    sparseResidency2Samples: VkBool32,
    sparseResidency4Samples: VkBool32,
    sparseResidency8Samples: VkBool32,
    sparseResidency16Samples: VkBool32,
    sparseResidencyAliased: VkBool32,
    variableMultisampleRate: VkBool32,
    inheritedQueries: VkBool32,
};

pub const VkDeviceQueueCreateInfo = extern struct {
    sType: i32,
    pNext: ?*const anyopaque,
    flags: u32,
    queueFamilyIndex: u32,
    queueCount: u32,
    pQueuePriorities: [*]const f32,
};
pub const VkDeviceCreateFlags = extern struct {};

pub const CString = [*:0]const u8;

pub const CStrings = [*]const CString;

pub const VkDeviceCreateInfo = extern struct {
    sType: i32,
    pNext: ?*const anyopaque,
    flags: u32,
    queueCreateInfoCount: u32,
    pQueueCreateInfos: [*]const VkDeviceQueueCreateInfo,
    enabledLayerCount: u32,
    ppEnabledLayerNames: ?CStrings,
    enabledExtensionCount: u32,
    ppEnabledExtensionNames: ?CStrings,
    pEnabledFeatures: ?[*]const VkPhysicalDeviceFeatures,
};

pub const VkExtent3D = extern struct {
    width: u32,
    height: u32,
    depth: u32,
};

pub const VkQueueFamilyProperties = extern struct {
    queueFlags: u32,
    queueCount: u32,
    timestampValidBits: u32,
    minImageTransferGranularity: VkExtent3D,
};

pub const VkInstance = opaque {};
pub const VkPhysicalDevice = opaque {};
pub const VkDevice = opaque {};

extern "vulkan" fn vkCreateInstance(
    info: *const VkInstanceCreateInfo,
    allocator: ?*const anyopaque,
    instance: *?*VkInstance,
) callconv(.c) VkResult.Type;

extern "vulkan" fn vkDestroyInstance(
    instance: *const VkInstance,
    allocator: ?*const anyopaque,
) callconv(.c) void;

extern "vulkan" fn vkEnumeratePhysicalDevices(
    instance: *const VkInstance,
    pPhysicalDeviceCount: *u32,
    pPhysicalDevices: ?[*]*VkPhysicalDevice,
) callconv(.c) VkResult.Type;

extern "vulkan" fn vkGetPhysicalDeviceProperties(
    physicalDevice: *VkPhysicalDevice,
    pProperties: *VkPhysicalDeviceProperties,
) callconv(.c) void;

extern "vulkan" fn vkCreateDevice(
    physicalDevice: *VkPhysicalDevice,
    pCreateInfo: *const VkDeviceCreateInfo,
    allocator: ?*const anyopaque,
    pDevice: *?*VkDevice,
) callconv(.c) VkResult.Type;

extern "vulkan" fn vkDestroyDevice(
    device: *VkDevice,
    allocator: ?*const anyopaque,
) callconv(.c) void;

extern "vulkan" fn vkGetPhysicalDeviceQueueFamilyProperties(
    physicalDevice: *VkPhysicalDevice,
    pQueueFamilyPropertyCount: *u32,
    pQueueFamilyProperties: ?[*]VkQueueFamilyProperties,
) callconv(.c) void;
