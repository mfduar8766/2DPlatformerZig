const std = @import("std");
const PLATFORM_TYPES = @import("../types.zig").PLATFORM_TYPES;
const ENEMY_TYPES = @import("../types.zig").ENEMY_TYPES;

pub const GameObjects = struct {
    const Self = @This();
    allocator: std.mem.Allocator,
    platformTypes: std.AutoHashMap(u8, PLATFORM_TYPES),
    enemyTypes: std.AutoHashMap(u8, ENEMY_TYPES),

    pub fn init(allocator: std.mem.Allocator) !Self {
        return .{
            .allocator = allocator,
            .platformTypes = std.AutoHashMap(u8, PLATFORM_TYPES).init(allocator),
            .enemyTypes = std.AutoHashMap(u8, ENEMY_TYPES).init(allocator),
        };
    }
    pub fn deinit(self: *Self) void {
        self.platformTypes.deinit();
        self.enemyTypes.deinit();
    }
};
