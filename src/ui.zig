const std = @import("std");
const board = @import("board.zig");
const enemy_module = @import("enemy.zig"); // To get Enemy type

// Function to get character representation for a tile
fn getTileChar(tile_type: board.TileType) u8 {
    return switch (tile_type) {
        board.TileType.Path => '#',
        board.TileType.Buildable => '.',
        board.TileType.Scenery => ' ',
    };
}

pub fn displayBoard(b: board.Board, enemies: std.ArrayList(enemy_module.Enemy)) !void {
    std.debug.print("Board ({}x{}) with {} enemies:\n", .{ b.width, b.height, enemies.items.len });

    // Create a temporary buffer for display
    // Each tile is a u8 (char), plus newline for each row
    var display_buffer = std.ArrayList(u8).init(b.allocator);
    defer display_buffer.deinit();

    // Initialize buffer with base tiles
    for (0..b.height) |y| {
        for (0..b.width) |x| {
            const tile = b.tiles[y * b.width + x];
            try display_buffer.append(getTileChar(tile));
        }
        try display_buffer.append('\n');
    }

    // Overlay enemies onto the buffer
    // Note: This is a simple overlay. If multiple enemies are on the same tile,
    // the last one processed will be shown. More complex rendering might show a count or different char.
    for (enemies.items) |current_enemy| {
        // Round enemy float coordinates to nearest tile integer coordinates
        const enemy_tile_x = @round(current_enemy.x);
        const enemy_tile_y = @round(current_enemy.y);

        // Ensure coordinates are within bounds
        if (enemy_tile_x >= 0 and @as(u32, @intFromFloat(enemy_tile_x)) < b.width and
            enemy_tile_y >= 0 and @as(u32, @intFromFloat(enemy_tile_y)) < b.height)
        {
            const ex: u32 = @intFromFloat(enemy_tile_x);
            const ey: u32 = @intFromFloat(enemy_tile_y);
            const buffer_index = ey * (b.width + 1) + ex; // +1 for newline characters in buffer

            // Determine enemy character (e.g., 'E' for Grunt, 'S' for Sprinter)
            const enemy_char: u8 = switch (current_enemy.kind) {
                enemy_module.EnemyKind.Grunt => 'G',
                enemy_module.EnemyKind.Sprinter => 'S',
            };
            display_buffer.items[buffer_index] = enemy_char;
        }
    }

    // Print the buffer
    std.debug.print("{s}", .{display_buffer.items});
}

pub fn displayHUD(game: @import("game.zig").Game) !void {
    // Using std.io.getStdOut().writer() for more conventional printing, can also use std.debug.print
    const stdout_writer = std.io.getStdOut().writer();

    try stdout_writer.print("--------------------\n", .{});
    try stdout_writer.print("Player Health: {}   Currency: {}\n", .{ game.player_health, game.player_currency });
    try stdout_writer.print("Wave: {}           Enemies Left: {}\n", .{ game.current_wave_number, game.enemies.items.len });
    if (game.game_over) {
        try stdout_writer.print("!!! GAME OVER !!!\n", .{});
    }
    try stdout_writer.print("--------------------\n", .{});
}
