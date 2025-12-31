const rayLib = @import("raylib");
const GAME_OBJECT_TYPES = @import("../types.zig").GAME_OBJECT_TYPES;
const POSITION = @import("../types.zig").POSITION;

pub const Rectangle = struct {
    const Self = @This();
    color: rayLib.Color,
    objectType: GAME_OBJECT_TYPES = GAME_OBJECT_TYPES{ .PLAYER = 0 },
    rect: rayLib.Rectangle,

    pub fn init(
        objectType: GAME_OBJECT_TYPES,
        width: f32,
        height: f32,
        position: rayLib.Vector2,
        color: rayLib.Color,
    ) Self {
        return .{
            .color = color,
            .objectType = objectType,
            .rect = rayLib.Rectangle.init(position.x, position.y, width, height),
        };
    }
    pub fn intersects(self: Self, other: Rectangle) bool {
        return self.getRightEdge() >= other.getLeftEdge() and
            self.getLeftEdge() <= other.getRightEdge() and
            self.getBottomEdge() >= other.getTopEdge() and
            self.getTopEdge() <= other.getBottomEdge();
    }
    pub fn draw(self: Self) void {
        rayLib.drawRectangle(
            @as(i32, @intFromFloat(self.rect.x)),
            @as(i32, @intFromFloat(self.rect.y)),
            @as(i32, @intFromFloat(self.rect.width)),
            @as(i32, @intFromFloat(self.rect.height)),
            self.color,
        );
    }
    pub fn getHeight(self: Self) f32 {
        return self.rect.height;
    }
    pub fn getWidth(self: Self) f32 {
        return self.rect.width;
    }
    pub fn getPosition(self: Self) rayLib.Vector2 {
        return rayLib.Vector2.init(self.rect.x, self.rect.y);
    }
    pub fn setPosition(self: *Self, pos: POSITION, value: f32) void {
        if (pos == .X) {
            self.rect.x = value;
        } else {
            self.rect.y = value;
        }
    }
    pub fn addPosition(self: *Self, pos: POSITION, value: f32) void {
        if (pos == .X) {
            self.rect.x += value;
        } else {
            self.rect.y += value;
        }
    }
    pub fn subtractPosition(self: *Self, pos: POSITION, value: f32) void {
        if (pos == .X) {
            self.rect.x -= value;
        } else {
            self.rect.y -= value;
        }
    }
    pub fn setWidth(self: *Self, value: f32) void {
        self.rect.width = value;
    }
    pub fn setHeight(self: *Self, value: f32) void {
        self.rect.height = value;
    }
    ///This is the bottom edge of the platform
    ///
    ///For example:
    ///If the platform is 50X50 and the vector is (300.0, -200.0)
    /// The bottom of the platform is -200.0+50.0 = -150.0
    ///
    /// This is the bottom of the rectangle
    pub fn getBottomEdge(self: Self) f32 {
        return self.rect.y + self.rect.height;
    }
    ///This is the top of the rectangle or the acual surface where the player can walk on position Y
    pub fn getTopEdge(self: Self) f32 {
        return self.rect.y;
    }
    pub fn getCenter(self: Self) f32 {
        self.rect.y + (self.rect.height / 2);
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
        return self.rect.x + self.rect.width;
    }
    ///This retuns the left side of the rectangle position X
    pub fn getLeftEdge(self: Self) f32 {
        return self.rect.x;
    }
};

pub fn CreateRectangle(position: rayLib.Vector2, width: f32, height: f32, color: rayLib.Color) type {
    return struct {
        const Self = @This();
        rect: rayLib.Rectangle,
        color: rayLib.Color,
        objectType: GAME_OBJECT_TYPES,

        pub fn init() Self {
            return .{
                .color = color,
                .rect = rayLib.Rectangle.init(position.x, position.y, width, height),
            };
        }
        pub fn intersects(self: Self, other: Rectangle) bool {
            return self.getRightEdge() >= other.getLeftEdge() and
                self.getLeftEdge() <= other.getRightEdge() and
                self.getBottomEdge() >= other.getTopEdge() and
                self.getTopEdge() <= other.getBottomEdge();
        }
        pub fn draw(self: Self) void {
            rayLib.drawRectangle(
                @as(i32, @intFromFloat(self.rect.x)),
                @as(i32, @intFromFloat(self.rect.y)),
                @as(i32, @intFromFloat(self.rect.width)),
                @as(i32, @intFromFloat(self.rect.height)),
                self.color,
            );
        }
        pub fn getHeight(self: Self) f32 {
            return self.rect.height;
        }
        pub fn getWidth(self: Self) f32 {
            return self.rect.width;
        }
        pub fn getPosition(self: Self) rayLib.Vector2 {
            return rayLib.Vector2.init(self.rect.x, self.rect.y);
        }
        pub fn setPosition(self: *Self, pos: POSITION, value: f32) void {
            if (pos == .X) {
                self.rect.x = value;
            } else {
                self.rect.y = value;
            }
        }
        pub fn addPosition(self: *Self, pos: POSITION, value: f32) void {
            if (pos == .X) {
                self.rect.x += value;
            } else {
                self.rect.y += value;
            }
        }
        pub fn subtractPosition(self: *Self, pos: POSITION, value: f32) void {
            if (pos == .X) {
                self.rect.x -= value;
            } else {
                self.rect.y -= value;
            }
        }
        pub fn setWidth(self: *Self, value: f32) void {
            self.rect.width = value;
        }
        pub fn setHeight(self: *Self, value: f32) void {
            self.rect.height = value;
        }
        ///This is the bottom edge of the platform
        ///
        ///For example:
        ///If the platform is 50X50 and the vector is (300.0, -200.0)
        /// The bottom of the platform is -200.0+50.0 = -150.0
        ///
        /// This is the bottom of the rectangle
        pub fn getBottomEdge(self: Self) f32 {
            return self.rect.y + self.rect.height;
        }
        ///This is the top of the rectangle or the acual surface where the player can walk on position Y
        pub fn getTopEdge(self: Self) f32 {
            return self.rect.y;
        }
        pub fn getCenter(self: Self) f32 {
            self.rect.y + (self.rect.height / 2);
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
            return self.rect.x + self.rect.width;
        }
        ///This retuns the left side of the rectangle position X
        pub fn getLeftEdge(self: Self) f32 {
            return self.rect.x;
        }
    };
}
