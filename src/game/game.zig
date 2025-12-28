const std = @import("std");
const rayLib = @import("raylib");
const Player = @import("./player.zig").Player;
const Platform = @import("./platforms.zig").Platform;
const Rectangle = @import("../common/shapes.zig").Rectangle;
const GAME_OBJECT_TYPES = @import("../types.zig").GAME_OBJECT_TYPES;
const Enemy = @import("./enemies.zig").Enemy;
const PLATFORM_TYPES = @import("../types.zig").PLATFORM_TYPES;
const Levels = @import("./levels.zig").Levels;
const createLevel0 = @import("./levels.zig").createLevel0;

const Config = struct {
    const Self = @This();
    fps: i32,
    windowWidth: i32,
    windowHeight: i32,
    windowTitle: [:0]const u8,

    pub fn init() Self {
        return .{
            .fps = 60,
            .windowHeight = 1500,
            .windowWidth = 1500,
            .windowTitle = "Game",
        };
    }
};

const GameUI = struct {
    const Self = @This();
    healthBarRect: Rectangle = Rectangle.init(
        GAME_OBJECT_TYPES{ .UI = .HEALTH_BAR },
        100.0,
        20,
        rayLib.Vector2.init(10.0, 10.0),
        .red,
    ),
    staminaBarRect: Rectangle = Rectangle.init(
        GAME_OBJECT_TYPES{ .UI = .STAMINA_BAR },
        100.0,
        20,
        rayLib.Vector2.init(10.0, 40.0),
        .green,
    ),

    pub fn init() Self {
        return .{};
    }
    pub fn draw(self: *Self) void {
        self.healthBarRect.draw();
        self.staminaBarRect.draw();
    }
};

pub const Game = struct {
    const Self = @This();
    const totalLevels: usize = 3;
    allocator: std.mem.Allocator,
    config: Config,
    player: *Player,
    gameUI: GameUI,
    currentLevel: usize = 0,
    levelsList: [totalLevels]*Levels = undefined,

    pub fn init(allocator: std.mem.Allocator) !*Self {
        const gamePtr = try allocator.create(Self);
        gamePtr.* = Self{
            .allocator = allocator,
            .config = Config.init(),
            .player = try Player.init(allocator),
            .gameUI = GameUI.init(),
        };
        inline for (0..totalLevels) |i| {
            const platforms = try createLevel0(allocator, 5);
            gamePtr.levelsList[i] = try Levels.init(allocator, platforms);
        }
        return gamePtr;
    }
    pub fn deinit(self: *Self) void {
        for (self.levelsList) |level| {
            level.deinit();
        }
        self.player.deinit();
        self.allocator.destroy(self);
    }
    pub fn run(self: *Self) void {
        rayLib.setTargetFPS(self.config.fps);
        rayLib.initWindow(self.config.windowWidth, self.config.windowHeight, self.config.windowTitle);
        var camera = rayLib.Camera2D{
            .target = self.player.rect.position,
            .offset = rayLib.Vector2.init(
                @as(f32, @floatFromInt(self.config.windowWidth)) / 2.0,
                @as(f32, @floatFromInt(self.config.windowHeight)) / 2.0,
            ),
            .rotation = 0.0,
            .zoom = 1.0,
        };
        while (!rayLib.windowShouldClose()) {
            const dt = rayLib.getFrameTime();
            camera.target = self.player.rect.position;
            rayLib.beginDrawing();
            defer rayLib.endDrawing();

            rayLib.clearBackground(rayLib.Color.sky_blue);

            self.gameUI.draw();
            self.player.handleMovement(dt);

            camera.begin();
            for (self.levelsList, 0..) |Level, levelIndex| {
                switch (levelIndex) {
                    0 => {
                        if (Level.dynamicPlatForms.items.len > 0) {
                            //
                        }
                        self.renderStaticLevelPlatforms(levelIndex);
                    },
                    1 => {
                        self.renderStaticLevelPlatforms(levelIndex);
                    },
                    2 => {
                        self.renderStaticLevelPlatforms(levelIndex);
                    },
                    else => {},
                }
            }
            self.player.draw();
            camera.end();
        }
    }
    fn renderStaticLevelPlatforms(self: *Self, levelID: usize) void {
        for (self.levelsList[levelID].staticPlatforms) |platform| {
            platform.draw();
            // 3. Check collision for this platform
            if (self.player.rect.intersects(platform.rect)) {
                if (self.player.velocityY > 0) { // Only if falling down
                    self.player.rect.position.y = platform.rect.position.y - self.player.rect.height;
                    self.player.velocityY = 0;
                    self.player.onGround = true;
                }
            }
        }
    }
};
