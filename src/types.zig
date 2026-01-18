pub const SCREEN_HEIGHT: i32 = 2500;
pub const SCREEN_WIDTH: i32 = 1500;
pub const SCREEN_DIVISOR: i32 = 2;
pub const GRAVITY: f32 = 100.0;

pub const LogLevels = enum(u6) {
    INFO = 0,
    WARNING = 1,
    ERROR = 2,
    FATAL = 3,
    DEBUG = 4,
    pub fn get(key: u6) []const u8 {
        return switch (key) {
            0 => "INFO",
            1 => "WARNING",
            2 => "ERROR",
            3 => "FATAL",
            4 => "DEBUG",
            else => "UNKNOWN",
        };
    }
};

pub const OsPlatForms = enum(u4) {
    LINUX,
    MAC_ARM_64,
    MAC_X64,
    WIN_32,
    WIN_64,
    pub fn getOS(key: u4) []const u8 {
        return switch (key) {
            0 => "linux64",
            1 => "mac-arm64",
            2 => "mac-x64",
            3 => "win32",
            4 => "win64",
            else => "UNKNOWN",
        };
    }
};

pub const FileExtensions = enum(u8) {
    TXT,
    PNG,
    JPG,
    LOG,
    SH,
    pub fn get(key: u8) []const u8 {
        return switch (key) {
            0 => "txt",
            1 => "png",
            2 => "jpg",
            3 => "log",
            4 => "sh",
            else => "",
        };
    }
};

pub const DIRECTION = enum(u8) {
    LEFT = 0,
    RIGHT = 1,
    UP = 2,
    DOWN = 3,
};

pub const PLATFORM_TYPES = enum(u8) {
    GROUND = 0,
    VERTICAL = 1,
    SLIPPERY = 2,
    WATER = 3,
    ICE = 4,
    GRASS = 5,
    WALL = 6,
};

pub const ENEMY_TYPES = enum(u8) {
    LOW = 0,
    MED = 1,
    HIGH = 2,
    BOSS = 3,
};

pub const UI_TYPES = enum(u2) {
    MAIN_MENU = 0,
    HEALTH_BAR = 1,
    STAMINA_BAR = 2,
    INVENTORY = 3,
};

pub const GAME_OBJECT_TYPES = union(enum) {
    PLAYER: u2, // Player uses a simple integer type
    PLATFORM: PLATFORM_TYPES, // Platform can hold values from PLATFORM_TYPES
    ENEMY: ENEMY_TYPES, // Enemy can hold values from ENEMY_TYPE
    UI: UI_TYPES,
    WORLD: u2,
};

pub const PLAYER_STATE = enum(u8) {
    FRENZY = 0,
    DEAD = 1,
    ALIVE = 2,
};

pub const VELOCITY = enum(u2) {
    X = 0,
    Y = 1,
};

pub const POSITION = enum(u2) {
    X = 0,
    Y = 1,
};

pub const COLLISION_TYPES = enum(u8) {
    HEAD_BUMP = 0,
    FALLING = 1,
    WALL = 3,
    PLATFORM = 4,
    HORRIZONTAL = 5,
    ENEMY_BODY = 6,
    PROJECTILE = 7,
};
