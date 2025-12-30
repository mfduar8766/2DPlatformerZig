const std = @import("std");
const rayLib = @import("raylib");
const Platform = @import("./platforms.zig").Platform;
const PLATFORM_TYPES = @import("../types.zig").PLATFORM_TYPES;
const Enemy = @import("./enemies.zig").Enemy;

pub const Levels = struct {
    const Self = @This();
    staticPlatforms: []const Platform,
    allocator: std.mem.Allocator,
    dynamicPlatForms: std.ArrayList(*Platform),
    enemies: std.ArrayList(*Enemy),

    pub fn init(allocator: std.mem.Allocator, platforms: []const Platform) !*Self {
        const levels = try allocator.create(Self);
        levels.* = Self{
            .allocator = allocator,
            .dynamicPlatForms = std.ArrayList(*Platform).empty,
            .enemies = std.ArrayList(*Enemy).empty,
            .staticPlatforms = platforms,
        };
        return levels;
    }
    pub fn deinit(self: *Self) void {
        // for (self.staticPlatforms) |platform| {
        //     platform.deinit();
        // }
        self.allocator.free(self.staticPlatforms);
        self.dynamicPlatForms.deinit(self.allocator);
        self.enemies.deinit(self.allocator);
        self.allocator.destroy(self);
    }
};

pub fn createLevel0(allocator: std.mem.Allocator, comptime staticPlatforms: usize) ![]Platform {
    var list = try allocator.alloc(Platform, staticPlatforms);
    const ground = Platform.init(
        // allocator,
        PLATFORM_TYPES.GROUND,
        300.0,
        100.0,
        // rayLib.Vector2.init(
        //     @as(f32, @floatFromInt(1500)) / 2.0,
        //     @as(f32, @floatFromInt(1500)) / 2.0,
        // ),
        rayLib.Vector2.init(0.0, @as(f32, @floatFromInt(rayLib.getScreenHeight())) - 30.0),
        .green,
        false,
        false,
    );
    // const ground2 = Platform.init(
    //     // allocator,
    //     PLATFORM_TYPES.GROUND,
    //     300.0,
    //     100.0,
    //     rayLib.Vector2.init(301.0, @as(f32, @floatFromInt(rayLib.getScreenHeight())) - 30.0),
    //     .green,
    //     false,
    //     false,
    // );
    const water = Platform.init(
        // allocator,
        PLATFORM_TYPES.WATER,
        500.0,
        30.0,
        rayLib.Vector2.init(ground.rect.getWidth(), @as(f32, @floatFromInt(rayLib.getScreenHeight())) - 20.0),
        .dark_blue,
        true,
        true,
    );
    const verticalPlatform = Platform.init(
        // allocator,
        PLATFORM_TYPES.VERTICAL,
        200.0,
        50.0,
        rayLib.Vector2.init(200.0, -200.0),
        .green,
        false,
        false,
    );
    // const verticalPlatform0 = Platform.init(
    //     // allocator,
    //     PLATFORM_TYPES.VERTICAL,
    //     200.0,
    //     50.0,
    //     rayLib.Vector2.init(300.0, 1280.0),
    //     .green,
    //     false,
    // );
    // const icePlatform = Platform.init(
    //     // allocator,
    //     PLATFORM_TYPES.ICE,
    //     200.0,
    //     50.0,
    //     rayLib.Vector2.init(500.0, 1180.0),
    //     // rayLib.Vector2.init(0, 1180.0),
    //     .white,
    //     true,
    // );

    list[0] = ground;
    // list[1] = ground2;
    list[1] = water;
    list[2] = verticalPlatform;
    // list[3] = verticalPlatform;
    // list[4] = icePlatform;
    return list;
}
