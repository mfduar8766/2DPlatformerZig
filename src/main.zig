const std = @import("std");
const _2DPlatformerZig = @import("_2DPlatformerZig");
const rayLib = @import("raylib");
const Game = @import("./game/game.zig").Game;

//Had to install deps
//sudo apt install libxinerama-dev libxrandr-dev
//sudo apt install libxcursor-dev libx11-dev
//sudo apt install libx11-dev libxi-dev libglu1-mesa-dev
//sudo apt install libgl1-mesa-dev libglx-dev

const SCREEN_HEIGHT: i32 = 2500;
const SCREEN_WIDTH: i32 = 1500;
const SCREEN_DIVISOR: i32 = 2;

const MOVE = enum(u2) {
    LEFT = 0,
    RIGHT = 1,
};

const PLATFORM_TYPES = enum(u8) {
    GROUND = 0,
    VERTICAL = 1,
    SLIPPERY = 2,
    WATER = 3,
    ICE = 4,
    GRASS = 5,
};

const ENEMY_TYPES = enum(u8) {
    LOW = 0,
    MED = 1,
    HIGH = 3,
    BOSS = 4,
};

const UI_TYPES = enum(u2) {
    HEALTH_BAR = 0,
    STAMINA_BAR = 1,
};

const GAME_OBJECT_TYPES = union(enum) {
    PLAYER: u2, // Player uses a simple integer type
    PLATFORM: PLATFORM_TYPES, // Platform can hold values from PLATFORM_TYPES
    ENEMY: ENEMY_TYPES, // Enemy can hold values from ENEMY_TYPE
    UI: UI_TYPES,
};

const Config = struct {
    const Self = @This();
    fps: i32,
    windowWidth: i32,
    windowHeight: i32,
    windowTitle: [:0]const u8,

    pub fn init() Self {
        return .{
            .fps = 60,
            .windowHeight = 1500,
            .windowWidth = 1500,
            .windowTitle = "Game",
        };
    }
};

const Rectangle = struct {
    const Self = @This();
    width: f32,
    height: f32,
    position: rayLib.Vector2,
    color: rayLib.Color,
    objectType: GAME_OBJECT_TYPES = GAME_OBJECT_TYPES{ .PLAYER = 0 },

    pub fn init(
        objectType: GAME_OBJECT_TYPES,
        width: f32,
        height: f32,
        position: rayLib.Vector2,
        color: rayLib.Color,
    ) Self {
        return .{
            .height = height,
            .width = width,
            .position = position,
            .color = color,
            .objectType = objectType,
        };
    }
    pub fn intersects(self: Self, other: Rectangle) bool {
        const xOverlap = self.position.x < other.position.x + other.width and
            self.position.x + self.width > other.position.x;
        const yOverlap = self.position.y < other.position.y + other.height and
            self.position.y + self.height > other.position.y;
        return xOverlap and yOverlap;
    }
    pub fn draw(self: Self) void {
        rayLib.drawRectangle(
            @as(i32, @intFromFloat(self.position.x)),
            @as(i32, @intFromFloat(self.position.y)),
            @as(i32, @intFromFloat(self.width)),
            @as(i32, @intFromFloat(self.height)),
            self.color,
        );
    }
};

const Platform = struct {
    const Self = @This();
    platFormType: PLATFORM_TYPES = PLATFORM_TYPES.GROUND,
    rect: Rectangle,
    dealDamage: bool = false,
    damageAmount: f32 = 0,
    pub fn init(
        platFormType: PLATFORM_TYPES,
        width: f32,
        height: f32,
        position: rayLib.Vector2,
        color: rayLib.Color,
        dealDamage: bool,
    ) Self {
        var platform = Self{
            .rect = Rectangle.init(
                GAME_OBJECT_TYPES{ .PLATFORM = platFormType },
                width,
                height, // 30.0
                position, //rayLib.Vector2.init(0, 0),
                color,
            ),
            .platFormType = platFormType,
            .dealDamage = dealDamage,
        };
        platform.setDamageAmount(platFormType);
        return platform;
    }
    pub fn draw(self: Self) void {
        self.rect.draw();
    }
    fn setDamageAmount(self: *Self, platForm: PLATFORM_TYPES) void {
        switch (platForm) {
            PLATFORM_TYPES.ICE => {
                self.damageAmount = 10.0;
            },
            PLATFORM_TYPES.WATER => {
                self.damageAmount = 5.0;
            },
            else => {},
        }
    }
};

