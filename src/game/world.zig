const std = @import("std");
const rayLib = @import("raylib");
const PLATFORM_TYPES = @import("../types.zig").PLATFORM_TYPES;
const Enemy = @import("./enemies.zig").Enemy;
const Utils = @import("../utils/utils.zig");
const Rectangle = @import("../common/shapes.zig").Rectangle;
const LEVEL_TYPEs = @import("../types.zig").LEVEL_TYPES;
const ObjectProperties = @import("../common//objectProperties.zig").ObjectProperties;
const DamageComponent = @import("../common/objectProperties.zig").DamageComponent;
const TILE_SIZE = @import("../types.zig").TILE_SIZE;
const TILE_SIZE_F = @import("../types.zig").TILE_SIZE_F;

const CHAR_EMPTY_SPACE: u8 = '.';
const CHAR_GROUND: u8 = '#';
const CHAR_WATER: u8 = '~';
const CHAR_WALL: u8 = '|';
const CHAR_SPILES: u8 = '^';
const CHAR_HORRIZONTAL_PLATFORM: u8 = '_';
const CHAR_CHECK_POINT: u8 = 'C';
const CHAR_ENEMY: u8 = 'E';
const WATER_HEIGHT = 5.0;
const SPIKE_HEIGHT = 5.0;
pub const LevelBluePrintMappingObjectTypes = enum(u8) {
    EMPTY_SPACE,
    GROUND,
    WATER,
    WALL,
    SPIKES,
    HORRIZONTAL_PLATFORMS,
    CHECK_POINT,
    ENEMY,

    pub fn charToId(char: u8) u8 {
        return switch (char) {
            CHAR_EMPTY_SPACE => 0,
            CHAR_GROUND => 1,
            CHAR_WATER => 2,
            CHAR_WALL => 3,
            CHAR_SPILES => 4,
            CHAR_HORRIZONTAL_PLATFORM => 5,
            CHAR_CHECK_POINT => 6,
            CHAR_ENEMY => 7,
            else => 0,
        };
    }
    pub fn idToChar(id: usize) u8 {
        return switch (id) {
            0 => CHAR_EMPTY_SPACE,
            1 => CHAR_GROUND,
            2 => CHAR_WATER,
            3 => CHAR_WALL,
            4 => CHAR_SPILES,
            5 => CHAR_HORRIZONTAL_PLATFORM,
            6 => CHAR_CHECK_POINT,
            7 => CHAR_ENEMY,
            else => CHAR_EMPTY_SPACE,
        };
    }
};

