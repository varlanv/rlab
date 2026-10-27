const std = @import("std");
const lang = @import("../lang.zig");
const VkStructureType = @import("VkStructureType.zig");
const VkResult = @import("VkResult.zig");

const Self = @This();
const VK_MAX_PHYSICAL_DEVICE_NAME_SIZE = 256;
const VK_UUID_SIZE = 16;

pub const VkQueueFlagBits = enum(u32) {
    VK_QUEUE_GRAPHICS_BIT = 0x00000001,
    VK_QUEUE_COMPUTE_BIT = 0x00000002,
    VK_QUEUE_TRANSFER_BIT = 0x00000004,
    // Provided by VK_VERSION_1_1
    VK_QUEUE_PROTECTED_BIT = 0x00000010,
};

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

pub const VkPhysicalDevices = struct {
    devices: []*VkPhysicalDevice,
    properties: []VkPhysicalDeviceProperties,
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

pub const VkDeviceCreateInfo = extern struct {
    sType: i32,
    pNext: ?*const anyopaque,
    flags: u32,
    queueCreateInfoCount: u32,
    pQueueCreateInfos: [*]const VkDeviceQueueCreateInfo,
    enabledLayerCount: u32,
    ppEnabledLayerNames: ?lang.CStrings,
    enabledExtensionCount: u32,
    ppEnabledExtensionNames: ?lang.CStrings,
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

pub const VkCommandPoolCreateInfo = extern struct {
    sType: i32,
    pNext: ?*const anyopaque,
    flags: u32,
    queueFamilyIndex: u32,
};

pub const VkInstance = opaque {
    pub extern "vulkan" fn vkEnumeratePhysicalDevices(
        self: *const VkInstance,
        pPhysicalDeviceCount: *u32,
        pPhysicalDevices: ?[*]*VkPhysicalDevice,
    ) callconv(.c) VkResult.Type;

    pub extern "vulkan" fn vkDestroyInstance(
        self: *const VkInstance,
        allocator: ?*const anyopaque,
    ) callconv(.c) void;

    pub extern "vulkan" fn vkCreateInstance(
        info: *const VkInstanceCreateInfo,
        allocator: ?*const anyopaque,
        instance: *?*VkInstance,
    ) callconv(.c) VkResult.Type;
};

pub const VkPhysicalDevice = opaque {
    pub extern "vulkan" fn vkGetPhysicalDeviceProperties(
        self: *VkPhysicalDevice,
        pProperties: *VkPhysicalDeviceProperties,
    ) callconv(.c) void;

    pub extern "vulkan" fn vkGetPhysicalDeviceQueueFamilyProperties(
        self: *VkPhysicalDevice,
        pQueueFamilyPropertyCount: *u32,
        pQueueFamilyProperties: ?[*]VkQueueFamilyProperties,
    ) callconv(.c) void;

    pub extern "vulkan" fn vkCreateDevice(
        self: *VkPhysicalDevice,
        pCreateInfo: *const VkDeviceCreateInfo,
        allocator: ?*const anyopaque,
        pDevice: *?*VkDevice,
    ) callconv(.c) VkResult.Type;
};

pub const VkCommandPool = opaque {};

pub const VkQueue = opaque {
    pub extern "vulkan" fn vkQueueWaitIdle(self: *VkQueue) callconv(.c) VkResult.Type;
};

pub const VkDevice = opaque {
    pub extern "vulkan" fn vkGetDeviceQueue(
        self: *VkDevice,
        queueFamilyIndex: u32,
        queueIndex: u32,
        pQueue: **VkQueue,
    ) callconv(.c) void;

    pub extern "vulkan" fn vkCreateCommandPool(
        self: *VkDevice,
        pCreateInfo: *const VkCommandPoolCreateInfo,
        pAllocator: ?*const anyopaque,
        pCommandPool: *?*VkCommandPool,
    ) callconv(.c) VkResult.Type;

    pub extern "vulkan" fn vkDeviceWaitIdle(
        self: *VkDevice,
    ) callconv(.c) VkResult.Type;

    pub extern "vulkan" fn vkDestroyCommandPool(
        self: *VkDevice,
        commandPool: *VkCommandPool,
        allocator: ?*const anyopaque,
    ) callconv(.c) void;

    pub extern "vulkan" fn vkDestroyDevice(
        self: *VkDevice,
        allocator: ?*const anyopaque,
    ) callconv(.c) void;
};
