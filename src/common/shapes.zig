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
        return self.getRightEdge() >= other.getLeftEdge() and
            self.getLeftEdge() <= other.getRightEdge() and
            self.getBottomEdge() >= other.getTopEdge() and
            self.getTopEdge() <= other.getBottomEdge();
        // const xOverlap = self.position.x < other.position.x + other.width and
        //     self.position.x + self.width > other.position.x;
        // const yOverlap = self.position.y < other.position.y + other.height and
        //     self.position.y + self.height > other.position.y;
        // return xOverlap and yOverlap;
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
    ///This is the bottom edge of the platform
    ///
    ///For example:
    ///If the platform is 50X50 and the vector is (300.0, -200.0)
    /// The bottom of the platform is -200.0+50.0 = -150.0
    ///
    /// This is the bottom of the rectangle
    pub fn getBottomEdge(self: Self) f32 {
        return self.position.y + self.height;
    }
    ///This is the top of the rectangle or the acual surface where the player can walk on position Y
    pub fn getTopEdge(self: Self) f32 {
        return self.position.y;
    }
    pub fn getCenter(self: Self) f32 {
        self.position.y + (self.height / 2);
    }
    ///This gets the horizontal line of the platform
    ///
    /// For example:
    ///
    /// If the vector is (200.0, 200.0) and the width is 300 then then right edge, or the width of the platform is 200+300 = 500
    ///
    /// Anything with an X-coordinate less than 500 is to the left of that edge.
    ///
    ///Anything with an X-coordinate greater than 500 has moved past the platform.
    pub fn getRightEdge(self: Self) f32 {
        return self.position.x + self.width;
    }
    ///This retuns the left side of the rectangle position X
    pub fn getLeftEdge(self: Self) f32 {
        return self.position.x;
    }
};
