const Enemy = @import("../game/enemies.zig").Enemy;
const rayLib = @import("raylib");
const std = @import("std");
const TILE_SIZE_F = @import("../types.zig").TILE_SIZE_F;
const Utils = @import("../utils//utils.zig");
const Rectangle = @import("./shapes.zig").Rectangle;
const Player = @import("../game//player.zig").Player;
const COLLISION_TYPES = @import("../types.zig").COLLISION_TYPES;
const POSITION = @import("../types.zig").POSITION;
const DIRECTION = @import("../types.zig").DIRECTION;
const ObjectProperties = @import("../common//objectProperties.zig").ObjectProperties;
const LevelBluePrintMappingObjectTypes = @import("../game//world.zig").LevelBluePrintMappingObjectTypes;

pub const EnemyType = Entity(*Enemy);
pub const PlayerType = Entity(*Player);

pub const PlayerPosition = struct {
    playerLeftEdge: f32,
    playerRightEdge: f32,
    playerTopEdge: f32,
    playerBottomEdge: f32,
};

pub const UpdateProps = struct {
    const Self = @This();
    dt: f32,
    player: *Player,
    topLeftCeil: u8 = undefined,
    topRightCeil: u8 = undefined,
    bottomLeft: u8 = undefined,
    bottomRight: u8 = undefined,
    middleLeft: u8 = undefined,
    middleRight: u8 = undefined,
    objectProperties: ?*const ObjectProperties = undefined,
    levelObjectProperties: ?*const std.AutoHashMap(u8, ObjectProperties) = undefined,

    pub fn init(
        dt: f32,
        player: *Player,
        topLeftCeil: u8,
        topRightCeil: u8,
        bottomLeft: u8,
        bottomRight: u8,
        middleLeft: u8,
        middleRight: u8,
        objectProperties: ?*const ObjectProperties,
        levelObjectProperties: ?*const std.AutoHashMap(u8, ObjectProperties),
    ) Self {
        return Self{
            .dt = dt,
            .player = player,
            .topLeftCeil = topLeftCeil,
            .topRightCeil = topRightCeil,
            .bottomLeft = bottomLeft,
            .bottomRight = bottomRight,
            .middleLeft = middleLeft,
            .middleRight = middleRight,
            .objectProperties = objectProperties,
            .levelObjectProperties = levelObjectProperties,
        };
    }
};

pub fn CreateEntity(allocator: std.mem.Allocator, comptime T: type) !Entity(T) {
    return try Entity(T).init(allocator);
}

///This is the interface for the entity behavior
fn Entity(comptime T: type) type {
    return union(enum) {
        const Self = @This();
        sequence: Sequence(T),
        checkHealth: CheckHealth(T),
        movement: Movement(T),
        collisions: Collisions(T),
        damage: Damage(T),

        pub fn init(allocator: std.mem.Allocator) !Self {
            const children = try allocator.alloc(Entity(T), 4);
            children[0] = .{ .movement = Movement(T).init() };
            children[1] = .{ .collisions = Collisions(T).init() };
            children[2] = .{ .damage = Damage(T).init() };
            children[3] = .{ .checkHealth = CheckHealth(T).init() };
            return Self{
                .sequence = Sequence(T).init(allocator, children),
            };
        }
        pub fn deinit(self: *Self) void {
            switch (self.*) {
                .sequence => |*payload| payload.deinit(),
                else => {},
            }
        }
        pub fn update(self: *Self, props: *const UpdateProps, objectType: T) void {
            switch (self.*) {
                .sequence => |*payload| payload.update(props, objectType),
                .movement => |*payload| payload.update(props, objectType),
                .collisions => |*payload| payload.update(props, objectType),
                .damage => |*payload| payload.update(props, objectType),
                .checkHealth => |*payload| payload.update(props, objectType),
            }
        }
    };
}

