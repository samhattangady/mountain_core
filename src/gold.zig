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
const ANIM_MAX_COUNT = 256;
const CARRIERS_PER_LANE = 3;
const BUILDER_PER_LANE = 2;

const LANE0_POSITION = SCREEN_SIZE.scaleVec2(.{ .x = 0.5, .y = 0.1 }).add(LANE_OFFSET);
const BUILDER0_POSITION = SCREEN_SIZE.scaleVec2(.{ .x = 0.5, .y = 0.7 }).add(LANE_OFFSET);
const LANE_OFFSET = Vec2{ .x = (SCREEN_SIZE.x * 0.45) / (LANES_MAX_COUNT + 1) };
const SAME_LANE_OFFSET = LANE_OFFSET.scale(0.1).add(.{ .y = -4 });
const STORAGE_SLOT = Vec2{ .x = SCREEN_SIZE.x * 0.7, .y = SCREEN_SIZE.y * 0.2 };
const BASE_STORAGE_SLOT = Vec2{ .x = SCREEN_SIZE.x * 0.7, .y = SCREEN_SIZE.y * 0.6 };
const STORAGE_ROW = Vec2{ .y = 30 };
const STORAGE_LANE = Vec2{ .x = 25 };
const CARRIER_SLOT = Vec2{ .x = SCREEN_SIZE.x * 0.6, .y = SCREEN_SIZE.y * 0.3 };
const CARRIER_LANE = Vec2{ .x = SCREEN_SIZE.x * 0.4 / (LANES_MAX_COUNT + 1) };
const CARRIER_OFFSET = Vec2{ .x = 20 };
const CARRIER_DROPOFF_SLOT = Vec2{ .x = SCREEN_SIZE.x * 0.7, .y = SCREEN_SIZE.y * 0.5 };
const CARRIER_DROPOFF_LANE = Vec2{ .x = SCREEN_SIZE.x * 0.2 / (LANES_MAX_COUNT + 1) };
const CARRIER_DROPOFF_OFFSET = Vec2{ .x = 20 };

const UPGRADE_SCORE_MULTIPLIER = 8;
const NUM_UPGRADE_LEVELS = 30;

const CARRIER_TIMER = 150;
const BUILDER_TIMER = 90;
const MINER_TIMER = 90;

const UPGRADE_COSTS = @import("upgrade_costs.zig").UPGRADE_COSTS;

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
    ore,
    ore2,
    ore3,
    ore4,

    fn score(self: ResType) usize {
        return switch (self) {
            .none, .reserved => 0,
            .stone => 9,
            .ore => 9 * UPGRADE_SCORE_MULTIPLIER,
            .ore2 => 9 * (std.math.powi(usize, UPGRADE_SCORE_MULTIPLIER, 2) catch unreachable),
            .ore3 => 9 * (std.math.powi(usize, UPGRADE_SCORE_MULTIPLIER, 3) catch unreachable),
            .ore4 => 9 * (std.math.powi(usize, UPGRADE_SCORE_MULTIPLIER, 4) catch unreachable),
        };
    }
    fn upgrade(self: ResType) ResType {
        return switch (self) {
            .none, .reserved => .none,
            .stone => .ore,
            .ore => .ore2,
            .ore2 => .ore3,
            .ore3 => .ore4,
            .ore4 => .ore4,
        };
    }
    fn color(self: ResType) Vec4 {
        return switch (self) {
            .none, .reserved => .{},
            .stone => colors.apollo_dark_1,
            .ore => colors.apollo_dark_2,
            .ore2 => colors.apollo_dark_3,
            .ore3 => colors.apollo_dark_4,
            .ore4 => colors.apollo_dark_5,
        };
    }
};

pub const Storage = struct {
    num_rows: usize = 1,
    storage: [STORAGE_MAX_SIZE]ResType = [_]ResType{.none} ** STORAGE_MAX_SIZE,
};

