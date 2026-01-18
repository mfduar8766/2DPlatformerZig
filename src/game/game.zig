const std = @import("std");
const rayLib = @import("raylib");
const Player = @import("./player.zig").Player;
const Rectangle = @import("../common/shapes.zig").Rectangle;
const GAME_OBJECT_TYPES = @import("../types.zig").GAME_OBJECT_TYPES;
const GRAVITY = @import("../types.zig").GRAVITY;
const Utils = @import("../utils/utils.zig");
const POSITION = @import("../types.zig").POSITION;
const COLLISION_TYPES = @import("../types.zig").COLLISION_TYPES;
const DIRECTION = @import("../types.zig").DIRECTION;
const World = @import("./world.zig").World;
const ObjectProperties = @import("../common/objectProperties.zig").ObjectProperties;
const LevelBluePrintMappingObjectTypes = @import("./world.zig").LevelBluePrintMappingObjectTypes;
const Widgets = @import("./widgets.zig").Widgets;

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
    world: *World(totalLevels, 0) = undefined,

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
        // std.debug.print("LLL: {any}\n", .{@intFromEnum(LevelBluePrintMappingObjectTypes.GROUND)});
        while (!rayLib.windowShouldClose()) {
            const dt = rayLib.getFrameTime();
            try self.update(dt);
            self.handleCamera(dt, screenW, &camera);
            self.draw(camera);
        }
    }
    fn createGameObjects(self: *Self) !void {
        self.widgets = Widgets.init();
        self.player = try Player.init(self.allocator, self.config);
        self.world = try World(totalLevels, 0).init(self.allocator);
    }
    fn update(self: *Self, dt: f32) !void {
        self.player.handleMovement(dt, self.world.getRect());
        const playerCenterX = self.player.getRect().getCenterX();
        const currentPlayerLocation = Utils.intFromFloat(usize, playerCenterX / self.world.getLevelWidth());
        const nextLevelIndex = @min(currentPlayerLocation, totalLevels - 1);
        if (nextLevelIndex != self.world.getLevelIndex()) {
            std.debug.print("Moving to next level at index: {d}\n", .{nextLevelIndex});
            try self.world.loadLevel(nextLevelIndex);
        }
        if (nextLevelIndex == self.world.getLevelIndex()) {
            self.checkForCollisions(dt);
        }
    }
    fn checkForCollisions(self: *Self, dt: f32) void {
        const rect = self.player.getRect();
        const pX = rect.getPosition().x;
        const pY = rect.getPosition().y;
        const margin: f32 = 2.0;
        const pRightEdge = rect.getRightEdge();
        const pBottomEdge = rect.getBottomEdge();
        const pH = rect.getHeight();
        const pLeftEdge = rect.getLeftEdge();
        const pTopEdge = rect.getTopEdge();

        // 1. Get tile IDs at critical points
        // const topLeft = self.world.getTilesAt(pX + margin, pY);

        //For Ceiling/Head-Bump Detection:
        //You want to look slightly above the player to see if they are about to hit something.
        //Code snippet
        const topLeftCeil = self.world.getTilesAt(pX + margin, pY - 1.0);

        //For Wall Detection (while moving):
        //You want to look slightly inside the player's height so you don't accidentally detect the floor as a wall.
        // const topLeftWall = self.world.getTilesAt(p_x + margin, p_y + 2.0);
        const topRight = self.world.getTilesAt(pRightEdge - margin, pY);
        const bottomLeft = self.world.getTilesAt(pX + margin, pBottomEdge);
        const bottomRight = self.world.getTilesAt(pRightEdge - margin, pBottomEdge);
        const middleLeft = self.world.getTilesAt(pX, pY + (pH / 2));
        const middleRight = self.world.getTilesAt(pRightEdge, pY + (pH / 2));
        const velY = self.player.getVelocity(.Y);
        const velX = self.player.getVelocity(.X);

        if (velX > 0.0 and 0.0 == velY) {
            self.checkCollisionEnemies(dt, pLeftEdge, pRightEdge, .X);
        }
        // --- VERTICAL COLLISIONS (Falling) ---
        else if (velY >= 0.0) {
            // Find the top edge of the tile grid row the feet are currently in
            const gridY = @floor(pBottomEdge / 32.0) * 32.0;
            if (bottomLeft == 1 or bottomRight == 1) {
                // GROUND: Standard collision at the grid line
                if (pBottomEdge >= gridY) {
                    self.handleCollisionss(
                        dt,
                        .FALLING,
                        gridY,
                        &self.world.getObjectProperties(1).?,
                        .Y,
                        null,
                    );
                }
            } else if (bottomLeft == 2 or bottomRight == 2 or bottomLeft == 4 or bottomRight == 4) {
                self.player.startFalling(dt);
                // WATER/SPIKES: Collision at the offset (+5px)
                const waterSurfaceY = gridY + 5.0;
                if (pBottomEdge >= waterSurfaceY) {
                    const id = if (bottomLeft != 0) bottomLeft else bottomRight;
                    self.handleCollisionss(
                        dt,
                        .FALLING,
                        waterSurfaceY,
                        &self.world.getObjectProperties(id).?,
                        .Y,
                        null,
                    );
                } else {
                    // IMPORTANT: We are inside the tile but haven't hit the water surface yet.
                    // We must keep falling!
                    self.player.setIsOnGround(false);
                }
            } else if (bottomLeft == 5 and bottomRight == 5) {
                if (pBottomEdge >= gridY) {
                    self.handleCollisionss(
                        dt,
                        .FALLING,
                        gridY,
                        &self.world.getObjectProperties(5).?,
                        .Y,
                        null,
                    );
                }
            } else if (middleRight == 5 or middleRight == 3) {
                // FALLING AND MOVE RIGHT AND COLLIDE WITH AN OBJECT
                const leftEdgeOfGrid = @floor(pRightEdge / 32.0) * 32.0;
                const bottomOfGridElement = @floor(pTopEdge / 32.0) * 32.0;
                if (pRightEdge >= leftEdgeOfGrid and pTopEdge >= bottomOfGridElement) {
                    self.handleCollisionss(
                        dt,
                        .HORRIZONTAL,
                        leftEdgeOfGrid,
                        &self.world.getObjectProperties(middleRight).?,
                        .X,
                        .RIGHT,
                    );
                }
            } else if (middleLeft == 5 or middleLeft == 3) {
                // FALLING AND MOVE LEFT AND COLLIDE WITH ANY OBJECT
                const rightEdgeOfGrid = @floor(pLeftEdge / 32.0) * 32.0;
                const bottomOfGridElement = @floor(pTopEdge / 32.0) * 32.0;
                if (pLeftEdge >= rightEdgeOfGrid and pTopEdge >= bottomOfGridElement) {
                    self.handleCollisionss(
                        dt,
                        .HORRIZONTAL,
                        rightEdgeOfGrid,
                        &self.world.getObjectProperties(middleLeft).?,
                        .X,
                        .LEFT,
                    );
                }
            } else {
                // AIR: Nothing below feet
                self.player.setIsOnGround(false);
                self.checkCollisionEnemies(dt, 0.0, 0.0, .Y);
            }
        }
        // --- VERTICAL COLLISIONS Jumping ---
        else if (velY < 0.0) {
            if (middleRight == 5 or middleRight == 3) {
                // JUMPING AND MOVE RIGHT AND COLLIDE WITH AN OBJECT
                const leftEdgeOfGrid = @floor(pRightEdge / 32.0) * 32.0;
                const topOfGridElement = @floor(pBottomEdge / 32.0) * 32.0;
                if (pRightEdge >= leftEdgeOfGrid and pTopEdge <= topOfGridElement) {
                    self.handleCollisionss(
                        dt,
                        .HORRIZONTAL,
                        leftEdgeOfGrid,
                        &self.world.getObjectProperties(middleRight).?,
                        .X,
                        .RIGHT,
                    );
                }
            } else if (middleLeft == 5 or middleLeft == 3) {
                // JUMPING AND MOVE LEFT AND COLLIDE WITH ANY OBJECT
                const rightEdgeOfGrid = @floor(pLeftEdge / 32.0) * 32.0;
                const topOfGridElement = @floor(pBottomEdge / 32.0) * 32.0;
                if (pLeftEdge >= rightEdgeOfGrid and pTopEdge <= topOfGridElement) {
                    self.handleCollisionss(
                        dt,
                        .HORRIZONTAL,
                        rightEdgeOfGrid,
                        &self.world.getObjectProperties(middleLeft).?,
                        .X,
                        .LEFT,
                    );
                }
            } else if (topLeftCeil == 3 or topRight == 3 or topLeftCeil == 5 or topRight == 5) {
                // HEAD BUMP: Check if top hits a solid tile (ID 3 or 5)
                const id = if (topLeftCeil != 0) topLeftCeil else topRight;
                const ceilLine = @ceil(pY / 32.0) * 32.0;
                self.handleCollisionss(
                    dt,
                    .HEAD_BUMP,
                    ceilLine,
                    &self.world.getObjectProperties(id).?,
                    .Y,
                    null,
                );
            }
        }

        // --- HORIZONTAL COLLISIONS (Walls) ---
        // if (vel_x > 0) {
        //     if (middleRight == 3 or topRight == 3 or bottomRight == 3) {
        //         const wallX = @floor((pRightEdge) / 32.0) * 32.0;
        //         self.player.rect.setPosition(.X, wallX - p_w);
        //         self.player.setVelocity(.X, 0);
        //     }
        // }
        // if (vel_x > 0) {
        //     if (middleRight == 3 or topRight == 3 or bottomRight == 3) {
        //         const wallX = @floor((pRightEdge) / 32.0) * 32.0;
        //         self.player.rect.setPosition(.X, wallX - p_w);
        //         self.player.setVelocity(.X, 0);
        //     }
        // } else if (vel_x < 0) {
        //     if (middleLeft == 3 or topLeft == 3 or bottomLeft == 3) {
        //         const wallX = @ceil(p_x / 32.0) * 32.0;
        //         self.player.rect.setPosition(.X, wallX);
        //         self.player.setVelocity(.X, 0);
        //     }
        // }
    }
    fn checkCollisionEnemies(self: *Self, dt: f32, pLeftEdge: f32, pRightEdge: f32, position: POSITION) void {
        if (position == .Y) {
            for (self.world.enemies.items) |enemy| {
                if (enemy.isDynamic) {} else {
                    if (enemy.rect.intersects(self.player.rect)) {
                        self.handleCollisionss(
                            dt,
                            .ENEMY_BODY,
                            enemy.rect.getTopEdge(),
                            &enemy.rect.objectProperties,
                            .Y,
                            null,
                        );
                        break;
                    }
                }
            }
        } else {
            for (self.world.enemies.items) |enemy| {
                if (pLeftEdge <= enemy.rect.getLeftEdge() and self.ccollidedWithLeftEdge(&enemy.rect)) {
                    self.handleCollisionss(
                        dt,
                        .ENEMY_BODY,
                        enemy.rect.getLeftEdge(),
                        &enemy.rect.objectProperties,
                        .X,
                        .RIGHT,
                    );
                    break;
                } else if (pRightEdge >= enemy.rect.getLeftEdge() and self.collidedWithRightEdge(&enemy.rect)) {
                    self.handleCollisionss(
                        dt,
                        .ENEMY_BODY,
                        enemy.rect.getRightEdge(),
                        &enemy.rect.objectProperties,
                        .X,
                        .LEFT,
                    );
                    break;
                }
            }
        }
    }
    fn handleCollisionss(
        self: *Self,
        dt: f32,
        collisionType: COLLISION_TYPES,
        objectPosition: f32,
        properties: *const ObjectProperties,
        position: POSITION,
        direction: ?DIRECTION,
    ) void {
        switch (collisionType) {
            .FALLING => {
                switch (properties.objectType) {
                    LevelBluePrintMappingObjectTypes.GROUND, LevelBluePrintMappingObjectTypes.HORRIZONTAL_PLATFORMS => {
                        self.player.getRect().setPosition(
                            position,
                            objectPosition - self.player.getRect().getHeight(),
                        );
                        self.player.setVelocity(.Y, 0.0);
                        self.player.setIsOnGround(true);
                    },
                    LevelBluePrintMappingObjectTypes.WATER => self.player.getRect().setPosition(
                        position,
                        objectPosition - self.player.getRect().getHeight(),
                    ),
                    else => {},
                }
            },
            .WALL => {
                if (direction) |dir| {
                    if (dir == .LEFT) {}
                }
            },
            .HEAD_BUMP => {
                self.player.getRect().setPosition(position, objectPosition + self.player.getRect().getHeight());
                self.player.setVelocity(.Y, 0.0);
                self.player.startFalling(dt);
            },
            .HORRIZONTAL => {
                if (direction) |dir| {
                    if (dir == .RIGHT) {
                        self.player.getRect().setPosition(position, objectPosition - self.player.getRect().getWidth());
                    } else if (dir == .LEFT) {
                        // IF WANT WALBOUNCE DO objectPosition + self.player.getRect().getWidth() + SOME_BOUNCE_AMOUNT
                        self.player.getRect().setPosition(position, objectPosition + self.player.getRect().getWidth());
                    }
                }
            },
            .PLATFORM => {},
            .ENEMY_BODY => {
                if (direction) |dir| {
                    if (dir == .RIGHT) {
                        self.player.getRect().setPosition(position, objectPosition - self.player.getRect().getWidth());
                    } else if (dir == .LEFT) {
                        self.player.getRect().setPosition(position, objectPosition + self.player.getRect().getWidth());
                    }
                } else {
                    self.player.getRect().setPosition(
                        position,
                        objectPosition - self.player.getRect().getHeight(),
                    );
                }
            },
            else => {},
        }
        if (properties.damage != null) {
            self.handleDamage(dt, position, properties, direction);
        }
    }
    fn handleDamage(self: *Self, dt: f32, position: POSITION, properties: *const ObjectProperties, direction: ?DIRECTION) void {
        if (properties.damage) |damageComponent| {
            const damage = damageComponent.damageAmount;
            if (damageComponent.damageOverTime) {
                if (self.currentTime == 0.0) {
                    self.currentTime = rayLib.getTime();
                    self.player.applyDamage(damage);
                    self.player.applyObjectEffects(dt, position, properties, direction);
                    self.widgets.healthBarRect.setWidth(self.player.getHealth());
                }
                const elapsedTime = rayLib.getTime() - self.currentTime;
                if (damageComponent.damageOverTime and elapsedTime > 1.0) {
                    self.player.applyDamage(damage);
                    self.player.applyObjectEffects(dt, position, properties, direction);
                    self.widgets.healthBarRect.setWidth(self.player.getHealth());
                }
            } else {
                self.player.applyDamage(damage);
                self.player.applyObjectEffects(dt, position, properties, direction);
                self.widgets.healthBarRect.setWidth(self.player.getHealth());
            }
        }
        if (self.player.health <= 0) {
            self.handleGameOver();
        }
    }
    fn handleCamera(self: *Self, dt: f32, screenW: f32, camera: *rayLib.Camera2D) void {
        camera.target = rayLib.Vector2.lerp(camera.target, self.player.getRect().getPosition(), lerpFactor * dt);

        //Global World Clamping (Stops camera at very beginning and very end of world)
        const startOfWorld = self.world.getRect().getPosition().x;
        const endOfWorld = self.world.getRect().getRightEdge();
        const halfViewX = (screenW / 2.0) / camera.zoom;
        const leftLimit = startOfWorld + halfViewX;
        const rightLimit = endOfWorld - halfViewX;
        if (camera.target.x < leftLimit) camera.target.x = leftLimit;
        if (camera.target.x > rightLimit) camera.target.x = rightLimit;
    }
    fn draw(self: *Self, camera: rayLib.Camera2D) void {
        rayLib.beginDrawing();
        rayLib.beginMode2D(camera);
        rayLib.clearBackground(rayLib.Color.sky_blue);
        self.world.draw();
        for (self.world.enemies.items) |enemy| {
            enemy.draw();
        }
        self.player.draw();
        rayLib.endMode2D();
        self.widgets.draw();
        rayLib.endDrawing();
    }
    // fn checkForIntersection(self: *Self, dt: f32, otherRect: *Recttangle) void {
    //     const intersector = otherRect.getRect();
    //     if (self.player.getRect().intersects(intersector)) {
    //         // CASE: Falling onto a platform/Ground (Landing)
    //         if (self.player.getVelocity(.Y) > 0.0) {
    //             // Only land if we are actually above the intersector's surface
    //             // This prevents "teleporting" to the top if we hit the side
    //             if (self.player.rect.getPosition().y <= intersector.getTopEdge()) {
    //                 self.handleCollisions(dt, .FALLING, intersector, null);
    //             }
    //         }

    //         // CASE: Jumping into the bottom of a platform (Head Bump)
    //         else if (self.player.getVelocity(.Y) <= 0 and 0 == self.player.getVelocity(.X)) {
    //             // Only bump if our head is actually below the bottom edge
    //             if (self.player.rect.getPosition().y > intersector.getTopEdge()) {
    //                 self.handleCollisions(dt, .HEAD_BUMP, intersector, null);
    //             }
    //         } else if (otherRect.getRect().objectType.PLATFORM == .WALL) {
    //             if (self.player.getVelocity(.X) > 0 and self.player.getRect().getRightEdge() >= intersector.getPosition().x) {
    //                 self.handleCollisions(dt, .WALL, intersector, .RIGHT);
    //             } else if (self.player.getVelocity(.X) < 0 and self.player.getRect().getLeftEdge() >= intersector.getPosition().x) {
    //                 self.handleCollisions(dt, .WALL, intersector, .LEFT);
    //             }
    //         }
    //     } else {
    //         // 2. If NOT intersecting, check if we just walked off an edge
    //         // If the player thinks they are grounded, but they are no longer
    //         // horizontally aligned with THIS platform:
    //         if (self.isOnSurface(intersector) and self.isOffTheEdge(intersector)) {
    //             // We don't need to call checkForIntersection again.
    //             // Just let gravity take over in the next frame.
    //             self.player.startFalling(dt);
    //             self.handleCollisions(dt, .FALLING, intersector, null);
    //         }
    //     }
    // }
    // fn handleCollisions(self: *Self, dt: f32, collisionType: COLLISION_TYPES, otherRect: Rectangle, dirction: ?DIRECTION) void {
    //     switch (collisionType) {
    //         .FALLING => {
    //             //TODO: NEED TO FIGURE OUT HOW BOUNCE WILL WORK DONT WANT TO JUMP AND FALL AND BOUNCE AGAIN
    //             //SOMEHOW NEED TO FIGURE OUT HOW TO DITINGUISH BETWEEN A PLATFORM HEAD BUMP AND DAMAGE CAUSING A BOUNCE
    //             // EXAMPLE IF I FALL FROM A PLATFORM AND HIT THE GROUND SHOULD I BOUNCE?
    //             self.player.getRect().setPosition(.Y, otherRect.getTopEdge() - self.player.getRect().getHeight());
    //             self.player.setVelocity(.Y, 0.0);
    //             if (otherRect.damage.dealDamage) {
    //                 self.handleDamage(dt, .Y, otherRect);
    //             }
    //         },
    //         .WALL => {
    //             if (dirction) |di| {
    //                 if (di == .LEFT) {
    //                     self.player.setVelocity(.X, 0.0);
    //                     self.player.getRect().setPosition(.X, otherRect.getPosition().x + self.player.getRect().getWidth());
    //                 } else {
    //                     self.player.setVelocity(.X, 0.0);
    //                     self.player.getRect().setPosition(.X, otherRect.getPosition().x - self.player.getRect().getWidth());
    //                 }
    //             }
    //         },
    //         .HEAD_BUMP => {
    //             //TODO: NEED TO FIGURE OUT HOW BOUNCE WILL WORK DONT WANT TO JUMP AND FALL AND BOUNCE AGAIN
    //             //SOMEHOW NEED TO FIGURE OUT HOW TO DITINGUISH BETWEEN A PLATFORM HEAD BUMP AND DAMAGE CAUSING A BOUNCE
    //             // EXAMPLE IF I FALL FROM A PLATFORM AND HIT THE GROUND SHOULD I BOUNCE?
    //             self.player.getRect().setPosition(.Y, otherRect.getBottomEdge());
    //             self.player.setVelocity(.Y, 0.0);
    //             self.player.startFalling(dt);
    //             if (otherRect.damage.dealDamage) {
    //                 self.handleDamage(dt, .Y, otherRect);
    //             }
    //         },
    //     }
    // }
    // fn handleDamage(self: *Self, dt: f32, position: POSITION, otherRect: Rectangle) void {
    //     if (self.currentTime == 0.0) {
    //         self.currentTime = rayLib.getTime();
    //         self.player.applyDamage(dt, position, otherRect);
    //         self.widgets.healthBarRect.setWidth(self.player.getHealth());
    //     }
    //     const elapsedTime = rayLib.getTime() - self.currentTime;
    //     if (otherRect.damage.damageOverTime and elapsedTime > 1.0) {
    //         self.player.applyDamage(dt, position, otherRect);
    //         self.widgets.healthBarRect.setWidth(self.player.getHealth());
    //     }
    //     if (self.player.health <= 0) {
    //         self.handleGameOver();
    //     }
    // }
    ///Check if the player is horizontally overlapping the platform
    fn isWithinHorizontalBounds(self: Self, rect: *Rectangle) bool {
        return self.player.rect.getRightEdge() > rect.getLeftEdge() and
            self.player.rect.getLeftEdge() < rect.getRightEdge();
    }
    fn isOffTheEdge(self: Self, rect: *Rectangle) bool {
        return self.player.rect.getRightEdge() < rect.getPosition().x or self.player.rect.getPosition().x > rect.getRightEdge();
    }
    fn isOnSurface(self: Self, rect: *Rectangle) bool {
        // Rectangle.rect.getPosition().y - self.player.rect.height == self.player.rect.getPosition().y
        // 1. Check Horizontal (Aligned)
        if (!self.isWithinHorizontalBounds(rect)) return false;

        // 2. Check Vertical (Touching Surface)
        const pBottom = self.player.rect.getBottomEdge();
        const platTop = rect.getTopEdge();

        // Check if player's feet are within 1 pixel of the platform top
        const touchingSurface = @abs(pBottom - platTop) < 1.0;
        return touchingSurface;
    }
    fn isOnTopOfPlatform(self: Self, rect: *Rectangle) bool {
        // 1. Horizontal check (already works!)
        if (!self.isWithinHorizontalBounds(rect)) return false;

        const playerBottom = self.player.rect.getBottomEdge();
        const platformTop = rect.getTopEdge();

        // 2. Are the feet between the top of the platform and a little bit inside it?
        // We check if the player is within a "skin" or "buffer" area (e.g., 4 pixels).
        const isFallingOrStanding = self.player.velocityY >= 0;
        const isAtCorrectHeight = playerBottom >= platformTop and playerBottom <= platformTop + 4.0;
        return isFallingOrStanding and isAtCorrectHeight;
    }
    ///self.player.rect.getRightEdge() >= rect.getLeftEdge();
    fn ccollidedWithLeftEdge(self: Self, rect: *Rectangle) bool {
        return self.player.rect.getRightEdge() >= rect.getLeftEdge();
    }
    ///self.player.rect.getLeftEdge() <= rect.getRightEdge();
    fn collidedWithRightEdge(self: Self, rect: *Rectangle) bool {
        return self.player.rect.getLeftEdge() <= rect.getRightEdge();
    }
    ///
    fn collidedWithBottom(self: Self, rect: *Rectangle) bool {
        return self.player.rect.getTopEdge() >= rect.getBottomEdge();
    }
    ///self.player.rect.getBottomEdge() >= rect.getTopEdge();
    fn collidedWithTop(self: Self, rect: *Rectangle) bool {
        return self.player.rect.getBottomEdge() >= rect.getTopEdge();
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
