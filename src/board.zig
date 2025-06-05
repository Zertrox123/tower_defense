const std = @import("std");

pub const TileType = enum {
    Path,
    Buildable,
    Scenery,
};

// Vec2u32 for coordinates
pub const Vec2u32 = struct {
    x: u32,
    y: u32,
};

pub const Board = struct {
    width: u32,
    height: u32,
    tiles: []TileType,
    occupied: []bool,
    path_waypoints: std.ArrayList(Vec2u32), // Added for enemy pathfinding
    allocator: std.mem.Allocator,

    pub fn createBoard(width: u32, height: u32, allocator: std.mem.Allocator) !Board {
        const num_tiles = width * height;
        const tiles_data = try allocator.alloc(TileType, num_tiles);
        errdefer allocator.free(tiles_data);

        const occupied_data = try allocator.alloc(bool, num_tiles);
        errdefer allocator.free(occupied_data);

        var path_waypoints_list = std.ArrayList(Vec2u32).init(allocator);
        errdefer path_waypoints_list.deinit(); // Ensure this is deinitialized if subsequent operations fail

        // Initialize all tiles to Scenery and not occupied
        for (0..num_tiles) |i| {
            tiles_data[i] = TileType.Scenery;
            occupied_data[i] = false;
        }

        // Simple horizontal path in the middle row
        if (height > 0) {
            const middle_row = height / 2;
            for (0..width) |x| {
                const index = middle_row * width + x;
                if (index < num_tiles) {
                    tiles_data[index] = TileType.Path;
                    // Add waypoint for each tile on the path
                    try path_waypoints_list.append(Vec2u32{ .x = @intCast(x), .y = middle_row });
                }
            }

            // Designate tiles adjacent to the path as Buildable
            if (middle_row > 0) {
                const row_above = middle_row - 1;
                for (0..width) |x| {
                    const index = row_above * width + x;
                    if (index < num_tiles) {
                        tiles_data[index] = TileType.Buildable;
                    }
                }
            }
            if (middle_row < height - 1) {
                const row_below = middle_row + 1;
                for (0..width) |x| {
                    const index = row_below * width + x;
                    if (index < num_tiles) {
                        tiles_data[index] = TileType.Buildable;
                    }
                }
            }
        }

        return Board{
            .width = width,
            .height = height,
            .tiles = tiles_data,
            .occupied = occupied_data,
            .path_waypoints = path_waypoints_list,
            .allocator = allocator,
        };
    }

    pub fn destroy(self: *Board) void {
        self.allocator.free(self.tiles);
        self.allocator.free(self.occupied);
        self.path_waypoints.deinit(); // Deinitialize the new ArrayList
        self.* = undefined;
    }

    pub fn isTileBuildableAndUnoccupied(self: Board, x: u32, y: u32) bool {
        if (x >= self.width or y >= self.height) {
            return false;
        }
        const index = y * self.width + x;
        return self.tiles[index] == TileType.Buildable and !self.occupied[index];
    }

    pub fn setTileOccupied(self: *Board, x: u32, y: u32, is_occupied: bool) void {
        if (x >= self.width or y >= self.height) {
            return;
        }
        const index = y * self.width + x;
        self.occupied[index] = is_occupied;
    }
};

test "Board.createBoard path_waypoints" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const test_width: u32 = 10;
    const test_height: u32 = 5;
    var board = try Board.createBoard(test_width, test_height, allocator);
    defer board.destroy();

    // Path on row 2 (5/2)
    const expected_middle_row = test_height / 2;
    try std.testing.expectEqual(board.path_waypoints.items.len, test_width);
    for (board.path_waypoints.items, 0..) |wp, i| {
        try std.testing.expectEqual(@as(usize, wp.x), i); // Cast wp.x (u32) to usize for comparison with i (usize)
        try std.testing.expectEqual(wp.y, expected_middle_row);
    }
}

test "Board.isTileBuildableAndUnoccupied and setTileOccupied" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var board = try Board.createBoard(10, 5, allocator); // Path on row 2, Buildable on rows 1 and 3
    defer board.destroy();

    try std.testing.expect(board.isTileBuildableAndUnoccupied(0, 1));
    try std.testing.expect(!board.isTileBuildableAndUnoccupied(0, 2));
    try std.testing.expectEqual(board.tiles[2 * 10 + 0], TileType.Path);
    try std.testing.expect(!board.isTileBuildableAndUnoccupied(0, 0));
    try std.testing.expectEqual(board.tiles[0], TileType.Scenery);

    board.setTileOccupied(0, 1, true);
    try std.testing.expect(!board.isTileBuildableAndUnoccupied(0, 1));

    board.setTileOccupied(0, 1, false);
    try std.testing.expect(board.isTileBuildableAndUnoccupied(0, 1));

    board.setTileOccupied(0, 2, true);
    try std.testing.expect(!board.isTileBuildableAndUnoccupied(0, 2));
}
