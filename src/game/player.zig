const std = @import("std");
const rayLib = @import("raylib");
const Rectangle = @import("../common/shapes.zig").Rectangle;
const GAME_OBJECT_TYPES = @import("../types.zig").GAME_OBJECT_TYPES;
const MOVE = @import("../types.zig").MOVE;
const GRAVITY = @import("../types.zig").GRAVITY;
const PLAYER_STATE = @import("../types.zig").PLAYER_STATE;
const VELOCITY = @import("../types.zig").VELOCITY;
const Utils = @import("../utils/utils.zig");
const Config = @import("./game.zig").Config;

pub const Player = struct {
    const Self = @This();
    allocator: std.mem.Allocator,
    rect: Rectangle,
    jumpHeight: f32 = -200.0,
    speedMultiplier: f32 = 2.0,
    jumpMultiplier: f32 = 2.0,
    fallingSpeed: f32 = 100.0,
    fallingMultiplier: f32 = 2.0,
    health: f32 = 100.0,
    stamina: f32 = 100.0,
    velocityX: f32 = 0.0,
    velocityY: f32 = 0.0,
    playerState: PLAYER_STATE = .ALIVE, // BEFORE THIS WAS A BOOL onGround SHOULD I KEEP A BOOL OR A ENUM? ENUM SEEMS TO BE MORE WORK
    // jumpStartTime: f64 = 0.0,
    damageBounce: f32 = -100.0,
    spped: f32 = 100.0,
    canSwim: bool = false,
    onGround: bool = true,
    isFalling: bool = false,
    config: *Config,

    pub fn init(allocator: std.mem.Allocator, config: *Config) !*Self {
        const playerPtr = try allocator.create(Self);
        playerPtr.* = Self{
            .allocator = allocator,
            .rect = Rectangle.init(
                GAME_OBJECT_TYPES{ .PLAYER = 0 },
                50.0,
                50.0,
                rayLib.Vector2.init(
                    0.0,
                    Utils.floatFromInt(f32, rayLib.getScreenHeight()) - 50.0,
                ),
                .red,
            ),
            .config = config,
        };
        return playerPtr;
    }
    pub fn deinit(self: *Self) void {
        self.allocator.destroy(self);
    }
    pub fn getRect(self: Self) Rectangle {
        return self.rect;
    }
    pub fn handleMovement(self: *Self, dt: f32, levelBounds: Rectangle) void {
        if (self.velocityX > 0 and (!rayLib.isKeyDown(.d) or !rayLib.isKeyDown(.a))) {
            self.velocityX = 0.0;
        }
        if (rayLib.isKeyDown(.d)) {
            self.velocityX = self.spped;
            self.rect.addPosition(.X, self.velocityX * self.speedMultiplier * dt);
            self.checkBounds(MOVE.RIGHT, levelBounds);
        } else if (rayLib.isKeyDown(.a)) {
            self.velocityX = self.spped;
            self.rect.subtractPosition(.X, self.velocityX * self.speedMultiplier * dt);
            self.checkBounds(MOVE.LEFT, levelBounds);
        }

        if (rayLib.isKeyPressed(rayLib.KeyboardKey.w) and self.onGround) {
            self.velocityY = self.jumpHeight; //* self.jumpMultiplier;
            self.onGround = false;
            // self.jumpStartTime = rayLib.getTime();
        }
        if (!self.onGround) {
            // Pull the velocity down gradually
            // Gravity should be high (e.g., 980 or 1200) to feel snappy
            self.velocityY += GRAVITY * dt;
            // Move the player based on the current velocity
            self.rect.addPosition(.Y, self.velocityY * dt);
        }
        // const currentTime = rayLib.getTime();
        // if (currentTime - self.jumpStartTime >= 1.0 and !self.onGround) {
        //     self.velocityY += GRAVITY * dt; // Apply gravity every frame
        //     self.rect.addPosition(.Y, self.velocityY * dt); // Update position based on velocityY
        // }
    }
    pub fn draw(self: Self) void {
        self.rect.draw();
    }
    pub fn setDamage(self: *Self, damageAmount: f32) void {
        self.health = self.health - damageAmount;
    }
    pub fn getHealth(self: Self) f32 {
        return self.health;
    }
    pub fn setPlayerState(self: *Self, state: PLAYER_STATE) void {
        self.playerState = state;
    }
    pub fn getPlayerState(self: Self) PLAYER_STATE {
        return self.playerState;
    }
    pub fn setIsFalling(self: *Self, value: bool) void {
        self.isFalling = value;
    }
    pub fn getIsFalling(self: Self) bool {
        return self.isFalling;
    }
    pub fn setIsOnGround(self: *Self, value: bool) void {
        self.onGround = value;
    }
    pub fn getIsOnGround(self: Self) bool {
        return self.onGround;
    }
    pub fn setVelocity(self: *Self, velocity: VELOCITY, value: f32) void {
        if (velocity == .X) {
            self.velocityX = value;
        }
        self.velocityY = value;
    }
    pub fn getVelocity(self: Self, velocity: VELOCITY) f32 {
        if (velocity == .X) {
            return self.velocityX;
        }
        return self.velocityY;
    }
    pub fn applyDamageBounce(self: *Self, dt: f32) void {
        self.velocityY = self.damageBounce;
        self.velocityY += GRAVITY * dt;
        self.rect.addPosition(.Y, self.velocityY * dt);
        self.rect.subtractPosition(.X, self.velocityX * dt);
        self.onGround = false;
    }
    pub fn startFalling(self: *Self, dt: f32) void {
        self.onGround = false;
        self.velocityY = self.fallingSpeed;
        self.velocityY += GRAVITY * dt;
        self.rect.addPosition(.Y, self.velocityY * dt);
        self.isFalling = true;
    }
    pub fn reset(self: *Self) void {
        self.velocityX = 0.0;
        self.velocityY = 0.0;
        self.isFalling = false;
        self.onGround = true;
        self.playerState = .ALIVE;
        self.rect.setPosition(.X, 0.0);
        self.rect.setPosition(.Y, @as(f32, @floatFromInt(rayLib.getScreenHeight())) - 80.0);
    }
    // fn checkBounds(self: *Self, move: MOVE, levelBounds: Rectangle) void {
    //     switch (move) {
    //         MOVE.LEFT => {
    //             if (self.rect.getPosition().x < 0) {
    //                 self.rect.setPosition(.X, 0.0);
    //             }
    //         },
    //         MOVE.RIGHT => {
    //             if (self.rect.getRightEdge() >= levelBounds.getRightEdge()) {
    //                 self.rect.setPosition(.X, (levelBounds.getPosition().x + levelBounds.getWidth()) - self.rect.getWidth());
    //             }
    //         },
    //     }
    // }
    fn checkBounds(self: *Self, move: MOVE, worldBounds: Rectangle) void {
        switch (move) {
            MOVE.LEFT => {
                // Stop at the absolute beginning of Level 0
                if (self.rect.getPosition().x < worldBounds.getPosition().x) {
                    self.rect.setPosition(.X, worldBounds.getPosition().x);
                }
            },
            MOVE.RIGHT => {
                if (self.rect.getRightEdge() >= worldBounds.getRightEdge()) {
                    self.rect.setPosition(.X, worldBounds.getRightEdge() - self.getRect().getWidth());
                }
            },
        }
    }
};
