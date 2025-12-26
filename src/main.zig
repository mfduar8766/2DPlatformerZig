const std = @import("std");
const _2DPlatformerZig = @import("_2DPlatformerZig");
const rayLib = @import("raylib");

//Had to install deps
//sudo apt install libxinerama-dev libxrandr-dev
//sudo apt install libxcursor-dev libx11-dev
//sudo apt install libx11-dev libxi-dev libglu1-mesa-dev
//sudo apt install libgl1-mesa-dev libglx-dev

const MOVE = enum(u2) {
    LEFT = 0,
    RIGHT = 1,
    UP = 2,
    DOWN = 3,
};

const PLATFORM_TYPES = enum(u2) {
    GROUND = 0,
    VERTIAL = 1,
    SLIPPERY = 2,
    WATER = 3,
};

const ENEMY_TYPES = enum(u8) {
    LOW = 0,
    MED = 1,
    HIGH = 3,
    BOSS = 4,
};

const INDICATOR_TYPES = enum(u2) {
    HEALTH_BAR = 0,
    STAMINA_BAR = 1,
};

const SCREEN_DIVISOR: i32 = 2;

const GAME_OBJECT_TYPES = union(enum) {
    PLAYER: u2, // Player uses a simple integer type
    PLATFORM: PLATFORM_TYPES, // Platform can hold values from PLATFORM_TYPES
    ENEMY: ENEMY_TYPES, // Enemy can hold values from ENEMY_TYPE
    INDICATOR: INDICATOR_TYPES,
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
    posX: rayLib.Vector2,
    posY: rayLib.Vector2,
    color: rayLib.Color,
    objectType: GAME_OBJECT_TYPES = GAME_OBJECT_TYPES{ .PLAYER = 0 },

    pub fn init(
        objectType: GAME_OBJECT_TYPES,
        width: f32,
        height: f32,
        posX: rayLib.Vector2,
        posY: rayLib.Vector2,
        color: rayLib.Color,
    ) Self {
        return .{
            .height = height,
            .width = width,
            .posX = posX,
            .posY = posY,
            .color = color,
            .objectType = objectType,
        };
    }
    pub fn intersects(self: Self, other: Rectangle) bool {
        return self.posX.x < other.posX.x + other.width and
            self.posX.x + self.width > other.posX.x and
            self.posY.y < other.posY.y + other.height and
            self.posY.y + self.height > other.posY.y;
    }
    pub fn draw(self: Self) void {
        rayLib.drawRectangle(
            @as(i32, @intFromFloat(self.posX.x)),
            @as(i32, @intFromFloat(self.posY.y)),
            @as(i32, @intFromFloat(self.width)),
            @as(i32, @intFromFloat(self.height)),
            self.color,
        );
    }
};

const Platform = struct {
    const Self = @This();
    platFormType: PLATFORM_TYPES = PLATFORM_TYPES.GROUND,
    quadrants: Rectangle,
    dealDamage: bool = false,
    damageAmount: f32 = 0,
    pub fn init(
        platFormType: PLATFORM_TYPES,
        width: f32,
        height: f32,
        posX: rayLib.Vector2,
        posY: rayLib.Vector2,
        color: rayLib.Color,
        dealDamage: bool,
    ) Self {
        // const posYxCord = @as(f32, @floatFromInt(width));
        var platform = Self{
            .quadrants = Rectangle.init(
                GAME_OBJECT_TYPES{ .PLATFORM = platFormType },
                width,
                height, // 30.0
                posX, //rayLib.Vector2.init(0, 0),
                posY, //setVericalPosition(platFormType, width, height),
                // rayLib.Vector2.init(
                //     posYxCord,
                //     if (platFormType == .GROUND) @as(f32, @floatFromInt(rayLib.getScreenHeight())) - height else 50.0,
                // ),
                color,
            ),
            .platFormType = platFormType,
            .dealDamage = dealDamage,
        };
        platform.setDamageAmount(platFormType);
        return platform;
    }
    pub fn draw(self: Self) void {
        self.quadrants.draw();
    }
    fn setVericalPosition(platform: PLATFORM_TYPES, width: i32, height: f32) rayLib.Vector2 {
        const posYxCord = @as(f32, @floatFromInt(width));
        return switch (platform) {
            PLATFORM_TYPES.GROUND => {
                return rayLib.Vector2.init(
                    posYxCord,
                    @as(f32, @floatFromInt(rayLib.getScreenHeight())) - height,
                );
            },
            PLATFORM_TYPES.SLIPPERY => rayLib.Vector2.init(posYxCord, 100),
            PLATFORM_TYPES.VERTIAL => rayLib.Vector2.init(posYxCord, height),
            PLATFORM_TYPES.WATER => rayLib.Vector2.init(posYxCord, 200),
        };
    }
    fn setDamageAmount(self: *Self, platForm: PLATFORM_TYPES) void {
        switch (platForm) {
            PLATFORM_TYPES.WATER => {
                self.damageAmount = 10.0;
            },
            else => {},
        }
    }
};

