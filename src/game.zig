const std = @import("std");
const Board = @import("board.zig").Board;
const Vec2u32 = @import("board.zig").Vec2u32;
const Tower = @import("tower.zig").Tower;
const TowerKind = @import("tower.zig").TowerKind;
const Enemy = @import("enemy.zig").Enemy;
const EnemyKind = @import("enemy.zig").EnemyKind;
// const isTileBuildableAndUnoccupied = @import("board.zig").Board.isTileBuildableAndUnoccupied; // Not directly used here anymore
// const setTileOccupied = @import("board.zig").Board.setTileOccupied; // Not directly used here anymore

pub const Game = struct {
    board: Board,
    towers: std.ArrayList(Tower),
    enemies: std.ArrayList(Enemy),
    next_enemy_id: u32,
    allocator: std.mem.Allocator,

    // New game state fields
    player_health: i32,
    player_currency: u32,
    current_wave_number: u32,
    game_over: bool,
    enemies_per_wave: u32,
    enemies_spawned_this_wave: u32,

    pub fn initGame(board_width: u32, board_height: u32, allocator: std.mem.Allocator) !Game {
        const board_instance = try Board.createBoard(board_width, board_height, allocator);
        const towers_list = std.ArrayList(Tower).init(allocator);
        const enemies_list = std.ArrayList(Enemy).init(allocator);

        return Game{
            .board = board_instance,
            .towers = towers_list,
            .enemies = enemies_list,
            .next_enemy_id = 0,
            .allocator = allocator,
            .player_health = 100,
            .player_currency = 200,
            .current_wave_number = 0,
            .game_over = false,
            .enemies_per_wave = 3,
            .enemies_spawned_this_wave = 0,
        };
    }

    pub fn deinitGame(game: *Game) void {
        game.board.destroy();
        game.towers.deinit();
        game.enemies.deinit(); // Deinitialize new list
        game.* = undefined;
    }

    pub fn placeTower(game: *Game, kind: TowerKind, x: u32, y: u32) bool {
        if (!game.board.isTileBuildableAndUnoccupied(x, y)) {
            std.debug.print("Cannot place tower at ({}, {}): Tile is not buildable or is occupied.\n", .{ x, y });
            return false;
        }
        const new_tower = Tower.createTower(kind, x, y);
        game.towers.append(new_tower) catch |err| {
            std.debug.print("Failed to add tower to list (allocator error): {}\n", .{err});
            return false;
        };
        game.board.setTileOccupied(x, y, true);
        std.debug.print("Placed {} tower at ({}, {}).\n", .{ kind, x, y });
        return true;
    }

    pub fn spawnEnemy(game: *Game, kind: EnemyKind) !void {
        if (game.board.path_waypoints.items.len == 0) {
            std.debug.print("Cannot spawn enemy: Path is not defined.\n", .{});
            // Or return an error like: return error.PathNotDefined;
            return; // Simple return for now
        }
        const start_waypoint = game.board.path_waypoints.items[0];
        const start_x: f32 = @floatFromInt(start_waypoint.x);
        const start_y: f32 = @floatFromInt(start_waypoint.y);

        const new_enemy = Enemy.createEnemy(game.next_enemy_id, kind, start_x, start_y);
        try game.enemies.append(new_enemy);
        game.next_enemy_id += 1;
        std.debug.print("Spawned enemy {} ID {}\n", .{kind, new_enemy.id});
    }

    pub fn updateEnemies(game: *Game, delta_time: f32) void {
        var i: usize = 0;
        while (i < game.enemies.items.len) {
            var enemy = &game.enemies.items[i]; // Get a mutable reference

            if (enemy.path_index >= game.board.path_waypoints.items.len) {
                // Enemy reached the end or went past (should ideally be caught by distance check)
                std.debug.print("Enemy {} reached the end!\n", .{enemy.id});
                game.player_health -= 1; // Or some enemy-specific damage value
                if (game.player_health <= 0) {
                    game.player_health = 0;
                    game.game_over = true;
                    std.debug.print("Player health depleted. Game Over!\n", .{});
                }
                // Mark for removal (e.g. by swapping with last and popping)
                _ = game.enemies.swapRemove(i);
                // Do not increment i, as the current index now holds a new enemy (or list is shorter)
                continue;
            }

            const target_waypoint_coord = game.board.path_waypoints.items[enemy.path_index];
            const target_x: f32 = @floatFromInt(target_waypoint_coord.x);
            const target_y: f32 = @floatFromInt(target_waypoint_coord.y);

            const dx = target_x - enemy.x;
            const dy = target_y - enemy.y;

            const dist_sq = dx * dx + dy * dy;

            // Check if close enough to snap to waypoint
            // Using a threshold based on speed and delta_time, or a fixed small value
            const snap_threshold_sq: f32 = (enemy.speed * delta_time) * (enemy.speed * delta_time) * 1.1; // A bit more than one step
            const fixed_snap_sq: f32 = 0.01; // (0.1 * 0.1)

            if (dist_sq < fixed_snap_sq or dist_sq < snap_threshold_sq) {
                enemy.x = target_x;
                enemy.y = target_y;
                enemy.path_index += 1;

                // Check again if the new path_index is the end
                if (enemy.path_index >= game.board.path_waypoints.items.len) {
                    std.debug.print("Enemy {} reached the end (after snap)!\n", .{enemy.id});
                    game.player_health -= 1; // Or some enemy-specific damage value
                    if (game.player_health <= 0) {
                        game.player_health = 0;
                        game.game_over = true;
                        std.debug.print("Player health depleted. Game Over!\n", .{});
                    }
                    _ = game.enemies.swapRemove(i);
                    // DO NOT INCREMENT i HERE. Loop will restart with new element at i or terminate.
                    continue;
                }
                // If not removed, but snapped, then we are done with this enemy for this update tick.
                // So we should increment i and continue to the next enemy.
                i += 1;
                continue;
            } else {
                // Move towards target
                const dist = @sqrt(dist_sq); // Requires -lm on linux for zig test/run if using std.math.sqrt
                                           // @sqrt is a builtin, should be fine.
                const norm_dx = dx / dist;
                const norm_dy = dy / dist;

                enemy.x += norm_dx * enemy.speed * delta_time;
                enemy.y += norm_dy * enemy.speed * delta_time;
            }
            i += 1;
        }
    }

    pub fn startNextWave(game: *Game) void {
        game.current_wave_number += 1;
        game.enemies_spawned_this_wave = 0;
        game.enemies_per_wave = 2 + game.current_wave_number; // Example: Wave 1 -> 3 enemies, Wave 2 -> 4 enemies
        std.debug.print("Wave {} starting! ({} enemies)\n", .{ game.current_wave_number, game.enemies_per_wave });
    }

    pub fn manageEnemySpawning(game: *Game) !void {
        if (game.enemies_spawned_this_wave < game.enemies_per_wave) {
            // For now, always spawn Grunts. Could be randomized or wave-dependent.
            // Also, this spawns one enemy per game update if conditions met.
            // A timer could be added for spawn intervals within a wave.
            try game.spawnEnemy(EnemyKind.Grunt);
            game.enemies_spawned_this_wave += 1;
        }
    }

    pub fn updateGame(game: *Game, delta_time: f32) !void {
        if (game.game_over) {
            return;
        }

        // Check for starting next wave
        // Condition: No enemies currently active AND
        // (either it's the very start of the game (wave 0 and nothing spawned yet from it) OR
        //  all enemies for the current wave have been spawned)
        if (game.enemies.items.len == 0) {
            if (game.current_wave_number == 0 or (game.enemies_spawned_this_wave == game.enemies_per_wave)) {
                game.startNextWave();
            }
        }

        // Only try to spawn if the wave has started and not all enemies for the wave are out
        if (game.current_wave_number > 0) {
             try game.manageEnemySpawning();
        }
        game.updateEnemies(delta_time);

        // Placeholder for tower actions
        // towersAttack(game, delta_time);

        // Check for game over again in case health dropped during enemy update
        if (game.player_health <= 0 and !game.game_over) {
            game.game_over = true;
            std.debug.print("Game Over condition met during updateGame.\n",.{});
        }
    }
};

