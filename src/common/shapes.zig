const std = @import("std");
const rayLib = @import("raylib");
const GAME_OBJECT_TYPES = @import("../types.zig").GAME_OBJECT_TYPES;
const POSITION = @import("../types.zig").POSITION;
const PLATFORM = @import("../types.zig").PLATFORM_TYPES;
const ObjectProperties = @import("./objectProperties.zig").ObjectProperties;
const DamageComponent = @import("./objectProperties.zig").DamageComponent;

pub const Rectangle = struct {
    const Self = @This();
    color: rayLib.Color,
    objectType: GAME_OBJECT_TYPES = GAME_OBJECT_TYPES{ .PLAYER = 0 },
    rect: rayLib.Rectangle,
    objectProperties: ObjectProperties = undefined,

    pub fn init(
        objectType: GAME_OBJECT_TYPES,
        width: f32,
        height: f32,
        position: rayLib.Vector2,
        color: rayLib.Color,
    ) Self {
        var self = Self{
            .color = color,
            .objectType = objectType,
            .rect = rayLib.Rectangle.init(position.x, position.y, width, height),
        };
        self.setDamageAmount();
        return self;
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
    ///self.rect.height
    pub fn getHeight(self: Self) f32 {
        return self.rect.height;
    }
    ///self.rect.width
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
    ///This is the bottom edge of the rectangle
    ///
    ///For example:
    ///If the rectangle is 50X50 and the vector is (300.0, -200.0)
    /// The bottom of the rectangle is -200.0+50.0 = -150.0
    ///
    /// This is the bottom of the rectangle
    ///
    /// self.rect.y + self.rect.height
    pub fn getBottomEdge(self: Self) f32 {
        return self.rect.y + self.rect.height;
    }
    ///This is the top of the rectangle or the acual surface where the player can walk on position Y
    ///
    ///self.rect.y
    pub fn getTopEdge(self: Self) f32 {
        return self.rect.y;
    }
    ///self.getPosition().y + (self.rect.height / 2)
    pub fn getCenterY(self: Self) f32 {
        return self.getPosition().y + (self.rect.height / 2);
    }
    ///self.getPosition().x + (self.getWidth() / 2.0)
    pub fn getCenterX(self: Self) f32 {
        return self.getPosition().x + (self.getWidth() / 2.0);
    }
    ///This gets the horizontal line of the rectangle
    ///
    /// For example:
    ///
    /// If the vector is (200.0, 200.0) and the width is 300 then then right edge, or the width of the rectangle is 200+300 = 500
    ///
    /// Anything with an X-coordinate less than 500 is to the left of that edge.
    ///
    ///Anything with an X-coordinate greater than 500 has moved past the rectangle.
    ///
    /// self.rect.x + self.rect.width
    pub fn getRightEdge(self: Self) f32 {
        return self.rect.x + self.rect.width;
    }
    ///This retuns the left side of the rectangle position X
    ///
    /// self.rect.x
    pub fn getLeftEdge(self: Self) f32 {
        return self.rect.x;
    }
    ///Check if the rect is horizontally overlapping the platform
    pub fn isWithinHorizontalBounds(self: Self, rect: *Rectangle) bool {
        return self.rect.getRightEdge() > rect.getLeftEdge() and
            self.getLeftEdge() < rect.getRightEdge();
    }
    pub fn isOffTheEdge(self: Self, rect: *Rectangle) bool {
        return self.getRightEdge() < rect.getPosition().x or self.rect.getPosition().x > rect.getRightEdge();
    }
    pub fn isOnSurface(self: Self, rect: *Rectangle) bool {
        // Rectangle.rect.getPosition().y - self.player.rect.height == self.player.rect.getPosition().y
        // 1. Check Horizontal (Aligned)
        if (!self.isWithinHorizontalBounds(rect)) return false;

        // 2. Check Vertical (Touching Surface)
        const pBottom = self.player.rect.getBottomEdge();
        const platTop = rect.getTopEdge();

        // Check if rect's feet are within 1 pixel of the platform top
        const touchingSurface = @abs(pBottom - platTop) < 1.0;
        return touchingSurface;
    }
    ///self.rect.getRightEdge() >= rect.getLeftEdge();
    pub fn collidedWithLeftEdge(self: Self, rect: *Rectangle) bool {
        return self.getRightEdge() >= rect.getLeftEdge();
    }
    ///self.rect.getLeftEdge() <= rect.getRightEdge();
    pub fn collidedWithRightEdge(self: Self, rect: *Rectangle) bool {
        return self.getLeftEdge() <= rect.getRightEdge();
    }
    ///self.rect.getTopEdge() >= rect.getBottomEdge();
    pub fn collidedWithBottom(self: Self, rect: *Rectangle) bool {
        return self.getTopEdge() >= rect.getBottomEdge();
    }
    ///self.rect.getBottomEdge() >= rect.getTopEdge();
    pub fn collidedWithTop(self: Self, rect: *Rectangle) bool {
        return self.getBottomEdge() >= rect.getTopEdge();
    }
    fn setDamageAmount(self: *Self) void {
        switch (self.objectType) {
            // Use the capture syntax |value| to get the data inside
            .PLATFORM => |plat_type| {
                switch (plat_type) {
                    .GROUND => {
                        // self.damage = DamageHandler.init(true, 10.0, false);
                    },
                    .ICE => {
                        //self.damage = DamageHandler.init(true, 10.0, true)
                    },
                    .VERTICAL => {},
                    .SLIPPERY => {},
                    .WATER => {
                        // self.damage = DamageHandler.init(true, 10.0, true);
                        // self.effects = ObjectEffects.init(true, 10.0, false, false, false);
                    },
                    .GRASS => {},
                    .WALL => {
                        //self.effects = ObjectEffects.init(true, 10.0, false, false, false)
                    },
                }
            },
            .ENEMY => |enemy_type| {
                switch (enemy_type) {
                    .LOW => {
                        self.objectProperties = ObjectProperties.init(
                            .ENEMY,
                            true,
                            50.0,
                            false,
                            false,
                            false,
                            true,
                            DamageComponent.init(
                                10.0,
                                false,
                            ),
                        );
                    },
                    .MED => {},
                    .HIGH => {},
                    .BOSS => {},
                    .PATROL => {},
                }
            },
            else => |_| {},
        }
    }
};
