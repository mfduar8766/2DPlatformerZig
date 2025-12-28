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

pub fn createLevel0(allocator: std.mem.Allocator, staticPlatforms: comptime_int) ![]Platform {
    var list = try allocator.alloc(Platform, @as(usize, staticPlatforms));
    const ground = Platform.init(
        // allocator,
        PLATFORM_TYPES.GRASS,
        300.0,
        30.0,
        rayLib.Vector2.init(0.0, @as(f32, @floatFromInt(rayLib.getScreenHeight())) - 30.0),
        .green,
        false,
    );
    const water = Platform.init(
        // allocator,
        PLATFORM_TYPES.WATER,
        @as(f32, @floatFromInt(rayLib.getScreenWidth())) - 300.0,
        30.0,
        rayLib.Vector2.init(301.0, @as(f32, @floatFromInt(rayLib.getScreenHeight())) - 30.0),
        .dark_blue,
        true,
    );
    const verticalPlatform = Platform.init(
        // allocator,
        PLATFORM_TYPES.VERTICAL,
        200.0,
        50.0,
        rayLib.Vector2.init(100.0, 1350.0),
        .green,
        false,
    );
    const verticalPlatform0 = Platform.init(
        // allocator,
        PLATFORM_TYPES.VERTICAL,
        200.0,
        50.0,
        rayLib.Vector2.init(300.0, 1280.0),
        .green,
        false,
    );
    const icePlatform = Platform.init(
        // allocator,
        PLATFORM_TYPES.ICE,
        200.0,
        50.0,
        rayLib.Vector2.init(500.0, 1180.0),
        // rayLib.Vector2.init(0, 1180.0),
        .white,
        true,
    );

    list[0] = ground;
    list[1] = water;
    list[2] = verticalPlatform0;
    list[3] = verticalPlatform;
    list[4] = icePlatform;
    return list;
}

// pub fn LevelCreator(staticPlatformsPerLevel: comptime_int, platforms: [staticPlatformsPerLevel]Platform) type {
//     return struct {
//         const Self = @This();
//         staticPlatforms: []const Platform,
//         allocator: std.mem.Allocator,
//         dynamicPlatForms: std.ArrayList(*Platform),
//         enemies: std.ArrayList(*Enemy),

//         pub fn init(allocator: std.mem.Allocator) !*Self {
//             const levels = try allocator.create(Self);
//             levels.* = Self{
//                 .allocator = allocator,
//                 .dynamicPlatForms = std.ArrayList(*Platform).empty,
//                 .enemies = std.ArrayList(*Enemy).empty,
//             };
//             return levels;
//         }
//         pub fn deinit(self: *Self) void {
//             self.dynamicPlatForms.deinit(self.allocator);
//             self.enemies.deinit(self.allocator);
//             self.allocator.destroy(self);
//         }
//     };
// }

// pub fn createLevels(_: comptime_int) ![3]*LevelCreator {
//     // const levels: [totalLevels]*Levels = [totalLevels]*Levels{};
//     // inline for (totalLevels, 0..) |_, i| {
//     //     levels[i] = try LevelCreator(5, createLevel0(5));
//     // }
//     return ![3]*LevelCreator{
//         try LevelCreator(5, createLevel0(5)),
//         try LevelCreator(5, createLevel0(5)),
//         try LevelCreator(5, createLevel0(5)),
//     };
// }
