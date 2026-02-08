const GAME_OJECT_TYPE = @import("../types.zig").GAME_OBJECT_TYPES;

pub const ObjectProperties = struct {
    const Self = @This();
    objectType: GAME_OJECT_TYPE,
    bounce: bool = false,
    bounceAmount: f32 = 0.0,
    freeze: bool = false,
    instaKill: bool = false,
    slippery: bool = false,
    isSolid: bool = false,
    damage: ?DamageComponent = null,

    pub fn init(
        objectType: GAME_OJECT_TYPE,
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
    //TODO: Have a map that holds all the objectProperties and their damage ETC
    fn setDamageAmount(self: *Self) void {
        switch (self.objectType) {
            // Use the capture syntax |value| to get the data inside
            .PLATFORM => |plat_type| {
                switch (plat_type) {
                    .GROUND => {
                        // self.damage = DamageHandler.init(true, 10.0, false);
                    },
                    .ICE => {
                        //self.damage = DamageHandler.init(true, 10.0, true)
                    },
                    .VERTICAL => {},
                    .SLIPPERY => {},
                    .WATER => {
                        // self.damage = DamageHandler.init(true, 10.0, true);
                        // self.effects = ObjectEffects.init(true, 10.0, false, false, false);
                    },
                    .GRASS => {},
                    .WALL => {
                        //self.effects = ObjectEffects.init(true, 10.0, false, false, false)
                    },
                }
            },
            .ENEMY => |enemy_type| {
                switch (enemy_type) {
                    .LOW => {
                        self.damage = DamageComponent.init(10.0, false);
                        self.bounce = true;
                        self.bounceAmount = 10.0;
                        // self.objectProperties = ObjectProperties.init(
                        //     .ENEMY,
                        //     true,
                        //     50.0,
                        //     false,
                        //     false,
                        //     false,
                        //     true,
                        //     DamageComponent.init(
                        //         10.0,
                        //         false,
                        //     ),
                        // );
                    },
                    .MED => {},
                    .HIGH => {},
                    .BOSS => {},
                    .PATROL => {},
                }
            },
            .PROJECTILES => |projectileType| {
                switch (projectileType) {
                    .BULLETS => {},
                    .ARROWS => {},
                    .MAGIC => {},
                }
            },
            else => |_| {},
        }
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