fn Sequence(comptime T: type) type {
    return struct {
        const Self = @This();
        children: []Entity(T),
        allocator: std.mem.Allocator,

        pub fn init(allocator: std.mem.Allocator, children: []Entity(T)) Self {
            return Self{
                .children = children,
                .allocator = allocator,
            };
        }
        pub fn deinit(self: *Self) void {
            for (self.children) |*child| {
                child.deinit();
            }
            // Then free the slice itself
            self.allocator.free(self.children);
        }
        pub fn update(self: *Self, props: *const UpdateProps, objectType: T) void {
            for (self.children) |*child| {
                child.update(props, objectType);
            }
        }
        // pub fn checkForCollisions(self: *Self, dt: f32, objectType: T, props: CheckForCollisionsProps) void {
        //     for (self.children) |*child| {
        //         child.checkForCollisionsInternal(dt, objectType, props);
        //     }
        // }
    };
}

fn CheckHealth(comptime T: type) type {
    return struct {
        const Self = @This();
        const maxHp: f32 = 100.0;
        const oneForthHp: f32 = maxHp / 4.0;
        const halfHp: f32 = maxHp / 2.0;

        pub fn init() Self {
            return Self{};
        }
        pub fn update(_: *Self, _: *const UpdateProps, objectType: T) void {
            switch (@TypeOf(objectType)) {
                *Enemy => {
                    var enemy = @as(*Enemy, objectType);
                    if (enemy.hp == halfHp) {} else if (enemy.hp <= oneForthHp) {
                        enemy.state = .ALERT;
                    } else if (enemy.hp <= 0) {
                        enemy.state = .DEAD;
                    }
                },
                else => {},
            }
        }
    };
}

fn Movement(comptime T: type) type {
    return struct {
        const Self = @This();
        const attackRange: f32 = 150.0;
        const alertRange: f32 = 200.0;
        const outOfRange: f32 = 250.0;
        timer: Utils.Timer() = Utils.Timer().init(3.0),

        pub fn init() Self {
            return Self{};
        }
        pub fn update(self: *Self, props: *const UpdateProps, objectType: T) void {
            const dt = props.dt;
            const playerPosition = props.player.getRect().getPosition();
            const playerX = playerPosition.x;
            const playerY = playerPosition.y;
            switch (@TypeOf(objectType)) {
                *Enemy => {
                    var enemy = @as(*Enemy, objectType);
                    const enemyX = enemy.getRect().getPosition().x;
                    const dx = @abs(playerX - enemy.getRect().getPosition().x);
                    const dy = @abs(playerY - enemy.getRect().getPosition().y);
                    const state = enemy.state;
                    // const leftEdge = enemy.rect.getLeftEdge();
                    // std.debug.print("state: {} playerX: {d} enemyX: {d} eL: {d} DX: {d} DY: {d}\n", .{
                    //     state,
                    //     playerX,
                    //     enemyX,
                    //     leftEdge,
                    //     dx,
                    //     dy,
                    // });
                    if (state != .DEAD) {
                        if (enemy.state == .ALERT or state == .ATTACK) {
                            if (0.0 == dy) {
                                self.timer.reset();
                                enemy.getCoolDownTimer().reset();
                                enemy.update(dt, props, .IDEL, if (playerX < enemyX) .LEFT else .RIGHT);
                            }
                            if (dy > 0.0) {
                                if (props.player.onGround) {
                                    self.timer.start();
                                    if (self.timer.hasElapsed()) {
                                        self.timer.reset();
                                        enemy.handleCoolDown(dt, if (playerX < enemyX) .LEFT else .RIGHT);
                                    }
                                } else {
                                    enemy.reload();
                                }
                            }
                            if (dx >= outOfRange and !enemy.getCoolDownTimer().isRunning()) {
                                enemy.handleCoolDown(dt, if (playerX < enemyX) .LEFT else .RIGHT);
                            }
                        }
                        if (state == .COOL_DOWN) {
                            enemy.handleCoolDown(dt, if (playerX < enemyX) .LEFT else .RIGHT);
                        }
                        if (state != .COOL_DOWN and 0.0 == dy) {
                            if (dx < outOfRange and dx >= alertRange) {
                                enemy.update(dt, props, .ALERT, if (playerX < enemyX) .LEFT else .RIGHT);
                            } else if (dx < alertRange and dx <= attackRange) {
                                enemy.update(dt, props, .ATTACK, if (playerX < enemyX) .LEFT else .RIGHT);
                            }
                        }
                    }
                },
                else => {},
            }
        }
    };
}

