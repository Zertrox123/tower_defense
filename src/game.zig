const std = @import("std");
const board_module = @import("board.zig");
const tower_module = @import("tower.zig");
const enemy_module = @import("enemy.zig");
const wave_module = @import("wave.zig"); // Import the new wave module
const math = std.math;

pub const GameView = struct {
    enemies: []const enemy_module.Enemy,
    board: board_module.Board,
};

pub const Game = struct {
    allocator: std.mem.Allocator,
    board: board_module.Board,
    towers: std.ArrayList(tower_module.Tower),
    enemies: std.ArrayList(enemy_module.Enemy),
    tower_data_registry: std.ArrayList(tower_module.TowerData),

    // New wave management fields
    all_wave_definitions: std.ArrayList(wave_module.WaveData),
    current_wave_group_index: usize,
    enemies_spawned_in_current_group: u32,
    time_to_next_spawn_event: f32, // General timer for spawning logic (can be delay or interval)
    // `current_wave_number` (from before) will now be an index into `all_wave_definitions`

    player_health: i32,
    player_currency: u32,
    current_wave_number: u32, // Index for all_wave_definitions, 0 means before first wave.
    game_over: bool,

    enemy_path_template: std.ArrayList(struct { x: u32, y: u32 }),

    starting_health: i32 = 100,
    starting_currency: u32 = 200,
    // Removed: enemies_per_wave_base, wave_enemy_increment, enemies_spawned_this_wave, time_since_last_spawn, spawn_interval

    // Tower data loading (unchanged from previous step)
    fn loadAllTowerData(self: *Game) !void {
        try self.tower_data_registry.append(tower_module.TowerData{
            .id = 0, .name = "Minigun", .char_representation = 'M', .damage = 5, .range = 3.0, .firerate = 2.0, .cost = 50,
            .upgrades_to_id = 4, .upgrade_cost = 75,
        });
        try self.tower_data_registry.append(tower_module.TowerData{
            .id = 1, .name = "Sniper", .char_representation = 'S', .damage = 20, .range = 7.0, .firerate = 0.5, .cost = 100,
            .upgrades_to_id = null, .upgrade_cost = 0,
        });
        try self.tower_data_registry.append(tower_module.TowerData{
            .id = 2, .name = "Cannon", .char_representation = 'C', .damage = 35, .range = 4.0, .firerate = 0.33, .cost = 120,
            .upgrades_to_id = null, .upgrade_cost = 0,
        });
        try self.tower_data_registry.append(tower_module.TowerData{
            .id = 3, .name = "Laser", .char_representation = 'L', .damage = 2, .range = 2.5, .firerate = 5.0, .cost = 75,
            .upgrades_to_id = null, .upgrade_cost = 0,
        });
        try self.tower_data_registry.append(tower_module.TowerData{
            .id = 4, .name = "Minigun Mk2", .char_representation = 'm', .damage = 8, .range = 3.5, .firerate = 2.2, .cost = 0,
            .upgrades_to_id = null, .upgrade_cost = 0,
        });
    }

    // New: Load wave definitions
    fn loadWaveDefinitions(self: *Game) !void {
        // Wave 1 (index 0 in all_wave_definitions)
        var wave0_data = try wave_module.WaveData.init(self.allocator, &.{
            .{ .kind = .grunt, .count = 5, .spawn_interval = 0.8, .delay_after_previous_group = 0.0 },
        });
        errdefer wave0_data.deinit(); // Ensure cleanup if subsequent appends fail
        try self.all_wave_definitions.append(wave0_data);

        // Wave 2 (index 1)
        var wave1_data = try wave_module.WaveData.init(self.allocator, &.{
            .{ .kind = .grunt, .count = 8, .spawn_interval = 0.6, .delay_after_previous_group = 0.0 },
            .{ .kind = .scout, .count = 3, .spawn_interval = 1.0, .delay_after_previous_group = 2.0 },
        });
        errdefer wave1_data.deinit();
        try self.all_wave_definitions.append(wave1_data);

        // Wave 3 (index 2) - Example with more groups
        var wave2_data = try wave_module.WaveData.init(self.allocator, &.{
            .{ .kind = .scout, .count = 6, .spawn_interval = 0.5, .delay_after_previous_group = 0.0 },
            .{ .kind = .grunt, .count = 10, .spawn_interval = 0.4, .delay_after_previous_group = 3.0 },
            .{ .kind = .tank, .count = 2, .spawn_interval = 1.5, .delay_after_previous_group = 5.0 },
        });
        // errdefer wave2_data.deinit(); // Not strictly needed for last one if append is last op before success.
        try self.all_wave_definitions.append(wave2_data);
    }


    pub fn init(allocator: std.mem.Allocator, board_width: u32, board_height: u32) !Game {
        var board = try board_module.Board.init(allocator, board_width, board_height);
        var path_template = std.ArrayList(struct { x: u32, y: u32 }).init(allocator);
        errdefer { path_template.deinit(); board.deinit(); } // Handles path/board if subsequent ops fail

        const mid_y = board_height / 2;
        var x_coord: u32 = 0;
        while (x_coord < board_width) : (x_coord += 1) {
            if (!board.setTile(x_coord, mid_y, board_module.Tile.path)) return error.BoardSetupFailed;
            try path_template.append(.{ .x = x_coord, .y = mid_y });
        }
        if (path_template.items.len == 0) return error.PathSetupFailed;

        var game_instance = Game{
            .allocator = allocator, .board = board,
            .towers = std.ArrayList(tower_module.Tower).init(allocator),
            .enemies = std.ArrayList(enemy_module.Enemy).init(allocator),
            .tower_data_registry = std.ArrayList(tower_module.TowerData).init(allocator),
            .all_wave_definitions = std.ArrayList(wave_module.WaveData).init(allocator), // Init new field
            .current_wave_group_index = 0,
            .enemies_spawned_in_current_group = 0,
            .time_to_next_spawn_event = 0.0, // Will be set by startNextWave
            .player_health = Game.starting_health, .player_currency = Game.starting_currency,
            .current_wave_number = 0, // Before first wave
            .game_over = false,
            .enemy_path_template = path_template,
        };

        // Load data, with error propagation and cleanup
        game_instance.loadAllTowerData() catch |err| {
            // Deinit things specific to game_instance initialized so far
            game_instance.all_wave_definitions.deinit(); // Deinit new field
            game_instance.tower_data_registry.deinit();
            game_instance.enemies.deinit();
            game_instance.towers.deinit();
            // path_template and board are covered by errdefer in this scope
            return err;
        };

        game_instance.loadWaveDefinitions() catch |err| {
            // Deinit things specific to game_instance initialized so far
            // all_wave_definitions might be partially populated, its deinit handles that.
            for(game_instance.all_wave_definitions.items) |*wd| { wd.deinit(); } // Deinit individual WaveData
            game_instance.all_wave_definitions.deinit();
            game_instance.tower_data_registry.deinit();
            game_instance.enemies.deinit();
            game_instance.towers.deinit();
            return err;
        };

        return game_instance;
    }

    pub fn deinit(self: *Game) void {
        for (self.enemies.items) |*enemy| { enemy.deinit(); }
        self.enemies.deinit();
        self.towers.deinit();
        self.tower_data_registry.deinit();
        // Deinitialize all_wave_definitions
        for (self.all_wave_definitions.items) |*wave_data_item| {
            wave_data_item.deinit(); // Call deinit on each WaveData
        }
        self.all_wave_definitions.deinit();
        self.enemy_path_template.deinit();
        self.board.deinit();
    }

    // ... (placeTower, getTowerData, findTowerAt, upgradeTower, updateTowers remain the same) ...
    pub fn placeTower(self: *Game, tower_data_id: u32, x: u32, y: u32) bool {
        if (self.game_over) { std.debug.print("Cannot place tower: Game is over.\n", .{}); return false; }
        if (tower_data_id >= self.tower_data_registry.items.len) {
            std.debug.print("Tower ID {d} is invalid. Max ID is {d}.\n", .{tower_data_id, self.tower_data_registry.items.len - 1});
            return false;
        }
        const selected_tower_data = self.tower_data_registry.items[tower_data_id];
        if (selected_tower_data.cost == 0) {
            std.debug.print("{s} cannot be bought directly.\n", .{selected_tower_data.name});
            return false;
        }
        const tile = self.board.getTile(x,y);
        if (tile == null or tile.? != board_module.Tile.empty) {
            std.debug.print("Location ({d},{d}) is not buildable/occupied.\n", .{x,y});
            return false;
        }
        if (self.player_currency < selected_tower_data.cost) {
            std.debug.print("Not enough currency for {s}.\n", .{selected_tower_data.name});
            return false;
        }
        self.player_currency -= selected_tower_data.cost;
        const new_tower = tower_module.createTower(selected_tower_data.id, x, y);
        self.towers.append(new_tower) catch |e| { std.debug.print("Failed to append tower:{any}\n",.{e}); self.player_currency += selected_tower_data.cost; return false; };
        if (!self.board.setTile(x, y, board_module.Tile.tower)) {
            _ = self.towers.pop(); self.player_currency += selected_tower_data.cost;
            std.debug.print("Failed to set board tile.\n",.{}); return false;
        }
        return true;
    }
    pub fn getTowerData(self: Game, tower_instance: tower_module.Tower) ?tower_module.TowerData {
        if (tower_instance.data_id < self.tower_data_registry.items.len and
            self.tower_data_registry.items[tower_instance.data_id].id == tower_instance.data_id) {
            return self.tower_data_registry.items[tower_instance.data_id];
        }
        return null;
    }
    pub fn findTowerAt(self: Game, x: u32, y: u32) ?*tower_module.Tower {
        for (self.towers.items) |*t| { if (t.x == x and t.y == y) return t; } return null;
    }
    pub fn upgradeTower(self: *Game, tx: u32, ty: u32) bool {
        if (self.game_over) { std.debug.print("Game over.\n",{}); return false; }
        const t_ptr = self.findTowerAt(tx,ty) orelse {std.debug.print("No tower at ({d},{d}).\n",{tx,ty}); return false;};
        const td = self.tower_data_registry.items[t_ptr.data_id];
        const upg_id = td.upgrades_to_id orelse {std.debug.print("{s} max level.\n",{td.name}); return false;};
        if (upg_id >= self.tower_data_registry.items.len) { std.debug.print("Invalid upg_id {d}.\n",{upg_id}); return false;}
        if (self.player_currency < td.upgrade_cost) {std.debug.print("Need {d} for upg, have {d}.\n",{td.upgrade_cost, self.player_currency}); return false; }
        self.player_currency -= td.upgrade_cost;
        t_ptr.data_id = upg_id; t_ptr.current_cooldown = 0.0;
        const new_td = self.tower_data_registry.items[upg_id];
        std.debug.print("{s} upg to {s}.\n",{td.name, new_td.name}); return true;
    }
     fn updateTowers(self: *Game, delta_time: f32) !void {
        if (self.game_over) return;
        for (self.towers.items) |*t_inst_ptr| {
            var cur_t_inst = t_inst_ptr; cur_t_inst.current_cooldown -= delta_time;
            if (cur_t_inst.current_cooldown <= 0.0) {
                if (cur_t_inst.data_id >= self.tower_data_registry.items.len) continue;
                const cur_t_data = self.tower_data_registry.items[cur_t_inst.data_id];
                const gv = GameView{.enemies=self.enemies.items, .board=self.board};
                if (tower_module.findTarget(cur_t_inst.*, cur_t_data, gv)) |enemy_idx| {
                    if (enemy_idx < self.enemies.items.len) {
                        var target_e = &self.enemies.items[enemy_idx];
                        target_e.takeDamage(cur_t_data.damage);
                        cur_t_inst.current_cooldown = 1.0 / cur_t_data.firerate;
                    } else { cur_t_inst.current_cooldown = 0.0; }
                } else { cur_t_inst.current_cooldown = 0.0; }
            }
        }
    }


    // Modified: spawnEnemy now just takes a kind, path is from game.enemy_path_template
    fn spawnEnemy(self: *Game, kind: enemy_module.EnemyKind) !void {
        if (self.enemy_path_template.items.len == 0) return error.EmptyPath;
        // This now uses the game's path template for all enemies.
        var new_enemy = try enemy_module.spawnEnemy(self.allocator, kind, self.enemy_path_template.items);
        try self.enemies.append(new_enemy);
        // Debug print moved to manageEnemySpawning for context
    }

    // Modified startNextWave
    fn startNextWave(self: *Game) void {
        if (self.game_over and self.current_wave_number >= self.all_wave_definitions.items.len) {
             // If game is over because all waves cleared, don't try to start another.
            return;
        }
        if (self.player_health <= 0) { // Ensure game over if health is already 0
            self.game_over = true;
            return;
        }

        // Optional: Wave completion bonus for previous wave
        if (self.current_wave_number > 0) {
            // Example: const bonus = self.current_wave_number * 10;
            // self.player_currency += bonus;
            // std.debug.print("Wave {d} cleared! Bonus: +{d} currency.\n", .{self.current_wave_number, bonus});
        }

        self.current_wave_number += 1; // This is wave "number" (1-indexed for display)
                                       // but corresponds to index current_wave_number-1 in all_wave_definitions

        const current_wave_idx = self.current_wave_number -1; // Actual index

        if (current_wave_idx >= self.all_wave_definitions.items.len) {
            std.debug.print("All predefined waves cleared! You Win!\n", .{});
            self.game_over = true; // Set game over for victory
            return;
        }

        self.current_wave_group_index = 0;
        self.enemies_spawned_in_current_group = 0;

        const current_wave_definition = self.all_wave_definitions.items[current_wave_idx];
        if (current_wave_definition.enemy_groups.items.len > 0) {
            self.time_to_next_spawn_event = current_wave_definition.enemy_groups.items[0].delay_after_previous_group;
        } else {
            self.time_to_next_spawn_event = 0.0; // No groups, should not happen with good data
        }
        std.debug.print("Starting Wave {d} (Index {d}). First group delay: {f:.2}s\n", .{
            self.current_wave_number, current_wave_idx, self.time_to_next_spawn_event});
    }

    // New manageEnemySpawning
    fn manageEnemySpawning(self: *Game, delta_time: f32) !void {
        if (self.current_wave_number == 0) return; // No waves started yet
        const current_wave_idx = self.current_wave_number -1;
        if (current_wave_idx >= self.all_wave_definitions.items.len or self.game_over) {
            return; // All waves done or game is over
        }

        self.time_to_next_spawn_event -= delta_time;

        if (self.time_to_next_spawn_event <= 0) {
            const current_wave_data = &self.all_wave_definitions.items[current_wave_idx];

            if (self.current_wave_group_index >= current_wave_data.enemy_groups.items.len) {
                // All groups for this wave have been processed for spawning.
                // updateGame will check if all spawned enemies are dead to advance the wave.
                return;
            }

            const current_group_config = &current_wave_data.enemy_groups.items[self.current_wave_group_index];

            if (self.enemies_spawned_in_current_group < current_group_config.count) {
                // Spawn an enemy from the current group
                try self.spawnEnemy(current_group_config.kind);
                 std.debug.print("Spawned {s} from group {d}/{d} (Wave {d}). Total in group: {d}/{d}\n", .{
                    @tagName(current_group_config.kind),
                    self.current_wave_group_index + 1, current_wave_data.enemy_groups.items.len,
                    self.current_wave_number,
                    self.enemies_spawned_in_current_group + 1, current_group_config.count,
                });
                self.enemies_spawned_in_current_group += 1;
                self.time_to_next_spawn_event = current_group_config.spawn_interval; // Time for next enemy in this group
            }

            // Check if current group is finished AFTER attempting a spawn
            if (self.enemies_spawned_in_current_group >= current_group_config.count) {
                self.current_wave_group_index += 1; // Move to next group
                self.enemies_spawned_in_current_group = 0; // Reset count for new group

                if (self.current_wave_group_index < current_wave_data.enemy_groups.items.len) {
                    // There's another group in this wave, set delay for it
                    const next_group_config = &current_wave_data.enemy_groups.items[self.current_wave_group_index];
                    self.time_to_next_spawn_event = next_group_config.delay_after_previous_group;
                     std.debug.print("Group finished. Next group ({d}/{d}) starts in {f:.2}s.\n", .{
                        self.current_wave_group_index+1, current_wave_data.enemy_groups.items.len, self.time_to_next_spawn_event});

                } else {
                    // All groups in this wave are done spawning.
                    // Set a long delay or a flag to prevent further processing by manageEnemySpawning this wave.
                    self.time_to_next_spawn_event = 3600.0; // Effectively infinite for typical game session
                    std.debug.print("All groups in Wave {d} have finished spawning procedures.\n", .{self.current_wave_number});
                }
            }
        }
    }

    fn updateEnemies(self: *Game, delta_time: f32) void {
        // ... (remains mostly the same, ensures is_active check)
         if (self.game_over) return;
        var i: usize = 0;
        while (i < self.enemies.items.len) {
            var current_enemy_ptr = &self.enemies.items[i];
            if (!current_enemy_ptr.is_active) { i += 1; continue; }
            if (current_enemy_ptr.updatePosition(delta_time)) {
                std.debug.print("Enemy {} leaked.\n", .{current_enemy_ptr.id});
                self.player_health -= 1;
                current_enemy_ptr.is_active = false;
                if (self.player_health <= 0) { self.player_health = 0; self.game_over = true; }
            }
            i += 1;
        }
    }
    fn processEnemyDeaths(self: *Game) !void {
        // ... (remains the same)
        var i: usize = 0;
        while (i < self.enemies.items.len) {
            const enemy_instance = self.enemies.items[i];
            if (!enemy_instance.is_active) {
                if (enemy_instance.current_health == 0) {
                    self.player_currency += enemy_instance.gold_reward;
                }
                self.enemies.items[i].deinit();
                _ = self.enemies.swapRemove(i);
            } else { i += 1; }
        }
    }

    pub fn updateGame(self: *Game, delta_time: f32) !void {
        if (self.game_over) {
            // Check if game_over was due to victory (all waves cleared and no enemies left)
            if (self.current_wave_number > 0 and (self.current_wave_number-1) >= self.all_wave_definitions.items.len and self.enemies.items.len == 0) {
                 std.debug.print("Victory condition met!\n", .{});
            } else if (self.player_health <= 0) {
                 std.debug.print("Defeat condition met (player health <= 0).\n", .{});
            }
            return;
        }


        // 1. Start first wave / Check for advancing to next wave
        if (self.current_wave_number == 0) { // Game just started, start first wave
            self.startNextWave();
        } else { // Check if current wave is complete and time to start next
            const current_wave_idx = self.current_wave_number - 1;
            if (current_wave_idx < self.all_wave_definitions.items.len) {
                const current_wave_data = &self.all_wave_definitions.items[current_wave_idx];
                // Wave is complete if all groups have been processed for spawning AND no active enemies remain.
                if (self.current_wave_group_index >= current_wave_data.enemy_groups.items.len and
                    self.enemies.items.len == 0 and
                    self.player_health > 0) { // Ensure player is alive
                    std.debug.print("Wave {d} fully cleared (all groups spawned, all enemies dead).\n", .{self.current_wave_number});
                    self.startNextWave(); // This also handles game win if all definitions cleared
                    if (self.game_over) return; // Game might end due to victory in startNextWave
                }
            }
        }

        // 2. Manage enemy spawning for the current wave
        try self.manageEnemySpawning(delta_time);

        // 3. Update towers (targeting and firing)
        try self.updateTowers(delta_time);

        // 4. Update enemies (movement, and handling reaching the end of the path)
        self.updateEnemies(delta_time);
        if (self.game_over) return; // Check if an enemy leaking caused game over

        // 5. Process enemy deaths and remove inactive enemies
        try self.processEnemyDeaths();

        // Game over is checked at the start of the loop and after critical state changes.
    }
};

