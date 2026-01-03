const std = @import("std");
const rayLib = @import("raylib");
const PLATFORM_TYPES = @import("../types.zig").PLATFORM_TYPES;
const GAME_OBJECT_TYPES = @import("../types.zig").GAME_OBJECT_TYPES;
const Rectangle = @import("../common/shapes.zig").Rectangle;

pub const Platform = struct {
    const Self = @This();
    platformType: PLATFORM_TYPES,
    rect: Rectangle,
    pub fn init(
        platformType: PLATFORM_TYPES,
        width: f32,
        height: f32,
        position: rayLib.Vector2,
        color: rayLib.Color,
    ) Self {
        return Self{
            .platformType = platformType,
            .rect = Rectangle.init(
                GAME_OBJECT_TYPES{ .PLATFORM = platformType },
                width,
                height,
                position,
                color,
            ),
        };
    }
    pub fn draw(self: Self) void {
        self.rect.draw();
    }
    pub fn getRect(self: Self) Rectangle {
        return self.rect;
    }
};
