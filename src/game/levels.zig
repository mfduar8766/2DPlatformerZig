const std = @import("std");
const rayLib = @import("raylib");
const Platform = @import("./platforms.zig").Platform;
const PLATFORM_TYPES = @import("../types.zig").PLATFORM_TYPES;
const Enemy = @import("./enemies.zig").Enemy;
const Utils = @import("../utils/utils.zig");
const Rectangle = @import("../common/shapes.zig").Rectangle;
const LEVEL_TYPEs = @import("../types.zig").LEVEL_TYPES;

const LevelBluePrint = struct {
    const Self = @This();
    height: f32,
    width: f32,
    levelType: LEVEL_TYPEs,
    staticPlatformsCount: usize,
    position: rayLib.Vector2,

    pub fn init(levelType: LEVEL_TYPEs, width: f32, staticPlatformsCount: usize, position: rayLib.Vector2) Self {
        return .{
            .levelType = levelType,
            .width = width,
            .height = Utils.floatFromInt(f32, rayLib.getScreenHeight()),
            .staticPlatformsCount = staticPlatformsCount,
            .position = position,
        };
    }
};

const PlatformBluePrint = struct {
    const Self = @This();
    platFormType: PLATFORM_TYPES,
    width: f32,
    height: f32,
    position: rayLib.Vector2,
    color: rayLib.Color,
    dealDamage: bool,
    damageOverTime: bool,

    pub fn init(platformType: PLATFORM_TYPES, height: f32, width: f32, position: rayLib.Vector2, dealDamage: bool, damageOverTime: bool) Self {
        return .{
            .platFormType = platformType,
            .height = height,
            .width = width,
            .position = position,
            .dealDamage = dealDamage,
            .damageOverTime = damageOverTime,
        };
    }
};

const Level = struct {
    const Self = @This();
    allocator: std.mem.Allocator,
    staticPlatforms: []const Platform = undefined,
    dynamicPlatForms: std.ArrayList(*Platform),
    enemies: std.ArrayList(*Enemy),
    rect: Rectangle,

    pub fn init(allocator: std.mem.Allocator, platforms: []const Platform, rect: Rectangle) Self {
        return .{
            .allocator = allocator,
            .staticPlatforms = platforms,
            .dynamicPlatForms = std.ArrayList(*Platform).empty,
            .enemies = std.ArrayList(*Enemy).empty,
            .rect = rect,
        };
    }
    pub fn deinit(self: *Self) void {
        self.allocator.free(self.staticPlatforms);
        self.dynamicPlatForms.deinit(self.allocator);
        self.enemies.deinit(self.allocator);
    }
    pub fn getRect(self: Self) Rectangle {
        return self.rect;
    }
};

