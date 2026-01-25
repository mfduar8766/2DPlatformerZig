const Enemy = @import("../game/enemies.zig").Enemy;
const rayLib = @import("raylib");
const std = @import("std");
const TILE_SIZE_F = @import("../types.zig").TILE_SIZE_F;
const Utils = @import("../utils//utils.zig");
const Rectangle = @import("./shapes.zig").Rectangle;

pub const EnemyAIType = AI(*Enemy);

pub const CheckForCollisionsProps = struct {
    const Self = @This();
    topLeftCeil: u8 = undefined,
    topRightCeil: u8 = undefined,
    bottomLeft: u8 = undefined,
    bottomRight: u8 = undefined,
    middleLeft: u8 = undefined,
    middleRight: u8 = undefined,
    rect: *Rectangle = undefined,

    pub fn init(
        topLeftCeil: u8,
        topRightCeil: u8,
        bottomLeft: u8,
        bottomRight: u8,
        middleLeft: u8,
        middleRight: u8,
        rect: *Rectangle,
    ) Self {
        return Self{
            .topLeftCeil = topLeftCeil,
            .topRightCeil = topRightCeil,
            .bottomLeft = bottomLeft,
            .bottomRight = bottomRight,
            .middleLeft = middleLeft,
            .middleRight = middleRight,
            .rect = rect,
        };
    }
};

pub const PlayerProps = struct {
    const Self = @This();
    position: rayLib.Vector2,
    isOnSolidSurface: bool,

    pub fn init(position: rayLib.Vector2, isOnSolidSurface: bool) Self {
        return Self{
            .position = position,
            .isOnSolidSurface = isOnSolidSurface,
        };
    }
};

pub fn CreateEnemyAI(allocator: std.mem.Allocator) !EnemyAIType {
    return try AI(*Enemy).init(allocator);
}

