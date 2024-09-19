const std = @import("std");
const c = @import("interface.zig");
const haathi_lib = @import("haathi.zig");
const Haathi = @import("haathi.zig").Haathi;
const colors = @import("colors.zig");
const MouseState = @import("inputs.zig").MouseState;
const SCREEN_SIZE = @import("haathi.zig").SCREEN_SIZE;
const CursorStyle = @import("haathi.zig").CursorStyle;
const serializer = @import("serializer.zig");

const helpers = @import("helpers.zig");
const Vec2 = helpers.Vec2;
const Vec2i = helpers.Vec2i;
const Vec4 = helpers.Vec4;
const Rect = helpers.Rect;
const Button = helpers.Button;
const TextLine = helpers.TextLine;
const Orientation = helpers.Orientation;
const ConstIndexArray = helpers.ConstIndexArray;
const ConstKey = helpers.ConstKey;
const FONTS = haathi_lib.FONTS;

const build_options = @import("build_options");
const BUILDER_MODE = build_options.builder_mode;
const WORLD_SIZE = SCREEN_SIZE;
const WORLD_OFFSET = Vec2{};

const ALL_SPRITES = [_][]const u8{
    "img/structures.png",
    "img/ore0.png",
    "img/ore1.png",
    "img/djinn_walking.png",
    "img/djinn_carrying.png",
};

const PICKUP_SPRITE = haathi_lib.Sprite{ .path = "img/structures.png", .anchor = .{ .x = 0 * 28 }, .size = .{ .x = 28, .y = 28 } };
const DROPOFF_SPRITE = haathi_lib.Sprite{ .path = "img/structures.png", .anchor = .{ .x = 1 * 28 }, .size = .{ .x = 28, .y = 28 } };
const ACTION_SPRITE = haathi_lib.Sprite{ .path = "img/structures.png", .anchor = .{ .x = 2 * 28 }, .size = .{ .x = 28, .y = 28 } };
// TODO (23 Jul 2024 sam): lol
const NUMBER_STR = [_][]const u8{ "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12", "13", "14", "15", "16", "17", "18", "19", "20", "21", "22", "23", "24", "25", "26", "27", "28", "29", "30", "31", "32", "33", "34", "35", "36", "37", "38", "39", "40", "41", "42", "43", "44", "45", "46", "47", "48", "49" };

const OrePatch = struct {
    position: Vec2i,
};

// World has origin at the center, x-right, y-up.
// Screen has origin at bottomleft, x-right, y-up
const World = struct {
    size: Vec2 = WORLD_SIZE,
    offset: Vec2 = WORLD_OFFSET,
    center: Vec2 = WORLD_OFFSET.add(WORLD_SIZE.scale(0.5)),

    pub fn init(allocator: std.mem.Allocator) World {
        _ = allocator;
        return .{};
    }

    pub fn setup(self: *World) void {
        _ = self;
    }

    pub fn deinit(self: *World) void {
        _ = self;
    }

    pub fn clear(self: *World) void {
        _ = self;
    }

    pub fn worldToScreen(self: *const World, position: Vec2) Vec2 {
        return position.add(self.center);
    }

    pub fn screenToWorld(self: *const World, position: Vec2) Vec2 {
        return position.subtract(self.center);
    }
};

// gameStruct
pub const Game = struct {
    haathi: *Haathi,
    ticks: u64 = 0,
    steps: usize = 0,
    world: World,
    ff_mode: bool = false,

    xosh: std.Random.Xoshiro256,
    rng: std.Random = undefined,
    allocator: std.mem.Allocator,
    arena_handle: std.heap.ArenaAllocator,
    arena: std.mem.Allocator,

    pub const serialize_fields = [_][]const u8{
        "ticks",
        "steps",
        "world",
    };

    pub fn init(haathi: *Haathi) Game {
        // // TODO (19 Sep 2024 sam): load sounds and images
        haathi.loadSound("audio/damage.wav", false);
        haathi.loadSound("audio/danger.wav", false);
        haathi.loadSound("audio/capture.wav", false);
        for (ALL_SPRITES) |path| haathi.loadSpriteMap(path);
        const allocator = haathi.allocator;
        var arena_handle = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        const world = World.init(haathi.allocator);
        return .{
            .haathi = haathi,
            .xosh = std.Random.Xoshiro256.init(0),
            .world = world,
            .allocator = allocator,
            .arena_handle = arena_handle,
            .arena = arena_handle.allocator(),
        };
    }

    pub fn deinit(self: *Game) void {
        self.world.deinit();
    }

    fn clear(self: *Game) void {
        self.world.clear();
    }

    fn reset(self: *Game) void {
        self.clear();
        self.setup();
    }

    pub fn setup(self: *Game) void {
        _ = self;
    }

    pub fn saveGame(self: *Game) void {
        var stream = serializer.JsonStream.new(self.haathi.arena);
        var js = stream.serializer();
        js.beginObject() catch unreachable;
        serializer.serialize("game", self.*, &js) catch unreachable;
        js.endObject() catch unreachable;
        stream.webSave("save") catch unreachable;
        // stream.saveDataToFile("data/savefiles/save.json", self.arena) catch unreachable;
        // // always keep all the old saves just in case we need for anything.
        // const backup_save = std.fmt.allocPrint(self.arena, "data/savefiles/save_{d}.json", .{std.time.milliTimestamp()}) catch unreachable;
        // stream.saveDataToFile(backup_save, self.arena) catch unreachable;
    }

    pub fn loadGame(self: *Game) void {
        if (helpers.webLoad("save", self.haathi.arena)) |savefile| {
            const tree = std.json.parseFromSlice(std.json.Value, self.haathi.arena, savefile, .{}) catch |err| {
                helpers.debugPrint("parsing error {}\n", .{err});
                unreachable;
            };
            //self.sim.clearSim();
            serializer.deserialize("game", self, tree.value, .{ .allocator = self.haathi.allocator, .arena = self.haathi.arena });
            // self.resetMenu();
            // self.setupContextual();
        } else {
            helpers.debugPrint("no savefile found", .{});
        }
    }

    // updateGame
    pub fn update(self: *Game, ticks: u64) void {
        // clear the arena and reset.
        self.steps += 1;
        _ = self.arena_handle.reset(.retain_capacity);
        self.arena = self.arena_handle.allocator();
        self.ticks = ticks;
    }

    pub fn render(self: *Game) void {
        // background
        self.haathi.drawRect(.{
            .position = .{},
            .size = SCREEN_SIZE,
            .color = colors.solarized_base3,
        });
        self.haathi.drawRect(.{
            .position = self.haathi.inputs.mouse.current_pos,
            .size = .{ .x = 10, .y = 10 },
            .color = colors.solarized_red,
        });
    }
};
