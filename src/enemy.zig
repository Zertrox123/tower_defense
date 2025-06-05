const std = @import("std");

pub const EnemyKind = enum {
    Grunt,
    Sprinter,
};

pub const Enemy = struct {
    id: u32,
    kind: EnemyKind,
    x: f32, // current position x
    y: f32, // current position y
    health: i32,
    speed: f32, // tiles per second
    path_index: usize, // current target waypoint index in the board's path_waypoints
    gold_reward: u32,

    pub fn createEnemy(id: u32, kind: EnemyKind, start_x: f32, start_y: f32) Enemy {
        return switch (kind) {
            .Grunt => Enemy{
                .id = id,
                .kind = kind,
                .x = start_x,
                .y = start_y,
                .health = 100,
                .speed = 1.0,
                .path_index = 0, // Starts targeting the first waypoint
                .gold_reward = 10,
            },
            .Sprinter => Enemy{
                .id = id,
                .kind = kind,
                .x = start_x,
                .y = start_y,
                .health = 60,
                .speed = 2.5,
                .path_index = 0, // Starts targeting the first waypoint
                .gold_reward = 15,
            },
        };
    }
};

test "createEnemy Grunt" {
    const grunt = Enemy.createEnemy(1, EnemyKind.Grunt, 0.5, 5.5);
    try std.testing.expectEqual(@as(u32, 1), grunt.id);
    try std.testing.expectEqual(EnemyKind.Grunt, grunt.kind);
    try std.testing.expectEqual(@as(f32, 0.5), grunt.x);
    try std.testing.expectEqual(@as(f32, 5.5), grunt.y);
    try std.testing.expectEqual(@as(i32, 100), grunt.health);
    try std.testing.expectEqual(@as(f32, 1.0), grunt.speed);
    try std.testing.expectEqual(@as(usize, 0), grunt.path_index);
    try std.testing.expectEqual(@as(u32, 10), grunt.gold_reward);
}

test "createEnemy Sprinter" {
    const sprinter = Enemy.createEnemy(2, EnemyKind.Sprinter, 0.5, 5.5);
    try std.testing.expectEqual(@as(u32, 2), sprinter.id);
    try std.testing.expectEqual(EnemyKind.Sprinter, sprinter.kind);
    try std.testing.expectEqual(@as(f32, 0.5), sprinter.x);
    try std.testing.expectEqual(@as(f32, 5.5), sprinter.y);
    try std.testing.expectEqual(@as(i32, 60), sprinter.health);
    try std.testing.expectEqual(@as(f32, 2.5), sprinter.speed);
    try std.testing.expectEqual(@as(usize, 0), sprinter.path_index);
    try std.testing.expectEqual(@as(u32, 15), sprinter.gold_reward);
}
