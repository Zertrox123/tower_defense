const std = @import("std");
const game_module = @import("game.zig");
const ui_module = @import("ui.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var actual_game = try game_module.Game.init(allocator, 20, 10);
    defer actual_game.deinit();

    std.debug.print("Game initialized. Path example: ... \n", .{}); // Simplified startup message
    std.debug.print("Initial currency: {d}\n", .{actual_game.player_currency});

    var timer = try std.time.Timer.start();
    const desired_fps: f32 = 1.0;
    const time_per_frame_ns: u64 = @intFromFloat(@divFloor(1.0, desired_fps) * std.time.ns_per_s);

    var turn_count: u32 = 0;
    const max_turns: u32 = 200;

    try ui_module.displayHelp();
    try ui_module.displayAvailableTowers(actual_game);

    while (!actual_game.game_over and turn_count < max_turns) {
        const loop_start_time = timer.read();
        try ui_module.displayBoard(actual_game.board, actual_game.enemies, actual_game.towers, actual_game, allocator);
        try ui_module.displayHUD(actual_game);

        std.debug.print("Enter command (turn {d}, wave {d}): ", .{turn_count, actual_game.current_wave_number});
        var line_buffer: [100]u8 = undefined;
        const line = std.io.getStdIn().reader().readLine(&line_buffer) catch |err| {
            if (err == error.EndOfStream) {
                std.debug.print("EndOfStream (Ctrl+D), quitting.\n", .{});
                actual_game.game_over = true;
                continue;
            }
            std.debug.print("Error reading input: {any}\n", .{err});
            continue;
        };

        const trimmed_line = std.mem.trim(u8, line, " \r\n\t");
        var game_update_this_iteration = true;

        if (trimmed_line.len == 0 or std.mem.eql(u8, trimmed_line, "pass")) {
            std.debug.print("Passing turn...\n\n", .{});
        } else if (std.mem.eql(u8, trimmed_line, "quit")) {
            actual_game.game_over = true;
            std.debug.print("Quitting game...\n\n", .{});
            game_update_this_iteration = false;
        } else if (std.mem.eql(u8, trimmed_line, "help")) {
            try ui_module.displayHelp();
            try ui_module.displayAvailableTowers(actual_game);
            game_update_this_iteration = false;
        } else if (std.mem.startsWith(u8, trimmed_line, "buy ")) {
            var parts = std.mem.split(u8, trimmed_line, " ");
            _ = parts.next(); // Skip "buy"
            const id_str = parts.next() orelse { std.debug.print("Missing tower ID.\n", .{}); game_update_this_iteration = false; continue; };
            const x_str = parts.next() orelse { std.debug.print("Missing X coordinate.\n", .{}); game_update_this_iteration = false; continue; };
            const y_str = parts.next() orelse { std.debug.print("Missing Y coordinate.\n", .{}); game_update_this_iteration = false; continue; };

            const tower_id = std.fmt.parseInt(u32, id_str, 10) catch |e| { std.debug.print("Invalid ID '{s}':{any}\n", .{id_str,e}); game_update_this_iteration = false; continue; };
            const x_coord = std.fmt.parseInt(u32, x_str, 10) catch |e| { std.debug.print("Invalid X '{s}':{any}\n", .{x_str,e}); game_update_this_iteration = false; continue; };
            const y_coord = std.fmt.parseInt(u32, y_str, 10) catch |e| { std.debug.print("Invalid Y '{s}':{any}\n", .{y_str,e}); game_update_this_iteration = false; continue; };

            if (actual_game.placeTower(tower_id, x_coord, y_coord)) {
                 if(tower_id < actual_game.tower_data_registry.items.len){ // Check ID validity before accessing registry
                    const placed_tower_data = actual_game.tower_data_registry.items[tower_id];
                    std.debug.print("Placed {s} at ({d},{d}). Currency: {d}\n", .{ placed_tower_data.name, x_coord, y_coord, actual_game.player_currency });
                 } else { // Should be caught by placeTower's ID check, but defensive here.
                     std.debug.print("Placed tower ID {d} at ({d},{d}). Currency: {d}\n", .{ tower_id, x_coord, y_coord, actual_game.player_currency });
                 }
            } else { /* placeTower prints its own errors */ }
            std.debug.print("\n", .{});
        } else if (std.mem.startsWith(u8, trimmed_line, "upgrade ")) {
            var parts = std.mem.split(u8, trimmed_line, " ");
            _ = parts.next(); // Skip "upgrade"
            const x_str = parts.next() orelse { std.debug.print("Missing X coordinate for upgrade.\n", .{}); game_update_this_iteration = false; continue; };
            const y_str = parts.next() orelse { std.debug.print("Missing Y coordinate for upgrade.\n", .{}); game_update_this_iteration = false; continue; };

            const x_coord = std.fmt.parseInt(u32, x_str, 10) catch |e| { std.debug.print("Invalid X '{s}':{any}\n", .{x_str,e}); game_update_this_iteration = false; continue; };
            const y_coord = std.fmt.parseInt(u32, y_str, 10) catch |e| { std.debug.print("Invalid Y '{s}':{any}\n", .{y_str,e}); game_update_this_iteration = false; continue; };

            // actual_game.upgradeTower prints its own success/failure messages
            _ = actual_game.upgradeTower(x_coord, y_coord);
            // Game update proceeds after an 'upgrade' attempt
            game_update_this_iteration = true;
            std.debug.print("\n", .{});
        } else {
            std.debug.print("Unknown command: '{s}'. Type 'help'.\n\n", .{trimmed_line});
            game_update_this_iteration = false;
        }

        if (game_update_this_iteration and !actual_game.game_over) {
            const delta_time: f32 = 1.0 / desired_fps;
            std.debug.print("--- Processing Game Turn {d} (Wave {d}) ---\n", .{turn_count, actual_game.current_wave_number});
            try actual_game.updateGame(delta_time);
            turn_count += 1;
        } else if (!game_update_this_iteration) {
            // std.debug.print("--- Command Processed, Awaiting Next Input ---\n", .{});
        }

        const loop_end_time = timer.read();
        const elapsed_ns = loop_end_time - loop_start_time;
        if (elapsed_ns < time_per_frame_ns && game_update_this_iteration) {
            std.time.sleep(time_per_frame_ns - elapsed_ns);
        }
    }

    if (actual_game.game_over) {
        std.debug.print("\n--- FINAL GAME OVER ---\n", .{});
        std.debug.print("Survived {d} full waves.\n", .{if (actual_game.current_wave_number > 0) actual_game.current_wave_number - 1 else 0});
    } else if (turn_count >= max_turns) {
        std.debug.print("\n--- SIMULATION END (Max turns reached) ---\n", .{});
    } else {
         std.debug.print("\n--- SIMULATION END (Unknown reason) ---\n", .{});
    }

    std.debug.print("Final game state:\n", .{});
    try ui_module.displayBoard(actual_game.board, actual_game.enemies, actual_game.towers, actual_game, allocator);
    try ui_module.displayHUD(actual_game);
    std.debug.print("Main execution finished.\n", .{});
}
