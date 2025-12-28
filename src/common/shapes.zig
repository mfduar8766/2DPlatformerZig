const rayLib = @import("raylib");
const GAME_OBJECT_TYPES = @import("../types.zig").GAME_OBJECT_TYPES;

pub const Rectangle = struct {
    const Self = @This();
    width: f32,
    height: f32,
    position: rayLib.Vector2,
    color: rayLib.Color,
    objectType: GAME_OBJECT_TYPES = GAME_OBJECT_TYPES{ .PLAYER = 0 },

    pub fn init(
        objectType: GAME_OBJECT_TYPES,
        width: f32,
        height: f32,
        position: rayLib.Vector2,
        color: rayLib.Color,
    ) Self {
        return .{
            .height = height,
            .width = width,
            .position = position,
            .color = color,
            .objectType = objectType,
        };
    }
    pub fn intersects(self: Self, other: Rectangle) bool {
        const xOverlap = self.position.x < other.position.x + other.width and
            self.position.x + self.width > other.position.x;
        const yOverlap = self.position.y < other.position.y + other.height and
            self.position.y + self.height > other.position.y;
        return xOverlap and yOverlap;
    }
    pub fn draw(self: Self) void {
        rayLib.drawRectangle(
            @as(i32, @intFromFloat(self.position.x)),
            @as(i32, @intFromFloat(self.position.y)),
            @as(i32, @intFromFloat(self.width)),
            @as(i32, @intFromFloat(self.height)),
            self.color,
        );
    }
};