fn Collisions(comptime T: type) type {
    return struct {
        const Self = @This();

        pub fn init() Self {
            return Self{};
        }
        pub fn update(self: *Self, props: *const UpdateProps, objectType: T) void {
            switch (@TypeOf(objectType)) {
                *Enemy => {
                    const enemy = @as(*Enemy, objectType);
                    if (enemy.projectile) |*projectile| {
                        if (projectile.count < 0) {
                            return;
                        }
                        const idx = Utils.safeIntCast(usize, projectile.count);
                        const prokectileProperties = projectile.projectiles[idx];
                        if (rayLib.checkCollisionCircleRec(
                            prokectileProperties.projectileLocation,
                            prokectileProperties.radius,
                            props.player.rect.rect,
                        )) {
                            std.debug.print("PROJECTILE-COLLIDED\n", .{});
                            // std.debug.print("COLLIDED IDX: {} pR: {} projX: {}\n", .{
                            //     projectile.count,
                            //     props.player.rect.getRightEdge(),
                            //     prokectileProperties.projectileLocation.x,
                            // });
                        }
                    }
                    self.checkCollisionsEnemy(props.player, enemy);
                },
                *Player => {
                    var player = @as(*Player, objectType);
                    const rect = player.getRect();
                    const dt = props.dt;
                    const pY = rect.getPosition().y;
                    const pRightEdge = rect.getRightEdge();
                    const pBottomEdge = rect.getBottomEdge();
                    const pLeftEdge = rect.getLeftEdge();
                    const pTopEdge = rect.getTopEdge();

                    // 1. Get tile IDs at critical points
                    // const topLeft = self.world.getTilesAt(pX + margin, pY);

                    //For Ceiling/Head-Bump Detection:
                    //You want to look slightly above the player to see if they are about to hit something.
                    //Code snippet
                    const topLeftCeil = props.topLeftCeil;

                    //For Wall Detection (while moving):
                    //You want to look slightly inside the player's height so you don't accidentally detect the floor as a wall.
                    // const topLeftWall = self.world.getTilesAt(p_x + margin, p_y + 2.0);
                    // const topRight = self.world.getTilesAt(pRightEdge - margin, pY);
                    const topRightCeil = props.topRightCeil;
                    const bottomLeft = props.bottomLeft;
                    const bottomRight = props.bottomRight;
                    const middleLeft = props.middleLeft;
                    const middleRight = props.middleRight;
                    const velY = player.getVelocity(.Y);

                    // --- VERTICAL COLLISIONS (Falling) ---
                    if (velY >= 0.0) {
                        // Find the top edge of the tile grid row the feet are currently in
                        const gridY = @floor(pBottomEdge / TILE_SIZE_F) * TILE_SIZE_F;
                        if (bottomLeft == 1 or bottomRight == 1) {
                            // GROUND: Standard collision at the grid line
                            if (pBottomEdge >= gridY) {
                                self.handleCollisionss(
                                    player,
                                    .FALLING,
                                    gridY,
                                    &self.getObjectProperties(props.levelObjectProperties, 1).?,
                                    .Y,
                                    null,
                                );
                            }
                        } else if (bottomLeft == 2 or bottomRight == 2 or bottomLeft == 4 or bottomRight == 4) {
                            player.startFalling(dt);
                            // WATER/SPIKES: Collision at the offset (+5px)
                            const waterSurfaceY = gridY + 5.0;
                            if (pBottomEdge >= waterSurfaceY) {
                                const id = if (bottomLeft != 0) bottomLeft else bottomRight;
                                self.handleCollisionss(
                                    player,
                                    .FALLING,
                                    waterSurfaceY,
                                    &self.getObjectProperties(props.levelObjectProperties, id).?,
                                    .Y,
                                    null,
                                );
                            } else {
                                // IMPORTANT: We are inside the tile but haven't hit the water surface yet.
                                // We must keep falling!
                                player.setIsOnGround(false);
                            }
                        } else if (bottomLeft == 5 and bottomRight == 5) {
                            if (pBottomEdge >= gridY) {
                                self.handleCollisionss(
                                    player,
                                    .FALLING,
                                    gridY,
                                    &self.getObjectProperties(props.levelObjectProperties, 5).?,
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
                                    player,
                                    .HORRIZONTAL,
                                    leftEdgeOfGrid,
                                    &self.getObjectProperties(props.levelObjectProperties, middleRight).?,
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
                                    player,
                                    .HORRIZONTAL,
                                    rightEdgeOfGrid,
                                    &self.getObjectProperties(props.levelObjectProperties, middleLeft).?,
                                    .X,
                                    .LEFT,
                                );
                            }
                        } else {
                            // AIR: Nothing below feet
                            player.setIsOnGround(false);
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
                                    player,
                                    .HORRIZONTAL,
                                    leftEdgeOfGrid,
                                    &self.getObjectProperties(props.levelObjectProperties, middleRight).?,
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
                                    player,
                                    .HORRIZONTAL,
                                    rightEdgeOfGrid,
                                    &self.getObjectProperties(props.levelObjectProperties, middleLeft).?,
                                    .X,
                                    .LEFT,
                                );
                            }
                        } else if (topLeftCeil == 3 or topRightCeil == 3 or topLeftCeil == 5 or topRightCeil == 5) {
                            // HEAD BUMP: Check if top hits a solid tile (ID 3 or 5)
                            const id = if (topLeftCeil != 0) topLeftCeil else topRightCeil;
                            const ceilLine = @ceil(pY / TILE_SIZE_F) * TILE_SIZE_F;
                            self.handleCollisionss(
                                player,
                                .HEAD_BUMP,
                                ceilLine,
                                &self.getObjectProperties(props.levelObjectProperties, id).?,
                                .Y,
                                null,
                            );
                        }
                    }
                },
                else => {},
            }
        }
        fn checkCollisionsEnemy(self: *Self, player: *Player, enemy: *Enemy) void {
            const velX = player.velocityX;
            const velY = player.velocityY;
            const playerLeftEdge = player.getRect().getLeftEdge();
            const playerRightEdge = player.getRect().getRightEdge();
            const rightEdge = enemy.getRect().getRightEdge();
            const leftEdge = enemy.getRect().getLeftEdge();

            if (velY > 0.0) {
                if (player.getRect().collidedWithTop(enemy.getRect()) and
                    (playerRightEdge >= enemy.getRect().getLeftEdge() and playerLeftEdge <= enemy.getRect().getRightEdge()))
                {
                    self.handleCollisionss(
                        player,
                        .ENEMY_BODY,
                        enemy.rect.getTopEdge(),
                        &enemy.objectProperties,
                        .Y,
                        null,
                    );
                    return;
                }
            }
            if (0.0 == velY) {
                if (velX > 0.0) {
                    //PLAYER IS MOVING RIGHT AND IS AHEAD OF ENEMY DO NOTHING
                    if (playerLeftEdge >= rightEdge) {
                        return;
                    } else if (player.getRect().collidedWithLeftEdge(enemy.getRect())) {
                        std.debug.print("COLLIDE-1\n", .{});
                        self.handleCollisionss(
                            player,
                            .ENEMY_BODY,
                            leftEdge,
                            &enemy.objectProperties,
                            .X,
                            .RIGHT,
                        );
                        return;
                    }
                } else if (velX < 0.0) {
                    //PLAYER IS MOVING LEFT BUT IS BEHIND ENEMY DO NOTHING
                    if (playerRightEdge <= leftEdge) {
                        return;
                    }
                    if (player.getRect().collidedWithRightEdge(enemy.getRect())) {
                        std.debug.print("COLLIDE-2\n", .{});
                        self.handleCollisionss(
                            player,
                            .ENEMY_BODY,
                            rightEdge,
                            &enemy.objectProperties,
                            .X,
                            .LEFT,
                        );
                        return;
                    }
                }
            }
            if (0.0 == velX and 0.0 == velY) {
                if (enemy.velocityX < 0.0) {
                    if (player.getRect().collidedWithLeftEdge(enemy.getRect())) {
                        std.debug.print("COLLIDE-3\n", .{});
                        self.handleCollisionss(
                            player,
                            .ENEMY_BODY,
                            leftEdge,
                            &enemy.objectProperties,
                            .X,
                            .RIGHT,
                        );
                        return;
                    }
                } else if (enemy.velocityX > 0.0) {
                    if (player.getRect().collidedWithRightEdge(enemy.getRect())) {
                        std.debug.print("COLLIDE-4\n", .{});
                        self.handleCollisionss(
                            player,
                            .ENEMY_BODY,
                            rightEdge,
                            &enemy.objectProperties,
                            .X,
                            .LEFT,
                        );
                        return;
                    }
                }
            }
        }
        fn handleCollisionss(
            _: *Self,
            player: *Player,
            collisionType: COLLISION_TYPES,
            objectPosition: f32,
            properties: *const ObjectProperties,
            position: POSITION,
            direction: ?DIRECTION,
        ) void {
            switch (collisionType) {
                .FALLING => {
                    switch (properties.objectType) {
                        .LEVELS => |level| {
                            switch (level) {
                                .GROUND, .HORRIZONTAL_PLATFORMS => {
                                    player.getRect().setPosition(
                                        position,
                                        objectPosition - player.getRect().getHeight(),
                                    );
                                    player.setVelocity(.Y, 0.0);
                                    player.setIsOnGround(true);
                                },
                                .WATER => player.getRect().setPosition(
                                    position,
                                    objectPosition - player.getRect().getHeight(),
                                ),
                                .WALL => {
                                    if (direction) |dir| {
                                        if (dir == .LEFT) {}
                                    }
                                },
                                else => {},
                            }
                        },
                        else => {},
                    }
                },
                .WALL => {
                    if (direction) |dir| {
                        if (dir == .LEFT) {}
                    }
                },
                .HEAD_BUMP => {
                    player.getRect().setPosition(position, objectPosition + player.getRect().getHeight());
                    player.setVelocity(.Y, 0.0);
                },
                .HORRIZONTAL => {
                    if (direction) |dir| {
                        if (dir == .RIGHT) {
                            player.getRect().setPosition(position, objectPosition - player.getRect().getWidth());
                        } else if (dir == .LEFT) {
                            // IF WANT WALBOUNCE DO objectPosition + player.getRect().getWidth() + SOME_BOUNCE_AMOUNT
                            player.getRect().setPosition(position, objectPosition + player.getRect().getWidth());
                        }
                    }
                },
                .PLATFORM => {},
                .ENEMY_BODY => {
                    if (direction) |dir| {
                        if (dir == .RIGHT) {
                            player.getRect().setPosition(position, objectPosition - player.getRect().getWidth());
                            player.setVelocity(.X, 0.0);
                        } else if (dir == .LEFT) {
                            player.getRect().setPosition(position, objectPosition + player.getRect().getWidth());
                            player.setVelocity(.X, 0.0);
                        }
                    } else {
                        player.getRect().setPosition(
                            position,
                            objectPosition - player.getRect().getHeight(),
                        );
                        player.setVelocity(.Y, 0.0);
                    }
                },
                else => {},
            }
            // if (properties.damage != null) {
            //     self.handleDamage(dt, position, properties, direction);
            // }
        }
        fn getObjectProperties(
            _: *Self,
            levelObjectProperties: ?*const std.AutoHashMap(u8, ObjectProperties),
            key: u8,
        ) ?ObjectProperties {
            if (levelObjectProperties) |props| {
                if (props.get(key)) |obj| {
                    return obj;
                } else {
                    return null;
                }
            } else {
                return null;
            }
        }
    };
}

