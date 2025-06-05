# Zig Tower Defense

A simple text-based tower defense game written in Zig.

## Features

*   Place different types of towers to defend against enemies.
*   Upgrade existing towers to enhance their capabilities.
*   Face multiple waves of diverse enemy types.
*   Text-based interface with command-line controls.
*   Manage currency to strategically build and upgrade defenses.

## Building and Running

### Prerequisites

*   [Zig](https://ziglang.org/download/) (ensure it's added to your PATH)

### Building

To build the game, navigate to the project's root directory and run:

```bash
zig build
```

This will create an executable in the `zig-out/bin/` directory.

### Running

After building, you can run the game using:

```bash
zig build run
```

Alternatively, you can directly execute the compiled binary:

```bash
./zig-out/bin/zig-tower-defense
```

### Running Tests

To run the built-in tests:

```bash
zig build test
```

## How to Play

The game is played by entering commands in the terminal. The goal is to prevent enemies from reaching the end of the path by building and upgrading towers.

### Game Board

The game will display a board representing the map.
- `.` typically represents an empty, buildable tile.
- Path tiles (e.g., `#` or other symbols) show the route enemies will take.
- Towers are represented by characters (e.g., `M` for Minigun, `S` for Sniper).
- Enemies are represented by characters (e.g., `g` for grunt, `s` for scout).

### Commands

At each turn, you can enter one of the following commands:

*   `help`: Displays a list of available commands and tower types.
*   `buy <tower_id> <x> <y>`: Buys and places a tower with the specified ID at the given (x,y) coordinates.
    *   Example: `buy 0 5 2` (Buys tower with ID 0 and places it at column 5, row 2)
*   `upgrade <x> <y>`: Upgrades the tower at the given (x,y) coordinates.
    *   Example: `upgrade 5 2`
*   `pass`: Skips the current turn, allowing enemies to move and towers to fire.
*   `quit`: Exits the game.

You will also see information about your current health, currency, and the current wave.
Manage your currency wisely to build a strong defense and survive all enemy waves!

## Contributing

Contributions are welcome! Please feel free to open an issue or submit a pull request.

(Consider adding more specific guidelines if the project grows, such as coding style, testing requirements, etc.)
