const std = @import("std");
const rayLib = @import("raylib");
const GAME_OBJECT_TYPES = @import("../types.zig").GAME_OBJECT_TYPES;
const POSITION = @import("../types.zig").POSITION;
const PLATFORM = @import("../types.zig").PLATFORM_TYPES;

pub const DamageHandler = struct {
    const Self = @This();
    dealDamage: bool = false,
    damageAmount: f32 = 0,
    damageOverTime: bool = false,

    pub fn init(dealDamage: bool, damageAmount: f32, damageOverTime: bool) Self {
        return .{
            .dealDamage = dealDamage,
            .damageAmount = damageAmount,
            .damageOverTime = damageOverTime,
        };
    }
};

pub const ObjectEffects = struct {
    const Self = @This();
    bounce: bool = false,
    bounceAmount: f32 = 0.0,
    freeze: bool = false,
    instaKill: bool = false,
    slippery: bool = false,

    pub fn init(bounce: bool, bounceAmount: f32, freeze: bool, instaKill: bool, slippery: bool) Self {
        return .{
            .bounce = bounce,
            .bounceAmount = bounceAmount,
            .freeze = freeze,
            .instaKill = instaKill,
            .slippery = slippery,
        };
    }
};

pub const Rectangle = struct {
    const Self = @This();
    color: rayLib.Color,
    objectType: GAME_OBJECT_TYPES = GAME_OBJECT_TYPES{ .PLAYER = 0 },
    rect: rayLib.Rectangle,
    damage: DamageHandler = undefined,
    effects: ObjectEffects = undefined,

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
    pub fn getCenterY(self: Self) f32 {
        return self.getPosition().y + (self.rect.height / 2);
    }
    pub fn getCenterX(self: Self) f32 {
        return self.getPosition().x + (self.getWidth() / 2.0);
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
    fn setDamageAmount(self: *Self) void {
        switch (self.objectType) {
            // Use the capture syntax |value| to get the data inside
            .PLATFORM => |plat_type| {
                switch (plat_type) {
                    .GROUND => {
                        self.damage = DamageHandler.init(true, 10.0, false);
                    },
                    .ICE => self.damage = DamageHandler.init(true, 10.0, true),
                    .VERTICAL => {},
                    .SLIPPERY => {},
                    .WATER => {
                        self.damage = DamageHandler.init(true, 10.0, true);
                        self.effects = ObjectEffects.init(true, 10.0, false, false, false);
                    },
                    .GRASS => {},
                    .WALL => self.effects = ObjectEffects.init(true, 10.0, false, false, false),
                }
            },
            .ENEMY => |enemy_type| {
                switch (enemy_type) {
                    .LOW => {},
                    .MED => {},
                    .HIGH => {},
                    .BOSS => {},
                }
            },
            .LEVEL => |level_idx| {
                switch (level_idx) {
                    .STANDARD => {},
                    .MINI_BOSS => {},
                    .BOSS => {},
                }
            },
            else => |_| {},
        }
    }
};
