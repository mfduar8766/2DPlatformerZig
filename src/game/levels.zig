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

    pub fn init(
        platformType: PLATFORM_TYPES,
        height: f32,
        width: f32,
        position: rayLib.Vector2,
        dealDamage: bool,
        damageOverTime: bool,
    ) Self {
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

// const Level = struct {
//     const Self = @This();
//     allocator: std.mem.Allocator,
//     staticPlatforms: []const Platform = undefined,
//     dynamicPlatForms: std.ArrayList(*Platform),
//     enemies: std.ArrayList(*Enemy),
//     rect: Rectangle,

//     pub fn init(allocator: std.mem.Allocator, platforms: []const Platform, rect: Rectangle) Self {
//         return .{
//             .allocator = allocator,
//             .staticPlatforms = platforms,
//             .dynamicPlatForms = std.ArrayList(*Platform).empty,
//             .enemies = std.ArrayList(*Enemy).empty,
//             .rect = rect,
//         };
//     }
//     pub fn deinit(self: *Self) void {
//         self.allocator.free(self.staticPlatforms);
//         self.dynamicPlatForms.deinit(self.allocator);
//         self.enemies.deinit(self.allocator);
//     }
//     pub fn getRect(self: Self) Rectangle {
//         return self.rect;
//     }
// };

// pub fn CreateLevels(comptime totalLevels: usize) type {
//     return struct {
//         const Self = @This();
//         allocator: std.mem.Allocator,
//         levels: [totalLevels]*Level = undefined,
//         levelsMap: std.AutoHashMap(usize, LevelBluePrint) = undefined,
//         platformsPerLevel: std.AutoHashMap(usize, usize) = undefined,
//         platformBluePrintsMap: std.AutoHashMap(usize, PlatformBluePrint) = undefined,

//         pub fn init(allocator: std.mem.Allocator) !*Self {
//             const self = try allocator.create(Self);
//             self.* = Self{
//                 .allocator = allocator,
//                 .levelsMap = std.AutoHashMap(usize, LevelBluePrint).init(allocator),
//                 .platformsPerLevel = std.AutoHashMap(usize, usize).init(allocator),
//                 .platformBluePrintsMap = std.AutoHashMap(usize, PlatformBluePrint).init(allocator),
//             };
//             try self.createLevels(totalLevels);
//             return self;
//         }
//         pub fn deinit(self: *Self) void {
//             self.levelsMap.deinit();
//             self.platformsPerLevel.deinit();
//             self.platformBluePrintsMap.deinit();
//             for (self.levels) |level| {
//                 level.deinit();
//             }
//             self.allocator.destroy(self);
//         }
//         fn createLevels(self: *Self, comptime levelsCount: usize) !void {
//             inline for (0..levelsCount) |levelIndex| {
//                 try self.setPlatformsPerLevel(levelIndex);
//                 try self.createLevelBluePrint(levelIndex);
//             }
//             inline for (0..levelsCount) |levelIndex| {
//                 const levelData = self.levelsMap.get(levelIndex);
//                 if (levelData) |data| {
//                     self.levels[levelIndex] = try Level.init(
//                         self.allocator,
//                         &.{},
//                         Rectangle.init(.{ .LEVEL = levelIndex }, data.width, data.height, data.position, rayLib.Color.init(0, 0, 0, 0)),
//                     );
//                     const levvelPlatforms = self.platformsPerLevel.get(levelIndex);
//                     if (levvelPlatforms) |platforms| {
//                         self.levels[levelIndex].staticPlatforms = try self.createPlatforms(levelIndex, platforms);
//                     }
//                 }
//             }
//         }
//         fn createLevelBluePrint(self: *Self, currentLevl: usize) !void {
//             switch (currentLevl) {
//                 0 => try self.levelsMap.put(0, LevelBluePrint.init(.STANDARD, 1500.0, 7, rayLib.Vector2.init(0.0, 0.0))),
//                 1 => {
//                     const previousLevel = self.levelsMap.get(currentLevl - 1).?;
//                     const width = previousLevel.position.x + previousLevel.width + 1.0;
//                     try self.levelsMap.put(currentLevl, LevelBluePrint.init(.STANDARD, 1500.0, 3, rayLib.Vector2.init(width, 0.0)));
//                 },
//                 else => {},
//             }
//         }
//         fn setPlatformsPerLevel(self: *Self, levelIndex: usize) !void {
//             switch (levelIndex) {
//                 0 => try self.platformsPerLevel.put(levelIndex, 7),
//                 1 => try self.platformsPerLevel.put(levelIndex, 3),
//                 else => {},
//             }
//         }
//         fn createPlatforms(self: *Self, levelIndex: usize, totalPlatforms: usize) ![]Platform {
//             if (totalPlatforms == 0) return &.{};
//             var list = try self.allocator.alloc(Platform, totalPlatforms);
//             switch (levelIndex) {
//                 0 => createLevel0(&list),
//                 1 => {
//                     const lastLevelPlatforms = self.levels[levelIndex - 1].staticPlatforms;
//                     const lastPlatform = lastLevelPlatforms[lastLevelPlatforms.len - 1].rect;
//                     createLevel1(&list, lastPlatform, self.platformsPerLevel.get(levelIndex).?);
//                 },
//                 else => {
//                     list = list[0..0];
//                 },
//             }
//             return list;
//         }
//         fn createLevel0(list: *[]Platform) void {
//             const ground = Platform.init(
//                 PLATFORM_TYPES.GROUND,
//                 300.0,
//                 100.0,
//                 rayLib.Vector2.init(0.0, @as(f32, @floatFromInt(rayLib.getScreenHeight())) - 50.0 / 2),
//                 .brown,
//                 false,
//                 false,
//             );
//             const ground2 = Platform.init(
//                 PLATFORM_TYPES.GROUND,
//                 300.0,
//                 100.0,
//                 rayLib.Vector2.init(ground.rect.getRightEdge(), @as(f32, @floatFromInt(rayLib.getScreenHeight())) - 50.0 / 2.0),
//                 .brown,
//                 false,
//                 false,
//             );
//             const water = Platform.init(
//                 PLATFORM_TYPES.WATER,
//                 500.0,
//                 100.0,
//                 rayLib.Vector2.init(ground2.rect.getRightEdge(), @as(f32, @floatFromInt(rayLib.getScreenHeight())) - 10.0),
//                 .dark_blue,
//                 false,
//                 false,
//             );
//             const verticalPlatform = Platform.init(
//                 PLATFORM_TYPES.VERTICAL,
//                 200.0,
//                 50.0,
//                 rayLib.Vector2.init(100.0, 400.0),
//                 .green,
//                 false,
//                 false,
//             );
//             const verticalPlatform0 = Platform.init(
//                 PLATFORM_TYPES.VERTICAL,
//                 200.0,
//                 50.0,
//                 rayLib.Vector2.init(300.0, 300.0),
//                 .green,
//                 false,
//                 false,
//             );
//             const icePlatform = Platform.init(
//                 PLATFORM_TYPES.ICE,
//                 200.0,
//                 50.0,
//                 rayLib.Vector2.init(500.0, 200.0),
//                 .white,
//                 false,
//                 false,
//             );
//             const verticalPlatform1 = Platform.init(
//                 PLATFORM_TYPES.GRASS,
//                 600.0,
//                 50.0,
//                 rayLib.Vector2.init(icePlatform.rect.getRightEdge(), 500.0),
//                 .green,
//                 false,
//                 false,
//             );
//             list.*[0] = ground;
//             list.*[1] = ground2;
//             list.*[2] = water;
//             list.*[3] = verticalPlatform;
//             list.*[4] = verticalPlatform0;
//             list.*[5] = icePlatform;
//             list.*[6] = verticalPlatform1;
//         }
//         fn createLevel1(list: *[]Platform, lastPlatformPosition: Rectangle, len: usize) void {
//             const ground1 = Platform.init(
//                 PLATFORM_TYPES.GROUND,
//                 300.0,
//                 100.0,
//                 rayLib.Vector2.init(lastPlatformPosition.getRightEdge(), @as(f32, @floatFromInt(rayLib.getScreenHeight())) - 50.0 / 2.0),
//                 .red,
//                 false,
//                 false,
//             );
//             const ground2 = Platform.init(
//                 PLATFORM_TYPES.GROUND,
//                 300.0,
//                 100.0,
//                 rayLib.Vector2.init(ground1.getRect().getRightEdge(), @as(f32, @floatFromInt(rayLib.getScreenHeight())) - 50.0 / 2.0),
//                 .red,
//                 false,
//                 false,
//             );
//             const water = Platform.init(
//                 PLATFORM_TYPES.WATER,
//                 500.0,
//                 100.0,
//                 rayLib.Vector2.init(ground2.rect.getRightEdge(), @as(f32, @floatFromInt(rayLib.getScreenHeight())) - 10.0),
//                 .dark_blue,
//                 false,
//                 false,
//             );
//             list.*[0] = ground1;
//             list.*[1] = ground2;
//             list.*[2] = water;
//             list.* = list.*[0..len];
//         }
//     };
// }

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

pub fn World(comptime totalLevels: usize) type {
    return struct {
        const Self = @This();
        allocator: std.mem.Allocator,
        // levels: [totalLevels]Level,
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
                3000.0,
                Utils.floatFromInt(f32, rayLib.getScreenHeight()),
                rayLib.Vector2.init(0, 0),
                rayLib.Color.init(0, 0, 0, 0),
            );
            return self;
        }
        pub fn deinit(self: *Self) void {
            // for (0..totalLevels) |value| {
            //     self.levels[value].deinit();
            // }
            self.allocator.destroy(self);
        }
        pub fn getRect(self: Self) Rectangle {
            return self.rect;
        }
        // fn buildLevel(self: *Self, index: usize) !Level {
        // const platCount: usize = switch (index) {
        //     0 => 8,
        //     1 => 3,
        //     else => 0,
        // };
        // if (index == 0) {
        //     return Level.init(self.allocator, try self.createLevel0(platCount), Rectangle.init(
        //         .{ .LEVEL = .STANDARD },
        //         1500.0,
        //         Utils.floatFromInt(f32, rayLib.getScreenWidth()),
        //         rayLib.Vector2.init(0.0, 0.0),
        //         rayLib.Color.init(0, 0, 0, 0),
        //     ));
        // } else {
        //     const previousLevel = &self.levels[index - 1];
        //     const previousPlatform = previousLevel.staticPlatforms[previousLevel.staticPlatforms.len - 1].getRect();
        //     return Level.init(self.allocator, try self.createLevel1(platCount, previousPlatform), Rectangle.init(
        //         .{ .LEVEL = .STANDARD },
        //         1500.0,
        //         Utils.floatFromInt(f32, rayLib.getScreenWidth()),
        //         rayLib.Vector2.init(previousLevel.getRect().getRightEdge() + 1.0, 0.0),
        //         rayLib.Color.init(0, 0, 0, 0),
        //     ));
        // }
        // }
        // fn createLevel0(self: *Self, count: usize) ![]Platform {
        //     var list = try self.allocator.alloc(Platform, count);
        //     const ground = Platform.init(
        //         PLATFORM_TYPES.GROUND,
        //         300.0,
        //         100.0,
        //         rayLib.Vector2.init(0.0, @as(f32, @floatFromInt(rayLib.getScreenHeight())) - 50.0 / 2),
        //         .brown,
        //     );
        //     const ground2 = Platform.init(
        //         PLATFORM_TYPES.GROUND,
        //         300.0,
        //         100.0,
        //         rayLib.Vector2.init(ground.rect.getRightEdge(), @as(f32, @floatFromInt(rayLib.getScreenHeight())) - 50.0 / 2.0),
        //         .brown,
        //     );
        //     const water = Platform.init(
        //         PLATFORM_TYPES.WATER,
        //         500.0,
        //         100.0,
        //         rayLib.Vector2.init(ground2.rect.getRightEdge(), @as(f32, @floatFromInt(rayLib.getScreenHeight())) - 10.0),
        //         .dark_blue,
        //     );
        //     const verticalPlatform = Platform.init(
        //         PLATFORM_TYPES.VERTICAL,
        //         200.0,
        //         50.0,
        //         rayLib.Vector2.init(100.0, 400.0),
        //         .green,
        //     );
        //     const verticalPlatform0 = Platform.init(
        //         PLATFORM_TYPES.VERTICAL,
        //         200.0,
        //         50.0,
        //         rayLib.Vector2.init(300.0, 300.0),
        //         .green,
        //     );
        //     const icePlatform = Platform.init(
        //         PLATFORM_TYPES.ICE,
        //         200.0,
        //         50.0,
        //         rayLib.Vector2.init(500.0, 200.0),
        //         .white,
        //     );
        //     const verticalPlatform1 = Platform.init(
        //         PLATFORM_TYPES.GRASS,
        //         1000,
        //         50.0,
        //         rayLib.Vector2.init(icePlatform.rect.getRightEdge(), 500.0),
        //         .green,
        //     );
        //     const ver2 = Platform.init(
        //         PLATFORM_TYPES.WALL,
        //         100,
        //         200,
        //         rayLib.Vector2.init(400.0, 375.0),
        //         .green,
        //     );
        //     list[0] = ground;
        //     list[1] = ground2;
        //     list[2] = water;
        //     list[3] = verticalPlatform;
        //     list[4] = ver2;
        //     list[5] = verticalPlatform0;
        //     list[6] = icePlatform;
        //     list[7] = verticalPlatform1;
        //     // list[7] = ver2;
        //     return list;
        // }
        // fn createLevel1(self: *Self, count: usize, lastPlatformPosition: Rectangle) ![]Platform {
        //     var list = try self.allocator.alloc(Platform, count);
        //     const ground1 = Platform.init(
        //         PLATFORM_TYPES.GROUND,
        //         300.0,
        //         100.0,
        //         rayLib.Vector2.init(lastPlatformPosition.getRightEdge(), @as(f32, @floatFromInt(rayLib.getScreenHeight())) - 50.0 / 2.0),
        //         .red,
        //     );
        //     const ground2 = Platform.init(
        //         PLATFORM_TYPES.GROUND,
        //         300.0,
        //         100.0,
        //         rayLib.Vector2.init(ground1.getRect().getRightEdge(), @as(f32, @floatFromInt(rayLib.getScreenHeight())) - 50.0 / 2.0),
        //         .red,
        //     );
        //     const water = Platform.init(
        //         PLATFORM_TYPES.WATER,
        //         500.0,
        //         100.0,
        //         rayLib.Vector2.init(ground2.rect.getRightEdge(), @as(f32, @floatFromInt(rayLib.getScreenHeight())) - 10.0),
        //         .dark_blue,
        //     );
        //     list[0] = ground1;
        //     list[1] = ground2;
        //     list[2] = water;
        //     return list;
        // }
    };
}

