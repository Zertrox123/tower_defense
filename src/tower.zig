const std = @import("std");
const game_view_module = @import("game.zig");
const enemy_module = @import("enemy.zig");

// TowerData now includes upgrade information
pub const TowerData = struct {
    id: u32,
    name: []const u8,
    char_representation: u8,
    damage: u32,
    range: f32,
    firerate: f32,
    cost: u32,
    upgrades_to_id: ?u32, // Nullable ID of the TowerData this one upgrades to
    upgrade_cost: u32,   // Cost for this specific upgrade; 0 if no upgrade or not applicable
};

pub const Tower = struct {
    data_id: u32,
    x: u32,
    y: u32,
    current_cooldown: f32,
};

pub fn createTower(data_id: u32, x: u32, y: u32) Tower {
    return Tower{
        .data_id = data_id,
        .x = x,
        .y = y,
        .current_cooldown = 0.0,
    };
}

pub fn findTarget(
    tower: Tower,
    tower_data: TowerData,
    game_view: game_view_module.GameView
) ?usize {
    var closest_enemy_index: ?usize = null;
    var min_dist_sq: f32 = tower_data.range * tower_data.range + 0.001;

    var i: usize = 0;
    while (i < game_view.enemies.len) : (i += 1) {
        const current_enemy = game_view.enemies[i];
        if (!current_enemy.is_active or current_enemy.current_health == 0) {
            continue;
        }
        const tower_center_x = @intToFloat(f32, tower.x) + 0.5;
        const tower_center_y = @intToFloat(f32, tower.y) + 0.5;
        const dx = tower_center_x - current_enemy.x;
        const dy = tower_center_y - current_enemy.y;
        const dist_sq = (dx * dx) + (dy * dy);

        if (dist_sq < min_dist_sq) {
            min_dist_sq = dist_sq;
            closest_enemy_index = i;
        }
    }
    return closest_enemy_index;
}

// --- Tests ---
test "create tower" {
    const tower = createTower(0, 5, 5);
    try std.testing.expectEqual(@as(u32, 0), tower.data_id);
    try std.testing.expectEqual(@as(u32, 5), tower.x);
    try std.testing.expectEqual(@as(u32, 5), tower.y);
    try std.testing.expectEqual(@as(f32, 0.0), tower.current_cooldown);
}

test "findTarget with GameView (tower.zig)" { // Renamed to avoid conflict if game_test.zig also has one
    const allocator = std.testing.allocator;
    const test_tower_data = TowerData {
        .id = 0, .name = "TestGun", .char_representation = 'T',
        .damage = 10, .range = 3.0, .firerate = 1.0, .cost = 0,
        .upgrades_to_id = null, .upgrade_cost = 0, // Added new fields
    };
    const test_tower = Tower { .data_id = 0, .x = 0, .y = 0, .current_cooldown = 0.0 };

    var path_list = std.ArrayList(struct{x:u32,y:u32}).init(allocator);
    defer path_list.deinit();
    try path_list.appendSlice(&.{.{.x=0,.y=0}});

    var enemy1 = try enemy_module.spawnEnemy(allocator, .grunt, path_list.items);
    defer enemy1.deinit();
    enemy1.x = 1.0; enemy1.y = 1.0;
    enemy1.current_health = 10; enemy1.is_active = true;

    var enemy2 = try enemy_module.spawnEnemy(allocator, .grunt, path_list.items);
    defer enemy2.deinit();
    enemy2.x = 5.0; enemy2.y = 5.0;
    enemy2.current_health = 10; enemy2.is_active = true;

    var enemy3 = try enemy_module.spawnEnemy(allocator, .grunt, path_list.items);
    defer enemy3.deinit();
    enemy3.x = 1.5; enemy3.y = 1.5;
    enemy3.current_health = 0; enemy3.is_active = true;

    var enemy4 = try enemy_module.spawnEnemy(allocator, .grunt, path_list.items);
    defer enemy4.deinit();
    enemy4.x = 2.0; enemy4.y = 2.0;
    enemy4.current_health = 10; enemy4.is_active = true;

    var enemy5 = try enemy_module.spawnEnemy(allocator, .grunt, path_list.items);
    defer enemy5.deinit();
    enemy5.x = 1.2; enemy5.y = 1.2;
    enemy5.current_health = 10; enemy5.is_active = false;

    const mock_enemies_slice = &[_]enemy_module.Enemy{ enemy1, enemy2, enemy3, enemy4, enemy5 };
    var board = try board_module.Board.init(allocator, 1, 1); // Dummy board
    defer board.deinit();
    const game_view = game_view_module.GameView { .enemies = mock_enemies_slice, .board = board };

    const target_index = findTarget(test_tower, test_tower_data, game_view);
    try std.testing.expect(target_index != null);
    try std.testing.expectEqual(@as(usize, 0), target_index.?);

     const mock_enemies_slice_no_valid_target = &[_]enemy_module.Enemy{ enemy2, enemy3, enemy5 };
     const game_view_no_valid_target = game_view_module.GameView { .enemies = mock_enemies_slice_no_valid_target, .board = board };
    const no_target_index = findTarget(test_tower, test_tower_data, game_view_no_valid_target);
    try std.testing.expect(no_target_index == null);

    enemy1.is_active = false;
     const mock_enemies_slice_for_closest = &[_]enemy_module.Enemy{ enemy1, enemy4 };
    const game_view_closest = game_view_module.GameView { .enemies = mock_enemies_slice_for_closest, .board = board };
    const closest_target_index = findTarget(test_tower, test_tower_data, game_view_closest);
    try std.testing.expect(closest_target_index != null);
    try std.testing.expectEqual(@as(usize, 1), closest_target_index.?);
    enemy1.is_active = true;
}
