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
const EnemyAI = @import("../common/Entity.zig").CreateEnemyAI;
const TILE_SIZE_F = @import("../types.zig").TILE_SIZE_F;
const TILE_SIZE = @import("../types.zig").TILE_SIZE;
const EnemyAIType = @import("../common/AI.zig").EnemyAIType;
const PlayerProps = @import("../common/AI.zig").PlayerProps;
const CheckForCollisionsProps = @import("../common/AI.zig").CheckForCollisionsProps;
const Enemy = @import("./enemies.zig").Enemy;

pub const Config = struct {
    const Self = @This();
    // WINDOW_HEIGHT: i32 = 2500,
    // WINDOW_WIDTH: i32 = 1500,
    // WINDOW_DIVISOR: i32 = 2,
    tileSize: i32 = TILE_SIZE,
    tileSizeF: f32 = TILE_SIZE_F,
    fps: i32 = 60,
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
    enemyAI: EnemyAIType = undefined,
    screenHeight: f32 = 0.0,
    screenWidth: f32 = 0.0,

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
        self.enemyAI.deinit();
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
        self.screenHeight = screenH;
        self.screenWidth = screenW;
        var camera = rayLib.Camera2D{
            .target = self.player.rect.getPosition(),
            .offset = rayLib.Vector2.init(
                screenW / 2.0,
                screenH - 100.0, // Player pinned near bottom
            ),
            .rotation = 0.0,
            .zoom = 1.6, // impacts how much of the world if visible. Since my world is 32x32 a zoom of 1 is to much
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
        self.enemyAI = try EnemyAI(self.allocator);
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
        // const topRight = self.world.getTilesAt(pRightEdge - margin, pY);
        const topRightCeil = self.world.getTilesAt(pRightEdge + margin, pY - 1.0);
        const bottomLeft = self.world.getTilesAt(pX + margin, pBottomEdge);
        const bottomRight = self.world.getTilesAt(pRightEdge - margin, pBottomEdge);
        const middleLeft = self.world.getTilesAt(pX, pY + (pH / 2));
        const middleRight = self.world.getTilesAt(pRightEdge, pY + (pH / 2));
        const velY = self.player.getVelocity(.Y);
        const velX = self.player.getVelocity(.X);

        // --- VERTICAL COLLISIONS (Falling) ---
        if (velY >= 0.0) {
            // Find the top edge of the tile grid row the feet are currently in
            const gridY = @floor(pBottomEdge / TILE_SIZE_F) * TILE_SIZE_F;
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
                const leftEdgeOfGrid = @floor(pRightEdge / TILE_SIZE_F) * TILE_SIZE_F;
                const bottomOfGridElement = @floor(pTopEdge / TILE_SIZE_F) * TILE_SIZE_F;
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
                const rightEdgeOfGrid = @floor(pLeftEdge / TILE_SIZE_F) * TILE_SIZE_F;
                const bottomOfGridElement = @floor(pTopEdge / TILE_SIZE_F) * TILE_SIZE_F;
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
            }
        }
        // --- VERTICAL COLLISIONS Jumping ---
        else if (velY < 0.0) {
            if (middleRight == 5 or middleRight == 3) {
                // JUMPING AND MOVE RIGHT AND COLLIDE WITH AN OBJECT
                const leftEdgeOfGrid = @floor(pRightEdge / TILE_SIZE_F) * TILE_SIZE_F;
                const topOfGridElement = @floor(pBottomEdge / TILE_SIZE_F) * TILE_SIZE_F;
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
                //TODO: Add wall bounce effect here if desired and check for soid property some walls are not solid
            } else if (middleLeft == 5 or middleLeft == 3) {
                // JUMPING AND MOVE LEFT AND COLLIDE WITH ANY OBJECT
                const rightEdgeOfGrid = @floor(pLeftEdge / TILE_SIZE_F) * TILE_SIZE_F;
                const topOfGridElement = @floor(pBottomEdge / TILE_SIZE_F) * TILE_SIZE_F;
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
            } else if (topLeftCeil == 3 or topRightCeil == 3 or topLeftCeil == 5 or topRightCeil == 5) {
                // HEAD BUMP: Check if top hits a solid tile (ID 3 or 5)
                const id = if (topLeftCeil != 0) topLeftCeil else topRightCeil;
                const ceilLine = @ceil(pY / TILE_SIZE_F) * TILE_SIZE_F;
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
        //         const wallX = @floor((pRightEdge) / TILE_SIZE_F) * TILE_SIZE_F;
        //         self.player.rect.setPosition(.X, wallX - p_w);
        //         self.player.setVelocity(.X, 0);
        //     }
        // }
        // if (vel_x > 0) {
        //     if (middleRight == 3 or topRight == 3 or bottomRight == 3) {
        //         const wallX = @floor((pRightEdge) / TILE_SIZE_F) * TILE_SIZE_F;
        //         self.player.rect.setPosition(.X, wallX - p_w);
        //         self.player.setVelocity(.X, 0);
        //     }
        // } else if (vel_x < 0) {
        //     if (middleLeft == 3 or topLeft == 3 or bottomLeft == 3) {
        //         const wallX = @ceil(p_x / TILE_SIZE_F) * TILE_SIZE_F;
        //         self.player.rect.setPosition(.X, wallX);
        //         self.player.setVelocity(.X, 0);
        //     }
        // }

        // --- ENEMY COLLISIONS ---
        self.checkCollisionEnemies(dt, velX, velY, pLeftEdge, pRightEdge);
    }
    fn checkCollisionEnemies(self: *Self, dt: f32, velX: f32, velY: f32, pLeftEdge: f32, pRightEdge: f32) void {
        for (self.world.enemies.items) |enemy| {
            const leftEdge = enemy.rect.getLeftEdge();
            const rightEdge = enemy.rect.getRightEdge();
            self.enemyAI.update(
                dt,
                &PlayerProps.init(
                    self.player.getRect().getPosition(),
                    self.player.onGround,
                ),
                enemy,
            );
            if (velY > 0.0) {
                if (self.player.getRect().collidedWithTop(enemy.getRect()) and
                    (pRightEdge >= enemy.getRect().getLeftEdge() and pLeftEdge <= enemy.getRect().getRightEdge()))
                {
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
            if (0.0 == velY) {
                if (velX > 0.0) {
                    //PLAYER IS MOVING RIGHT AND IS AHEAD OF ENEMY DO NOTHING
                    if (pLeftEdge >= rightEdge) {
                        break;
                    } else if (pRightEdge >= leftEdge and self.player.getRect().collidedWithLeftEdge(enemy.getRect())) {
                        self.handleCollisionss(
                            dt,
                            .ENEMY_BODY,
                            leftEdge,
                            &enemy.rect.objectProperties,
                            .X,
                            .RIGHT,
                        );
                        break;
                    }
                } else if (velX < 0.0) {
                    //PLAYER IS MOVING LEFT BUT IS BEHIND ENEMY DO NOTHING
                    if (pRightEdge <= leftEdge) {
                        break;
                    }
                    if (pLeftEdge <= rightEdge and self.player.getRect().collidedWithRightEdge(enemy.getRect())) {
                        self.handleCollisionss(
                            dt,
                            .ENEMY_BODY,
                            rightEdge,
                            &enemy.rect.objectProperties,
                            .X,
                            .LEFT,
                        );
                        break;
                    }
                    //PLAYER IS MOVING LEFT AND IF AHEAD OF ENEMY BLOCK PLAYER FROM MOVING
                    else if (pLeftEdge >= rightEdge and self.player.getRect().collidedWithRightEdge(enemy.getRect())) {
                        self.handleCollisionss(
                            dt,
                            .ENEMY_BODY,
                            leftEdge,
                            &enemy.rect.objectProperties,
                            .X,
                            .LEFT,
                        );
                        break;
                    }
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
                        self.player.setVelocity(.X, 0.0);
                    } else if (dir == .LEFT) {
                        self.player.getRect().setPosition(position, objectPosition + self.player.getRect().getWidth());
                        self.player.setVelocity(.X, 0.0);
                    }
                } else {
                    self.player.getRect().setPosition(
                        position,
                        objectPosition - self.player.getRect().getHeight(),
                    );
                    self.player.setVelocity(.Y, 0.0);
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
        // Calculate what the camera actually sees
        const viewRect = rayLib.Rectangle{
            .x = camera.target.x - (camera.offset.x / camera.zoom),
            .y = camera.target.y - (camera.offset.y / camera.zoom),
            .width = self.screenWidth / camera.zoom,
            .height = self.screenHeight / camera.zoom,
        };
        for (self.world.enemies.items) |enemy| {
            const enemyCenterX = enemy.getRect().getCenterX();
            const currentEnemyLocation = Utils.intFromFloat(usize, enemyCenterX / self.world.getLevelWidth());
            const nextLevelIndex = @min(currentEnemyLocation, totalLevels - 1);
            if (enemy.enemyState != .DEAD and nextLevelIndex == self.world.getLevelIndex() and rayLib.Rectangle.checkCollision(
                viewRect,
                enemy.rect.rect,
            )) {
                enemy.draw();
            }
        }
        self.player.draw();
        rayLib.endMode2D();
        self.widgets.draw();
        rayLib.endDrawing();
    }
    fn isOnTopOfPlatform(self: Self, rect: *Rectangle) bool {
        // 1. Horizontal check (already works!)
        if (!self.player.rect.isWithinHorizontalBounds(rect)) return false;

        const playerBottom = self.player.rect.getBottomEdge();
        const platformTop = rect.getTopEdge();

        // 2. Are the feet between the top of the platform and a little bit inside it?
        // We check if the player is within a "skin" or "buffer" area (e.g., 4 pixels).
        const isFallingOrStanding = self.player.velocityY >= 0;
        const isAtCorrectHeight = playerBottom >= platformTop and playerBottom <= platformTop + 4.0;
        return isFallingOrStanding and isAtCorrectHeight;
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
    fn checkIfSolid(self: *Self, value: u8) bool {
        return self.world.getObjectProperties(value).?.isSolid;
    }
    fn createCheckForCollisionPorps(self: *Self, rect: *Rectangle, otherRect: *Rectangle) *CheckForCollisionsProps {
        const x = rect.getPosition().x;
        const y = rect.getPosition().y;
        const margin: f32 = 2.0;
        const rightEdge = rect.getRightEdge();
        const bottomEdge = rect.getBottomEdge();
        const height = rect.getHeight();
        const topLeftCeil = self.world.getTilesAt(x + margin, y - 1.0);
        //For Wall Detection (while moving):
        //You want to look slightly inside the player's height so you don't accidentally detect the floor as a wall.
        // const topLeftWall = self.world.getTilesAt(p_x + margin, p_y + 2.0);
        const topRight = self.world.getTilesAt(rightEdge - margin, y);
        const bottomLeft = self.world.getTilesAt(x + margin, bottomEdge);
        const bottomRight = self.world.getTilesAt(rightEdge - margin, bottomEdge);
        const middleLeft = self.world.getTilesAt(x, y + (height / 2));
        const middleRight = self.world.getTilesAt(rightEdge, y + (height / 2));
        return &CheckForCollisionsProps.init(
            topLeftCeil,
            topRight,
            bottomLeft,
            bottomRight,
            middleLeft,
            middleRight,
            otherRect,
        );
    }
};
