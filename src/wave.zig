const std = @import("std");
const enemy_module = @import("enemy.zig"); // For enemy.EnemyKind

pub const WaveEnemyConfig = struct {
    kind: enemy_module.EnemyKind,
    count: u32,
    spawn_interval: f32, // Time between spawns of enemies within this config group
    delay_after_previous_group: f32, // Delay after the previous WaveEnemyConfig in the wave is finished
};

pub const WaveData = struct {
    enemy_groups: std.ArrayList(WaveEnemyConfig),

    pub fn init(allocator: std.mem.Allocator, groups_slice: []const WaveEnemyConfig) !WaveData {
        var self = WaveData{
            .enemy_groups = std.ArrayList(WaveEnemyConfig).init(allocator),
        };
        // Try to append all groups. If any append fails, deinit and propagate error.
        errdefer self.deinit();
        for (groups_slice) |*group_config| {
            try self.enemy_groups.append(group_config.*);
        }
        return self;
    }

    pub fn deinit(self: *WaveData) void {
        // WaveEnemyConfig itself is simple, no deep deinit needed for its items.
        // Only the ArrayList itself needs deinitialization.
        self.enemy_groups.deinit();
    }
};

test "WaveData init and deinit" {
    const allocator = std.testing.allocator;
    const test_groups = [_]WaveEnemyConfig{
        .{ .kind = .grunt, .count = 5, .spawn_interval = 1.0, .delay_after_previous_group = 0.0 },
        .{ .kind = .scout, .count = 3, .spawn_interval = 0.5, .delay_after_previous_group = 2.0 },
    };

    var wave_data = try WaveData.init(allocator, &test_groups);
    defer wave_data.deinit();

    try std.testing.expectEqual(@as(usize, 2), wave_data.enemy_groups.items.len);
    try std.testing.expectEqual(enemy_module.EnemyKind.grunt, wave_data.enemy_groups.items[0].kind);
    try std.testing.expectEqual(@as(u32, 5), wave_data.enemy_groups.items[0].count);
    try std.testing.expectEqual(enemy_module.EnemyKind.scout, wave_data.enemy_groups.items[1].kind);
}

test "WaveData init with empty groups" {
    const allocator = std.testing.allocator;
    const empty_groups = [_]WaveEnemyConfig{};
    var wave_data = try WaveData.init(allocator, &empty_groups);
    defer wave_data.deinit();
    try std.testing.expectEqual(@as(usize, 0), wave_data.enemy_groups.items.len);
}