const GameUI = struct {
    const Self = @This();
    healthBarRect: Rectangle = Rectangle.init(
        GAME_OBJECT_TYPES{ .UI = .HEALTH_BAR },
        100.0,
        20,
        rayLib.Vector2.init(10.0, 10.0),
        .red,
    ),
    staminaBarRect: Rectangle = Rectangle.init(
        GAME_OBJECT_TYPES{ .UI = .STAMINA_BAR },
        100.0,
        20,
        rayLib.Vector2.init(10.0, 40.0),
        .green,
    ),

    pub fn init() Self {
        return .{};
    }
    pub fn draw(self: *Self) void {
        self.healthBarRect.draw();
        self.staminaBarRect.draw();
    }
};

const Player = struct {
    const Self = @This();
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

    pub fn init() Self {
        return .{
            .rect = Rectangle.init(
                GAME_OBJECT_TYPES{ .PLAYER = 0 },
                50.0,
                50.0,
                // Set player on bottom left of screen
                rayLib.Vector2.init(0.0, @as(f32, @floatFromInt(rayLib.getScreenHeight())) - 80.0),
                .red,
            ),
        };
    }
    pub fn handleMovement(self: *Self, dt: f32) void {
        if (rayLib.isKeyDown(rayLib.KeyboardKey.d)) {
            self.rect.position.x += self.velocityX * self.speedMultiplier * dt;
            self.checkBounds(MOVE.RIGHTnull);
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

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
    const allocator = gpa.allocator();
    var game = try Game.init(allocator);
    defer {
        game.deinit();
        const deinit_status = gpa.deinit();
        if (deinit_status == .leak) @panic("Main::main()::leaking memory exiting program...");
    }
    game.run();

    // var platforms = try std.ArrayList(*Platform).initCapacity(allocator, 3);
    // const config = Config.init();
    // rayLib.setTargetFPS(config.fps);
    // rayLib.initWindow(config.windowWidth, config.windowHeight, config.windowTitle);
    // defer {
    //     rayLib.closeWindow();
    //     platforms.deinit(allocator);
    //     const deinit_status = gpa.deinit();
    //     if (deinit_status == .leak) @panic("Main::main()::leaking memory exiting program...");
    // }

    // var gameUI = GameUI.init();
    // var player = Player.init();
    // var ground = Platform.init(
    //     PLATFORM_TYPES.GRASS,
    //     300.0,
    //     30.0,
    //     rayLib.Vector2.init(0.0, @as(f32, @floatFromInt(rayLib.getScreenHeight())) - 30.0),
    //     .green,
    //     false,
    // );
    // var water = Platform.init(
    //     PLATFORM_TYPES.WATER,
    //     @as(f32, @floatFromInt(rayLib.getScreenWidth())) - 300.0,
    //     30.0,
    //     rayLib.Vector2.init(301.0, @as(f32, @floatFromInt(rayLib.getScreenHeight())) - 30.0),
    //     .dark_blue,
    //     true,
    // );
    // var verticalPlatform = Platform.init(
    //     PLATFORM_TYPES.VERTICAL,
    //     200.0,
    //     50.0,
    //     rayLib.Vector2.init(100.0, 1350.0),
    //     .green,
    //     false,
    // );
    // var verticalPlatform0 = Platform.init(
    //     PLATFORM_TYPES.VERTICAL,
    //     200.0,
    //     50.0,
    //     rayLib.Vector2.init(300.0, 1280.0),
    //     .green,
    //     false,
    // );
    // var icePlatform = Platform.init(
    //     PLATFORM_TYPES.ICE,
    //     200.0,
    //     50.0,
    //     rayLib.Vector2.init(500.0, 1180.0),
    //     // rayLib.Vector2.init(0, 1180.0),
    //     .white,
    //     true,
    // );
    // try platforms.append(allocator, &verticalPlatform);
    // try platforms.append(allocator, &verticalPlatform0);
    // try platforms.append(allocator, &icePlatform);
    // try platforms.append(allocator, &ground);
    // try platforms.append(allocator, &water);

    // while (!rayLib.windowShouldClose()) {
    //     const dt = rayLib.getFrameTime();
    //     rayLib.beginDrawing();
    //     defer rayLib.endDrawing();

    //     rayLib.clearBackground(rayLib.Color.sky_blue);
    //     player.handleMovement(dt);
    //     for (platforms.items) |platform| {
    //         platform.draw();
    //         // 3. Check collision for this platform
    //         if (player.rect.intersects(platform.rect)) {
    //             if (player.velocityY > 0) { // Only if falling down
    //                 player.rect.position.y = platform.rect.position.y - player.rect.height;
    //                 player.velocityY = 0;
    //                 player.onGround = true;
    //             }
    //         }
    //     }
    //     gameUI.draw();
    //     player.rect.draw();
    // }
}
