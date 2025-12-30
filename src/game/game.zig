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
const GRAVITY = @import("../types.zig").GRAVITY;
const PLAYER_STATE = @import("../types.zig").PLAYER_STATE;
const VELOCITY = @import("../types.zig").VELOCITY;

const Config = struct {
    const Self = @This();
    fps: i32,
    windowWidth: i32,
    windowHeight: i32,
    windowTitle: [:0]const u8,

    pub fn init() Self {
        return .{
            .fps = 60,
            .windowHeight = 600,
            .windowWidth = 800,
            .windowTitle = "Game",
        };
    }
};

const Widgets = struct {
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
    widgets: Widgets,
    currentLevel: usize = 0,
    levelsList: [totalLevels]*Levels = undefined,
    isGameOver: bool = false,
    currentTime: f64 = 0.0,

    pub fn init(allocator: std.mem.Allocator) !*Self {
        const gamePtr = try allocator.create(Self);
        gamePtr.* = Self{
            .allocator = allocator,
            .config = Config.init(),
            .player = try Player.init(allocator),
            .widgets = Widgets.init(),
        };
        inline for (0..totalLevels) |i| {
            const platforms = try createLevel0(allocator, 3);
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
                5.0,
                @as(f32, @floatFromInt(self.config.windowHeight)) - 80.0,
            ),
            .rotation = 0.0,
            .zoom = 1.0,
        };
        while (!rayLib.windowShouldClose()) {
            const dt = rayLib.getFrameTime();
            self.player.handleMovement(dt);
            camera.target = self.player.rect.position;

            rayLib.beginDrawing();
            defer rayLib.endDrawing();

            if (self.isGameOver) {
                rayLib.clearBackground(.black);
                self.resetGameState();
            }
            if (!self.isGameOver) {
                rayLib.clearBackground(rayLib.Color.sky_blue);
            }

            self.widgets.draw();

            // camera.begin();
            rayLib.beginMode2D(camera);

            self.drawWorld(dt);
            self.player.draw();
            // camera.end();
            rayLib.endMode2D();
        }
    }
    fn drawWorld(self: *Self, dt: f32) void {
        const level = self.levelsList[self.currentLevel];
        self.renderStaticLevelPlatforms(dt, level);
    }
    fn renderStaticLevelPlatforms(self: *Self, dt: f32, level: *Levels) void {
        for (level.staticPlatforms) |platform| {
            platform.draw();
            self.checkForIntersection(dt, platform);
            self.checkForIntersection(dt, platform);
        }
    }
    fn checkForIntersection(self: *Self, dt: f32, platform: Platform) void {
        if (self.player.rect.intersects(platform.rect)) {
            std.debug.print("INTERSECTED playerX: {d} playerY: {d} playerVelY: {d} isFalling: {any} playerH: {d} playerW: {d} playerGetH: {d} playerGetW: {d} playerStat: {any} platFormT: {any} platformX: {d} platformY: {d} platformH: {d} platformW: {d} platformGetH: {d} platformGetW: {d} damage: {d} dealDamage: {any}\n", .{
                self.player.rect.position.x,
                self.player.rect.position.y,
                self.player.velocityY,
                self.player.getIsFalling(),
                self.player.rect.height,
                self.player.rect.width,
                self.player.rect.getHeight(),
                self.player.rect.getWidth(),
                self.player.getPlayerState(),
                platform.rect.objectType,
                platform.rect.position.x,
                platform.rect.position.y,
                platform.rect.height,
                platform.rect.width,
                platform.rect.getHeight(),
                platform.rect.getWidth(),
                platform.damageAmount,
                platform.dealDamage,
            });
            if (self.player.velocityY > 0) {
                self.player.velocityY = 0;
                self.player.rect.position.y = platform.rect.position.y - self.player.rect.height;
                self.player.setIsOnGround(true);
                self.player.setIsFalling(false);
            } else if (self.player.velocityY < 0) {
                if (self.player.rect.position.y >= platform.rect.position.y) {
                    std.debug.print("HIT BOTTOM OF PLATFORM\n", .{});
                    self.currentTime = 0.0;
                    self.player.setVelocity(VELOCITY.Y, 0.0);
                    self.player.rect.position.y = platform.rect.position.y + platform.rect.height;
                    self.player.startFalling(dt);
                }
            }
            if (platform.dealDamage and self.player.onGround) {
                self.handleDamage(dt, platform.damageOverTime, platform.damageAmount);
            }
            // PLAYER ON PLATFORM AND WILL FALL
        } else if (platform.rect.position.y - self.player.rect.height == self.player.rect.position.y) {
            if (self.player.rect.getWidth() < platform.rect.position.x or self.player.rect.position.x > platform.rect.getWidth()) {
                self.player.startFalling(dt);
                self.checkForIntersection(dt, platform);
            }
        } else if (self.player.onGround) {
            if (self.player.rect.position.x > platform.rect.getWidth() and platform.platFormType == .GROUND) {
                // FELL FROM PLATFORM
                self.player.startFalling(dt);
                self.checkForIntersection(dt, platform);
            }
        }
    }
    fn handleDamage(self: *Self, dt: f32, damageOverTime: bool, damageAmount: f32) void {
        if (self.currentTime == 0.0) {
            self.currentTime = rayLib.getTime();
            self.player.setDamage(damageAmount);
            self.widgets.healthBarRect.width = self.player.getHealth();
            self.player.applyDamageBounce(dt);
        }
        const elapsedTime = rayLib.getTime() - self.currentTime;
        if (damageOverTime and elapsedTime > 1.0) {
            self.player.setDamage(damageAmount);
            self.widgets.healthBarRect.width = self.player.getHealth();
            self.player.applyDamageBounce(dt);
        }
        if (self.player.health < 0) {
            self.handleGameOver();
        }
    }
    fn resetGameState(self: *Self) void {
        self.isGameOver = false;
        self.currentTime = 0.0;
        self.player.reset();
    }
    fn handleGameOver(self: *Self) void {
        self.player.setPlayerState(.DEAD);
        // self.player.velocityY = 200.0 * self.player.jumpMultiplier;
        // self.player.velocityY += GRAVITY * dt;
        // self.player.rect.position.y = self.player.velocityY;
        self.isGameOver = true;
    }
};
