const Enemy = @import("../game/enemies.zig").Enemy;
const rayLib = @import("raylib");
const std = @import("std");
const TILE_SIZE_F = @import("../types.zig").TILE_SIZE_F;
const Utils = @import("../utils//utils.zig");

pub const EnemyAIType = AI(*Enemy);

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

        pub fn init(allocator: std.mem.Allocator) !Self {
            const children = try allocator.alloc(AI(T), 2);
            children[0] = .{ .checkHealth = CheckHealth(T).init() };
            children[1] = .{ .movement = Movement(T).init() };
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
        pub fn update(self: *Self, dt: f32, playerLocation: rayLib.Vector2, objectType: T) void {
            switch (self.*) {
                .sequence => |*payload| payload.update(dt, playerLocation, objectType),
                .checkHealth => |*payload| payload.update(dt, playerLocation, objectType),
                .movement => |*payload| payload.update(dt, playerLocation, objectType),
            }
        }
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
        pub fn update(self: *Self, dt: f32, playerLocation: rayLib.Vector2, objectType: T) void {
            for (self.children) |*child| {
                child.update(dt, playerLocation, objectType);
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

        pub fn update(_: *Self, _: f32, _: rayLib.Vector2, objectType: T) void {
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
        isPlayerOnGroundLevel: bool = true,

        pub fn init() Self {
            return Self{};
        }

        pub fn update(self: *Self, dt: f32, playerPosition: rayLib.Vector2, objectType: T) void {
            const playerX = playerPosition.x;
            const playerY = playerPosition.y;
            switch (@TypeOf(objectType)) {
                *Enemy => {
                    var enemy = @as(*Enemy, objectType);
                    const enemyX = enemy.getRect().getPosition().x;
                    const enemyY = enemy.getRect().getPosition().y;
                    const dx = @abs(playerX - enemy.getRect().getPosition().x);
                    self.isPlayerOnGroundLevel = playerY == enemyY;
                    // const dy = @abs(playerY - enemy.getRect().getPosition().y);
                    std.debug.print("state: {} isOnGround: {} playerX: {d} playerY: {d} enemyX: {d} enemyY: {d} DX: {d}\n", .{
                        enemy.enemyState,
                        self.isPlayerOnGroundLevel,
                        playerX,
                        playerY,
                        enemyX,
                        enemyY,
                        dx,
                    });
                    if (enemy.enemyState != .DEAD) {
                        if (enemy.enemyState == .ALERT or enemy.enemyState == .ATTACK) {
                            if (self.isPlayerOnGroundLevel and self.timer.isRunning()) {
                                self.timer.reset();
                                enemy.resetCoolDownTimer();
                            }
                            if (!self.isPlayerOnGroundLevel and !self.timer.isRunning()) {
                                std.debug.print("STARAT-TIMER\n", .{});
                                self.timer.start();
                                if (self.timer.hasElapsed()) {
                                    std.debug.print("ELLAPSED\n", .{});
                                    self.timer.reset();
                                    enemy.handleCoolDown(dt, if (playerX < enemyX) .LEFT else .RIGHT);
                                }
                            }
                            if (dx >= outOfRange) {
                                enemy.handleCoolDown(dt, if (playerX < enemyX) .LEFT else .RIGHT);
                            }
                        }
                        if (enemy.enemyState == .COOL_DOWN) {
                            enemy.handleCoolDown(dt, if (playerX < enemyX) .LEFT else .RIGHT);
                        }
                        if (enemy.enemyState != .COOL_DOWN) {
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