test "Game spawnEnemy and basic updateEnemies" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var game = try Game.initGame(5, 3, allocator); // Path on row 1 (0,1) to (4,1)
    defer game.deinitGame();

    // Path should be (0,1), (1,1), (2,1), (3,1), (4,1)
    try std.testing.expectEqual(@as(usize, 5), game.board.path_waypoints.items.len);
    try std.testing.expectEqual(Vec2u32{ .x = 0, .y = 1 }, game.board.path_waypoints.items[0]);

    try game.spawnEnemy(EnemyKind.Grunt);
    try std.testing.expectEqual(@as(usize, 1), game.enemies.items.len);
    try std.testing.expectEqual(@as(u32, 0), game.enemies.items[0].id);
    try std.testing.expectEqual(@as(f32, 0.0), game.enemies.items[0].x);
    try std.testing.expectEqual(@as(f32, 1.0), game.enemies.items[0].y);
    try std.testing.expectEqual(@as(usize, 0), game.enemies.items[0].path_index);

    // Enemy spawns at (0,1), path_index = 0. Target is path_waypoints[0] = (0,1).
    // First update: enemy is already at target. Snaps, path_index becomes 1. Position (0,1).
    game.updateEnemies(0.5); // delta_time = 0.5 seconds
    try std.testing.expectEqual(@as(f32, 0.0), game.enemies.items[0].x);
    try std.testing.expectEqual(@as(f32, 1.0), game.enemies.items[0].y);
    try std.testing.expectEqual(@as(usize, 1), game.enemies.items[0].path_index); // Now targeting path_waypoints[1] = (1,1)

    // Second update: enemy at (0,1), path_index = 1. Target is (1,1). Speed 1.0. delta_time = 0.6.
    // dx = 1, dy = 0. dist = 1. norm_dx = 1, norm_dy = 0.
    // new_x = 0.0 + 1.0 * 1.0 * 0.6 = 0.6. new_y = 1.0.
    game.updateEnemies(0.6);
    try std.testing.expectEqual(@as(f32, 0.6), game.enemies.items[0].x);
    try std.testing.expectEqual(@as(f32, 1.0), game.enemies.items[0].y);
    try std.testing.expectEqual(@as(usize, 1), game.enemies.items[0].path_index); // Still targeting (1,1), not reached yet.

    std.debug.print("\nEnemy after updates: id {}, x: {d:.2}, y: {d:.2}, path_idx: {}\n", .{
        game.enemies.items[0].id, game.enemies.items[0].x, game.enemies.items[0].y, game.enemies.items[0].path_index,
    });

    // Third update: enemy at (0.6,1), path_index = 1. Target is (1,1). Speed 1.0. delta_time = 0.4 to make it reach.
    // dx = 0.4, dy = 0. dist = 0.4. norm_dx = 1, norm_dy = 0.
    // new_x = 0.6 + 1.0 * 1.0 * 0.4 = 1.0. new_y = 1.0
    game.updateEnemies(0.4);
    try std.testing.expectEqual(@as(f32, 1.0), game.enemies.items[0].x); // Reached (1,1)
    try std.testing.expectEqual(@as(f32, 1.0), game.enemies.items[0].y);
    try std.testing.expectEqual(@as(usize, 2), game.enemies.items[0].path_index); // Snapped, now targeting path_waypoints[2] = (2,1)

    // Move enemy to the end of the path
    // Path: (0,1) (1,1) (2,1) (3,1) (4,1) -> 5 waypoints, indices 0-4
    // Current state: at (1,1), path_index = 2, target is (2,1)

    game.updateEnemies(1.0); // Moves from (1,1) to (2,1). Snaps. path_index = 3. Target (3,1)
    try std.testing.expectEqual(@as(f32, 2.0), game.enemies.items[0].x);
    try std.testing.expectEqual(@as(usize, 3), game.enemies.items[0].path_index);

    game.updateEnemies(1.0); // Moves from (2,1) to (3,1). Snaps. path_index = 4. Target (4,1)
    try std.testing.expectEqual(@as(f32, 3.0), game.enemies.items[0].x);
    try std.testing.expectEqual(@as(usize, 4), game.enemies.items[0].path_index); // Now targeting path_waypoints[4] = (4,1)

    // This update moves the enemy to the last waypoint (4,1).
    // It snaps, path_index becomes 5.
    // Then, within the same updateEnemies call, it's detected that path_index (5) >= waypoints.len (5),
    // so the enemy is removed.
    std.debug.print("Before update that moves to last waypoint and removes: enemy x={d:.1}, path_idx={}\n", .{game.enemies.items[0].x, game.enemies.items[0].path_index});
    game.updateEnemies(1.0);

    std.debug.print("After update that should remove enemy, count: {}\n", .{game.enemies.items.len});
    try std.testing.expectEqual(@as(usize, 0), game.enemies.items.len); // Enemy should be removed
}