// --- Tests ---
fn createGameForTest(allocator: std.mem.Allocator) !Game {
    return Game.init(allocator, 10, 5);
}

test "loadWaveDefinitions" {
    const allocator = std.testing.allocator;
    var game = Game.init(allocator, 10, 5) catch |err| {
        std.debug.print("Failed to init game for test: {any}\n", .{err});
        return err;
    };
    defer game.deinit();

    // loadWaveDefinitions is called in init. Check results.
    try std.testing.expectEqual(@as(usize, 3), game.all_wave_definitions.items.len); // 3 waves defined

    // Check Wave 0 (index 0)
    const wave0 = game.all_wave_definitions.items[0];
    try std.testing.expectEqual(@as(usize, 1), wave0.enemy_groups.items.len);
    try std.testing.expectEqual(enemy_module.EnemyKind.grunt, wave0.enemy_groups.items[0].kind);
    try std.testing.expectEqual(@as(u32, 5), wave0.enemy_groups.items[0].count);

    // Check Wave 1 (index 1)
    const wave1 = game.all_wave_definitions.items[1];
    try std.testing.expectEqual(@as(usize, 2), wave1.enemy_groups.items.len);
    try std.testing.expectEqual(enemy_module.EnemyKind.grunt, wave1.enemy_groups.items[0].kind);
    try std.testing.expectEqual(@as(u32, 8), wave1.enemy_groups.items[0].count);
    try std.testing.expectEqual(enemy_module.EnemyKind.scout, wave1.enemy_groups.items[1].kind);
    try std.testing.expectEqual(@as(u32, 3), wave1.enemy_groups.items[1].count);
    try std.testing.expectEqualApprox(@as(f32,2.0), wave1.enemy_groups.items[1].delay_after_previous_group, 0.001);
}