fn Damage(comptime T: type) type {
    return struct {
        const Self = @This();

        pub fn init() Self {
            return Self{};
        }
        pub fn update(_: *Self, _: *const UpdateProps, _: T) void {}
    };
}

// pub fn CreateEntity(allocator: std.mem.Allocator, comptime T: type, objectType: T) !Entity(T) {
//     return try Entity(T).init(allocator, objectType);
// }
// fn Entity(comptime T: type) type {
//     return union(enum) {
//         const Self = @This();
//         sequence: Sequence(T),
//         checkHealth: CheckHealth(T),
//         movement: Movement(T),
//         collisions: Collisions(T),

//         pub fn init(allocator: std.mem.Allocator, objectType: T) !Self {
//             const children = try allocator.alloc(Entity(T), 3);
//             children[0] = .{ .checkHealth = CheckHealth(T).init() };
//             children[1] = .{ .movement = Movement(T).init() };
//             children[2] = .{ .collisions = Collisions(T).init() };
//             return Self{
//                 .sequence = Sequence(T).init(allocator, children, objectType),
//             };
//         }
//         pub fn deinit(self: *Self) void {
//             switch (self.*) {
//                 .sequence => |*payload| payload.deinit(),
//                 else => {},
//             }
//         }
//         pub fn handleMovement(self: *Self, dt: f32, rect: *Rectangle) void {
//             switch (self.*) {
//                 .sequence => |*payload| payload.handleMovement(dt, payload.objectType, rect),
//                 else => {},
//             }
//         }
//         // Helper for the Sequence to call children (requires objectType)
//         pub fn handleMovementInternal(self: *Self, dt: f32, objectType: T, rect: *Rectangle) void {
//             switch (self.*) {
//                 .sequence => |*payload| payload.handleMovement(dt, objectType, rect),
//                 .movement => |*payload| payload.handleMovement(dt, objectType, rect),
//                 else => {},
//             }
//         }
//         pub fn update(self: *Self, dt: f32, playerProps: *const PlayerProps) void {
//             switch (self.*) {
//                 .sequence => |*payload| payload.update(dt, payload.objectType, playerProps),
//             }
//         }
//         pub fn updateInternal(self: *Self, dt: f32, object: T, playerProps: *const PlayerProps) void {
//             switch (self.*) {
//                 .sequence => |*payload| payload.update(dt, object, playerProps),
//                 .checkHealth => |*payload| payload.update(dt, object, playerProps),
//                 .movement => |*payload| payload.update(dt, object, playerProps),
//                 .collisions => |*payload| payload.update(dt, object, playerProps),
//             }
//         }
//         pub fn checkForCollisions(self: *Self, dt: f32, props: CheckForCollisionsProps) void {
//             switch (self.*) {
//                 .sequence => |*payload| payload.checkForCollisions(dt, payload.objectType, props),
//                 // .collisions => |*payload| payload.checkForCollisions(dt, objectType, props),
//                 else => {},
//             }
//         }
//         pub fn checkForCollisionsInternal(self: *Entity(T), dt: f32, objectType: T, props: CheckForCollisionsProps) void {
//             switch (self.*) {
//                 .sequence => |*payload| payload.checkForCollisions(dt, objectType, props),
//                 .collisions => |*payload| payload.checkForCollisions(dt, objectType, props),
//                 else => {},
//             }
//         }
//     };
// }

// fn Sequence(comptime T: type) type {
//     return struct {
//         const Self = @This();
//         children: []Entity(T),
//         allocator: std.mem.Allocator,
//         objectType: T,

//         pub fn init(allocator: std.mem.Allocator, children: []Entity(T), objectType: T) Self {
//             return Self{
//                 .children = children,
//                 .allocator = allocator,
//                 .objectType = objectType,
//             };
//         }
//         pub fn deinit(self: *Self) void {
//             for (self.children) |*child| {
//                 child.deinit();
//             }
//             // Then free the slice itself
//             self.allocator.free(self.children);
//         }
//         pub fn update(self: *Self, dt: f32, objectType: T, playerProps: *const PlayerProps) void {
//             for (self.children) |*child| {
//                 child.updateInternal(dt, objectType, playerProps);
//             }
//         }
//         pub fn checkForCollisions(self: *Self, dt: f32, objectType: T, props: CheckForCollisionsProps) void {
//             for (self.children) |*child| {
//                 child.checkForCollisionsInternal(dt, objectType, props);
//             }
//         }
//     };
// }
