const std = @import("std");

const Tile = enum {
    empty,
    path,
    tower,
    obstacle,
};

pub const Board = struct {
    width: u32,
    height: u32,
    tiles: []Tile,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, width: u32, height: u32) !Board {
        const tiles_count = width * height;
        const tiles_buffer = try allocator.alloc(Tile, tiles_count);
        for (tiles_buffer) |*tile| {
            tile.* = Tile.empty;
        }

        return Board{
            .width = width,
            .height = height,
            .tiles = tiles_buffer,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Board) void {
        self.allocator.free(self.tiles);
        self.* = undefined; // To catch use-after-free
    }

    pub fn getTile(self: Board, x: u32, y: u32) ?Tile {
        if (x >= self.width or y >= self.height) {
            return null;
        }
        return self.tiles[y * self.width + x];
    }

    pub fn setTile(self: *Board, x: u32, y: u32, tile: Tile) bool {
        if (x >= self.width or y >= self.height) {
            return false;
        }
        self.tiles[y * self.width + x] = tile;
        return true;
    }

    // Basic pathfinding placeholder - replace with actual A* or similar
    pub fn findPath(self: Board, start_x: u32, start_y: u32, end_x: u32, end_y: u32) ?std.ArrayList(struct {x: u32, y: u32}) {
        // Placeholder: For now, just returns a straight line if possible, or null
        // This needs a proper pathfinding algorithm (e.g., A*)
        _ = start_x;
        _ = start_y;
        _ = end_x;
        _ = end_y;
        std.debug.print("Warning: findPath is not implemented yet.\n", .{});
        return null;
    }

    pub fn isValidCoordinate(self: Board, x: u32, y: u32) bool {
        return x < self.width and y < self.height;
    }
};

test "board initialization and deinitialization" {
    const allocator = std.testing.allocator;
    var board = try Board.init(allocator, 10, 10);
    defer board.deinit();

    try std.testing.expectEqual(@as(u32, 10), board.width);
    try std.testing.expectEqual(@as(u32, 10), board.height);
    try std.testing.expectEqual(@as(usize, 100), board.tiles.len);

    for (board.tiles) |tile| {
        try std.testing.expectEqual(Tile.empty, tile);
    }
}

test "board getTile and setTile" {
    const allocator = std.testing.allocator;
    var board = try Board.init(allocator, 5, 5);
    defer board.deinit();

    // Test setting a tile
    const set_success = board.setTile(2, 3, Tile.path);
    try std.testing.expect(set_success);

    // Test getting the tile
    const tile = board.getTile(2, 3);
    try std.testing.expect(tile != null);
    try std.testing.expectEqual(Tile.path, tile.?);

    // Test out of bounds get
    const oob_tile = board.getTile(10, 10);
    try std.testing.expect(oob_tile == null);

    // Test out of bounds set
    const oob_set_success = board.setTile(10, 10, Tile.tower);
    try std.testing.expect(!oob_set_success);
}

test "isValidCoordinate" {
    const allocator = std.testing.allocator;
    var board = try Board.init(allocator, 8, 6);
    defer board.deinit();

    try std.testing.expect(board.isValidCoordinate(0, 0));
    try std.testing.expect(board.isValidCoordinate(7, 5));
    try std.testing.expect(!board.isValidCoordinate(8, 0));
    try std.testing.expect(!board.isValidCoordinate(0, 6));
    try std.testing.expect(!board.isValidCoordinate(8, 6));
}
