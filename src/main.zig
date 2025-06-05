const std = @import("std");
const board_module = @import("board.zig");
const ui = @import("ui.zig");
const game_module = @import("game.zig");
const tower_module = @import("tower.zig");
const enemy_module = @import("enemy.zig"); // Import enemy module

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const board_width: u32 = 20;
    const board_height: u32 = 10; // Path on row 5 (y=5), Buildable on 4 and 6

    var game = try game_module.Game.initGame(board_width, board_height, allocator);
    defer game.deinitGame();

    std.debug.print("Initial board state (before tower placement):\n", .{});
    try ui.displayBoard(game.board, game.enemies); // Pass enemies list, use try
    std.debug.print("\n", .{});

    // Tower placement attempts (from previous subtask, kept for context)
    const valid_x: u32 = 2;
    const valid_y: u32 = 4;
    if (game.placeTower(tower_module.TowerKind.Minigun, valid_x, valid_y)) {
        std.debug.print("Tower placement at ({}, {}) Succeeded.\n", .{ valid_x, valid_y });
    } else {
        std.debug.print("Tower placement at ({}, {}) Failed.\n", .{ valid_x, valid_y });
    }
    std.debug.print("\n", .{});


    // Spawn enemies
    try game.spawnEnemy(enemy_module.EnemyKind.Grunt);
    std.time.sleep(10 * std.time.ns_per_ms); // Small delay between spawns if desired
    try game.spawnEnemy(enemy_module.EnemyKind.Sprinter);
    std.time.sleep(10 * std.time.ns_per_ms);
    try game.spawnEnemy(enemy_module.EnemyKind.Grunt);


    std.debug.print("\n", .{});


    // Spawn initial enemies - for testing, updateGame will handle wave logic
    // try game.spawnEnemy(enemy_module.EnemyKind.Grunt);
    // try game.spawnEnemy(enemy_module.EnemyKind.Sprinter);
    // try game.spawnEnemy(enemy_module.EnemyKind.Grunt);


    std.debug.print("\nStarting game loop...\n", .{});
    var timer = std.time.Timer.start() catch @panic("Failed to start timer");
    const sleep_duration_per_turn_ms: u64 = 200; // For "turn-based" feel for now

    // Initial call to updateGame to potentially start the first wave
    try game.updateGame(0.01); // Small initial delta, or could be 0
    try ui.displayBoard(game.board, game.enemies);
    try ui.displayHUD(game);
    std.debug.print("\n--- Turn End ---\n", .{});


    while (!game.game_over) {
        const last_lap_ns = timer.lap();
        const last_lap_ns_f32 = @as(f32, @floatFromInt(last_lap_ns)); // Convert to f32 earlier
        const ns_per_s_f32 = @as(f32, @floatFromInt(std.time.ns_per_s));   // Convert to f32 earlier
        const calculated_delta_time = last_lap_ns_f32 / ns_per_s_f32; // Result should be f32
        const delta_time: f32 = calculated_delta_time; // Assign f32 to f32

        std.debug.print("Delta Time: {d:.3}s\n", .{delta_time});

        // Process player input (placeholder)
        // if (player_pressed_key_to_spawn_tower) { game.placeTower(...) }
        // if (player_pressed_key_to_start_next_wave_early) { game.startNextWave() }


        try game.updateGame(delta_time);
        try ui.displayBoard(game.board, game.enemies);
        try ui.displayHUD(game);

        if (game.game_over) {
            std.debug.print("\nGAME OVER detected in main loop.\n", .{});
            break;
        }

        std.debug.print("--- Turn End ---\n", .{});
        std.time.sleep(sleep_duration_per_turn_ms * std.time.ns_per_ms);
    }

    std.debug.print("\nGame loop finished.\n", .{});
    std.debug.print("Final Wave Reached: {}\n", .{game.current_wave_number});

    // Final tower list (from previous subtask)
    std.debug.print("Placed Towers ({}):\n", .{game.towers.items.len});
    for (game.towers.items) |t| {
        std.debug.print("- {} at ({}, {}), Cost: {}, Dmg: {}, Range: {d:.1}\n", .{ t.kind, t.x, t.y, t.cost, t.damage, t.range });
    }
    std.debug.print("Final Enemy Count: {}\n", .{game.enemies.items.len});
}