///This is the interface for the entity behavior
fn AI(comptime T: type) type {
    return union(enum) {
        const Self = @This();
        sequence: Sequence(T),
        checkHealth: CheckHealth(T),
        movement: Movement(T),
        // collisions: Collisions(T),

        pub fn init(allocator: std.mem.Allocator) !Self {
            const children = try allocator.alloc(AI(T), 2);
            children[0] = .{ .checkHealth = CheckHealth(T).init() };
            children[1] = .{ .movement = Movement(T).init() };
            // children[2] = .{ .collisions = Collisions(T).init() };
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
        pub fn update(self: *Self, dt: f32, playerProps: *const PlayerProps, objectType: T) void {
            switch (self.*) {
                .sequence => |*payload| payload.update(dt, playerProps, objectType),
                .checkHealth => |*payload| payload.update(dt, playerProps, objectType),
                .movement => |*payload| payload.update(dt, playerProps, objectType),
            }
        }
        // pub fn checkForCollisions(self: *Self, dt: f32, props: CheckForCollisionsProps, objectType: T) void {
        //     switch (self.*) {
        //         .collisions => |*payload| payload.checkForCollisions(dt, props, objectType),
        //         else => {},
        //     }
        // }
    };
}

fn Sequence(comptime T: type) type {
    return struct {
        const Self = @This();
        children: []AI(T),
        allocator: std.mem.Allocator,

        pub fn init(allocator: std.mem.Allocator, children: []AI(T)) Self {
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
        pub fn update(self: *Self, dt: f32, playerProps: *const PlayerProps, objectType: T) void {
            for (self.children) |*child| {
                child.update(dt, playerProps, objectType);
            }
        }
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

        pub fn update(_: *Self, _: f32, _: *const PlayerProps, objectType: T) void {
            switch (@TypeOf(objectType)) {
                *Enemy => {
                    var enemy = @as(*Enemy, objectType);
                    if (enemy.hp == halfHp) {} else if (enemy.hp <= oneForthHp) {
                        enemy.enemyState = .ALERT;
                    } else if (enemy.hp <= 0) {
                        enemy.enemyState = .DEAD;
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

        pub fn update(self: *Self, dt: f32, playerProps: *const PlayerProps, objectType: T) void {
            const playerX = playerProps.position.x;
            const playerY = playerProps.position.y;
            const playerPosition = playerProps.position;
            switch (@TypeOf(objectType)) {
                *Enemy => {
                    var enemy = @as(*Enemy, objectType);
                    const enemyX = enemy.getRect().getPosition().x;
                    const dx = @abs(playerX - enemy.getRect().getPosition().x);
                    const dy = @abs(playerY - enemy.getRect().getPosition().y);
                    // std.debug.print("state: {} playerX: {d} enemyX: {d} DX: {d} DY: {d}\n", .{
                    //     enemy.enemyState,
                    //     playerX,
                    //     enemyX,
                    //     dx,
                    //     dy,
                    // });
                    if (enemy.enemyState != .DEAD) {
                        if (enemy.enemyState == .ALERT or enemy.enemyState == .ATTACK) {
                            if (0.0 == dy) {
                                self.timer.reset();
                                enemy.getCoolDownTimer().reset();
                                enemy.update(dt, playerPosition, .IDEL, if (playerX < enemyX) .LEFT else .RIGHT);
                            }
                            if (dy > 0.0 and playerProps.isOnSolidSurface) {
                                self.timer.start();
                                if (self.timer.hasElapsed()) {
                                    std.debug.print("ELLAPSED\n", .{});
                                    self.timer.reset();
                                    enemy.handleCoolDown(dt, if (playerX < enemyX) .LEFT else .RIGHT);
                                }
                            }
                            if (dx >= outOfRange and !enemy.getCoolDownTimer().isRunning()) {
                                enemy.handleCoolDown(dt, if (playerX < enemyX) .LEFT else .RIGHT);
                            }
                        }
                        if (enemy.enemyState == .COOL_DOWN) {
                            enemy.handleCoolDown(dt, if (playerX < enemyX) .LEFT else .RIGHT);
                        }
                        if (enemy.enemyState != .COOL_DOWN and 0.0 == dy) {
                            if (dx < outOfRange and dx >= alertRange) {
                                enemy.update(dt, playerPosition, .ALERT, if (playerX < enemyX) .LEFT else .RIGHT);
                            } else if (dx < alertRange and dx <= attackRange) {
                                enemy.update(dt, playerPosition, .ATTACK, if (playerX < enemyX) .LEFT else .RIGHT);
                            }
                        }
                    }
                },
                else => {},
            }
        }
    };
}

//TODO: DO WE NEED THIS HERER?? OR HANDLE IT IN GAME.ZIG??
// fn Collisions(comptime T: type) type {
//     return struct {
//         const Self = @This();

//         pub fn init() Self {
//             return Self{};
//         }

//         pub fn checkForCollisions(_: *Self, _: f32, props: CheckForCollisionsProps, objectType: T) void {
//             switch (@TypeOf(objectType)) {
//                 *Enemy => {
//                     var enemy = @as(*Enemy, objectType);
//                     const rect = enemy.getRect();
//                     const x = rect.getPosition().x;
//                     const y = rect.getPosition().y;
//                     const rightEdge = rect.getRightEdge();
//                     const bottomEdge = rect.getBottomEdge();
//                     const height = rect.getHeight();
//                     const leftEdge = rect.getLeftEdge();
//                     const topEdge = rect.getTopEdge();
//                     const otherRectLeftEdge = props.rect.getLeftEdge();
//                     const otherRectRightEdge = props.rect.getRightEdge();
//                     const otherRectTopEdge = props.rect.getTopEdge();
//                     const otherRectBottomEdge = props.rect.getBottomEdge();

//                     // 1. Get tile IDs at critical points
//                     // const topLeft = self.world.getTilesAt(pX + margin, pY);

//                     //For Ceiling/Head-Bump Detection:
//                     //You want to look slightly above the player to see if they are about to hit something.
//                     //Code snippet
//                     const topLeftCeil = props.topLeftCeil;
//                     const topRight = props.topRightCeil;
//                     const bottomLeft = props.bottomLeft;
//                     const bottomRight = props.bottomRight;
//                     const middleRight = props.middleRight;
//                     const middleLeft = props.middleLeft;

//                     //For Wall Detection (while moving):
//                     //You want to look slightly inside the player's height so you don't accidentally detect the floor as a wall.
//                     // const topLeftWall = self.world.getTilesAt(p_x + margin, p_y + 2.0);
//                     const velY = enemy.getVelocity(.Y);
//                     //--- VERTICAL COLLISION FALLING ---
//                     if (velY >= 0.0) {}
//                     //--- VERTICAL COLLISION JUMPING ---
//                     else if (velY < 0.0) {}
//                     //--- HORIZONTAL COLLISIONS (Walls) ---
//                     else if (0.0 == velY) {
//                         if (otherRectLeftEdge <= leftEdge and  props.rect.collidedWithLeftEdge(rect)) {

//                         }
//                     }
//                 },
//                 *Player => {},
//                 else => {},
//             }
//         }
//     };
// }
