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

const LANES_MAX_COUNT = 10;
const MINER_MAX_TARGET_SLOTS = 10;
const MINER_MAX_COUNT = 100;
const STORAGE_MAX_SIZE = 100;
const STORAGE_PER_ROW = 10;
const ANIM_TICKS = 600;
const ANIM_MAX_COUNT = 1024;

const LANE0_POSITION = SCREEN_SIZE.scaleVec2(.{ .x = 0.5, .y = 0.7 }).add(LANE_OFFSET);
const LANE_OFFSET = Vec2{ .x = (SCREEN_SIZE.x * 0.45) / (LANES_MAX_COUNT + 1) };
const SAME_LANE_OFFSET = LANE_OFFSET.scale(0.1).add(.{ .y = -4 });
const STORAGE_SLOT = Vec2{ .x = SCREEN_SIZE.x * 0.7, .y = SCREEN_SIZE.y * 0.6 };
const STORAGE_ROW = Vec2{ .y = 30 };
const STORAGE_LANE = Vec2{ .x = 25 };

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

pub const Mountain = struct {
    mass: usize = 1000000,
};

const ResType = enum {
    none,
    reserved,
    stone,
};

pub const Storage = struct {
    num_rows: usize = 1,
    storage: [STORAGE_MAX_SIZE]ResType = [_]ResType{.none} ** STORAGE_MAX_SIZE,
};

pub const Miner = struct {
    timer: u8,
};

pub const Carrier = struct {};

pub const Animation = struct {
    mine_index: u8,
    storage_index: u8,
    start_tick: u32,
    res: ResType,
};

const ButtonAction = enum {
    miner_recruit,
};