pub const Miner = struct {
    timer: u8,
};

pub const Builder = struct {
    timer: u8,
    reserved: bool = false,
};

pub const Carrier = struct {
    timer: u16,
    state: enum {
        waiting,
        carrying,
        delivering,
        returning,
    } = .waiting,
    res: [10]ResType = [_]ResType{.none} ** 10,

    pub fn numFull(self: *Carrier) u8 {
        var count: u8 = 0;
        for (self.res) |res| {
            if (res != .none) count += 1;
        }
        return count;
    }
    pub fn numCarried(self: *Carrier) u8 {
        var count: u8 = 0;
        for (self.res) |res| {
            if (res != .none and res != .reserved) count += 1;
        }
        return count;
    }
    pub fn numReserved(self: *Carrier) u8 {
        var count: u8 = 0;
        for (self.res) |res| {
            if (res == .reserved) count += 1;
        }
        return count;
    }
};

const AnimData = union(enum) {
    none: void,
    miner: struct {
        mine_index: u8,
        storage_index: u8,
    },
    carrier_pickup: struct {
        carrier_index: u8,
        storage_index: u8,
        carrier_slot_index: u8,
    },
    carrier_dropoff: struct {
        carrier_index: u8,
        storage_index: u8,
        carrier_slot_index: u8,
    },
    builder: struct {
        builder_index: u8,
        storage_index: u8,
    },
};

pub const Animation = struct {
    data: AnimData,
    start_step: u32,
    res: ResType,
};

const ButtonAction = enum {
    miner_recruit,
    carrier_recruit,
    builder_recruit,
    miner_speedup,
    carrier_speedup,
    builder_speedup,
    carrier_strength,
    resource_upgrade,
    anim_speedup,
    rep_mult_increase,
    //mine_storage_add_row,
    //base_storage_add_row,
};
const NUM_ACTIONS = @typeInfo(ButtonAction).Enum.fields.len;

const UpgradeButton = struct {
    button: Button,
    cost: u64,
};

