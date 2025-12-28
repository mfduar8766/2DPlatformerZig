const std = @import("std");
const rayLib = @import("raylib");
const Rectangle = @import("../common/shapes.zig").Rectangle;
const GAME_OBJECT_TYPES = @import("../types.zig").GAME_OBJECT_TYPES;
const MOVE = @import("../types.zig").MOVE;

pub const Player = struct {
    const Self = @This();
    allocator: std.mem.Allocator,
    velocityX: f32 = 100.0,
    rect: Rectangle,
    jumpHeight: f32 = -200.0,
    speedMultiplier: f32 = 2.0,
    jumpMultiplier: f32 = 2.0,
    health: f32 = 100.0,
    stamina: f32 = 100.0,
    gravity: f32 = 100.0,
    velocityY: f32 = 0.0,
    onGround: bool = true,
    jumpStartTime: f64 = 0.0,

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
        if (rayLib.isKeyPressed(rayLib.KeyboardKey.w) and self.onGround) {
            self.velocityY = self.jumpHeight * self.jumpMultiplier;
            self.onGround = false;
            // self.jumpStartTime = rayLib.getTime();
        }
        // 3. Gravity & Vertical Position (The "Gradual" part)
        if (!self.onGround) {
            // Pull the velocity down gradually
            // Gravity should be high (e.g., 980 or 1200) to feel snappy
            self.velocityY += self.gravity * dt;
            // Move the player based on the current velocity
            self.rect.position.y += self.velocityY * dt;
        }

        // if (!self.onGround) {
        //     self.rect.position.y += self.velocityY * dt;
        //     self.rect.setIsFalling(true);
        // }
        // const currentTime = rayLib.getTime();
        // if (currentTime - self.jumpStartTime >= 1.0 and !self.onGround) {
        //     self.velocityY += self.gravity * dt; // Apply gravity every frame
        //     self.rect.position.y += self.velocityY * dt; // Update position based on velocityY
        // }
    }
    pub fn draw(self: *Self) void {
        self.rect.draw();
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
