const std = @import("std");
const _2DPlatformerZig = @import("_2DPlatformerZig");
const rayLib = @import("raylib");
const Game = @import("./game/game.zig").Game;

//Had to install deps
//sudo apt install libxinerama-dev libxrandr-dev
//sudo apt install libxcursor-dev libx11-dev
//sudo apt install libx11-dev libxi-dev libglu1-mesa-dev
//sudo apt install libgl1-mesa-dev libglx-dev

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
    const allocator = gpa.allocator();
    var game = try Game.init(allocator);
    defer {
        game.deinit();
        const deinit_status = gpa.deinit();
        if (deinit_status == .leak) @panic("Main::main()::leaking memory exiting program...");
    }
    try game.run();
}
