const std = @import("std");
const Rectangle = @import("../common/shapes.zig").Rectangle;
const GAME_OBJECT_TYPES = @import("../types.zig").GAME_OBJECT_TYPES;
const rayLib = @import("raylib");
const ENEMY_TYPES = @import("../types.zig").ENEMY_TYPES;
const ENEMY_STATE = @import("../types.zig").ENEMEY_STATE;
const TILE_SIZE_F = @import("../types.zig").TILE_SIZE_F;
const VELOCITY = @import("../types.zig").VELOCITY;
const DIRECTION = @import("../types.zig").DIRECTION;
const TImer = @import("../utils/utils.zig").Timer();
const Utils = @import("../utils//utils.zig");
const ObjectProperties = @import("../common/objectProperties.zig").ObjectProperties;
const DamageComponent = @import("../common/objectProperties.zig").DamageComponent;
const UpdateProps = @import("../common/Entity.zig").UpdateProps;
const PlayerPosition = @import("../common/Entity.zig").PlayerPosition;

pub const ProjectileProperties = struct {
    const Self = @This();
    objectType: GAME_OBJECT_TYPES,
    projectileLocation: rayLib.Vector2,
    projectileMaxRangeX: f32 = 200.0,
    projectileMaxRangeY: f32 = 200.0,
    radius: f32 = 3.0,
    objectProperties: *const ObjectProperties = undefined,
    color: rayLib.Color,
    velocityX: f32 = 5.0,
    velocityY: f32 = 5.0,

    pub fn init(
        objectType: GAME_OBJECT_TYPES,
        projectileLocation: rayLib.Vector2,
        projectileMaxRangeX: f32,
        projectileMaxRangeY: f32,
        color: rayLib.Color,
        objectProperties: *const ObjectProperties,
    ) Self {
        return Self{
            .objectType = objectType,
            .projectileLocation = projectileLocation,
            .projectileMaxRangeX = projectileMaxRangeX,
            .projectileMaxRangeY = projectileMaxRangeY,
            .color = color,
            .objectProperties = objectProperties,
        };
    }

    pub fn draw(self: Self) void {
        switch (self.objectType) {
            .PROJECTILES => |projectileType| {
                switch (projectileType) {
                    .BULLETS => rayLib.drawCircleV(self.projectileLocation, self.radius, self.color),
                    .ARROWS => {},
                    .MAGIC => {},
                }
            },
            else => {},
        }
    }
};

pub fn Projectile(total: comptime_int) type {
    return struct {
        const Self = @This();
        projectiles: [total]ProjectileProperties = undefined,
        count: isize = 0,

        pub fn init(
            objectType: GAME_OBJECT_TYPES,
            projectileLocation: rayLib.Vector2,
            projectileMaxRangeX: f32,
            projectileMaxRangeY: f32,
            color: rayLib.Color,
            objectProperties: *const ObjectProperties,
        ) Self {
            var projectiles: [total]ProjectileProperties = undefined;
            for (0..total) |i| {
                projectiles[i] = ProjectileProperties.init(
                    objectType,
                    projectileLocation,
                    projectileMaxRangeX,
                    projectileMaxRangeY,
                    color,
                    objectProperties,
                );
            }
            return Self{
                .count = Utils.safeIntCast(isize, projectiles.len - 1),
                .projectiles = projectiles,
            };
        }
        pub fn reload(self: *Self) void {
            self.count = Utils.safeIntCast(isize, self.projectiles.len - 1);
        }
    };
}

