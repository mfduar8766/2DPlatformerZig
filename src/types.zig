pub const SCREEN_HEIGHT: i32 = 2500;
pub const SCREEN_WIDTH: i32 = 1500;
pub const SCREEN_DIVISOR: i32 = 2;

pub const MOVE = enum(u2) {
    LEFT = 0,
    RIGHT = 1,
};

pub const PLATFORM_TYPES = enum(u8) {
    GROUND = 0,
    VERTICAL = 1,
    SLIPPERY = 2,
    WATER = 3,
    ICE = 4,
    GRASS = 5,
};

pub const ENEMY_TYPES = enum(u8) {
    LOW = 0,
    MED = 1,
    HIGH = 3,
    BOSS = 4,
};

pub const UI_TYPES = enum(u2) {
    HEALTH_BAR = 0,
    STAMINA_BAR = 1,
};

pub const GAME_OBJECT_TYPES = union(enum) {
    PLAYER: u2, // Player uses a simple integer type
    PLATFORM: PLATFORM_TYPES, // Platform can hold values from PLATFORM_TYPES
    ENEMY: ENEMY_TYPES, // Enemy can hold values from ENEMY_TYPE
    UI: UI_TYPES,
};
