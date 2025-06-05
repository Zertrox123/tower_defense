const std = @import("std");

pub const TowerKind = enum {
    Minigun,
    Sniper,
};

pub const Tower = struct {
    kind: TowerKind,
    x: u32,
    y: u32,
    damage: u32,
    range: f32,
    cost: u32,

    pub fn createTower(kind: TowerKind, x: u32, y: u32) Tower {
        return switch (kind) {
            .Minigun => Tower{
                .kind = kind,
                .x = x,
                .y = y,
                .damage = 5,
                .range = 3.0,
                .cost = 50,
            },
            .Sniper => Tower{
                .kind = kind,
                .x = x,
                .y = y,
                .damage = 20,
                .range = 7.0,
                .cost = 100,
            },
        };
    }
};

test "createTower" {
    const minigun = Tower.createTower(TowerKind.Minigun, 1, 2);
    try std.testing.expectEqual(minigun.kind, TowerKind.Minigun);
    try std.testing.expectEqual(minigun.x, 1);
    try std.testing.expectEqual(minigun.y, 2);
    try std.testing.expectEqual(minigun.damage, 5);
    try std.testing.expectEqual(minigun.range, 3.0);
    try std.testing.expectEqual(minigun.cost, 50);

    const sniper = Tower.createTower(TowerKind.Sniper, 3, 4);
    try std.testing.expectEqual(sniper.kind, TowerKind.Sniper);
    try std.testing.expectEqual(sniper.x, 3);
    try std.testing.expectEqual(sniper.y, 4);
    try std.testing.expectEqual(sniper.damage, 20);
    try std.testing.expectEqual(sniper.range, 7.0);
    try std.testing.expectEqual(sniper.cost, 100);
}