pub fn World2(comptime totalLevels: usize, currentLevel: usize) type {
    return struct {
        const Self = @This();
        const TILE_SIZE: usize = 32;
        ///The Blueprints (Shared across all instances)
        ///
        ///Each . represents a row so each char(.,~,|,_,^,ETC) represends a cell in that row
        ///
        ///Each row needs to have 47 cells which is (levelWidth + tileSize - 1) / tileSize
        ///Example: (1500 / 32 - 1) / 32
        const BLUEPRINTS = [totalLevels][19][]const u8{
            .{
                "...............................................", // 0-9 empty
                "...............................................",
                "...............................................",
                "...............................................",
                "...............................................",
                "...............................................",
                "...............................................",
                "...............................................",
                "...............................................",
                "...............................................",
                ".....|.........................................", // 10
                ".....|.........................................",
                ".....|...................|.....................", // 12
                ".....|...................|.....................",
                ".....|...................|.....................",
                ".....|...................|.....................",
                "..........___..................................",
                "P....|...................|.....................",
                "###############~~~~~###########################", // 18
            },
            .{
                "...............................................", // 0-9 empty
                "...............................................",
                "...............................................",
                "...............................................",
                "...............................................",
                "...............................................",
                "...............................................",
                "...............................................",
                "...............................................",
                "...............................................",
                ".....|.........................................", // 10
                ".....|.........................................",
                ".....|...................|.....................", // 12
                ".....|...................|.....................",
                ".....|...................|.....................",
                ".....|...................|.....................",
                "...............................................",
                ".....|...................|.....................",
                "~~~############~~~~~###########################", // 18
            },
        };
        const LEVEL_WIDTH = 1504; // TILE_SIZE * COLUMNS_PER_LEVEL (32 * 47)
        const ROWS = BLUEPRINTS[0].len; //19 HEIGHT
        const COLUMNS_PER_LEVEL = BLUEPRINTS[0][0].len; // 47 chars WIDTH
        const WORLD_PIXEL_WIDTH = @as(f32, @floatFromInt(LEVEL_WIDTH * totalLevels));
        // const ROWS: usize = (600 + TILE_SIZE - 1) / TILE_SIZE; // 19
        // const COLUMNS: usize = (1500 + TILE_SIZE - 1) / TILE_SIZE; // 47
        allocator: std.mem.Allocator,
        rect: Rectangle = undefined,
        currentLevelIndex: usize = 0,
        // The "Baked" 1D array for physics/rendering
        activeMap: [ROWS * WORLD_PIXEL_WIDTH]u8 = undefined,
        enemies: std.ArrayList(*Enemy),
        dynamicPlatforms: std.ArrayList(*Platform),

        pub fn init(allocator: std.mem.Allocator) !*Self {
            const self = try allocator.create(Self);
            self.* = .{
                .allocator = allocator,
                .enemies = std.ArrayList(*Enemy).empty,
                .dynamicPlatforms = std.ArrayList(*Platform).empty,
                .rect = Rectangle.init(
                    .{ .WORLD = 0 },
                    WORLD_PIXEL_WIDTH,
                    Utils.floatFromInt(f32, ROWS) * TILE_SIZE,
                    rayLib.Vector2.init(0.0, 0.0),
                    rayLib.Color.init(0, 0, 0, 0),
                ),
            };
            try self.loadLevel(currentLevel);
            return self;
        }
        pub fn deinit(self: *Self) void {
            self.dynamicPlatforms.deinit(self.allocator);
            self.enemies.deinit(self.allocator);
            self.allocator.destroy(self);
        }
        pub fn getRect(self: Self) Rectangle {
            return self.rect;
        }
        pub fn getLevelIndex(self: Self) usize {
            return self.currentLevelIndex;
        }
        pub fn setLevelIndex(self: *Self, levelIndex: usize) void {
            self.currentLevelIndex = levelIndex;
        }
        pub fn getLevelWidth(_: Self) f32 {
            return Utils.floatFromInt(f32, LEVEL_WIDTH);
        }
        pub fn loadLevel(self: *Self, levelIndex: usize) !void {
            self.currentLevelIndex = levelIndex;
            self.enemies.clearRetainingCapacity();
            self.dynamicPlatforms.clearRetainingCapacity();
            // const blueprint = BLUEPRINTS[levelIndex];
            // for (0..ROWS) |y| {
            //     for (0..COLUMNS_PER_LEVEL) |x| {
            //         const char = blueprint[y][x];
            //         // 2. Use COLUMNS_PER_LEVEL for indexing here!
            //         const idx = y * COLUMNS_PER_LEVEL + x;
            //         self.activeMap[idx] = charToId(char);
            //         //TODO: FIGURE OUT HOW TO SET PLAYER PROPERLY
            //         // if (char == 'P' and self.currentLevelIndex == 0) {
            //         //     // Global spawn logic
            //         //     const global_x_offset = @as(f32, @floatFromInt(levelIndex * LEVEL_WIDTH));
            //         //     const spawn_x = (@as(f32, @floatFromInt(x)) * @as(f32, @floatFromInt(TILE_SIZE))) + global_x_offset;
            //         //     const spawn_y = @as(f32, @floatFromInt(y)) * @as(f32, @floatFromInt(TILE_SIZE));
            //         //     self.player.getRect().setPosition(.X, spawn_x);
            //         //     self.player.getRect().setPosition(.Y, spawn_y);
            //         // }
            //     }
            // }
            //This sets the activeMap by getting the currentLevelIndex and mapping it to the bluePrints 2d array
            const currentLevelBluePrint = BLUEPRINTS[levelIndex];
            for (0..ROWS) |rows| {
                for (0..COLUMNS_PER_LEVEL) |cols| {
                    const char = currentLevelBluePrint[rows][cols];
                    const index = rows * COLUMNS_PER_LEVEL + cols;
                    self.activeMap[index] = charToId(char);
                }
            }
        }
        pub fn getTilesAt(self: *Self, playerX: f32, playerY: f32) u8 {
            // 1. Determine which level index this X coordinate belongs to
            // Example: 1600 / 1504 = 1.06 -> Index 1
            const level_idx = @as(i32, @intFromFloat(playerX / @as(f32, @floatFromInt(LEVEL_WIDTH))));

            // 2. Safety: If outside the entire world bounds, return empty (0)
            if (level_idx < 0 or level_idx >= totalLevels) return 0;
            const u_level_idx = @as(usize, @intCast(level_idx));

            // 3. Calculate "Local X" (0 to 1503) within that specific level
            const global_x_offset = @as(f32, @floatFromInt(u_level_idx * LEVEL_WIDTH));
            const local_x = playerX - global_x_offset;

            // 4. Convert Local X and World Y to Grid Coordinates (0-46 and 0-18)
            const col = @as(i32, @intFromFloat(local_x / @as(f32, @floatFromInt(TILE_SIZE))));
            const row = @as(i32, @intFromFloat(playerY / @as(f32, @floatFromInt(TILE_SIZE))));

            // 5. Safety: Grid boundary check
            if (col < 0 or col >= COLUMNS_PER_LEVEL or row < 0 or row >= ROWS) return 0;

            const u_col = @as(usize, @intCast(col));
            const u_row = @as(usize, @intCast(row));

            // 6. Data Source Selection
            // If the requested level is the one currently in 'activeMap', use the fast array.
            // Otherwise, peek directly into the BLUEPRINTS strings.
            if (u_level_idx == self.currentLevelIndex) {
                return self.activeMap[u_row * COLUMNS_PER_LEVEL + u_col];
            } else {
                // Character lookup from the constant strings
                const char = BLUEPRINTS[u_level_idx][u_row][u_col];
                return charToId(char);
            }
        }
        pub fn draw(self: *Self) void {
            // 1. Draw the level the player is currently in
            drawBlueprint(self.currentLevelIndex);
            // 2. Draw the NEXT level so there is no gap when looking ahead
            if (self.currentLevelIndex < totalLevels - 1) {
                drawBlueprint(self.currentLevelIndex + 1);
            }
            // 3. Draw the PREVIOUS level so there is no gap when looking back
            if (self.currentLevelIndex > 0) {
                drawBlueprint(self.currentLevelIndex - 1);
            }
        }
        pub fn isSolid(self: *Self, x: f32, y: f32) bool {
            const id = self.getTilesAt(x, y);
            // IDs: 1 (Ground), 3 (Wall), 5 (Platform) are solid
            return (id == 1 or id == 3 or id == 5);
        }
        // 3. New Helper to draw ANY blueprint by index
        fn drawBlueprint(levelIndex: usize) void {
            const blueprint = BLUEPRINTS[levelIndex];
            const global_x_offset = @as(f32, @floatFromInt(levelIndex * LEVEL_WIDTH));
            const tileSize = @as(f32, @floatFromInt(TILE_SIZE));
            for (0..ROWS) |y| {
                for (0..COLUMNS_PER_LEVEL) |x| {
                    const id = charToId(blueprint[y][x]);
                    if (id == 0) continue;
                    const posX = (@as(f32, @floatFromInt(x)) * tileSize) + global_x_offset;
                    const posY = @as(f32, @floatFromInt(y)) * tileSize;
                    drawTiles(id, posX, posY, tileSize);
                }
            }
        }
        fn drawTiles(id: usize, posX: f32, posY: f32, size: f32) void {
            // std.debug.print("X: {d} Y: {d}\n", .{ posX, posY });
            switch (id) {
                1 => rayLib.drawRectangleV(.{ .x = posX, .y = posY }, .{ .x = size, .y = size }, rayLib.Color.brown),
                2 => rayLib.drawRectangleV(.{ .x = posX, .y = posY }, .{ .x = size, .y = size }, rayLib.Color.blue),
                3 => rayLib.drawRectangleV(.{ .x = posX, .y = posY }, .{ .x = size, .y = size }, rayLib.Color.green),
                4 => rayLib.drawRectangleV(.{ .x = posX, .y = posY }, .{ .x = size, .y = size }, rayLib.Color.red),
                5 => rayLib.drawRectangleV(.{ .x = posX, .y = posY }, .{ .x = size, .y = size }, rayLib.Color.green),
                6 => rayLib.drawRectangleV(.{ .x = posX, .y = posY }, .{ .x = size, .y = size }, rayLib.Color.gold),
                else => {},
            }
        }
        fn charToId(char: u8) u8 {
            return switch (char) {
                '.' => 0, // Empty space / Sky
                '#' => 1, // Ground
                '~' => 2, // Water
                '|' => 3, // Pillar
                '^' => 4, // Spikes
                '_' => 5, // horrizontal
                'C' => 6, // chekpoint
                else => 0,
            };
        }
        fn idToChar(id: usize) u8 {
            return switch (id) {
                0 => '.', // Empty space
                1 => '#', // Ground
                2 => '~', // Water
                3 => '|', // Wall
                4 => '^', // Spikes
                5 => '_', // Horrizontal
                6 => 'C', // Checkpoint
            };
        }
    };
}