pub const Enemy = struct {
    const Self = @This();
    allocator: std.mem.Allocator,
    rect: Rectangle = undefined,
    isDynamic: bool = false,
    index: usize = 0,
    state: ENEMY_STATE = .IDEL,
    hp: f32 = 100.0,
    speedMultiplier: f32 = 1.5,
    velocityX: f32 = 0.0,
    velocityY: f32 = 0.0,
    speed: f32 = 100.0,
    coolDownTimer: TImer = TImer.init(1.3),
    weapon: ?Rectangle = null,
    projectile: ?Projectile(2) = null,
    objectProperties: ObjectProperties = undefined,

    pub fn init(
        allocator: std.mem.Allocator,
        index: usize,
        enemyType: ENEMY_TYPES,
        position: rayLib.Vector2,
        isDynamic: ?bool,
    ) !*Self {
        const enemyPtr = try allocator.create(Self);
        enemyPtr.* = Self{
            .index = index,
            .allocator = allocator,
            .rect = Rectangle.init(
                GAME_OBJECT_TYPES{ .ENEMY = enemyType },
                TILE_SIZE_F,
                TILE_SIZE_F,
                position,
                .red,
            ),
            .isDynamic = if (isDynamic != null) isDynamic.? else false,
            .objectProperties = ObjectProperties.init(
                .{ .ENEMY = enemyType },
                true,
                50.0,
                false,
                false,
                false,
                true,
                DamageComponent.init(
                    10.0,
                    false,
                ),
            ),
        };
        // enemyPtr.projectile =
        return enemyPtr;
    }
    pub fn deinit(self: *Self) void {
        self.allocator.destroy(self);
    }
    pub fn getRect(self: *Self) *Rectangle {
        return &self.rect;
    }
    pub fn update(self: *Self, dt: f32, _: *const UpdateProps, state: ENEMY_STATE, direction: DIRECTION) void {
        self.state = state;
        switch (state) {
            .IDEL => {
                self.velocityX = 0.0;
            },
            .ALERT => {
                self.velocityX = 0.0;
                // self.attack(playerPosition, direction);
            },
            .ATTACK => {
                if (direction == .LEFT) {
                    // self.attack(playerPosition, direction);
                    self.velocityX = -self.speed;
                    self.rect.addPosition(.X, self.velocityX * self.speedMultiplier * dt);
                } else if (direction == .RIGHT) {
                    // self.attack(playerPosition, direction);
                    self.velocityX = self.speed;
                    self.rect.addPosition(.X, self.velocityX * self.speedMultiplier * dt);
                }
            },
            .PATROL => {
                self.velocityX = self.speed;
                self.rect.addPosition(.X, self.velocityX * self.speedMultiplier * dt);
            },
            .DEAD => {},
            .COOL_DOWN => {},
        }
    }
    pub fn draw(self: *Self) void {
        self.rect.draw();
        // if (self.state == .ALERT) {
        //     if (self.projectile) |projectile| {
        //         if (projectile.count >= 0) {
        //             projectile.projectiles[Utils.safeIntCast(usize, projectile.count)].draw();
        //         }
        //     }
        // }
    }
    pub fn setVelocity(self: *Self, velociy: VELOCITY, value: f32) void {
        if (velociy == .X) {
            self.velocityX = value;
        } else {
            self.velocityY = value;
        }
    }
    pub fn getVelocity(self: Self, velocity: VELOCITY) f32 {
        if (velocity == .X) {
            return self.velocityX;
        } else {
            return self.velocityY;
        }
    }
    pub fn handleCoolDown(self: *Self, dt: f32, direction: DIRECTION) void {
        self.coolDownTimer.start();
        if (self.state != .COOL_DOWN) {
            self.state = .COOL_DOWN;
        }
        if (!self.coolDownTimer.hasElapsed()) {
            if (direction == .LEFT) {
                self.velocityX = self.speed;
                self.rect.addPosition(.X, self.velocityX * self.speedMultiplier * dt);
            } else if (direction == .RIGHT) {
                self.velocityX = self.speed;
                self.rect.subtractPosition(.X, self.velocityX * self.speedMultiplier * dt);
            }
        } else {
            self.state = .IDEL;
            self.velocityX = 0.0;
            self.coolDownTimer.reset();
        }
    }
    pub fn getCoolDownTimer(self: *Self) *TImer {
        return &self.coolDownTimer;
    }
    pub fn reload(self: *Self) void {
        if (self.projectile) |*projectile| {
            if (projectile.count < 0) {
                projectile.reload();
            }
        }
    }
    pub fn attack(self: *Self, props: *const UpdateProps, direction: DIRECTION) void {
        if (self.projectile) |*projectile| {
            const idx = Utils.safeIntCast(usize, projectile.count);
            var bullet = &projectile.projectiles[idx];
            const playerPosition = PlayerPosition{
                .playerLeftEdge = props.player.getRect().getLeftEdge(),
                .playerRightEdge = props.player.getRect().getRightEdge(),
                .playerTopEdge = props.player.getRect().getTopEdge(),
                .playerBottomEdge = props.player.getRect().getBottomEdge(),
            };
            if (direction == .LEFT) {
                self.handleBullets(false, false, &playerPosition, projectile, &bullet);
            } else if (direction == .RIGHT) {
                self.handleBullets(true, false, &playerPosition, projectile, &bullet);
            } else if (direction == .UP) {
                //
            }
        }
    }
    fn handleBullets(
        _: *Self,
        increaseVelX: bool,
        _: bool,
        playerPosition: *const PlayerPosition,
        projectile: *Projectile(2),
        projectileProps: **ProjectileProperties,
    ) void {
        if (increaseVelX) {
            projectileProps.*.projectileLocation.x += projectileProps.*.velocityX; //.projectileLocation.x += projectileProps.velocityX;
        } else {
            projectileProps.*.projectileLocation.x -= projectileProps.*.velocityX;
        }
        if (projectileProps.*.projectileMaxRangeX > 0.0) {
            if (projectileProps.*.projectileLocation.x <= projectileProps.*.projectileMaxRangeX) {
                if (projectile.count < 0) {
                    return;
                }
                projectile.count -= 1;
            }
        } else {
            if (!increaseVelX and projectileProps.*.projectileLocation.x <= playerPosition.rightEdge) {
                if (projectile.count < 0) {
                    return;
                }
                projectile.count -= 1;
            } else if (increaseVelX and projectileProps.*.projectileLocation.x >= playerPosition.leftEdge) {
                if (projectile.count < 0) {
                    return;
                }
                projectile.count -= 1;
            }
        }
    }
    fn createProjectiles(self: *Self) void {
        self.projectile = Projectile(2).init(
            .{ .PROJECTILES = .BULLETS },
            rayLib.Vector2.init(self.rect.getLeftEdge() - 3.0, self.rect.getCenterY()),
            0.0,
            0.0,
            .green,
            &ObjectProperties.init(
                .{ .PROJECTILES = .BULLETS },
                false,
                0.0,
                false,
                false,
                false,
                true,
                DamageComponent.init(
                    20.0,
                    false,
                ),
            ),
        );
    }
};