pub fn CreateLevels(comptime totalLevels: usize) type {
    return struct {
        const Self = @This();
        allocator: std.mem.Allocator,
        levels: [totalLevels]*Level = undefined,
        levelsMap: std.AutoHashMap(usize, LevelBluePrint) = undefined,
        platformsPerLevel: std.AutoHashMap(usize, usize) = undefined,
        platformBluePrintsMap: std.AutoHashMap(usize, PlatformBluePrint) = undefined,

        pub fn init(allocator: std.mem.Allocator) !*Self {
            const self = try allocator.create(Self);
            self.* = Self{
                .allocator = allocator,
                .levelsMap = std.AutoHashMap(usize, LevelBluePrint).init(allocator),
                .platformsPerLevel = std.AutoHashMap(usize, usize).init(allocator),
                .platformBluePrintsMap = std.AutoHashMap(usize, PlatformBluePrint).init(allocator),
            };
            try self.createLevels(totalLevels);
            return self;
        }
        pub fn deinit(self: *Self) void {
            self.levelsMap.deinit();
            self.platformsPerLevel.deinit();
            self.platformBluePrintsMap.deinit();
            for (self.levels) |level| {
                level.deinit();
            }
            self.allocator.destroy(self);
        }
        fn createLevels(self: *Self, comptime levelsCount: usize) !void {
            inline for (0..levelsCount) |levelIndex| {
                try self.setPlatformsPerLevel(levelIndex);
                try self.createLevelBluePrint(levelIndex);
            }
            inline for (0..levelsCount) |levelIndex| {
                const levelData = self.levelsMap.get(levelIndex);
                if (levelData) |data| {
                    self.levels[levelIndex] = try Level.init(
                        self.allocator,
                        &.{},
                        Rectangle.init(.{ .LEVEL = levelIndex }, data.width, data.height, data.position, rayLib.Color.init(0, 0, 0, 0)),
                    );
                    const levvelPlatforms = self.platformsPerLevel.get(levelIndex);
                    if (levvelPlatforms) |platforms| {
                        self.levels[levelIndex].staticPlatforms = try self.createPlatforms(levelIndex, platforms);
                    }
                }
            }
        }
        fn createLevelBluePrint(self: *Self, currentLevl: usize) !void {
            switch (currentLevl) {
                0 => try self.levelsMap.put(0, LevelBluePrint.init(.STANDARD, 1500.0, 7, rayLib.Vector2.init(0.0, 0.0))),
                1 => {
                    const previousLevel = self.levelsMap.get(currentLevl - 1).?;
                    const width = previousLevel.position.x + previousLevel.width + 1.0;
                    try self.levelsMap.put(currentLevl, LevelBluePrint.init(.STANDARD, 1500.0, 3, rayLib.Vector2.init(width, 0.0)));
                },
                else => {},
            }
        }
        fn setPlatformsPerLevel(self: *Self, levelIndex: usize) !void {
            switch (levelIndex) {
                0 => try self.platformsPerLevel.put(levelIndex, 7),
                1 => try self.platformsPerLevel.put(levelIndex, 3),
                else => {},
            }
        }
        fn createPlatforms(self: *Self, levelIndex: usize, totalPlatforms: usize) ![]Platform {
            if (totalPlatforms == 0) return &.{};
            var list = try self.allocator.alloc(Platform, totalPlatforms);
            switch (levelIndex) {
                0 => createLevel0(&list),
                1 => {
                    const lastLevelPlatforms = self.levels[levelIndex - 1].staticPlatforms;
                    const lastPlatform = lastLevelPlatforms[lastLevelPlatforms.len - 1].rect;
                    createLevel1(&list, lastPlatform, self.platformsPerLevel.get(levelIndex).?);
                },
                else => {
                    list = list[0..0];
                },
            }
            return list;
        }
        fn createLevel0(list: *[]Platform) void {
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
                600.0,
                50.0,
                rayLib.Vector2.init(icePlatform.rect.getRightEdge(), 500.0),
                .green,
                false,
                false,
            );
            list.*[0] = ground;
            list.*[1] = ground2;
            list.*[2] = water;
            list.*[3] = verticalPlatform;
            list.*[4] = verticalPlatform0;
            list.*[5] = icePlatform;
            list.*[6] = verticalPlatform1;
        }
        fn createLevel1(list: *[]Platform, lastPlatformPosition: Rectangle, len: usize) void {
            const ground1 = Platform.init(
                PLATFORM_TYPES.GROUND,
                300.0,
                100.0,
                rayLib.Vector2.init(lastPlatformPosition.getRightEdge(), @as(f32, @floatFromInt(rayLib.getScreenHeight())) - 50.0 / 2.0),
                .red,
                false,
                false,
            );
            const ground2 = Platform.init(
                PLATFORM_TYPES.GROUND,
                300.0,
                100.0,
                rayLib.Vector2.init(ground1.getRect().getRightEdge(), @as(f32, @floatFromInt(rayLib.getScreenHeight())) - 50.0 / 2.0),
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
            list.*[0] = ground1;
            list.*[1] = ground2;
            list.*[2] = water;
            list.* = list.*[0..len];
        }
    };
}