const Player = struct {
    const Self = @This();
    const HEALTH: f32 = 100.0;
    const STAMINA: f32 = 100.0;
    speed: f32,
    canJump: bool,
    quadrants: Rectangle,
    jumpHeight: f32,
    speedMultiplier: f32,
    jumpMultiplier: f32,
    health: f32 = HEALTH,
    stamina: f32 = STAMINA,
    healthBar: Rectangle = Rectangle.init(
        GAME_OBJECT_TYPES{ .INDICATOR = .HEALTH_BAR },
        HEALTH,
        20,
        rayLib.Vector2.init(10.0, 10.0),
        rayLib.Vector2.init(10.0, 10.0),
        .red,
    ),
    staminaBar: Rectangle = Rectangle.init(
        GAME_OBJECT_TYPES{ .INDICATOR = .STAMINA_BAR },
        STAMINA,
        20,
        rayLib.Vector2.init(10.0, 10.0),
        rayLib.Vector2.init(10.0, 40.0),
        .green,
    ),

    pub fn init() Self {
        return .{
            .canJump = false,
            .speed = 3.0,
            .jumpHeight = 0.5,
            .speedMultiplier = 1.2,
            .jumpMultiplier = 1.1,
            .quadrants = Rectangle.init(
                GAME_OBJECT_TYPES{ .PLAYER = 0 },
                50.0,
                50.0,
                // Set player on bottom left of screen
                rayLib.Vector2.init(0.0, @as(f32, @floatFromInt(rayLib.getScreenHeight())) - 50.0),
                rayLib.Vector2.init(0.0, @as(f32, @floatFromInt(rayLib.getScreenHeight())) - 50.0 - 30.0),
                .red,
            ),
        };
    }
    pub fn updateAndDraw(self: *Self, object: Rectangle) void {
        self.handleMovement();
        if (self.quadrants.intersects(object)) {
            self.health -= 10.0;
            self.healthBar.width = self.health;
            self.quadrants.posY.y += 30.0;
        }
        self.healthBar.draw();
        self.staminaBar.draw();
        self.quadrants.draw();
    }
    fn handleMovement(self: *Self) void {
        if (rayLib.isKeyDown(rayLib.KeyboardKey.s)) {
            self.quadrants.posX.x += self.speed;
            self.checkBounds(MOVE.RIGHT);
        } else if (rayLib.isKeyDown(rayLib.KeyboardKey.a)) {
            self.quadrants.posX.x -= self.speed;
            self.checkBounds(MOVE.LEFT);
        } else if (rayLib.isKeyPressed(rayLib.KeyboardKey.w)) {
            self.quadrants.posY.y -= (self.jumpHeight * self.health);
        }
    }
    fn checkBounds(self: *Self, move: MOVE) void {
        switch (move) {
            MOVE.LEFT => {
                if (self.quadrants.posX.x < 0) {
                    self.quadrants.posX.x = 0;
                }
            },
            MOVE.RIGHT => {
                if (self.quadrants.posX.x + self.quadrants.width > @as(f32, @floatFromInt(rayLib.getScreenWidth()))) {
                    self.quadrants.posX.x = @as(f32, @floatFromInt(rayLib.getScreenWidth())) - self.quadrants.width;
                }
            },
            MOVE.UP => {},
            MOVE.DOWN => {},
        }
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
    const allocator = gpa.allocator();
    var platforms = try std.ArrayList(*Platform).initCapacity(allocator, 3);
    const config = Config.init();
    rayLib.setTargetFPS(config.fps);
    rayLib.initWindow(config.windowWidth, config.windowHeight, config.windowTitle);
    defer {
        rayLib.closeWindow();
        platforms.deinit(allocator);
        const deinit_status = gpa.deinit();
        if (deinit_status == .leak) @panic("Main::main()::leaking memory exiting program...");
    }

    var player = Player.init();
    var ground = Platform.init(
        PLATFORM_TYPES.GROUND,
        @as(f32, @floatFromInt(rayLib.getScreenWidth())),
        30.0,
        rayLib.Vector2.init(0, 0),
        rayLib.Vector2.init(@as(f32, @floatFromInt(rayLib.getScreenWidth())), @as(f32, @floatFromInt(rayLib.getScreenHeight())) - 30.0),
        .green,
        false,
    );
    var verticalPlatform = Platform.init(
        PLATFORM_TYPES.VERTIAL,
        200.0,
        50.0,
        rayLib.Vector2.init(100.0, 100.0),
        rayLib.Vector2.init(50.0, 1350.0),
        .green,
        false,
    );
    var verticalPlatform0 = Platform.init(
        PLATFORM_TYPES.VERTIAL,
        200.0,
        50.0,
        rayLib.Vector2.init(300.0, 100.0),
        rayLib.Vector2.init(0, 1280.0),
        .green,
        false,
    );
    try platforms.append(allocator, &verticalPlatform);
    try platforms.append(allocator, &verticalPlatform0);
    try platforms.append(allocator, &ground);

    while (!rayLib.windowShouldClose()) {
        rayLib.beginDrawing();
        defer rayLib.endDrawing();

        rayLib.clearBackground(rayLib.Color.sky_blue);

        for (platforms.items) |value| {
            value.draw();
        }
        player.updateAndDraw(verticalPlatform.quadrants);
    }
}
