const std = @import("std");
const Rectangle = @import("../common/shapes.zig").Rectangle;
const GAME_OBJECT_TYPES = @import("../types.zig").GAME_OBJECT_TYPES;
const rayLib = @import("raylib");
const ENEMY_TYPES = @import("../types.zig").ENEMY_TYPES;
const ENEMY_STATE = @import("../types.zig").ENEMEY_STATE;
const TILE_SIZE_F32 = @import("../types.zig").TILE_SIZE_F32;

pub const Enemy = struct {
    const Self = @This();
    allocator: std.mem.Allocator,
    rect: Rectangle,
    isDynamic: bool = false,
    index: usize = 0,
    enemyAI: EnemyAI = undefined,
    enemyState: ENEMY_STATE = .IDEL,
    hp: f32 = 100.0,
    speedMultiplier: f32 = 2.0,
    velocityX: f32 = 0.0,
    speed: f32 = 100.0,

    pub fn init(allocator: std.mem.Allocator, index: usize, enemyType: ENEMY_TYPES, position: rayLib.Vector2, isDynamic: ?bool) !*Self {
        const enemyPtr = try allocator.create(Self);
        enemyPtr.* = Self{
            .index = index,
            .allocator = allocator,
            .rect = Rectangle.init(
                GAME_OBJECT_TYPES{ .ENEMY = enemyType },
                TILE_SIZE_F32,
                TILE_SIZE_F32,
                position,
                .red,
            ),
            .isDynamic = if (isDynamic != null) isDynamic.? else false,
        };
        enemyPtr.createAI();
        return enemyPtr;
    }
    pub fn deinit(self: *Self) void {
        self.allocator.destroy(self);
    }
    pub fn update(self: *Self, dt: f32, playerLocation: rayLib.Vector2) void {
        // std.debug.print("UPDATE: {d}\n", .{self.index});
        _ = self.enemyAI.update(dt, playerLocation, self);
    }
    pub fn draw(self: Self) void {
        self.rect.draw();
    }
    fn createAI(self: *Self) void {
        self.enemyAI = EnemyAI{
            .sequence = .{
                .children = &[_]EnemyAI{
                    .{ .checkHealth = .{ .hp = 100.0 } },
                    .{ .moveTowardsPlayer = .{} },
                },
            },
        };
    }
    // fn attack(self: *Self) void {

    // }
};

///Node - This is the interface for the enemy behavior
const EnemyAI = union(enum) {
    const Self = @This();
    sequence: Sequence,
    checkHealth: CheckHealth,
    moveTowardsPlayer: MoveTowardsPlayer,

    pub fn update(self: Self, dt: f32, playerLocation: rayLib.Vector2, enemy: *Enemy) ENEMY_STATE {
        return switch (self) {
            // "payload" is the specific struct instance (Sequence, CheckHealth, etc.)
            .sequence => |payload| payload.update(dt, playerLocation, enemy),
            .checkHealth => |payload| payload.update(dt, playerLocation, enemy),
            .moveTowardsPlayer => |payload| payload.update(dt, playerLocation, enemy),
        };
    }
};

const Sequence = struct {
    const Self = @This();
    children: []const EnemyAI,

    pub fn update(self: Self, dt: f32, playerLocation: rayLib.Vector2, enemy: *Enemy) ENEMY_STATE {
        std.debug.print("[Sequence] - calling sequence...\n", .{});
        for (self.children) |child| {
            const status = child.update(dt, playerLocation, enemy);
            if (status == .ALERT) {
                return status;
            }
        }
        return .IDEL;
    }
};

const CheckHealth = struct {
    const Self = @This();
    hp: f32,

    pub fn update(self: Self, dt: f32, playerLocation: rayLib.Vector2, _: *Enemy) ENEMY_STATE {
        std.debug.print("[CheckHealth] - dt: {d}, pLocation: {any} Checking Health (HP: {d:.0})... ", .{ dt, playerLocation, self.hp });
        if (self.hp > 20) {
            std.debug.print("OK.\n", .{});
            return .IDEL;
        }
        // std.debug.print("TOO LOW.\n", .{});
        return .IDEL;
    }
};

const MoveTowardsPlayer = struct {
    const Self = @This();
    const attackRange: f32 = 200.0;
    pub fn update(_: Self, dt: f32, playerLocation: rayLib.Vector2, enemy: *Enemy) ENEMY_STATE {
        const dx = @abs(playerLocation.x - enemy.rect.rect.x);
        const dy = @abs(playerLocation.y - enemy.rect.rect.y);
        std.debug.print("[MoveTowardsPlayer] Pathfinding to player. state: {any} playerLocation: {any} enemyLocation: {any} DX: {d}\n", .{ enemy.enemyState, playerLocation, enemy.rect.getPosition(), dx });
        if (dx < attackRange and dy < TILE_SIZE_F32) {
            enemy.enemyState = .ATTACK;
            std.debug.print("ATTACK\n", .{});
            enemy.velocityX = -enemy.speed;
            enemy.rect.addPosition(.X, enemy.velocityX * enemy.speedMultiplier * dt);
            return .ATTACK;
        } else if (dx > attackRange and dy < TILE_SIZE_F32 and enemy.enemyState == .ATTACK) {
            enemy.enemyState = .PATROL;
            enemy.velocityX = enemy.speed;
            enemy.rect.addPosition(.X, enemy.velocityX * enemy.speedMultiplier * dt);
            return .PATROL;
        }
        return .IDEL;
    }
};
