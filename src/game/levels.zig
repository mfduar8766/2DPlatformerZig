const std = @import("std");
const rayLib = @import("raylib");
const Platform = @import("./platforms.zig").Platform;
const PLATFORM_TYPES = @import("../types.zig").PLATFORM_TYPES;
const Enemy = @import("./enemies.zig").Enemy;
const Utils = @import("../utils/utils.zig");
const Rectangle = @import("../common/shapes.zig").Rectangle;

const LEVEL_TYPE = enum(u8) {
    BOSS = 0,
};

pub const Levels = struct {
    const Self = @This();
    staticPlatforms: []const Platform,
    allocator: std.mem.Allocator,
    dynamicPlatForms: std.ArrayList(*Platform),
    enemies: std.ArrayList(*Enemy),
    rect: Rectangle,

    pub fn init(allocator: std.mem.Allocator, platforms: []const Platform, rect: Rectangle) !*Self {
        const levels = try allocator.create(Self);
        levels.* = Self{
            .allocator = allocator,
            .dynamicPlatForms = std.ArrayList(*Platform).empty,
            .enemies = std.ArrayList(*Enemy).empty,
            .staticPlatforms = platforms,
            .rect = rect,
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
    pub fn getRect(self: Self) Rectangle {
        return self.rect;
    }
    // pub fn createStaticPlatforms(self: *Self, comptime staticPlatforms: usize) void {
    //     var list = try self.allocator.alloc([]Platform, staticPlatforms);

    // }
};

pub fn CreateLevelStaticPlatforms() type {
    return struct {
        const Self = @This();

        pub fn init() Self {
            return .{};
        }
    };
}

pub fn createLevel0(allocator: std.mem.Allocator, comptime staticPlatforms: usize) ![]Platform {
    var list = try allocator.alloc(Platform, staticPlatforms);
    const ground = Platform.init(
        PLATFORM_TYPES.GROUND,
        300.0,
        100.0,
        rayLib.Vector2.init(0.0, @as(f32, @floatFromInt(rayLib.getScreenHeight())) - 50.0 / 2),
        .brown,
        false,
        false,
    );
    const ground2 = Platform.init(
        PLATFORM_TYPES.GROUND,
        300.0,
        100.0,
        rayLib.Vector2.init(ground.rect.getRightEdge(), @as(f32, @floatFromInt(rayLib.getScreenHeight())) - 50.0 / 2.0),
        .brown,
        false,
        false,
    );
    const water = Platform.init(
        PLATFORM_TYPES.WATER,
        500.0,
        100.0,
        rayLib.Vector2.init(ground2.rect.getRightEdge(), @as(f32, @floatFromInt(rayLib.getScreenHeight())) - 10.0),
        .dark_blue,
        false,
        false,
    );
    const verticalPlatform = Platform.init(
        PLATFORM_TYPES.VERTICAL,
        200.0,
        50.0,
        rayLib.Vector2.init(100.0, 400.0),
        .green,
        false,
        false,
    );
    const verticalPlatform0 = Platform.init(
        PLATFORM_TYPES.VERTICAL,
        200.0,
        50.0,
        rayLib.Vector2.init(300.0, 300.0),
        .green,
        false,
        false,
    );
    const icePlatform = Platform.init(
        PLATFORM_TYPES.ICE,
        200.0,
        50.0,
        rayLib.Vector2.init(500.0, 200.0),
        .white,
        false,
        false,
    );
    const verticalPlatform1 = Platform.init(
        PLATFORM_TYPES.GRASS,
        1500.0,
        50.0,
        rayLib.Vector2.init(icePlatform.rect.getRightEdge(), 500.0),
        .green,
        false,
        false,
    );
    list[0] = ground;
    list[1] = ground2;
    list[2] = water;
    list[3] = verticalPlatform;
    list[4] = verticalPlatform0;
    list[5] = icePlatform;
    list[6] = verticalPlatform1;
    return list;
}

pub fn createLevel1(allocator: std.mem.Allocator, comptime staticPlatforms: usize) ![]Platform {
    var list = try allocator.alloc(Platform, staticPlatforms);
    const ground = Platform.init(
        PLATFORM_TYPES.GROUND,
        300.0,
        100.0,
        rayLib.Vector2.init(1500.0, @as(f32, @floatFromInt(rayLib.getScreenHeight())) - 50.0 / 2.0),
        .red,
        false,
        false,
    );
    const ground2 = Platform.init(
        PLATFORM_TYPES.GROUND,
        300.0,
        100.0,
        rayLib.Vector2.init(ground.rect.getRightEdge(), @as(f32, @floatFromInt(rayLib.getScreenHeight())) - 50.0 / 2.0),
        .red,
        false,
        false,
    );
    const water = Platform.init(
        PLATFORM_TYPES.WATER,
        500.0,
        100.0,
        rayLib.Vector2.init(ground2.rect.getRightEdge(), @as(f32, @floatFromInt(rayLib.getScreenHeight())) - 10.0),
        .dark_blue,
        false,
        false,
    );
    list[0] = ground;
    list[1] = ground2;
    list[2] = water;
    return list;
}