pub fn World(comptime totalLevels: usize) type {
    return struct {
        const Self = @This();
        allocator: std.mem.Allocator,
        levels: [totalLevels]Level,
        rect: Rectangle,

        pub fn init(allocator: std.mem.Allocator) !*Self {
            const self = try allocator.create(Self);
            self.allocator = allocator;
            var worldSize: f32 = 0;
            inline for (0..totalLevels) |i| {
                self.levels[i] = try self.buildLevel(i);
                worldSize += self.levels[i].getRect().getWidth();
            }
            self.rect = Rectangle.init(
                .{ .WORLD = 0 },
                worldSize,
                Utils.floatFromInt(f32, rayLib.getScreenHeight()),
                rayLib.Vector2.init(0, 0),
                rayLib.Color.init(0, 0, 0, 0),
            );
            return self;
        }
        pub fn deinit(self: *Self) void {
            for (0..totalLevels) |value| {
                self.levels[value].deinit();
            }
            self.allocator.destroy(self);
        }
        pub fn getRect(self: Self) Rectangle {
            return self.rect;
        }
        fn buildLevel(self: *Self, index: usize) !Level {
            const platCount: usize = switch (index) {
                0 => 8,
                1 => 3,
                else => 0,
            };
            if (index == 0) {
                return Level.init(self.allocator, try self.createLevel0(platCount), Rectangle.init(
                    .{ .LEVEL = .STANDARD },
                    1500.0,
                    Utils.floatFromInt(f32, rayLib.getScreenWidth()),
                    rayLib.Vector2.init(0.0, 0.0),
                    rayLib.Color.init(0, 0, 0, 0),
                ));
            } else {
                const previousLevel = &self.levels[index - 1];
                const previousPlatform = previousLevel.staticPlatforms[previousLevel.staticPlatforms.len - 1].getRect();
                return Level.init(self.allocator, try self.createLevel1(platCount, previousPlatform), Rectangle.init(
                    .{ .LEVEL = .STANDARD },
                    1500.0,
                    Utils.floatFromInt(f32, rayLib.getScreenWidth()),
                    rayLib.Vector2.init(previousLevel.getRect().getRightEdge() + 1.0, 0.0),
                    rayLib.Color.init(0, 0, 0, 0),
                ));
            }
        }
        fn createLevel0(self: *Self, count: usize) ![]Platform {
            var list = try self.allocator.alloc(Platform, count);
            const ground = Platform.init(
                PLATFORM_TYPES.GROUND,
                300.0,
                100.0,
                rayLib.Vector2.init(0.0, @as(f32, @floatFromInt(rayLib.getScreenHeight())) - 50.0 / 2),
                .brown,
            );
            const ground2 = Platform.init(
                PLATFORM_TYPES.GROUND,
                300.0,
                100.0,
                rayLib.Vector2.init(ground.rect.getRightEdge(), @as(f32, @floatFromInt(rayLib.getScreenHeight())) - 50.0 / 2.0),
                .brown,
            );
            const water = Platform.init(
                PLATFORM_TYPES.WATER,
                500.0,
                100.0,
                rayLib.Vector2.init(ground2.rect.getRightEdge(), @as(f32, @floatFromInt(rayLib.getScreenHeight())) - 10.0),
                .dark_blue,
            );
            const verticalPlatform = Platform.init(
                PLATFORM_TYPES.VERTICAL,
                200.0,
                50.0,
                rayLib.Vector2.init(100.0, 400.0),
                .green,
            );
            const verticalPlatform0 = Platform.init(
                PLATFORM_TYPES.VERTICAL,
                200.0,
                50.0,
                rayLib.Vector2.init(300.0, 300.0),
                .green,
            );
            const icePlatform = Platform.init(
                PLATFORM_TYPES.ICE,
                200.0,
                50.0,
                rayLib.Vector2.init(500.0, 200.0),
                .white,
            );
            const verticalPlatform1 = Platform.init(
                PLATFORM_TYPES.GRASS,
                1000,
                50.0,
                rayLib.Vector2.init(icePlatform.rect.getRightEdge(), 500.0),
                .green,
            );
            const ver2 = Platform.init(
                PLATFORM_TYPES.WALL,
                100,
                50,
                rayLib.Vector2.init(200.0, 500.0),
                .green,
            );
            list[0] = ground;
            list[1] = ground2;
            list[2] = water;
            list[3] = verticalPlatform;
            list[4] = ver2;
            list[5] = verticalPlatform0;
            list[6] = icePlatform;
            list[7] = verticalPlatform1;
            // list[7] = ver2;
            return list;
        }
        fn createLevel1(self: *Self, count: usize, lastPlatformPosition: Rectangle) ![]Platform {
            var list = try self.allocator.alloc(Platform, count);
            const ground1 = Platform.init(
                PLATFORM_TYPES.GROUND,
                300.0,
                100.0,
                rayLib.Vector2.init(lastPlatformPosition.getRightEdge(), @as(f32, @floatFromInt(rayLib.getScreenHeight())) - 50.0 / 2.0),
                .red,
            );
            const ground2 = Platform.init(
                PLATFORM_TYPES.GROUND,
                300.0,
                100.0,
                rayLib.Vector2.init(ground1.getRect().getRightEdge(), @as(f32, @floatFromInt(rayLib.getScreenHeight())) - 50.0 / 2.0),
                .red,
            );
            const water = Platform.init(
                PLATFORM_TYPES.WATER,
                500.0,
                100.0,
                rayLib.Vector2.init(ground2.rect.getRightEdge(), @as(f32, @floatFromInt(rayLib.getScreenHeight())) - 10.0),
                .dark_blue,
            );
            list[0] = ground1;
            list[1] = ground2;
            list[2] = water;
            return list;
        }
    };
}
