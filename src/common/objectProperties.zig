const LevelBluePrintMappingObjectTypes = @import("../game/world.zig").LevelBluePrintMappingObjectTypes;

pub const ObjectProperties = struct {
    const Self = @This();
    objectType: LevelBluePrintMappingObjectTypes,
    bounce: bool = false,
    bounceAmount: f32 = 0.0,
    freeze: bool = false,
    instaKill: bool = false,
    slippery: bool = false,
    isSolid: bool = false,
    damage: ?DamageComponent = null,

    pub fn init(
        objectType: LevelBluePrintMappingObjectTypes,
        bounce: bool,
        bounceAmount: f32,
        freeze: bool,
        instaKill: bool,
        slippery: bool,
        isSolid: bool,
        damage: ?DamageComponent,
    ) Self {
        return .{
            .objectType = objectType,
            .bounce = bounce,
            .bounceAmount = bounceAmount,
            .freeze = freeze,
            .instaKill = instaKill,
            .slippery = slippery,
            .isSolid = isSolid,
            .damage = damage,
        };
    }
};

pub const DamageComponent = struct {
    const Self = @This();
    damageAmount: f32 = 0.0,
    damageOverTime: bool = false,

    pub fn init(damageAmount: f32, damageOverTime: bool) Self {
        return .{
            .damageAmount = damageAmount,
            .damageOverTime = damageOverTime,
        };
    }
};
