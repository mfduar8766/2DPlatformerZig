const std = @import("std");
const Rectangle = @import("../common/shapes.zig").Rectangle;
const GAME_OBJECT_TYPES = @import("../types.zigj").GAME_OBJECT_TYPES;
const rayLib = @import("raylib");

pub const Enemy = struct {
    const Self = @This();
    allocator: std.mem.Allocator,
    rect: Rectangle,

    pub fn init(allocator: std.mem.Allocator) !*Self {
        const enemyPtr = try allocator.create(Self);
        enemyPtr.* = Self{
            .allocator = allocator,
            .rect = Rectangle.init(
                .{ .ENEMY = .LOW },
                50,
                50.0,
                rayLib.Vector2.init(0.0, 1300.0),
                .black,
            ),
        };
        return enemyPtr;
    }
    pub fn deinit(self: *Self) void {
        self.allocator.destroy(self);
    }
};
