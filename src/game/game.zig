const std = @import("std");
const rayLib = @import("raylib");
const Player = @import("./player.zig").Player;
const Platform = @import("./platforms.zig").Platform;
const Rectangle = @import("../common/shapes.zig").Rectangle;
const GAME_OBJECT_TYPES = @import("../types.zig").GAME_OBJECT_TYPES;
const Enemy = @import("./enemies.zig").Enemy;
const PLATFORM_TYPES = @import("../types.zig").PLATFORM_TYPES;
const GRAVITY = @import("../types.zig").GRAVITY;
const PLAYER_STATE = @import("../types.zig").PLAYER_STATE;
const Utils = @import("../utils/utils.zig");
const World2 = @import("./levels.zig").World2;
const POSITION = @import("../types.zig").POSITION;
const COLLISION_TYPES = @import("../types.zig").COLLISION_TYPES;
const DIRECTION = @import("../types.zig").DIRECTION;

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
    isGameOver: bool = false,
    currentTime: f64 = 0.0,
    world: *World2(totalLevels, 0) = undefined,

    pub fn init(allocator: std.mem.Allocator) !*Self {
        const gamePtr = try allocator.create(Self);
        var config = Config.init();
        gamePtr.* = Self{
            .allocator = allocator,
            .config = &config,
        };
        return gamePtr;
    }
    pub fn deinit(self: *Self) void {
        self.world.deinit();
        self.player.deinit();
        self.allocator.destroy(self);
    }
    pub fn run(self: *Self) !void {
        rayLib.initWindow(self.config.windowWidth, self.config.windowHeight, self.config.windowTitle);
        defer rayLib.closeWindow();
        rayLib.setTargetFPS(self.config.fps);
        try self.createGameObjects();
        const screenH = Utils.floatFromInt(f32, rayLib.getScreenHeight());
        const screenW = Utils.floatFromInt(f32, rayLib.getScreenWidth());
        var camera = rayLib.Camera2D{
            .target = self.player.rect.getPosition(),
            .offset = rayLib.Vector2.init(
                screenW / 2.0,
                screenH - 100.0, // Player pinned near bottom
            ),
            .rotation = 0.0,
            .zoom = 2.0, // impacts how much of the world if visible. Since my world is 32x32 a zoom of 1 is to much
        };
        while (!rayLib.windowShouldClose()) {
            rayLib.beginDrawing();
            rayLib.clearBackground(.black);
            rayLib.endDrawing();

            const dt = rayLib.getFrameTime();
            const playerCenterX = self.player.getRect().getCenterX();
            // 1. Calculate which level the player IS IN right now
            const detected_idx = Utils.intFromFloat(usize, playerCenterX / self.world.getLevelWidth());
            // 2. Safety check: Don't try to load Level 5 if you only have 2 levels
            const safe_idx = @min(detected_idx, totalLevels - 1);

            //UPDATE LOGIC
            self.player.handleMovement(dt, self.world.getRect());

            //CHECK FOR COLLISIONS
            if (safe_idx == self.world.getLevelIndex()) {
                const rect = self.player.getRect();
                const p_x = rect.getPosition().x;
                const p_y = rect.getPosition().y;
                const p_w = rect.getWidth();
                const p_h = rect.getHeight();
                // Check points at the player's feet
                const bottomLeft = self.world.getTilesAt(p_x + 2, p_y + p_h);
                const bottomRight = self.world.getTilesAt(p_x + p_w - 2, p_y + p_h);
                if (bottomLeft != 0 or bottomRight != 0) {
                    // std.debug.print("CCCCCCC {any} {any} {any}\n", .{ bottomLeft, bottomRight, right });
                    // We hit something!
                    // If ID is 1 (Ground), stop falling.
                    // If ID is 4 (Spikes), take damage.
                }
            }

            //LEVEL TRANSITION
            if (safe_idx != self.world.getLevelIndex()) {
                std.debug.print("Crossing into Level {d}!\n", .{safe_idx});
                try self.world.loadLevel(safe_idx);
            }

            //CAMERA
            // camera.target.x += (self.player.getRect().getPosition().x - camera.target.x) * lerpFactor * dt;
            // camera.target.y += (self.player.getRect().getPosition().y - camera.target.y) * lerpFactor * dt;
            camera.target = rayLib.Vector2.lerp(camera.target, self.player.getRect().getPosition(), lerpFactor * dt);

            //Global World Clamping (Stops camera at very beginning and very end of world)
            const startOfWorld = self.world.getRect().getPosition().x;
            const endOfWorld = self.world.getRect().getRightEdge();
            const halfViewX = (screenW / 2.0) / camera.zoom;
            const leftLimit = startOfWorld + halfViewX;
            const rightLimit = endOfWorld - halfViewX;
            if (camera.target.x < leftLimit) camera.target.x = leftLimit;
            if (camera.target.x > rightLimit) camera.target.x = rightLimit;

            //DRAW
            rayLib.beginDrawing();
            rayLib.beginMode2D(camera);
            rayLib.clearBackground(rayLib.Color.sky_blue);
            self.widgets.draw();
            self.world.draw();
            self.player.draw();
            rayLib.endMode2D();
            rayLib.endDrawing();
        }
    }
    // pub fn run(self: *Self) !void {
    //     rayLib.initWindow(self.config.windowWidth, self.config.windowHeight, self.config.windowTitle);
    //     defer rayLib.closeWindow();
    //     rayLib.setTargetFPS(self.config.fps);

    //     try self.createGameObjects();
    // const screenH = Utils.floatFromInt(f32, rayLib.getScreenHeight());
    // const screenW = Utils.floatFromInt(f32, rayLib.getScreenWidth());
    // var camera = rayLib.Camera2D{
    //     .target = self.player.rect.getPosition(),
    //     .offset = rayLib.Vector2.init(
    //         screenW / 2.0,
    //         screenH - 100.0, // Player pinned near bottom
    //     ),
    //     .rotation = 0.0,
    //     .zoom = 1.0,
    // };

    //     while (!rayLib.windowShouldClose()) {
    //         const dt = rayLib.getFrameTime();
    //         if (self.isGameOver) {
    //             self.resetGameState();
    //             continue;
    //         }

    //         const currentLevelObj = self.world.levels[self.currentLevel];
    //         const playerCenterX = self.player.getRect().getCenterX();

    //         // --- 1. UPDATE PHASE (Movement & Level Switching) ---
    //         // Pass the level bounds for horizontal clamping/walls
    //         self.player.handleMovement(dt, self.world.getRect());

    //         // Seamless Level Switching based on Player Center
    //         if (playerCenterX > currentLevelObj.getRect().getRightEdge()) {
    //             if (self.currentLevel < self.world.levels.len - 1) {
    //                 self.currentLevel += 1;
    //             }
    //         } else if (playerCenterX < currentLevelObj.getRect().getPosition().x) {
    //             if (self.currentLevel > 0) {
    //                 self.currentLevel -= 1;
    //             }
    //         }

    //         // --- 2. MULTI-LEVEL COLLISION ---
    //         // We check current, previous, and next level so the "seams" are solid
    //         var isOnGround = false;
    //         const checkOffsets = [_]isize{ -1, 0, 1 };

    //         for (checkOffsets) |offset| {
    //             const idx = @as(isize, @intCast(self.currentLevel)) + offset;
    //             if (idx >= 0 and idx < self.world.levels.len) {
    //                 const targetLevel = self.world.levels[@as(usize, @intCast(idx))];
    //                 for (targetLevel.staticPlatforms) |platform| {
    //                     self.checkForIntersection(dt, platform);
    //                     // Critical: set ground flag regardless of which level the platform belongs to
    //                     if (self.isOnTopOfPlatform(platform)) {
    //                         isOnGround = true;
    //                     }
    //                 }
    //             }
    //         }

    //         // Apply Grounded/Falling State
    //         self.player.setIsOnGround(isOnGround);
    //         if (isOnGround) {
    //             self.player.setIsFalling(false);
    //         } else if (self.player.getVelocity(.Y) > 0) {
    //             self.player.setIsFalling(true);
    //         }

    //         // --- 3. CAMERA LOGIC ---
    //         // Smoothly follow player
    // camera.target.x += (self.player.rect.getPosition().x - camera.target.x) * lerpFactor * dt;
    // camera.target.y += (self.player.rect.getPosition().y - camera.target.y) * lerpFactor * dt;

    //         // Global World Clamping (Stops camera at very beginning and very end of ALL levels)
    //         const startOfWorld = self.world.levels[0].getRect().getPosition().x;
    //         const endOfWorld = self.world.levels[self.world.levels.len - 1].getRect().getRightEdge();
    //         const halfViewX = (screenW / 2.0) / camera.zoom;
    //         const leftLimit = startOfWorld + halfViewX;
    //         const rightLimit = endOfWorld - halfViewX;
    //         if (camera.target.x < leftLimit) camera.target.x = leftLimit;
    //         if (camera.target.x > rightLimit) camera.target.x = rightLimit;

    //         // --- 4. CULLING RECT ---
    //         // Defines exactly what the camera "sees" in world coordinates
    //         const cameraRect = rayLib.Rectangle.init(
    //             camera.target.x - (camera.offset.x / camera.zoom),
    //             camera.target.y - (camera.offset.y / camera.zoom),
    //             screenW / camera.zoom,
    //             screenH / camera.zoom,
    //         );

    //         // --- 5. DRAW PHASE ---
    //         rayLib.beginDrawing();
    //         rayLib.clearBackground(rayLib.Color.sky_blue);
    //         rayLib.beginMode2D(camera);
    //         // Draw platforms from ALL levels, but only if they are on screen (Culling)
    //         for (self.world.levels) |lvl| {
    //             for (lvl.staticPlatforms) |platform| {
    //                 if (rayLib.checkCollisionRecs(cameraRect, platform.getRect().rect)) {
    //                     platform.draw();
    //                 }
    //             }
    //         }
    //         self.player.draw();
    //         rayLib.endMode2D();
    //         self.widgets.draw();
    //         rayLib.endDrawing();
    //     }
    // }
    fn createGameObjects(self: *Self) !void {
        self.widgets = Widgets.init();
        self.player = try Player.init(self.allocator, self.config);
        self.world = try World2(totalLevels, 0).init(self.allocator);
    }
    fn checkForIntersection(self: *Self, dt: f32, otherRect: Platform) void {
        const intersector = otherRect.getRect();
        if (self.player.getRect().intersects(intersector)) {
            // CASE: Falling onto a platform/Ground (Landing)
            if (self.player.getVelocity(.Y) > 0.0) {
                // Only land if we are actually above the intersector's surface
                // This prevents "teleporting" to the top if we hit the side
                if (self.player.rect.getPosition().y <= intersector.getTopEdge()) {
                    self.handleCollisions(dt, .FALLING, intersector, null);
                }
            }

            // CASE: Jumping into the bottom of a platform (Head Bump)
            else if (self.player.getVelocity(.Y) <= 0 and 0 == self.player.getVelocity(.X)) {
                // Only bump if our head is actually below the bottom edge
                if (self.player.rect.getPosition().y > intersector.getTopEdge()) {
                    self.handleCollisions(dt, .HEAD_BUMP, intersector, null);
                }
            } else if (otherRect.getRect().objectType.PLATFORM == .WALL) {
                if (self.player.getVelocity(.X) > 0 and self.player.getRect().getRightEdge() >= intersector.getPosition().x) {
                    self.handleCollisions(dt, .WALL, intersector, .RIGHT);
                } else if (self.player.getVelocity(.X) < 0 and self.player.getRect().getLeftEdge() >= intersector.getPosition().x) {
                    self.handleCollisions(dt, .WALL, intersector, .LEFT);
                }
            }
        } else {
            // 2. If NOT intersecting, check if we just walked off an edge
            // If the player thinks they are grounded, but they are no longer
            // horizontally aligned with THIS platform:
            if (self.isOnSurface(intersector) and self.isOffTheEdge(intersector)) {
                // We don't need to call checkForIntersection again.
                // Just let gravity take over in the next frame.
                self.player.startFalling(dt);
                self.handleCollisions(dt, .FALLING, intersector, null);
            }
        }
    }
    fn handleCollisions(self: *Self, dt: f32, collisionType: COLLISION_TYPES, otherRect: Rectangle, dirction: ?DIRECTION) void {
        switch (collisionType) {
            .FALLING => {
                //TODO: NEED TO FIGURE OUT HOW BOUNCE WILL WORK DONT WANT TO JUMP AND FALL AND BOUNCE AGAIN
                //SOMEHOW NEED TO FIGURE OUT HOW TO DITINGUISH BETWEEN A PLATFORM HEAD BUMP AND DAMAGE CAUSING A BOUNCE
                // EXAMPLE IF I FALL FROM A PLATFORM AND HIT THE GROUND SHOULD I BOUNCE?
                self.player.getRect().setPosition(.Y, otherRect.getTopEdge() - self.player.getRect().getHeight());
                self.player.setVelocity(.Y, 0.0);
                if (otherRect.damage.dealDamage) {
                    self.handleDamage(dt, .Y, otherRect);
                }
            },
            .WALL => {
                if (dirction) |di| {
                    if (di == .LEFT) {
                        self.player.setVelocity(.X, 0.0);
                        self.player.getRect().setPosition(.X, otherRect.getPosition().x + self.player.getRect().getWidth());
                    } else {
                        self.player.setVelocity(.X, 0.0);
                        self.player.getRect().setPosition(.X, otherRect.getPosition().x - self.player.getRect().getWidth());
                    }
                }
            },
            .HEAD_BUMP => {
                //TODO: NEED TO FIGURE OUT HOW BOUNCE WILL WORK DONT WANT TO JUMP AND FALL AND BOUNCE AGAIN
                //SOMEHOW NEED TO FIGURE OUT HOW TO DITINGUISH BETWEEN A PLATFORM HEAD BUMP AND DAMAGE CAUSING A BOUNCE
                // EXAMPLE IF I FALL FROM A PLATFORM AND HIT THE GROUND SHOULD I BOUNCE?
                self.player.getRect().setPosition(.Y, otherRect.getBottomEdge());
                self.player.setVelocity(.Y, 0.0);
                self.player.startFalling(dt);
                if (otherRect.damage.dealDamage) {
                    self.handleDamage(dt, .Y, otherRect);
                }
            },
        }
    }
    fn handleDamage(self: *Self, dt: f32, position: POSITION, otherRect: Rectangle) void {
        if (self.currentTime == 0.0) {
            self.currentTime = rayLib.getTime();
            self.player.applyDamage(dt, position, otherRect);
            self.widgets.healthBarRect.setWidth(self.player.getHealth());
        }
        const elapsedTime = rayLib.getTime() - self.currentTime;
        if (otherRect.damage.damageOverTime and elapsedTime > 1.0) {
            self.player.applyDamage(dt, position, otherRect);
            self.widgets.healthBarRect.setWidth(self.player.getHealth());
        }
        if (self.player.health <= 0) {
            self.handleGameOver();
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

//     // --- PHASE 1: INPUT & DIRECTIONMENT ---
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
