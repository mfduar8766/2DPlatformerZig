const std = @import("std");
const Rectangle = @import("../common/shapes.zig").Rectangle;
const GAME_OBJECT_TYPES = @import("../types.zig").GAME_OBJECT_TYPES;
const rayLib = @import("raylib");
const ENEMY_TYPES = @import("../types.zig").ENEMY_TYPES;

pub const Enemy = struct {
    const Self = @This();
    allocator: std.mem.Allocator,
    rect: Rectangle,
    isDynamic: bool = false,

    pub fn init(allocator: std.mem.Allocator, enemyType: ENEMY_TYPES, position: rayLib.Vector2, isDynamic: ?bool) !*Self {
        const enemyPtr = try allocator.create(Self);
        enemyPtr.* = Self{
            .allocator = allocator,
            .rect = Rectangle.init(
                GAME_OBJECT_TYPES{ .ENEMY = enemyType },
                32.0,
                32.0,
                position,
                .red,
            ),
            .isDynamic = if (isDynamic.?) isDynamic.? else false,
        };
        return enemyPtr;
    }
    pub fn draw(self: Self) void {
        self.rect.draw();
    }
    pub fn deinit(self: *Self) void {
        self.allocator.destroy(self);
    }
};
