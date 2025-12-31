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
const createLevel1 = @import("./levels.zig").createLevel1;
const GRAVITY = @import("../types.zig").GRAVITY;
const PLAYER_STATE = @import("../types.zig").PLAYER_STATE;
const Utils = @import("../utils/utils.zig");

pub const Config = struct {
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
    const totalLevels: usize = 2;
    const lerpFactor = 8.0;
    allocator: std.mem.Allocator,
    config: *Config = undefined,
    player: *Player = undefined,
    widgets: Widgets = undefined,
    currentLevel: usize = 0,
    levelsList: [totalLevels]*Levels = undefined,
    isGameOver: bool = false,
    currentTime: f64 = 0.0,
    //const worldBounds = rayLib.Rectangle.init(0, 0, 3000.0, screenH);
    worldSize: Rectangle = undefined,
    pub fn init(allocator: std.mem.Allocator) !*Self {
        const gamePtr = try allocator.create(Self);
        var config = Config.init();
        gamePtr.* = Self{
            .allocator = allocator,
            .config = &config,
            // .player = try Player.init(allocator, &config),
            // .widgets = Widgets.init(),
        };
        // try gamePtr.createLevels();
        return gamePtr;
    }
    pub fn deinit(self: *Self) void {
        for (self.levelsList) |level| {
            level.deinit();
        }
        self.player.deinit();
        self.allocator.destroy(self);
    }
    pub fn run(self: *Self) !void {
        rayLib.initWindow(self.config.windowWidth, self.config.windowHeight, self.config.windowTitle);
        defer rayLib.closeWindow();

        try self.createGameObjects();
        rayLib.setTargetFPS(self.config.fps);

        const screenH = Utils.floatFromInt(f32, rayLib.getScreenHeight());
        const screenW = Utils.floatFromInt(f32, rayLib.getScreenWidth());

        var camera = rayLib.Camera2D{
            .target = self.player.rect.getPosition(),
            .offset = rayLib.Vector2.init(
                screenW / 2.0,
                screenH - 100.0, // Player pinned near bottom
            ),
            .rotation = 0.0,
            .zoom = 1.0,
        };

        while (!rayLib.windowShouldClose()) {
            const dt = rayLib.getFrameTime();
            if (self.isGameOver) {
                self.resetGameState();
                continue;
            }

            const currentLevelObj = self.levelsList[self.currentLevel];
            const playerRect = self.player.getRect();
            const playerCenterX = playerRect.getPosition().x + (playerRect.getWidth() / 2.0);

            // --- 1. UPDATE PHASE (Movement & Level Switching) ---
            // Pass the level bounds for horizontal clamping/walls
            self.player.handleMovement(dt, self.worldSize);

            // Seamless Level Switching based on Player Center
            if (playerCenterX > currentLevelObj.getRect().getRightEdge()) {
                if (self.currentLevel < self.levelsList.len - 1) {
                    self.currentLevel += 1;
                }
            } else if (playerCenterX < currentLevelObj.getRect().getPosition().x) {
                if (self.currentLevel > 0) {
                    self.currentLevel -= 1;
                }
            }

            // --- 2. MULTI-LEVEL COLLISION ---
            // We check current, previous, and next level so the "seams" are solid
            var isOnGround = false;
            const checkOffsets = [_]isize{ -1, 0, 1 };

            for (checkOffsets) |offset| {
                const idx = @as(isize, @intCast(self.currentLevel)) + offset;
                if (idx >= 0 and idx < self.levelsList.len) {
                    const targetLevel = self.levelsList[@as(usize, @intCast(idx))];
                    for (targetLevel.staticPlatforms) |platform| {
                        self.checkForIntersection(dt, platform);
                        // Critical: set ground flag regardless of which level the platform belongs to
                        if (self.isOnTopOfPlatform(platform)) {
                            isOnGround = true;
                        }
                    }
                }
            }

            // Apply Grounded/Falling State
            self.player.setIsOnGround(isOnGround);
            if (isOnGround) {
                self.player.setIsFalling(false);
            } else if (self.player.getVelocity(.Y) > 0) {
                self.player.setIsFalling(true);
            }

            // --- 3. CAMERA LOGIC ---
            // Smoothly follow player
            camera.target.x += (self.player.rect.getPosition().x - camera.target.x) * lerpFactor * dt;
            camera.target.y += (self.player.rect.getPosition().y - camera.target.y) * lerpFactor * dt;

            // Global World Clamping (Stops camera at very beginning and very end of ALL levels)
            const startOfWorld = self.levelsList[0].getRect().getPosition().x;
            const endOfWorld = self.levelsList[self.levelsList.len - 1].getRect().getRightEdge();
            const halfViewX = (screenW / 2.0) / camera.zoom;

            const leftLimit = startOfWorld + halfViewX;
            const rightLimit = endOfWorld - halfViewX;

            if (camera.target.x < leftLimit) camera.target.x = leftLimit;
            if (camera.target.x > rightLimit) camera.target.x = rightLimit;

            // --- 4. CULLING RECT ---
            // Defines exactly what the camera "sees" in world coordinates
            const cameraRect = rayLib.Rectangle.init(
                camera.target.x - (camera.offset.x / camera.zoom),
                camera.target.y - (camera.offset.y / camera.zoom),
                screenW / camera.zoom,
                screenH / camera.zoom,
            );

            // --- 5. DRAW PHASE ---
            rayLib.beginDrawing();
            rayLib.clearBackground(rayLib.Color.sky_blue);
            rayLib.beginMode2D(camera);
            // Draw platforms from ALL levels, but only if they are on screen (Culling)
            for (self.levelsList) |lvl| {
                for (lvl.staticPlatforms) |platform| {
                    if (rayLib.checkCollisionRecs(cameraRect, platform.rect.rect)) {
                        platform.draw();
                    }
                }
            }
            self.player.draw();
            rayLib.endMode2D();
            self.widgets.draw();
            rayLib.endDrawing();
        }
    }
    fn createGameObjects(self: *Self) !void {
        self.widgets = Widgets.init();
        try self.createLevels();
        self.player = try Player.init(self.allocator, self.config);
    }
    fn createLevels(self: *Self) !void {
        const level0 = try Levels.init(
            self.allocator,
            try createLevel0(self.allocator, 7),
            Rectangle.init(
                .{ .LEVEL = 0 },
                1500.0,
                Utils.floatFromInt(f32, rayLib.getScreenHeight()),
                rayLib.Vector2.init(0.0, 0.0),
                rayLib.Color.init(0, 0, 0, 0), //fade(rayLib.Color.white, 0.5),
            ),
        );
        const level1 = try Levels.init(
            self.allocator,
            try createLevel1(self.allocator, 3),
            Rectangle.init(
                .{ .LEVEL = 1 },
                1500.0,
                Utils.floatFromInt(f32, rayLib.getScreenHeight()),
                rayLib.Vector2.init(level0.getRect().getRightEdge(), 0.0),
                rayLib.Color.init(0, 0, 0, 0),
            ),
        );
        const levels = [totalLevels]*Levels{ level0, level1 };
        self.levelsList = levels;
        self.worldSize = Rectangle.init(
            .{ .WORLD = 0 },
            level0.getRect().getWidth() + level1.getRect().getWidth(),
            Utils.floatFromInt(f32, rayLib.getScreenHeight()),
            rayLib.Vector2.init(0, 0),
            rayLib.Color.init(0, 0, 0, 0),
        );
    }
    fn checkForIntersection(self: *Self, dt: f32, platform: Platform) void {
        if (self.player.rect.intersects(platform.rect)) {
            // CASE: Falling onto a platform (Landing)
            if (self.player.velocityY > 0) {
                // Only land if we are actually above the platform's surface
                // This prevents "teleporting" to the top if we hit the side
                if (self.player.rect.getPosition().y < platform.rect.getTopEdge()) {
                    self.player.rect.setPosition(.Y, platform.rect.getTopEdge() - self.player.rect.getHeight());
                    self.player.setVelocity(.Y, 0.0);
                    // Note: We don't touch Velocity X here so the player can still walk!
                }
            }

            // CASE: Jumping into the bottom of a platform (Head Bump)
            else if (self.player.getVelocity(.Y) < 0) {
                // Only bump if our head is actually below the bottom edge
                if (self.player.rect.getPosition().y > platform.rect.getTopEdge()) {
                    self.player.rect.setPosition(.Y, platform.rect.getBottomEdge());
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
        return self.player.rect.getRightEdge() < platform.rect.getPosition().x or self.player.rect.getPosition().x > platform.rect.getRightEdge();
    }
    fn isOnSurface(self: Self, platform: Platform) bool {
        // platform.rect.getPosition().y - self.player.rect.height == self.player.rect.getPosition().y
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
            self.widgets.healthBarRect.setWidth(self.player.getHealth());
            self.player.applyDamageBounce(dt);
        }
        const elapsedTime = rayLib.getTime() - self.currentTime;
        if (damageOverTime and elapsedTime > 1.0) {
            self.player.setDamage(damageAmount);
            self.widgets.healthBarRect.setWidth(self.player.getHealth());
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
        // self.player.rect.getPosition().y = self.player.velocityY;
        self.isGameOver = true;
    }
};

// std.debug.print("INTERSECTED playerX: {d} playerVelY: {d} playerVelX: {d} isFalling: {any} playerGetTop: {d} playerGetBottom: {d} playerStat: {any} platFormT: {any} platformX: {d} platformGetTop: {d} platformGetBottom: {d}\n", .{
//     self.player.rect.getPosition().x,
//     self.player.getVelocity(.Y),
//     self.player.getVelocity(.X),
//     self.player.getIsFalling(),
//     self.player.rect.getTopEdge(),
//     self.player.rect.getBottomEdge(),
//     self.player.getPlayerState(),
//     platform.rect.objectType,
//     platform.rect.getPosition.x,
//     platform.rect.getTopEdge(),
//     platform.rect.getBottomEdge(),
// });

// SAMPLE WHILE LOOP
// while (!rayLib.windowShouldClose()) {
//     const dt = rayLib.getFrameTime();
//     const level = self.levelsList[self.currentLevel];

//     // --- PHASE 1: INPUT & MOVEMENT ---
//     self.player.handleMovement(dt);
//     for (self.enemies.items) |enemy| {
//         enemy.updateAI(dt, self.player.rect.getPosition());
//     }

//     // --- PHASE 2: COLLISION & RESOLUTION (The "Jury") ---
//     var foundGround = false;
//     for (level.staticPlatforms) |platform| {
//         self.checkForIntersection(dt, platform); // Snaps player/enemies
//         if (self.player.isOnTopOf(platform)) foundGround = true;

//         // Check if enemies hit platforms too!
//         for (self.enemies.items) |enemy| {
//             self.checkEnemyCollision(enemy, platform);
//         }
//     }
//     self.player.setIsOnGround(foundGround);

//     // --- PHASE 3: INTERACTION ---
//     // Check if player touched a coin, a trap, or an enemy
//     self.checkTriggers();

//     // --- PHASE 4: CAMERA ---
//     self.updateCamera(dt);

//     // --- PHASE 5: DRAWING (Purely visual) ---
//     rayLib.beginDrawing();
//     rayLib.beginMode2D(camera);
//     self.drawWorld();
//     self.player.draw();
//     for (self.enemies.items) |e| e.draw();
//     rayLib.endMode2D();
//     rayLib.endDrawing();
// }
