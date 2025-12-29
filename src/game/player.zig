const std = @import("std");
const rayLib = @import("raylib");
const Rectangle = @import("../common/shapes.zig").Rectangle;
const GAME_OBJECT_TYPES = @import("../types.zig").GAME_OBJECT_TYPES;
const MOVE = @import("../types.zig").MOVE;
const GRAVITY = @import("../types.zig").GRAVITY;
const PLAYER_STATE = @import("../types.zig").PLAYER_STATE;

pub const Player = struct {
    const Self = @This();
    allocator: std.mem.Allocator,
    velocityX: f32 = 100.0,
    rect: Rectangle,
    jumpHeight: f32 = -200.0,
    speedMultiplier: f32 = 2.0,
    jumpMultiplier: f32 = 2.0,
    fallingSpeed: f32 = 200.0,
    fallingMultiplier: f32 = 2.0,
    health: f32 = 100.0,
    stamina: f32 = 100.0,
    velocityY: f32 = 0.0,
    playerState: PLAYER_STATE = .GROUNDED, // BEFORE THIS WAS A BOOL onGround SHOULD I KEEP A BOOL OR A ENUM? ENUM SEEMS TO BE MORE WORK
    // jumpStartTime: f64 = 0.0,
    damageBounce: f32 = -200.0,
    canSwim: bool = false,

    pub fn init(allocator: std.mem.Allocator) !*Self {
        const playerPtr = try allocator.create(Self);
        playerPtr.* = Self{
            .allocator = allocator,
            .rect = Rectangle.init(
                GAME_OBJECT_TYPES{ .PLAYER = 0 },
                50.0,
                50.0,
                // Set player on bottom left of screen
                rayLib.Vector2.init(0.0, @as(f32, @floatFromInt(rayLib.getScreenHeight())) - 80.0),
                .red,
            ),
        };
        return playerPtr;
    }
    pub fn deinit(self: *Self) void {
        self.allocator.destroy(self);
    }
    pub fn handleMovement(self: *Self, dt: f32) void {
        if (rayLib.isKeyDown(rayLib.KeyboardKey.d)) {
            self.rect.position.x += self.velocityX * self.speedMultiplier * dt;
            self.checkBounds(MOVE.RIGHT);
        } else if (rayLib.isKeyDown(rayLib.KeyboardKey.a)) {
            self.rect.position.x -= self.velocityX * self.speedMultiplier * dt;
            self.checkBounds(MOVE.LEFT);
        }
        // Jumping
        if (rayLib.isKeyPressed(rayLib.KeyboardKey.w) and self.playerState == .GROUNDED) {
            self.velocityY = self.jumpHeight; //* self.jumpMultiplier;
            self.playerState = .JUMPING;
            // self.jumpStartTime = rayLib.getTime();
        }
        if (self.playerState == .JUMPING or self.playerState == .FALLING) {
            // Pull the velocity down gradually
            // Gravity should be high (e.g., 980 or 1200) to feel snappy
            self.velocityY += GRAVITY * dt;
            // Move the player based on the current velocity
            self.rect.position.y += self.velocityY * dt;
            self.playerState = .FALLING;
        }

        // if (!self.onGround) {
        //     self.rect.position.y += self.velocityY * dt;
        //     self.rect.setIsFalling(true);
        // }
        // const currentTime = rayLib.getTime();
        // if (currentTime - self.jumpStartTime >= 1.0 and !self.onGround) {
        //     self.velocityY += GRAVITY * dt; // Apply gravity every frame
        //     self.rect.position.y += self.velocityY * dt; // Update position based on velocityY
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
    pub fn applyDamageBound(self: *Self, dt: f32) void {
        self.velocityY = self.damageBounce;
        self.velocityY += GRAVITY * dt;
        self.rect.position.y += self.velocityY * dt;
        self.rect.position.x -= self.velocityX * dt;
        // self.playerState = .JUMPING;
    }
    pub fn setPlayerState(self: *Self, state: PLAYER_STATE) void {
        self.playerState = state;
    }
    pub fn getPlayerState(self: Self) PLAYER_STATE {
        return self.playerState;
    }
    fn checkBounds(self: *Self, move: MOVE) void {
        switch (move) {
            MOVE.LEFT => {
                if (self.rect.position.x < 0) {
                    self.rect.position.x = 0;
                }
            },
            MOVE.RIGHT => {
                if (self.rect.position.x + self.rect.width >= @as(f32, @floatFromInt(rayLib.getScreenWidth()))) {
                    self.rect.position.x = @as(f32, @floatFromInt(rayLib.getScreenWidth())) - self.rect.width;
                }
            },
        }
    }
};
