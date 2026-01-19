const Enemy = @import("../game/enemies.zig").Enemy;
const rayLib = @import("raylib");
const std = @import("std");
const TILE_SIZE_F32 = @import("../types.zig").TILE_SIZE_F32;

pub fn CreateEnemyAI() AI(*Enemy) {
    return AI(*Enemy).init();
}

///This is the interface for the entity behavior
fn AI(comptime T: type) type {
    return union(enum) {
        const Self = @This();
        sequence: Sequence(T),
        checkHealth: CheckHealth(T),
        moveTowardsPlayer: MoveTowardsPlayer(T),

        pub fn init() Self {
            return Self{
                .sequence = .{
                    .children = &[_]AI(T){
                        .{ .checkHealth = .{ .hp = 100.0 } },
                        .{ .moveTowardsPlayer = .{} },
                    },
                },
            };
        }
        pub fn update(self: Self, dt: f32, playerLocation: rayLib.Vector2, objectType: T) void {
            return switch (self) {
                // "payload" is the specific struct instance (Sequence, CheckHealth, etc.)
                .sequence => |payload| payload.update(dt, playerLocation, objectType),
                .checkHealth => |payload| payload.update(dt, playerLocation, objectType),
                .moveTowardsPlayer => |payload| payload.update(dt, playerLocation, objectType),
            };
        }
    };
}

fn Sequence(comptime T: type) type {
    return struct {
        const Self = @This();
        children: []const AI(T),

        pub fn update(self: Self, dt: f32, playerLocation: rayLib.Vector2, objectType: T) void {
            // std.debug.print("[Sequence] - calling sequence...\n", .{});
            for (self.children) |child| {
                child.update(dt, playerLocation, objectType);
                // const status = child.update(dt, playerLocation, enemy);
                // if (status == .ALERT) {
                //     //
                // }
            }
        }
    };
}

fn CheckHealth(comptime T: type) type {
    return struct {
        const Self = @This();
        hp: f32 = 100.0,

        pub fn update(_: Self, _: f32, _: rayLib.Vector2, objectType: T) void {
            // std.debug.print("[CheckHealth] - dt: {d}, pLocation: {any} Checking Health (HP: {d:.0})... ", .{ dt, playerLocation, self.hp });
            // std.debug.print("OK.\n", .{});
            // std.debug.print("TOO LOW.\n", .{});
            switch (@TypeOf(objectType)) {
                *Enemy => {
                    var enemy = @as(*Enemy, objectType);
                    if (enemy.hp <= 20.0) {
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

fn MoveTowardsPlayer(comptime T: type) type {
    return struct {
        const Self = @This();
        const attackRange: f32 = 200.0;
        const outOfRange: f32 = 250.0;
        pub fn update(_: Self, dt: f32, playerPosition: rayLib.Vector2, objectType: T) void {
            const playerX = playerPosition.x;
            const playerY = playerPosition.y;
            switch (@TypeOf(objectType)) {
                *Enemy => {
                    var enemy = @as(*Enemy, objectType);
                    const enemyX = enemy.getRect().getPosition().x;
                    // const enemyY = enemy.getRect().getPosition().y;
                    const dx = @abs(playerX - enemy.getRect().getPosition().x);
                    const dy = @abs(playerY - enemy.getRect().getPosition().y);
                    // std.debug.print("[MoveTowardsPlayer] Pathfinding to player. state: {any} playerPos: {any} enemyLocation: {any} DX: {d}\n", .{
                    //     objectType.enemyState,
                    //     playerPosition,
                    //     enemy.getRect().getPosition(),
                    //     dx,
                    // });
                    if ((enemy.enemyState == .IDEL or enemy.enemyState != .DEAD) and dx >= outOfRange) {
                        enemy.startCoolDown();
                    }
                    if (playerX < enemyX) {
                        if (dx < attackRange and dy < TILE_SIZE_F32) {
                            enemy.update(dt, playerPosition, .ATTACK, .LEFT);
                        } else if (dx > attackRange and dy < TILE_SIZE_F32 and objectType.enemyState == .ATTACK) {
                            enemy.update(dt, playerPosition, .PATROL, .LEFT);
                        }
                    } else if (playerX > enemyX) {
                        std.debug.print("GREATER\n", .{});
                        if (dx < attackRange and dy < TILE_SIZE_F32) {
                            enemy.update(dt, playerPosition, .ATTACK, .RIGHT);
                        } else if (dx > attackRange and dy < TILE_SIZE_F32 and objectType.enemyState == .ATTACK) {
                            enemy.update(dt, playerPosition, .PATROL, .RIGHT);
                        }
                    }
                    // if (dx < attackRange and dy < TILE_SIZE_F32) {
                    //     enemy.update(dt, playerPosition, .ATTACK);
                    // } else if (dx > attackRange and dy < TILE_SIZE_F32 and objectType.enemyState == .ATTACK) {
                    //     enemy.update(dt, playerPosition, .PATROL);
                    // }
                    // enemy.update(dt, playerPosition, .IDEL);
                },
                else => {},
            }
        }
    };
}