test "startNextWave logic" {
    const allocator = std.testing.allocator;
    var game = try createGameForTest(allocator);
    defer game.deinit();

    try std.testing.expectEqual(@as(u32,0), game.current_wave_number); // Initial state

    // Start first wave (Wave 1, index 0)
    game.startNextWave();
    try std.testing.expectEqual(@as(u32,1), game.current_wave_number);
    try std.testing.expectEqual(@as(usize,0), game.current_wave_group_index);
    try std.testing.expectEqual(@as(u32,0), game.enemies_spawned_in_current_group);
    // First group of first wave has 0.0 delay
    try std.testing.expectEqualApprox(@as(f32,0.0), game.time_to_next_spawn_event, 0.001);

    // Simulate completion of Wave 1, start Wave 2 (index 1)
    game.startNextWave();
    try std.testing.expectEqual(@as(u32,2), game.current_wave_number);
    try std.testing.expectEqual(@as(usize,0), game.current_wave_group_index);
    // First group of second wave also has 0.0 delay
    try std.testing.expectEqualApprox(@as(f32,0.0), game.time_to_next_spawn_event, 0.001);

    // Simulate completion of Wave 2, start Wave 3 (index 2)
    game.startNextWave();
    try std.testing.expectEqual(@as(u32,3), game.current_wave_number);

    // Simulate completion of Wave 3 (last defined wave)
    game.startNextWave(); // Tries to start wave 4 (index 3)
    try std.testing.expectEqual(@as(u32,4), game.current_wave_number); // Increments first
    try std.testing.expect(game.game_over); // Should set game_over to true (victory)
}

