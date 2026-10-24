const std = @import("std");

pub const InitialIo = struct {
    const Self = @This();
    io: std.Io,
    coreCount: usize,
    pool: ?*std.Io.Threaded,

    pub fn init(defaultIo: std.Io, gpa: std.mem.Allocator) !InitialIo {
        const cpu_count = try std.Thread.getCpuCount();
        if (cpu_count == 0) {
            return .{
                .io = defaultIo,
                .coreCount = cpu_count,
                .pool = null,
            };
        }
        var pool = try gpa.create(std.Io.Threaded);
        pool.* = .init(
            gpa,
            .{
                .async_limit = .limited(cpu_count),
                .concurrent_limit = .limited(cpu_count),
            },
        );
        return .{
            .io = pool.io(),
            .coreCount = cpu_count,
            .pool = pool,
        };
    }


    pub fn close(self: Self, gpa: std.mem.Allocator) void {
        if (self.pool) |pool| {
            pool.deinit();
            gpa.destroy(pool);
        }
    }
};

