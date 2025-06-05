const std = @import("std");
const board_module = @import("board.zig");
const tower_module = @import("tower.zig");
const enemy_module = @import("enemy.zig");
const game_module = @import("game.zig");

fn getTileChar(tile: board_module.Tile) u8 {
    return switch (tile) {
        .empty => '.',
        .path => '#',
        .tower => '?',
        .obstacle => 'X',
    };
}

pub fn displayBoard(
    b: board_module.Board,
    enemies: std.ArrayList(enemy_module.Enemy),
    towers: std.ArrayList(tower_module.Tower),
    game: game_module.Game,
    gpa: std.mem.Allocator,
) !void {
    var writer = std.io.getStdOut().writer();
    var display_buffer = std.ArrayList(std.ArrayList(u8)).init(gpa);
    defer {
        for (display_buffer.items) |row| { row.deinit(); }
        display_buffer.deinit();
    }

    var y: u32 = 0;
    while (y < b.height) : (y += 1) {
        var row = std.ArrayList(u8).init(gpa);
        errdefer row.deinit();
        var x: u32 = 0;
        while (x < b.width) : (x += 1) {
            const tile = b.getTile(x, y) orelse board_module.Tile.obstacle;
            try row.append(getTileChar(tile));
        }
        try display_buffer.append(row);
    }

    for (towers.items) |tower_instance| {
        if (tower_instance.y < b.height and tower_instance.x < b.width) {
            const tower_data_maybe = game.getTowerData(tower_instance);
            var tower_char: u8 = '?';
            if (tower_data_maybe) |tower_data| {
                tower_char = tower_data.char_representation;
            } else {
                std.debug.print("Warning: Could not get TowerData for tower at ({d},{d}) id {d} during display.\n", .{
                    tower_instance.x, tower_instance.y, tower_instance.data_id
                });
            }
            if (tower_instance.y < display_buffer.items.len and tower_instance.x < display_buffer.items[tower_instance.y].items.len) {
                 display_buffer.items[tower_instance.y].items[tower_instance.x] = tower_char;
            }
        }
    }

    for (enemies.items) |enemy_instance| {
        if (enemy_instance.is_active) {
            const board_x = @floor(enemy_instance.x);
            const board_y = @floor(enemy_instance.y);
            if (board_y >= 0 and @as(u32, @intFromFloat(board_y)) < b.height and
                board_x >= 0 and @as(u32, @intFromFloat(board_x)) < b.width)
            {
                const enemy_char = enemy_instance.getData().char_representation;
                const display_y: usize = @intCast(usize, @intFromFloat(board_y));
                const display_x: usize = @intCast(usize, @intFromFloat(board_x));
                 if (display_y < display_buffer.items.len and display_x < display_buffer.items[display_y].items.len) {
                    display_buffer.items[display_y].items[display_x] = enemy_char;
                }
            }
        }
    }

    try writer.print("-- Game Board --\n", .{});
    for (display_buffer.items) |row_to_print| {
        try writer.print("  ", .{});
        for (row_to_print.items) |char_to_print| {
            try writer.print("{c} ", .{char_to_print});
        }
        try writer.print("\n", .{});
    }
    try writer.print("----------------\n", .{});
}

pub fn displayHUD(game: game_module.Game) !void {
    var writer = std.io.getStdOut().writer();
    try writer.print("--- HUD ---\n", .{});
    try writer.print("Health: {d} | Currency: {d} | Wave: {d}\n", .{
        game.player_health, game.player_currency, game.current_wave_number,
    });

    var total_enemies_for_wave: u32 = 0;
    if (game.current_wave_number > 0) {
        total_enemies_for_wave = game.enemies_per_wave_base + ((game.current_wave_number -1 ) * game.wave_enemy_increment);
    }
    var active_enemies_count: u32 = 0;
    for (game.enemies.items) |*enemy| {
        if (enemy.is_active) active_enemies_count += 1;
    }

    if (game.current_wave_number == 0) {
        try writer.print("Enemies: N/A (Game not started)\n", .{});
    } else if (game.enemies_spawned_this_wave >= total_enemies_for_wave and active_enemies_count == 0) {
        try writer.print("Enemies: Wave {d} Complete!\n", .{game.current_wave_number});
    } else {
        try writer.print("Enemies (Wave {d}): Active {d} | Spawned {d}/{d}\n", .{
            game.current_wave_number, active_enemies_count,
            game.enemies_spawned_this_wave, total_enemies_for_wave,
        });
    }

    if (game.game_over) {
        try writer.print("\n!! GAME OVER !!\n", .{});
    }
    try writer.print("-----------\n", .{});
}

pub fn displayAvailableTowers(game: game_module.Game) !void {
    var writer = std.io.getStdOut().writer();
    try writer.print("--- Available Towers (ID | Name     | Cost | Dmg | Rng | Rate | Upgrade Cost) ---\n", .{});
    var id: u32 = 0;
    while(id < game.tower_data_registry.items.len) : (id +=1) {
        const tower_data = game.tower_data_registry.items[id];
        // Skip displaying towers that cannot be bought (cost == 0, e.g. Minigun Mk2)
        if (tower_data.cost == 0 and tower_data.upgrades_to_id == null) { // Show only buyable or base of upgrade lines
             // However, for this display, it might be better to show all, including upgrades.
             // Let's show all for now, CLI parsing will prevent buying cost 0.
        }

        try writer.print("ID: {d} | {s: <12} | Cost: {d: <3} | Dmg: {d: <3} | Rng: {f:.1} | Rate: {f:.1} | Upg Cost: {d: <3} ", .{
            id,
            tower_data.name,
            tower_data.cost,
            tower_data.damage,
            tower_data.range,
            tower_data.firerate,
            tower_data.upgrade_cost,
        });
        if (tower_data.upgrades_to_id) |upg_id| {
            if (upg_id < game.tower_data_registry.items.len) {
                 try writer.print("-> {s} (ID {d})\n", .{game.tower_data_registry.items[upg_id].name, upg_id});
            } else {
                 try writer.print("-> Invalid Upg ID ({d})\n", .{upg_id});
            }
        } else {
            try writer.print("-> Max Level\n", .{});
        }
    }
    try writer.print("-------------------------------------------------------------------------------\n", .{});
}

pub fn displayHelp() !void {
    var writer = std.io.getStdOut().writer();
    try writer.print("--- Commands ---\n", .{});
    try writer.print("  buy <id> <x> <y>  - Buy and place tower (e.g., 'buy 0 5 5').\n", .{});
    try writer.print("  upgrade <x> <y>   - Upgrade tower at location (e.g., 'upgrade 5 5').\n", .{}); // New command
    try writer.print("  pass              - End turn, let game proceed.\n", .{});
    try writer.print("  help              - Show this help message and available towers.\n", .{});
    try writer.print("  quit              - Exit the game.\n", .{});
    try writer.print("-----------------\n", .{});
}

// --- Tests ---
// ... (existing tests remain the same) ...
test "displayAvailableTowers runs without error" {
    const allocator = std.testing.allocator;
    var game = try game_module.Game.init(allocator, 5, 3);
    defer game.deinit();
    std.debug.print("\n--- Test: displayAvailableTowers output (manual verification) ---\n", .{});
    try displayAvailableTowers(game);
    std.debug.print("--- End Test: displayAvailableTowers output ---\n", .{});
}

test "displayHelp runs without error" {
    std.debug.print("\n--- Test: displayHelp output (manual verification) ---\n", .{});
    try displayHelp(); // Should now include 'upgrade' command
    std.debug.print("--- End Test: displayHelp output ---\n", .{});
}