test "manageEnemySpawning logic" {
    const allocator = std.testing.allocator;
    var game = try createGameForTest(allocator);
    defer game.deinit();

    game.startNextWave(); // Start Wave 1 (5 grunts, 0.8s interval, 0.0s initial delay)
    try std.testing.expectEqual(@as(u32,1), game.current_wave_number);

    // Tick 1: Spawn first grunt (time_to_next_spawn_event was 0.0)
    try game.manageEnemySpawning(0.1); // delta_time doesn't make it negative yet, but it was 0
    try std.testing.expectEqual(@as(usize,1), game.enemies.items.len);
    try std.testing.expectEqual(@as(u32,1), game.enemies_spawned_in_current_group);
    try std.testing.expectEqualApprox(@as(f32,0.8), game.time_to_next_spawn_event, 0.001);

    // Tick 2: Not enough time passed for next spawn
    try game.manageEnemySpawning(0.5); // total time passed for this interval: 0.5. Cooldown is 0.8.
    try std.testing.expectEqual(@as(usize,1), game.enemies.items.len); // Still 1 enemy
    try std.testing.expectEqualApprox(@as(f32,0.8-0.5), game.time_to_next_spawn_event, 0.001); // 0.3 remaining

    // Tick 3: Enough time for second spawn
    try game.manageEnemySpawning(0.3); // total time is 0.3. Cooldown becomes 0.
    try std.testing.expectEqual(@as(usize,2), game.enemies.items.len);
    try std.testing.expectEqual(@as(u32,2), game.enemies_spawned_in_current_group);
    try std.testing.expectEqualApprox(@as(f32,0.8), game.time_to_next_spawn_event, 0.001);

    // Spawn remaining 3 grunts for group 1 of wave 1
    var i:u32 = 2;
    while(i < 5) : (i+=1) {
        try game.manageEnemySpawning(0.8); // Exact interval
    }
    try std.testing.expectEqual(@as(usize,5), game.enemies.items.len);
    try std.testing.expectEqual(@as(u32,5), game.enemies_spawned_in_current_group);
    // Group 1 of Wave 1 is done. current_wave_group_index should be 1 (as Wave 1 only has 1 group).
    // time_to_next_spawn_event should be very large as all groups in wave are done.
    try game.manageEnemySpawning(0.01); // Process the group completion
    try std.testing.expectEqual(@as(usize,1), game.current_wave_group_index);
    try std.testing.expectEqualApprox(@as(f32,3600.0), game.time_to_next_spawn_event, 0.001);
}