// gameStruct
pub const Game = struct {
    haathi: *Haathi,
    ticks: u32 = 0,
    steps: usize = 0,
    world: World,
    ff_mode: bool = false,

    miners: std.ArrayList(Miner),
    // TODO (20 Sep 2024 sam): make this some kind of ring buffer
    animations: std.ArrayList(Animation),
    buttons: std.ArrayList(Button),
    mountain: Mountain = .{},
    storage: Storage = .{},
    miner_timer: u8 = 60,
    miner_strength: u8 = 1,
    miner_ore: ResType = .stone,

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
            .miners = std.ArrayList(Miner).initCapacity(allocator, MINER_MAX_COUNT) catch unreachable,
            .animations = std.ArrayList(Animation).initCapacity(allocator, ANIM_MAX_COUNT) catch unreachable,
            .buttons = std.ArrayList(Button).initCapacity(allocator, 32) catch unreachable,
            .allocator = allocator,
            .arena_handle = arena_handle,
            .arena = arena_handle.allocator(),
        };
    }

    pub fn deinit(self: *Game) void {
        self.world.deinit();
        self.miners.deinit();
        self.animations.deinit();
    }

    fn clear(self: *Game) void {
        self.world.clear();
    }

    fn reset(self: *Game) void {
        self.clear();
        self.setup();
    }

    pub fn setup(self: *Game) void {
        self.buttons.appendAssumeCapacity(.{
            .rect = .{
                .position = .{ .x = 30, .y = 30 },
                .size = .{ .x = 150, .y = 26 },
            },
            .value = @intFromEnum(ButtonAction.miner_recruit),
            .text = "Recruit Miner",
        });
    }

    pub fn saveGame(self: *Game) void {
        var stream = serializer.JsonStream.new(self.haathi.arena);
        var js = stream.serializer();
        js.beginObject() catch unreachable;
        serializer.serialize("game", self.*, &js) catch unreachable;
        js.endObject() catch unreachable;
        stream.webSave("save") catch unreachable;
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

    fn doButtonAction(self: *Game, action: ButtonAction) void {
        switch (action) {
            .miner_recruit => {
                self.miners.appendAssumeCapacity(.{ .timer = self.miner_timer });
            },
        }
    }

    fn addAnimation(self: *Game, anim: Animation) void {
        for (self.animations.items) |*ani| {
            if (anim.start_tick == 0) {
                ani.* = anim;
                return;
            }
        }
        if (self.animations.items.len >= ANIM_MAX_COUNT) return;
        self.animations.appendAssumeCapacity(anim);
    }

    fn getMinerPosition(self: *Game, index: usize) Vec2 {
        _ = self;
        const lane = @mod(index, LANES_MAX_COUNT);
        const row = @divFloor(index, LANES_MAX_COUNT);
        const position = LANE0_POSITION.add(LANE_OFFSET.scale(@floatFromInt(lane))).add(SAME_LANE_OFFSET.scale(@floatFromInt(row)));
        return position;
    }

    // updateGame
    pub fn update(self: *Game, ticks: u64) void {
        // clear the arena and reset.
        self.steps += 1;
        _ = self.arena_handle.reset(.retain_capacity);
        self.arena = self.arena_handle.allocator();
        self.ticks = @intCast(ticks);
        for (self.buttons.items) |*button| button.update(self.haathi.inputs.mouse);
        for (self.buttons.items) |button| {
            if (button.clicked) self.doButtonAction(@enumFromInt(button.value));
        }
        // update miners
        for (self.miners.items) |*miner| {
            if (miner.timer > 0) miner.timer -= 1;
        }
        // create resources if space exists
        var storage_start: usize = 0;
        for (self.miners.items, 0..) |*miner, miner_index| {
            if (miner.timer != 0) continue;
            var mined: usize = 0;
            // miner is done mining, find a space for the materials to go.
            const storage_max = self.storage.num_rows * STORAGE_PER_ROW;
            for (self.storage.storage[storage_start..storage_max], 0..) |*str, i| {
                if (str.* == .none) {
                    str.* = .reserved;
                    miner.timer = self.miner_timer;
                    mined += 1;
                    // create animation
                    self.addAnimation(.{
                        .res = self.miner_ore,
                        .start_tick = self.ticks,
                        .mine_index = @intCast(miner_index),
                        .storage_index = @intCast(storage_start + i),
                    });
                    if (mined == self.miner_strength) {
                        storage_start += i;
                        break;
                    }
                }
            }
        }
        for (self.animations.items) |*anim| {
            if (self.ticks < anim.start_tick) anim.start_tick = 0;
            if (anim.start_tick == 0) continue;
            if (self.ticks > anim.start_tick + ANIM_TICKS) {
                anim.start_tick = 0;
                self.storage.storage[anim.storage_index] = anim.res;
            }
        }
    }

    pub fn render(self: *Game) void {
        // background
        self.haathi.drawRect(.{
            .position = .{},
            .size = SCREEN_SIZE,
            .color = colors.apollo_light_4,
        });
        self.haathi.drawRect(.{
            .position = self.haathi.inputs.mouse.current_pos,
            .size = .{ .x = 10, .y = 10 },
            .color = colors.apollo_red_6,
        });
        for (self.buttons.items) |button| {
            const color = if (button.hovered) colors.apollo_blue_4.lerp(colors.apollo_blue_6, 0.4) else colors.apollo_blue_4;
            self.haathi.drawRect(.{ .position = button.rect.position, .size = button.rect.size, .color = color, .radius = 4 });
            const text_center = button.rect.position.add(button.rect.size.scaleVec2(.{ .x = 0.5, .y = 1 }).add(.{ .y = -18 }));
            self.haathi.drawText(.{ .text = button.text, .position = text_center, .color = colors.apollo_light_4 });
        }
        for (self.miners.items, 0..) |miner, miner_index| {
            const position = self.getMinerPosition(miner_index);
            self.haathi.drawRect(.{
                .position = position,
                .size = .{ .x = 12, .y = 40 },
                .color = colors.apollo_brown_2,
                .radius = 2,
            });
            const progress: f32 = @as(f32, @floatFromInt(miner.timer)) / @as(f32, @floatFromInt(@max(miner.timer, self.miner_timer)));
            self.haathi.drawRect(.{
                .position = position,
                .size = .{ .x = 12, .y = 40 * progress },
                .color = colors.apollo_brown_1,
                .radius = 2,
            });
        }
        for (self.animations.items) |anim| {
            if (anim.start_tick == 0) continue;
            const progress: f32 = @as(f32, @floatFromInt(self.ticks - anim.start_tick)) / ANIM_TICKS;
            const lane = @mod(anim.mine_index, LANES_MAX_COUNT);
            const row = @divFloor(anim.mine_index, LANES_MAX_COUNT);
            const start = LANE0_POSITION.add(LANE_OFFSET.scale(@floatFromInt(lane))).add(SAME_LANE_OFFSET.scale(@floatFromInt(row)));
            const str_lane = @mod(anim.storage_index, STORAGE_PER_ROW);
            const str_row = @divFloor(anim.storage_index, STORAGE_PER_ROW);
            const end = STORAGE_SLOT.add(STORAGE_LANE.scale(@floatFromInt(str_lane))).add(STORAGE_ROW.scale(@floatFromInt(str_row)));
            const pos = start.ease(end, progress);
            self.haathi.drawRect(.{
                .position = pos,
                .size = .{ .x = 8, .y = 8 },
                .color = colors.apollo_blue_4,
                .radius = 8,
            });
        }
        for (self.storage.storage[0 .. self.storage.num_rows * STORAGE_PER_ROW], 0..) |str, storage_index| {
            if (str == .none or str == .reserved) continue;
            const str_lane = @mod(storage_index, STORAGE_PER_ROW);
            const str_row = @divFloor(storage_index, STORAGE_PER_ROW);
            const pos = STORAGE_SLOT.add(STORAGE_LANE.scale(@floatFromInt(str_lane))).add(STORAGE_ROW.scale(@floatFromInt(str_row)));
            self.haathi.drawRect(.{
                .position = pos,
                .size = .{ .x = 8, .y = 8 },
                .color = colors.apollo_blue_4,
                .radius = 8,
            });
        }
    }
};
