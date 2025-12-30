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
    const lerpFactor = 8.0;
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
        rayLib.initWindow(self.config.windowWidth, self.config.windowHeight, self.config.windowTitle);
        defer rayLib.closeWindow(); // Good practice to close window on exit
        rayLib.setTargetFPS(self.config.fps);
        var camera = rayLib.Camera2D{
            .target = self.player.rect.position,
            .offset = rayLib.Vector2.init(
                5.0,
                @as(f32, @floatFromInt(self.config.windowHeight)) - 80.0,
            ),
            .rotation = 0.0,
            .zoom = 0.75, // Zoomed out slightly to see more world
        };

        while (!rayLib.windowShouldClose()) {
            const dt = rayLib.getFrameTime();
            if (self.isGameOver) {
                self.resetGameState();
                // Skip the rest of this frame so we start fresh
                continue;
            }
            const level = self.levelsList[self.currentLevel];

            //1. UPDATE PHASE (Physics & Logic)
            self.player.handleMovement(dt);
            var isOnGround = false;
            for (level.staticPlatforms) |platform| {
                // Use your existing intersection check
                // It should 'snap' the player's Y if a collision is found
                self.checkForIntersection(dt, platform);
                if (self.isOnTopOfPlatform(platform)) {
                    isOnGround = true;
                }
            }
            self.player.setIsOnGround(isOnGround);
            //Update Camera (Follow the SNAPPED position)
            camera.target.x += (self.player.rect.position.x - camera.target.x) * lerpFactor * dt;
            camera.target.y += (self.player.rect.position.y - camera.target.y) * lerpFactor * dt;

            //2. DRAW PHASE (Rendering only)
            //No physics or 'checkForIntersection' allowed inside here!
            rayLib.beginDrawing();
            rayLib.clearBackground(rayLib.Color.sky_blue);
            rayLib.beginMode2D(camera);
            for (level.staticPlatforms) |platform| {
                platform.draw();
            }
            self.player.draw();
            rayLib.endMode2D();
            self.widgets.draw();
            rayLib.endDrawing();
        }
    }
    fn checkForIntersection(self: *Self, dt: f32, platform: Platform) void {
        // 1. Check for actual physical overlap
        if (self.player.rect.intersects(platform.rect)) {
            // CASE: Falling onto a platform (Landing)
            if (self.player.velocityY > 0) {
                // Only land if we are actually above the platform's surface
                // This prevents "teleporting" to the top if we hit the side
                if (self.player.rect.position.y < platform.rect.getTopEdge()) {
                    self.player.rect.position.y = platform.rect.getTopEdge() - self.player.rect.height;
                    self.player.setVelocity(.Y, 0.0);
                    // Note: We don't touch Velocity X here so the player can still walk!
                }
            }

            // CASE: Jumping into the bottom of a platform (Head Bump)
            else if (self.player.getVelocity(.Y) < 0) {
                // Only bump if our head is actually below the bottom edge
                if (self.player.rect.position.y > platform.rect.getTopEdge()) {
                    self.player.rect.position.y = platform.rect.getBottomEdge();
                    self.player.setVelocity(.Y, 0.0);
                    self.player.startFalling(dt);
                }
            }

            // Damage Logic
            if (platform.dealDamage) {
                self.handleDamage(dt, platform.damageOverTime, platform.damageAmount);
            }
        } else {
            // 2. If NOT intersecting, check if we just walked off an edge
            // If the player thinks they are grounded, but they are no longer
            // horizontally aligned with THIS platform:
            if (self.isOnSurface(platform) and self.isOffTheEdge(platform)) {
                // We don't need to call checkForIntersection again.
                // Just let gravity take over in the next frame.
                self.player.startFalling(dt);
            }
        }
    }
    ///Check if the player is horizontally overlapping the platform
    fn isWithinHorizontalBounds(self: Self, platform: Platform) bool {
        return self.player.rect.getRightEdge() > platform.rect.getLeftEdge() and
            self.player.rect.getLeftEdge() < platform.rect.getRightEdge();
    }
    fn isOffTheEdge(self: Self, platform: Platform) bool {
        return self.player.rect.getRightEdge() < platform.rect.position.x or self.player.rect.position.x > platform.rect.getRightEdge();
    }
    fn isOnSurface(self: Self, platform: Platform) bool {
        // platform.rect.position.y - self.player.rect.height == self.player.rect.position.y
        // 1. Check Horizontal (Aligned)
        if (!self.isWithinHorizontalBounds(platform)) return false;

        // 2. Check Vertical (Touching Surface)
        const pBottom = self.player.rect.getBottomEdge();
        const platTop = platform.rect.getTopEdge();

        // Check if player's feet are within 1 pixel of the platform top
        const touchingSurface = @abs(pBottom - platTop) < 1.0;
        return touchingSurface;
    }
    fn isOnTopOfPlatform(self: Self, platform: Platform) bool {
        // 1. Horizontal check (already works!)
        if (!self.isWithinHorizontalBounds(platform)) return false;

        const playerBottom = self.player.rect.getBottomEdge();
        const platformTop = platform.rect.getTopEdge();

        // 2. Are the feet between the top of the platform and a little bit inside it?
        // We check if the player is within a "skin" or "buffer" area (e.g., 4 pixels).
        const isFallingOrStanding = self.player.velocityY >= 0;
        const isAtCorrectHeight = playerBottom >= platformTop and playerBottom <= platformTop + 4.0;

        return isFallingOrStanding and isAtCorrectHeight;
    }
    fn colliedWithgetLeftEdge(self: Self, platform: Platform) bool {
        return self.player.rect.getRightEdge() >= platform.rect.getLeftEdge();
    }
    fn collidedWithgetRightEdge(self: Self, platform: Platform) bool {
        return self.player.rect.getLeftEdge() <= platform.rect.getRightEdge();
    }
    fn collidedWithBottom(self: Self, platform: Platform) bool {
        return self.player.rect.getTopEdge() >= platform.rect.getBottomEdge();
    }
    fn collidedWithTop(self: Self, platform: Platform) bool {
        return self.player.rect.getBottomEdge() >= platform.rect.getTopEdge();
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

// std.debug.print("INTERSECTED playerX: {d} playerVelY: {d} playerVelX: {d} isFalling: {any} playerGetTop: {d} playerGetBottom: {d} playerStat: {any} platFormT: {any} platformX: {d} platformGetTop: {d} platformGetBottom: {d}\n", .{
//     self.player.rect.position.x,
//     self.player.getVelocity(.Y),
//     self.player.getVelocity(.X),
//     self.player.getIsFalling(),
//     self.player.rect.getTopEdge(),
//     self.player.rect.getBottomEdge(),
//     self.player.getPlayerState(),
//     platform.rect.objectType,
//     platform.rect.position.x,
//     platform.rect.getTopEdge(),
//     platform.rect.getBottomEdge(),
// });