// ... (Other tests like placeTower, upgradeTower, updateTowers, processEnemyDeaths, updateGame sequence tests remain)
// They would need to be run in context of the new wave system if they involve spawning or wave progression.
// For now, focusing on testing the new wave logic itself.
// The `updateGame` test needs to be more aware of the new wave logic.
test "updateGame with new wave logic" {
    const allocator = std.testing.allocator;
    var game = try createGameForTest(allocator);
    defer game.deinit();

    // Game starts, current_wave_number = 0.
    // First updateGame call:
    try game.updateGame(0.1); // Starts Wave 1 (index 0). Spawns first enemy of group 1.
    try std.testing.expectEqual(@as(u32,1), game.current_wave_number);
    try std.testing.expectEqual(@as(usize,1), game.enemies.items.len); // 1 grunt spawned
    try std.testing.expectEqual(enemy_module.EnemyKind.grunt, game.enemies.items[0].kind);
    try std.testing.expectEqual(@as(u32,1), game.enemies_spawned_in_current_group);
    try std.testing.expectEqual(@as(usize,0), game.current_wave_group_index); // Still in group 0

    // Simulate time to spawn all 5 grunts in group 1 of wave 1 (4 more after the first)
    // Interval 0.8s.
    try game.updateGame(0.8); // 2nd grunt
    try game.updateGame(0.8); // 3rd grunt
    try game.updateGame(0.8); // 4th grunt
    try game.updateGame(0.8); // 5th grunt
    try std.testing.expectEqual(@as(usize,5), game.enemies.items.len);
    try std.testing.expectEqual(@as(u32,5), game.enemies_spawned_in_current_group); // Group 1 done
    // After these spawns, manageEnemySpawning will detect group is done, increment current_wave_group_index.
    // Since Wave 1 (index 0) only has one group, current_wave_group_index becomes 1.
    // time_to_next_spawn_event becomes large.

    // For next wave to start, all enemies must be cleared.
    // Manually clear enemies for testing wave transition
    for(game.enemies.items) |*e| {e.deinit();}
    game.enemies.clearRetainingCapacity();
    try std.testing.expectEqual(@as(usize,0), game.enemies.items.len);

    // One more updateGame should trigger startNextWave (for Wave 2, index 1)
    try game.updateGame(0.1);
    try std.testing.expectEqual(@as(u32,2), game.current_wave_number); // Now on Wave 2
    try std.testing.expectEqual(@as(usize,0), game.current_wave_group_index); // Reset for new wave
    try std.testing.expectEqual(@as(u32,0), game.enemies_spawned_in_current_group); // Reset
    // First enemy of Wave 2, Group 1 (8 grunts, 0.6s interval, 0.0s initial delay) should spawn.
    try std.testing.expectEqual(@as(usize,1), game.enemies.items.len);
    try std.testing.expectEqual(enemy_module.EnemyKind.grunt, game.enemies.items[0].kind);
}