// gameStruct
pub const Game = struct {
    haathi: *Haathi,
    ticks: u32 = 0,
    steps: u32 = 0,
    world: World,
    ff_mode: bool = false,
    anim_steps: u16 = 37,

    miners: std.ArrayList(Miner),
    carriers: std.ArrayList(Carrier),
    builders: std.ArrayList(Builder),
    // TODO (20 Sep 2024 sam): make this some kind of ring buffer
    animations: std.ArrayList(Animation),
    buttons: std.ArrayList(UpgradeButton),
    mountain: Mountain = .{},
    mine_storage: Storage = .{},
    base_storage: Storage = .{},
    miner_timer: u8 = MINER_TIMER,
    carrier_timer: u16 = CARRIER_TIMER,
    builder_timer: u8 = BUILDER_TIMER,
    miner_strength: u8 = 1,
    carrier_capacity: u8 = 2,
    rep_mult: u64 = 1,
    miner_ore: ResType = .stone,
    score: u64 = 10,
    points: u64 = 10,
    levels: [NUM_ACTIONS]u8 = [_]u8{0} ** NUM_ACTIONS,

    xosh: std.Random.Xoshiro256,
    rng: std.Random = undefined,
    allocator: std.mem.Allocator,
    arena_handle: std.heap.ArenaAllocator,
    arena: std.mem.Allocator,

    pub const serialize_fields = [_][]const u8{
        "ticks",
        "steps",
        "world",
        "miners",
        "carriers",
        "builders",
        "mine_storage",
        "base_storage",
        "animations",
        "score",
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
            .carriers = std.ArrayList(Carrier).initCapacity(allocator, CARRIERS_PER_LANE * LANES_MAX_COUNT) catch unreachable,
            .builders = std.ArrayList(Builder).initCapacity(allocator, BUILDER_PER_LANE * LANES_MAX_COUNT) catch unreachable,
            .animations = std.ArrayList(Animation).initCapacity(allocator, ANIM_MAX_COUNT) catch unreachable,
            .buttons = std.ArrayList(UpgradeButton).initCapacity(allocator, 32) catch unreachable,
            .allocator = allocator,
            .arena_handle = arena_handle,
            .arena = arena_handle.allocator(),
        };
    }

    pub fn deinit(self: *Game) void {
        self.world.deinit();
        self.miners.deinit();
        self.animations.deinit();
        self.carriers.deinit();
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
            .button = .{
                .rect = .{
                    .position = .{ .x = 30, .y = 30 },
                    .size = .{ .x = 150, .y = 26 },
                },
                .value = @intFromEnum(ButtonAction.miner_recruit),
                .text = "Recruit Miner",
            },
            .cost = 0,
        });
        self.buttons.appendAssumeCapacity(.{
            .button = .{
                .rect = .{
                    .position = .{ .x = 200, .y = 30 },
                    .size = .{ .x = 150, .y = 26 },
                },
                .value = @intFromEnum(ButtonAction.miner_speedup),
                .text = "Miner Speedup",
            },
            .cost = 0,
        });
        // self.buttons.appendAssumeCapacity(.{
        //     .rect = .{
        //         .position = .{ .x = 350, .y = 30 },
        //         .size = .{ .x = 150, .y = 26 },
        //     },
        //     .value = @intFromEnum(ButtonAction.mine_storage_add_row),
        //     .text = "Storage Add Row",
        // });
        self.buttons.appendAssumeCapacity(.{
            .button = .{
                .rect = .{
                    .position = .{ .x = 30, .y = 90 },
                    .size = .{ .x = 150, .y = 26 },
                },
                .value = @intFromEnum(ButtonAction.carrier_recruit),
                .text = "Recruit Carrier",
            },
            .cost = 0,
        });
        self.buttons.appendAssumeCapacity(.{
            .button = .{
                .rect = .{
                    .position = .{ .x = 200, .y = 90 },
                    .size = .{ .x = 150, .y = 26 },
                },
                .value = @intFromEnum(ButtonAction.carrier_speedup),
                .text = "Carrier Speedup",
            },
            .cost = 0,
        });
        self.buttons.appendAssumeCapacity(.{
            .button = .{
                .rect = .{
                    .position = .{ .x = 400, .y = 90 },
                    .size = .{ .x = 150, .y = 26 },
                },
                .value = @intFromEnum(ButtonAction.carrier_strength),
                .text = "Carrier Strength",
            },
            .cost = 0,
        });
        self.buttons.appendAssumeCapacity(.{
            .button = .{
                .rect = .{
                    .position = .{ .x = 30, .y = 150 },
                    .size = .{ .x = 150, .y = 26 },
                },
                .value = @intFromEnum(ButtonAction.builder_recruit),
                .text = "Recruit Builder",
            },
            .cost = 0,
        });
        self.buttons.appendAssumeCapacity(.{
            .button = .{
                .rect = .{
                    .position = .{ .x = 200, .y = 150 },
                    .size = .{ .x = 150, .y = 26 },
                },
                .value = @intFromEnum(ButtonAction.builder_speedup),
                .text = "Builder Speedup",
            },
            .cost = 0,
        });
        //self.buttons.appendAssumeCapacity(.{
        //    .rect = .{
        //        .position = .{ .x = 350, .y = 90 },
        //        .size = .{ .x = 150, .y = 26 },
        //    },
        //    .value = @intFromEnum(ButtonAction.base_storage_add_row),
        //    .text = "Storage Builder",
        //});
        self.buttons.appendAssumeCapacity(.{
            .button = .{
                .rect = .{
                    .position = .{ .x = 200, .y = 190 },
                    .size = .{ .x = 150, .y = 26 },
                },
                .value = @intFromEnum(ButtonAction.resource_upgrade),
                .text = "Upgrade Resource",
            },
            .cost = 0,
        });
        self.buttons.appendAssumeCapacity(.{
            .button = .{
                .rect = .{
                    .position = .{ .x = 400, .y = 190 },
                    .size = .{ .x = 150, .y = 26 },
                },
                .value = @intFromEnum(ButtonAction.anim_speedup),
                .text = "Transfer Speedup",
            },
            .cost = 0,
        });
        self.buttons.appendAssumeCapacity(.{
            .button = .{
                .rect = .{
                    .position = .{ .x = 200, .y = 260 },
                    .size = .{ .x = 150, .y = 26 },
                },
                .value = @intFromEnum(ButtonAction.rep_mult_increase),
                .text = "Builder Rep Multiplier",
            },
            .cost = 0,
        });
        for (0..NUM_ACTIONS) |i| self.setButtonCost(@enumFromInt(i));
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

    fn verify(self: *Game) void {
        // make sure that every reserved slot has a corresponding animation
        for (self.mine_storage.storage, 0..) |str, str_index| {
            if (str == .reserved) {
                var found = false;
                for (self.animations.items, 0..) |anim, anim_index| {
                    _ = anim_index;
                    switch (anim.data) {
                        .miner => |data| {
                            if (data.storage_index == str_index) {
                                found = true;
                                break;
                            }
                        },
                        else => {},
                    }
                }
                if (!found) helpers.debugPrint("{d}: mine_storage_slot_{d} has no animation.", .{ self.score, str_index });
            }
        }
        for (self.base_storage.storage, 0..) |str, str_index| {
            if (str == .reserved) {
                var found = false;
                for (self.animations.items, 0..) |anim, anim_index| {
                    _ = anim_index;
                    switch (anim.data) {
                        .carrier_dropoff => |data| {
                            if (data.storage_index == str_index) {
                                found = true;
                                break;
                            }
                        },
                        else => {},
                    }
                }
                if (!found) helpers.debugPrint("{d}: base_storage_slot_{d} has no animation.", .{ self.score, str_index });
            }
        }
    }

    fn doButtonAction(self: *Game, action: ButtonAction) void {
        self.levels[@intFromEnum(action)] += 1;
        self.setButtonCost(action);
        switch (action) {
            .miner_recruit => {
                self.miners.appendAssumeCapacity(.{ .timer = self.miner_timer });
            },
            .carrier_recruit => {
                self.carriers.appendAssumeCapacity(.{ .timer = 0, .state = .waiting });
            },
            .builder_recruit => {
                self.builders.appendAssumeCapacity(.{ .timer = 0 });
            },
            .carrier_speedup => {
                self.carrier_timer -= @divFloor(self.carrier_timer, 5);
                for (self.carriers.items) |*carrier| {
                    if (carrier.timer > self.carrier_timer) carrier.timer = self.carrier_timer;
                }
            },
            .miner_speedup => {
                self.miner_timer -= @divFloor(self.miner_timer, 4);
            },
            .builder_speedup => {
                self.builder_timer -= @divFloor(self.builder_timer, 4);
            },
            .carrier_strength => {
                self.carrier_capacity += 1;
            },
            .anim_speedup => self.anim_steps -= @divFloor(self.anim_steps, 5),
            .rep_mult_increase => self.rep_mult *= self.rep_mult + 1,
            // .mine_storage_add_row => self.mine_storage.num_rows += 1,
            // .base_storage_add_row => self.base_storage.num_rows += 1,
            .resource_upgrade => {
                self.miner_ore = self.miner_ore.upgrade();
            },
        }
    }

    fn setButtonCost(self: *Game, action: ButtonAction) void {
        const level = self.levels[@intFromEnum(action)];
        const cost = UPGRADE_COSTS[@intFromEnum(action)][level];
        for (self.buttons.items) |*button| {
            if (button.button.value == @intFromEnum(action)) {
                button.cost = cost;
                return;
            }
        }
    }

    fn addAnimation(self: *Game, anim: Animation) void {
        for (self.animations.items) |*ani| {
            if (ani.data == .none) {
                ani.* = anim;
                return;
            }
        }
        if (self.animations.items.len >= ANIM_MAX_COUNT) unreachable;
        self.animations.appendAssumeCapacity(anim);
    }

    fn getMinerPosition(self: *Game, index: usize) Vec2 {
        _ = self;
        const lane = @mod(index, LANES_MAX_COUNT);
        const row = @divFloor(index, LANES_MAX_COUNT);
        const position = LANE0_POSITION.add(LANE_OFFSET.scale(@floatFromInt(lane))).add(SAME_LANE_OFFSET.scale(@floatFromInt(row)));
        return position;
    }

    fn getMineStoragePosition(self: *Game, index: usize) Vec2 {
        _ = self;
        const str_lane = @mod(index, STORAGE_PER_ROW);
        const str_row = @divFloor(index, STORAGE_PER_ROW);
        const position = STORAGE_SLOT.add(STORAGE_LANE.scale(@floatFromInt(str_lane))).add(STORAGE_ROW.scale(@floatFromInt(str_row)));
        return position;
    }

    fn getBaseStoragePosition(self: *Game, index: usize) Vec2 {
        _ = self;
        const str_lane = @mod(index, STORAGE_PER_ROW);
        const str_row = @divFloor(index, STORAGE_PER_ROW);
        const position = BASE_STORAGE_SLOT.add(STORAGE_LANE.scale(@floatFromInt(str_lane))).add(STORAGE_ROW.scale(@floatFromInt(str_row)));
        return position;
    }

    fn getBuilderPosition(self: *Game, index: usize) Vec2 {
        _ = self;
        const lane = @mod(index, LANES_MAX_COUNT);
        const row = @divFloor(index, LANES_MAX_COUNT);
        const position = BUILDER0_POSITION.add(LANE_OFFSET.scale(@floatFromInt(lane))).add(SAME_LANE_OFFSET.scale(@floatFromInt(row)));
        return position;
    }

    fn getCarrierWaitingPosition(self: *Game, index: usize) Vec2 {
        _ = self;
        const carrier_lane = @mod(index, LANES_MAX_COUNT);
        const carrier_row = @divFloor(index, LANES_MAX_COUNT);
        const position = CARRIER_SLOT.add(CARRIER_LANE.scale(@floatFromInt(carrier_lane))).add(CARRIER_OFFSET.scale(@floatFromInt(carrier_row)));
        return position;
    }

    fn getCarrierDropoffPosition(self: *Game, index: usize) Vec2 {
        _ = self;
        const carrier_lane = @mod(index, LANES_MAX_COUNT);
        const carrier_row = @divFloor(index, LANES_MAX_COUNT);
        const position = CARRIER_DROPOFF_SLOT.add(CARRIER_DROPOFF_LANE.scale(@floatFromInt(carrier_lane))).add(CARRIER_DROPOFF_OFFSET.scale(@floatFromInt(carrier_row)));
        return position;
    }

    fn tryCarrierPickup(self: *Game, carrier_index: u8, res: ResType, carrier_slot: u8) void {
        var carrier = &self.carriers.items[carrier_index];
        carrier.res[carrier_slot] = res;
        if (carrier.numCarried() == self.carrier_capacity) {
            carrier.timer = self.carrier_timer;
            carrier.state = .carrying;
        }
    }

    // updateGame
    pub fn update(self: *Game, ticks: u64) void {
        // clear the arena and reset.
        self.steps += 1;
        _ = self.arena_handle.reset(.retain_capacity);
        self.arena = self.arena_handle.allocator();
        self.ticks = @intCast(ticks);
        if (self.haathi.inputs.getKey(.control).is_down and self.haathi.inputs.getKey(.s).is_clicked) {
            self.saveGame();
        }
        for (self.buttons.items) |*button| button.button.update(self.haathi.inputs.mouse);
        for (self.buttons.items) |button| {
            if (button.button.clicked) {
                if (self.points >= button.cost) {
                    self.points -= button.cost;
                    self.doButtonAction(@enumFromInt(button.button.value));
                }
            }
        }
        // update miners
        for (self.miners.items) |*miner| {
            if (miner.timer > 0) miner.timer -= 1;
        }
        for (self.carriers.items) |*carrier| {
            if (carrier.timer > 0) carrier.timer -= 1;
        }
        for (self.builders.items) |*builder| {
            if (builder.timer > 0) builder.timer -= 1;
        }
        {
            // create resources if space exists
            for (self.miners.items, 0..) |*miner, miner_index| {
                if (miner.timer != 0) continue;
                var mined: usize = 0;
                // miner is done mining, find a space for the materials to go.
                const mine_storage_max = self.mine_storage.num_rows * STORAGE_PER_ROW;
                for (self.mine_storage.storage[0..mine_storage_max], 0..) |*str, i| {
                    if (str.* == .none) {
                        str.* = .reserved;
                        miner.timer = self.miner_timer;
                        mined += 1;
                        // create animation
                        self.addAnimation(.{
                            .res = self.miner_ore,
                            .start_step = self.steps,
                            .data = .{ .miner = .{
                                .mine_index = @intCast(miner_index),
                                .storage_index = @intCast(i),
                            } },
                        });
                        if (mined == self.miner_strength) {
                            break;
                        }
                    }
                }
            }
        }
        {
            for (self.carriers.items, 0..) |*carrier, carrier_index| {
                if (carrier.timer != 0) continue;
                switch (carrier.state) {
                    .waiting => {
                        var carried: u8 = carrier.numFull();
                        const mine_storage_max = self.mine_storage.num_rows * STORAGE_PER_ROW;
                        for (self.mine_storage.storage[0..mine_storage_max], 0..) |*str, i| {
                            if (str.* == .none or str.* == .reserved) continue;
                            if (carried >= self.carrier_capacity) {
                                break;
                            }
                            {
                                const res = str.*;
                                str.* = .none;
                                carrier.res[carried] = .reserved;
                                // create animation
                                self.addAnimation(.{
                                    .res = res,
                                    .start_step = self.steps,
                                    .data = .{ .carrier_pickup = .{
                                        .carrier_index = @intCast(carrier_index),
                                        .storage_index = @intCast(i),
                                        .carrier_slot_index = @intCast(carried),
                                    } },
                                });
                                carried += 1;
                            }
                        }
                    },
                    .carrying => {
                        carrier.state = .delivering;
                    },
                    .returning => {
                        carrier.state = .waiting;
                    },
                    .delivering => {
                        const base_storage_max = self.base_storage.num_rows * STORAGE_PER_ROW;
                        var base_dropped: u8 = carrier.numCarried();
                        for (self.base_storage.storage[0..base_storage_max], 0..) |*str, i| {
                            if (str.* == .none) {
                                str.* = .reserved;
                                // create animation
                                base_dropped -= 1;
                                self.addAnimation(.{
                                    .res = carrier.res[base_dropped],
                                    .start_step = self.steps,
                                    .data = .{ .carrier_dropoff = .{
                                        .carrier_index = @intCast(carrier_index),
                                        .storage_index = @intCast(i),
                                        .carrier_slot_index = base_dropped,
                                    } },
                                });
                                carrier.res[base_dropped] = .none;
                                if (base_dropped == 0) {
                                    carrier.timer = self.carrier_timer;
                                    carrier.state = .returning;
                                    break;
                                }
                            }
                        }
                    },
                }
            }
        }
        {
            const base_storage_max = self.base_storage.num_rows * STORAGE_PER_ROW;
            for (self.builders.items, 0..) |*builder, builder_index| {
                if (builder.timer != 0) continue;
                if (builder.reserved) continue;
                for (self.base_storage.storage[0..base_storage_max], 0..) |*str, i| {
                    if (str.* == .none or str.* == .reserved) continue;
                    {
                        const res = str.*;
                        str.* = .none;
                        builder.reserved = true;
                        self.score += res.score() * self.rep_mult;
                        self.points += res.score() * self.rep_mult;
                        // create animation
                        self.addAnimation(.{
                            .res = res,
                            .start_step = self.steps,
                            .data = .{ .builder = .{
                                .builder_index = @intCast(builder_index),
                                .storage_index = @intCast(i),
                            } },
                        });
                        break;
                    }
                }
            }
        }
        for (self.animations.items) |*anim| {
            if (self.steps < anim.start_step) unreachable;
            if (self.steps > anim.start_step + self.anim_steps) {
                switch (anim.data) {
                    .miner => |data| self.mine_storage.storage[data.storage_index] = anim.res,
                    .carrier_pickup => |data| {
                        self.tryCarrierPickup(data.carrier_index, anim.res, data.carrier_slot_index);
                    },
                    .carrier_dropoff => |data| {
                        self.base_storage.storage[data.storage_index] = anim.res;
                    },
                    .builder => |data| {
                        self.builders.items[data.builder_index].reserved = false;
                        self.builders.items[data.builder_index].timer = self.builder_timer;
                    },
                    .none => {},
                }
                anim.data = .none;
                anim.start_step = 0;
            }
        }
        // self.verify();
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
        const score_text = std.fmt.allocPrintZ(self.arena, "{d}: {d} points", .{ self.score, self.points }) catch unreachable;
        self.haathi.drawText(.{
            .text = score_text,
            .position = .{ .x = 300, .y = 300 },
            .color = colors.apollo_dark_1,
        });
        for (self.buttons.items) |button| {
            const progress: f32 = @min(1.0, @as(f32, @floatFromInt(self.points)) / @as(f32, @floatFromInt(button.cost)));
            const color = if (button.button.hovered and progress == 1.0) colors.apollo_blue_4.lerp(colors.apollo_blue_6, 0.4) else colors.apollo_blue_4;
            self.haathi.drawRect(.{ .position = button.button.rect.position, .size = button.button.rect.size, .color = colors.apollo_dark_4, .radius = 4 });
            self.haathi.drawRect(.{ .position = button.button.rect.position, .size = button.button.rect.size.scaleVec2(.{ .x = progress, .y = 1 }), .color = color, .radius = 4 });
            const text_center = button.button.rect.position.add(button.button.rect.size.scaleVec2(.{ .x = 0.5, .y = 1 }).add(.{ .y = -18 }));
            self.haathi.drawText(.{ .text = button.button.text, .position = text_center, .color = colors.apollo_light_4 });
            const cost_text = std.fmt.allocPrintZ(self.arena, "[{d}]", .{button.cost}) catch unreachable;
            self.haathi.drawText(.{ .text = cost_text, .position = text_center.add(.{ .y = -20 }), .color = colors.apollo_blue_1, .style = FONTS[1] });
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
            if (anim.start_step == 0) continue;
            const progress: f32 = @as(f32, @floatFromInt(self.steps - anim.start_step)) / @as(f32, @floatFromInt(self.anim_steps));
            switch (anim.data) {
                .none => {},
                .miner => |data| {
                    const start = self.getMinerPosition(data.mine_index);
                    const end = self.getMineStoragePosition(data.storage_index);
                    const pos = start.ease(end, progress);
                    self.haathi.drawRect(.{
                        .position = pos,
                        .size = .{ .x = 8, .y = 8 },
                        .color = anim.res.color(),
                        .radius = 8,
                    });
                },
                .carrier_pickup => |data| {
                    const start = self.getMineStoragePosition(data.storage_index);
                    const end = self.getCarrierWaitingPosition(data.carrier_index);
                    const pos = start.ease(end, progress);
                    self.haathi.drawRect(.{
                        .position = pos,
                        .size = .{ .x = 8, .y = 8 },
                        .color = anim.res.color(),
                        .radius = 8,
                    });
                },
                .carrier_dropoff => |data| {
                    const start = self.getCarrierDropoffPosition(data.carrier_index);
                    const end = self.getBaseStoragePosition(data.storage_index);
                    const pos = start.ease(end, progress);
                    self.haathi.drawRect(.{
                        .position = pos,
                        .size = .{ .x = 8, .y = 8 },
                        .color = anim.res.color(),
                        .radius = 8,
                    });
                },
                .builder => |data| {
                    const start = self.getBaseStoragePosition(data.storage_index);
                    const end = self.getBuilderPosition(data.builder_index);
                    const pos = start.ease(end, progress);
                    self.haathi.drawRect(.{
                        .position = pos,
                        .size = .{ .x = 8, .y = 8 },
                        .color = anim.res.color(),
                        .radius = 8,
                    });
                },
            }
        }
        for (self.mine_storage.storage[0 .. self.mine_storage.num_rows * STORAGE_PER_ROW], 0..) |str, storage_index| {
            const pos = self.getMineStoragePosition(storage_index);
            if (str == .none or str == .reserved) continue;
            self.haathi.drawRect(.{
                .position = pos,
                .size = .{ .x = 8, .y = 8 },
                .color = str.color(),
                .radius = 8,
            });
        }

        for (self.base_storage.storage[0 .. self.base_storage.num_rows * STORAGE_PER_ROW], 0..) |str, storage_index| {
            const pos = self.getBaseStoragePosition(storage_index);
            if (str == .none or str == .reserved) continue;
            self.haathi.drawRect(.{
                .position = pos,
                .size = .{ .x = 8, .y = 8 },
                .color = str.color(),
                .radius = 8,
            });
        }
        for (self.carriers.items, 0..) |*carrier, carrier_index| {
            const progress: f32 = 1.0 - (@as(f32, @floatFromInt(carrier.timer)) / @as(f32, @floatFromInt(@max(carrier.timer, self.carrier_timer))));
            const start = self.getCarrierWaitingPosition(carrier_index);
            const end = self.getCarrierDropoffPosition(carrier_index);
            const pos = switch (carrier.state) {
                .waiting => start,
                .carrying => start.ease(end, progress),
                .delivering => end,
                .returning => end.ease(start, progress),
            };
            self.haathi.drawRect(.{
                .position = pos,
                .size = .{ .x = 16, .y = 30 },
                .color = colors.apollo_green_1,
                .radius = 2,
            });
            self.haathi.drawText(.{
                .position = pos.add(.{ .x = 10 }),
                .text = @tagName(carrier.state),
                .color = colors.apollo_green_1,
            });
            for (carrier.res, 0..) |res, i| {
                self.haathi.drawRect(.{
                    .position = pos.add(.{ .y = 30 }).add(.{ .y = 10 * @as(f32, @floatFromInt(i)) }),
                    .size = .{ .x = 8, .y = 8 },
                    .color = res.color(),
                    .radius = 8,
                });
            }
        }
        for (self.builders.items, 0..) |builder, builder_index| {
            const position = self.getBuilderPosition(builder_index);
            self.haathi.drawRect(.{
                .position = position,
                .size = .{ .x = 12, .y = 40 },
                .color = colors.apollo_green_2,
                .radius = 2,
            });
            const progress: f32 = @as(f32, @floatFromInt(builder.timer)) / @as(f32, @floatFromInt(@max(builder.timer, self.builder_timer)));
            self.haathi.drawRect(.{
                .position = position,
                .size = .{ .x = 12, .y = 40 * progress },
                .color = colors.apollo_green_1,
                .radius = 2,
            });
        }
    }
};
