const std = @import("std");
const rayLib = @import("raylib");
const PLATFORM_TYPES = @import("../types.zig").PLATFORM_TYPES;
const GAME_OBJECT_TYPES = @import("../types.zig").GAME_OBJECT_TYPES;
const Rectangle = @import("../common/shapes.zig").Rectangle;

pub const Platform = struct {
    const Self = @This();
    platFormType: PLATFORM_TYPES = PLATFORM_TYPES.GROUND,
    rect: Rectangle,
    dealDamage: bool = false,
    damageAmount: f32 = 0,
    damageOverTime: bool = false,
    pub fn init(
        // alloocator: std.mem.Allocator,
        platFormType: PLATFORM_TYPES,
        width: f32,
        height: f32,
        position: rayLib.Vector2,
        color: rayLib.Color,
        dealDamage: bool,
        damageOverTime: bool,
    ) Self {
        var platForm = Self{
            // .allocator = alloocator,
            .rect = Rectangle.init(
                GAME_OBJECT_TYPES{ .PLATFORM = platFormType },
                width,
                height, // 30.0
                position, //rayLib.Vector2.init(0, 0),
                color,
            ),
            .platFormType = platFormType,
            .dealDamage = dealDamage,
            .damageOverTime = damageOverTime,
        };
        platForm.setDamageAmount(platFormType);
        return platForm;
    }
    pub fn deinit(_: *Self) void {
        // if (self.allocator) |allocator| {
        //     allocator.destroy(self);
        // }
        // self.allocator.destroy(self);
    }
    pub fn draw(self: Self) void {
        self.rect.draw();
    }
    fn setDamageAmount(self: *Self, platForm: PLATFORM_TYPES) void {
        switch (platForm) {
            PLATFORM_TYPES.ICE => {
                self.damageAmount = 10.0;
            },
            PLATFORM_TYPES.WATER => {
                self.damageAmount = 10.0;
            },
            else => {},
        }
    }
};
