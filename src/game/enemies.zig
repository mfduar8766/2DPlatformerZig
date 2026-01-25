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

pub const Enemy = struct {
    const Self = @This();
    allocator: std.mem.Allocator,
    rect: Rectangle,
    isDynamic: bool = false,
    index: usize = 0,
    enemyState: ENEMY_STATE = .IDEL,
    hp: f32 = 100.0,
    speedMultiplier: f32 = 1.5,
    velocityX: f32 = 0.0,
    velocityY: f32 = 0.0,
    speed: f32 = 100.0,
    coolDownTimer: TImer = TImer.init(1.3),
    isPatroling: bool = false,
    shouldBaclkOff: bool = false,

    pub fn init(allocator: std.mem.Allocator, index: usize, enemyType: ENEMY_TYPES, position: rayLib.Vector2, isDynamic: ?bool) !*Self {
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
        };
        return enemyPtr;
    }
    pub fn deinit(self: *Self) void {
        self.allocator.destroy(self);
    }
    pub fn update(self: *Self, dt: f32, _: rayLib.Vector2, state: ENEMY_STATE, direction: DIRECTION) void {
        self.enemyState = state;
        if (state == .ATTACK) {
            if (direction == .LEFT) {
                self.velocityX = self.speed;
                self.rect.subtractPosition(.X, self.velocityX * self.speedMultiplier * dt);
            } else if (direction == .RIGHT) {
                self.velocityX = self.speed;
                self.rect.addPosition(.X, self.velocityX * self.speedMultiplier * dt);
            }
        } else if (state == .PATROL) {
            self.velocityX = self.speed;
            self.rect.addPosition(.X, self.velocityX * self.speedMultiplier * dt);
        } else if (state == .IDEL) {
            self.velocityX = 0.0;
        }
    }
    pub fn getRect(self: *Self) *Rectangle {
        return &self.rect;
    }
    pub fn draw(self: Self) void {
        self.rect.draw();
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
        if (self.enemyState != .COOL_DOWN) {
            self.enemyState = .COOL_DOWN;
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
            self.enemyState = .IDEL;
            self.velocityX = 0.0;
            self.coolDownTimer.reset();
        }
    }
    pub fn getCoolDownTimer(self: *Self) *TImer {
        return &self.coolDownTimer;
    }
    // fn attack(self: *Self) void {

    // }
};