test "Game wave management and player health" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var game = try Game.initGame(5, 3, allocator);
    defer game.deinitGame();

    // Initial state
    try std.testing.expectEqual(@as(i32, 100), game.player_health);
    try std.testing.expectEqual(@as(u32, 0), game.current_wave_number);
    try std.testing.expectEqual(@as(u32, 3), game.enemies_per_wave); // 2 + 0 (initial wave not started)
    try std.testing.expectEqual(@as(bool, false), game.game_over);

    // Start first wave
    try game.updateGame(0.1); // Should trigger startNextWave
    try std.testing.expectEqual(@as(u32, 1), game.current_wave_number);
    try std.testing.expectEqual(@as(u32, 2 + 1), game.enemies_per_wave); // 2 + 1
    try std.testing.expectEqual(@as(u32, 1), game.enemies_spawned_this_wave); // First enemy of wave 1 spawned
    try std.testing.expectEqual(@as(usize, 1), game.enemies.items.len);

    // Simulate enemy reaching end
    game.enemies.items[0].path_index = game.board.path_waypoints.items.len; // Teleport to end
    game.updateEnemies(0.1); // Process reaching end
    try std.testing.expectEqual(@as(i32, 99), game.player_health);
    try std.testing.expectEqual(@as(usize, 0), game.enemies.items.len);

    // Deplete health
    game.player_health = 1;
    try game.spawnEnemy(EnemyKind.Grunt); // Need an enemy to trigger health loss
    game.enemies.items[0].path_index = game.board.path_waypoints.items.len; // Teleport to end
    game.updateEnemies(0.1); // Process reaching end
    try std.testing.expectEqual(@as(i32, 0), game.player_health);
    try std.testing.expectEqual(@as(bool, true), game.game_over);

    // Further updates should not change game over state or health
    try game.updateGame(0.1);
    try std.testing.expectEqual(@as(i32, 0), game.player_health);
}