pub fn World(comptime totalLevels: usize, currentLevel: usize) type {
    return struct {
        const Self = @This();
        ///The Blueprints (Shared across all instances)
        ///
        ///Each . represents a row so each char(.,~,|,_,^,ETC) represends a cell in that row
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
                "...............................................", // 10
                ".....|..|.......................................",
                ".....|..|.......................................", // 12
                ".....|..|.......................................",
                ".....|..|.......................................",
                ".....|..|.......................................",
                ".....|..|.............___.......................",
                ".....|..|..E...................................",
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
        dynamicPlatforms: std.ArrayList(Rectangle),
        levelObjectProperties: std.AutoHashMap(u8, ObjectProperties) = undefined,

        pub fn init(allocator: std.mem.Allocator) !*Self {
            // try foo(allocator);
            const self = try allocator.create(Self);
            self.* = .{
                .allocator = allocator,
                .enemies = std.ArrayList(*Enemy).empty,
                .dynamicPlatforms = std.ArrayList(Rectangle).empty,
                .rect = Rectangle.init(
                    .{ .WORLD = 0 },
                    WORLD_PIXEL_WIDTH,
                    Utils.floatFromInt(f32, ROWS) * TILE_SIZE,
                    rayLib.Vector2.init(0.0, 0.0),
                    rayLib.Color.init(0, 0, 0, 0),
                ),
                .levelObjectProperties = std.AutoHashMap(u8, ObjectProperties).init(allocator),
            };
            try self.setLevelObjectProperties();
            try self.loadLevel(currentLevel);
            return self;
        }
        pub fn deinit(self: *Self) void {
            self.dynamicPlatforms.deinit(self.allocator);
            // self.enemies.deinit(self.allocator);
            for (self.enemies.items) |enemy| {
                enemy.deinit();
            }
            self.enemies.deinit(self.allocator);
            self.levelObjectProperties.deinit();
            self.allocator.destroy(self);
        }
        pub fn getRect(self: *Self) Rectangle {
            return self.rect;
        }
        pub fn getLevelIndex(self: *Self) usize {
            return self.currentLevelIndex;
        }
        pub fn setLevelIndex(self: *Self, levelIndex: usize) void {
            self.currentLevelIndex = levelIndex;
        }
        pub fn getLevelWidth(_: *Self) f32 {
            return Utils.floatFromInt(f32, LEVEL_WIDTH);
        }
        pub fn loadLevel(self: *Self, levelIndex: usize) !void {
            self.currentLevelIndex = levelIndex;
            self.enemies.clearRetainingCapacity();
            self.dynamicPlatforms.clearRetainingCapacity();
            const currentLevelBluePrint = BLUEPRINTS[levelIndex];
            for (0..ROWS) |row| {
                for (0..COLUMNS_PER_LEVEL) |col| {
                    const gridCharacterLocation = currentLevelBluePrint[row][col];
                    const index = row * COLUMNS_PER_LEVEL + col;
                    self.activeMap[index] = LevelBluePrintMappingObjectTypes.charToId(gridCharacterLocation);
                    try self.handleDynamicObjectPlaceMent(
                        gridCharacterLocation,
                        col,
                        row,
                        levelIndex,
                        index,
                    );
                    //TODO: FIGURE OUT HOW TO RESET PLAYER RESPAWN
                    // if (char == 'P' and self.currentLevelIndex == 0) {
                    // Global spawn logic
                    // const global_x_offset = @as(f32, @floatFromInt(levelIndex * LEVEL_WIDTH));
                    // const spawn_x = (@as(f32, @floatFromInt(x)) * @as(f32, @floatFromInt(TILE_SIZE))) + global_x_offset;
                    // const spawn_y = @as(f32, @floatFromInt(y)) * @as(f32, @floatFromInt(TILE_SIZE));
                    // self.player.getRect().setPosition(.X, spawn_x);
                    // self.player.getRect().setPosition(.Y, spawn_y);
                    // }
                }
            }
        }
        pub fn draw(self: *Self) void {
            // 1. Draw the level the player is currently in
            drawLevelBluePrintByIndex(self.currentLevelIndex);
            // 2. Draw the NEXT level so there is no gap when looking ahead
            if (self.currentLevelIndex < totalLevels - 1) {
                drawLevelBluePrintByIndex(self.currentLevelIndex + 1);
            }
            // 3. Draw the PREVIOUS level so there is no gap when looking back
            if (self.currentLevelIndex > 0) {
                drawLevelBluePrintByIndex(self.currentLevelIndex - 1);
            }
        }
        ///0 => CHAR_EMPTY_SPACE
        ///
        /// 1 => CHAR_GROUND
        ///
        /// 2 => CHAR_WATER
        ///
        /// 3 => CHAR_WALL
        ///
        /// 4 => CHAR_SPILES
        ///
        /// 5 => CHAR_HORRIZONTAL_PLATFORM
        ///
        /// 6 => CHAR_CHECK_POINT
        ///
        /// 7 => CHAR_ENEMY
        pub fn getTilesAt(self: *Self, playerX: f32, playerY: f32) u8 {
            // 1. Determine which level index this X coordinate belongs to
            // Example: 1600 / 1504 = 1.06 -> Index 1
            const levelIndex = @as(i32, @intFromFloat(playerX / @as(f32, @floatFromInt(LEVEL_WIDTH))));

            // 2. Safety: If outside the entire world bounds, return empty (0)
            if (levelIndex < 0 or levelIndex >= totalLevels) return 0;
            const u_level_idx = @as(usize, @intCast(levelIndex));

            // 3. Calculate "Local X" (0 to 1503) within that specific level
            const global_x_offset = @as(f32, @floatFromInt(u_level_idx * LEVEL_WIDTH));
            const local_x = playerX - global_x_offset;

            // 4. Convert Local X and World Y to Grid Coordinates (0-46 and 0-18)
            const col = @as(i32, @intFromFloat(local_x / TILE_SIZE_F));
            const row = @as(i32, @intFromFloat(playerY / TILE_SIZE_F));

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
                return LevelBluePrintMappingObjectTypes.charToId(char);
            }
        }
        pub fn isSolid(self: *Self, x: f32, y: f32) bool {
            const id = self.getTilesAt(x, y);
            // IDs: 1 (Ground), 3 (Wall), 5 (Platform) are solid
            return (id == 1 or id == 3 or id == 5);
        }
        pub fn getObjectProperties(self: *Self, key: u8) ?ObjectProperties {
            if (self.levelObjectProperties.get(key)) |component| {
                return component;
            }
            return null;
        }
        fn setLevelObjectProperties(self: *Self) !void {
            const levelTileTypes = [5]u8{
                LevelBluePrintMappingObjectTypes.charToId(CHAR_GROUND),
                LevelBluePrintMappingObjectTypes.charToId(CHAR_WATER),
                LevelBluePrintMappingObjectTypes.charToId(CHAR_WALL),
                LevelBluePrintMappingObjectTypes.charToId(CHAR_SPILES),
                LevelBluePrintMappingObjectTypes.charToId(CHAR_HORRIZONTAL_PLATFORM),
            };
            for (levelTileTypes) |key| {
                switch (key) {
                    1 => try self.levelObjectProperties.put(key, ObjectProperties.init(
                        LevelBluePrintMappingObjectTypes.GROUND,
                        false,
                        0,
                        false,
                        false,
                        false,
                        true,
                        DamageComponent.init(
                            0,
                            false,
                        ),
                    )),
                    2 => try self.levelObjectProperties.put(key, ObjectProperties.init(
                        LevelBluePrintMappingObjectTypes.WATER,
                        true,
                        100.0,
                        false,
                        false,
                        false,
                        true,
                        DamageComponent.init(
                            10.0,
                            true,
                        ),
                    )),
                    3 => try self.levelObjectProperties.put(key, ObjectProperties.init(
                        LevelBluePrintMappingObjectTypes.WALL,
                        false,
                        0,
                        false,
                        false,
                        false,
                        false,
                        null,
                    )),
                    4 => try self.levelObjectProperties.put(key, ObjectProperties.init(
                        LevelBluePrintMappingObjectTypes.SPIKES,
                        true,
                        100.0,
                        false,
                        false,
                        false,
                        true,
                        DamageComponent.init(
                            10.0,
                            true,
                        ),
                    )),
                    5 => try self.levelObjectProperties.put(key, ObjectProperties.init(
                        LevelBluePrintMappingObjectTypes.HORRIZONTAL_PLATFORMS,
                        false,
                        0,
                        false,
                        false,
                        false,
                        true,
                        null,
                    )),
                    else => {},
                }
            }
        }
        fn drawLevelBluePrintByIndex(levelIndex: usize) void {
            const currentLevelBluePrint = BLUEPRINTS[levelIndex];
            const globalXOffset = Utils.floatFromInt(f32, levelIndex * LEVEL_WIDTH);
            for (0..ROWS) |row| {
                for (0..COLUMNS_PER_LEVEL) |col| {
                    const gridCharacterId = LevelBluePrintMappingObjectTypes.charToId(currentLevelBluePrint[row][col]);
                    if (gridCharacterId == 0) continue;
                    const posX = (Utils.floatFromInt(f32, col) * TILE_SIZE_F) + globalXOffset;
                    const posY = Utils.floatFromInt(f32, row) * TILE_SIZE_F;
                    drawTiles(gridCharacterId, posX, posY, TILE_SIZE_F);
                }
            }
        }
        fn drawTiles(id: usize, posX: f32, posY: f32, size: f32) void {
            switch (id) {
                1 => rayLib.drawRectangleV(
                    .{ .x = posX, .y = posY },
                    .{ .x = size, .y = size },
                    rayLib.Color.brown,
                ),
                // Subtract height from the size rayLib.Color.blue) to keep the water contained in the square
                // One warning: Since you are drawing the rectangle with a full size (32px),
                // but starting 5px lower, your water will actually stick out 5px into the tile below it.
                // To keep the water contained perfectly within its 32px cell, change your drawing line to this:
                2 => rayLib.drawRectangleV(
                    .{ .x = posX, .y = posY + WATER_HEIGHT },
                    .{ .x = size, .y = size - WATER_HEIGHT },
                    rayLib.Color.blue,
                ),
                3 => rayLib.drawRectangleV(
                    .{ .x = posX, .y = posY },
                    .{ .x = size, .y = size },
                    rayLib.Color.green,
                ),
                4 => rayLib.drawRectangleV(
                    .{ .x = posX, .y = posY + SPIKE_HEIGHT },
                    .{ .x = size, .y = size - SPIKE_HEIGHT },
                    rayLib.Color.red,
                ),
                5 => rayLib.drawRectangleV(
                    .{ .x = posX, .y = posY },
                    .{ .x = size, .y = size },
                    rayLib.Color.green,
                ),
                6 => rayLib.drawRectangleV(
                    .{ .x = posX, .y = posY },
                    .{ .x = size, .y = size },
                    rayLib.Color.gold,
                ),
                else => {},
            }
        }
        fn handleDynamicObjectPlaceMent(
            self: *Self,
            gridCharacterLocation: u8,
            col: usize,
            row: usize,
            levelIndex: usize,
            index: usize,
        ) !void {
            if (gridCharacterLocation == CHAR_ENEMY) {
                std.debug.print("INDEX: {d}\n", .{index});
                const global_x_offset = @as(f32, @floatFromInt(levelIndex * LEVEL_WIDTH));
                const spawn_x = (@as(f32, @floatFromInt(col)) * TILE_SIZE_F) + global_x_offset;
                const spawn_y = @as(f32, @floatFromInt(row)) * TILE_SIZE_F;
                try self.enemies.append(self.allocator, try Enemy.init(
                    self.allocator,
                    index,
                    .LOW,
                    rayLib.Vector2.init(
                        spawn_x,
                        spawn_y,
                    ),
                    false,
                ));
            }
        }
    };
}
