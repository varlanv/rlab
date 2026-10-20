const std = @import("std");
const rl = @import("raylib");
const rlgl = @import("rlgl");

pub const Monitor = struct {
    const Self = @This();
    monitor: i32,

    pub fn refreshRate(self: Self) i32 {
        return rl.GetMonitorRefreshRate(self.monitor);
    }

    pub fn width(self: Self) i32 {
        return rl.GetMonitorWidth(self.monitor);
    }

    pub fn height(self: Self) i32 {
        return rl.GetMonitorHeight(self.monitor);
    }

    pub fn current() Monitor {
        return .{
            .monitor = rl.GetCurrentMonitor(),
        };
    }
};

pub const Raylib = struct {
    pub fn setTargetFPS(value: i32) void {
        rl.SetTargetFPS(@as(c_int, @intCast(value)));
    }

    pub fn init(width: u32, height: u32, title: [*c]const u8) void {
        rl.InitWindow(@as(c_int, @intCast(width)), @as(c_int, @intCast(height)), title);
    }

    pub fn setConfigFlags(flags: usize) void {
        rl.SetConfigFlags(@as(c_uint, flags));
    }

    pub fn close() void {
        rl.CloseWindow();
    }

    pub const Flags = struct {
        pub const FLAG_WINDOW_RESIZABLE = rl.FLAG_WINDOW_RESIZABLE;
    };

    pub const Screen = struct {
        pub fn currentWidth() i32 {
            return rl.GetScreenWidth();
        }

        pub fn currentHeight() i32 {
            return rl.GetScreenHeight();
        }
    };

    pub const Window = struct {
        pub fn setSize(width: i32, height: i32) void {
            return rl.SetWindowSize(width, height);
        }

        pub fn setState(state: u32) void {
            return rl.SetWindowState(state);
        }

        pub fn clearState(state: u32) void {
            return rl.ClearWindowState(state);
        }
    };

    pub const Color = rl.Color;
    pub const Colors = struct {
        pub const RED: rl.Color = rl.RED;
        pub const RAYWHITE: rl.Color = rl.RAYWHITE;
    };
};

pub const GameGraphicsSettings = struct {
    const DEFAULT: GameGraphicsSettings = .{
        .vsyncEnabled = false,
        .windowResizeable = true,
    };
    vsyncEnabled: bool,
    windowResizeable: bool,
};

pub fn updateGraphicsSettings(settings: *const GameGraphicsSettings) void {
    const enabled: c_uint = @intCast(
        (if (settings.vsyncEnabled) rl.FLAG_VSYNC_HINT else 0) |
            (if (settings.windowResizeable) rl.FLAG_WINDOW_RESIZABLE else 0),
    );

    Raylib.Window.setState(enabled);
}

pub const FrameState = struct {
    fps: FPS,
    rectangle: Rectangle,
    backgroundColor: Raylib.Color,

    pub const Rectangle = struct {
        pub const INITIAL_POS_X = -50.0;
        speed: f32,
        posX: f32,
        posY: f32,
        width: i32,
        height: i32,
        color: Raylib.Color,
    };

    pub const FPS = struct {
        posX: i32,
        posY: i32,
    };
};

pub const FrameInput = struct {
    frameDeltaTime: f32,

    pub fn screenWidth(_: FrameInput) i32 {
        return Raylib.Screen.currentWidth();
    }
};

pub fn updateFrame(input: anytype, frame: *FrameState) void {
    updateRectangle(input, frame);
    updateCube(input, frame);
}

pub fn updateCube(_: anytype, _: *FrameState) void {}

pub fn updateRectangle(input: anytype, frame: *FrameState) void {
    var x: f32 = frame.rectangle.posX + frame.rectangle.speed * input.frameDeltaTime;
    if (x > @as(f32, @floatFromInt(input.screenWidth()))) {
        x = FrameState.Rectangle.INITIAL_POS_X;
    }
    frame.rectangle.posX = x;
}

pub fn draw(frame: *const FrameState) void {
    rl.BeginDrawing();
    rl.ClearBackground(frame.backgroundColor);
    rl.DrawFPS(frame.fps.posX, frame.fps.posY);
    rl.DrawRectangle(
        @trunc(frame.rectangle.posX),
        @trunc(frame.rectangle.posY),
        frame.rectangle.width,
        frame.rectangle.height,
        frame.rectangle.color,
    );

    rl.EndDrawing();
}

const StepRotation = struct {
    const Self = @This();
    step: i32 = 0,
    rotation_x: f32 = 0,
    rotation_y: f32 = 0,
    fn decrementX(self: Self) !void {
        self.rotation_x -= self.step;
    }
    fn decrementY(self: Self) !void {
        self.rotation_y -= self.step;
    }
    fn incrementX(self: Self) !void {
        self.rotation_x += self.step;
    }
    fn incrementY(self: Self) !void {
        self.rotation_y += self.step;
    }
};

pub fn main(_: std.process.Init) !void {
    const gameGraphicsSettings = GameGraphicsSettings.DEFAULT;
    Raylib.init(300, 200, "Rectangle Animation");
    defer Raylib.close();
    const model = rl.LoadModel("assets/Duck.glb");
    defer rl.UnloadModel(model);
    updateGraphicsSettings(&gameGraphicsSettings);
    const monitor = Monitor.current();
    Raylib.setTargetFPS(monitor.refreshRate());
    Raylib.Window.setSize(@divTrunc(monitor.width(), 2), @divTrunc(monitor.height(), 2));
    var rotation_x: f32 = 0;
    var rotation_y: f32 = 0;

    // var rotation_x: f32 = 0;
    // var rotation_y: f32 = 0;
    //
    // const camera: rl.Camera3D = .{
    //     .position = .{
    //         .x = 4,
    //         .y = 3,
    //         .z = 6,
    //     },
    //     .target = .{
    //         .x = 0,
    //         .y = 0,
    //         .z = 0,
    //     },
    //     .up = .{
    //         .x = 0,
    //         .y = 1,
    //         .z = 0,
    //     },
    //     .fovy = 45,
    //     .projection = rl.CAMERA_PERSPECTIVE,
    // };
    //
    // const center: rl.Vector3 = .{
    //     .x = 0,
    //     .y = 0,
    //     .z = 0,
    // };
    //
    // var currentFrame: FrameState = .{
    //     .backgroundColor = Raylib.Colors.RAYWHITE,
    //     .fps = .{
    //         .posX = 0,
    //         .posY = 0,
    //     },
    //     .rectangle = .{
    //         .speed = 500,
    //         .posX = 50,
    //         .posY = 200,
    //         .width = 50,
    //         .height = 50,
    //         .color = Raylib.Colors.RED,
    //     },
    // };

    // var step: f32 = 0;
    while (!rl.WindowShouldClose()) {
        drawDuck(model, &rotation_x, &rotation_y);
        // const frameInput: FrameInput = .{
        //     .frameDeltaTime = rl.GetFrameTime(),
        // };
        // updateFrame(frameInput, &currentFrame);
        // draw(&currentFrame);
        //
        // step = 90.0 * rl.GetFrameTime();
        //
        // if (rl.IsKeyDown(rl.KEY_LEFT)) rotation_x -= step;
        // if (rl.IsKeyDown(rl.KEY_RIGHT)) rotation_x += step;
        // if (rl.IsKeyDown(rl.KEY_UP)) rotation_y -= step;
        // if (rl.IsKeyDown(rl.KEY_DOWN)) rotation_y += step;
        //
        // rl.BeginDrawing();
        // {
        //     rl.ClearBackground(rl.RAYWHITE);
        //
        //     rl.BeginMode3D(camera);
        //     {
        //         rlgl.rlPushMatrix();
        //
        //         rlgl.rlRotatef(rotation_x, 1, 0, 0);
        //         rlgl.rlRotatef(rotation_y, 0, 1, 0);
        //
        //         // rl.DrawCube(center, 2, 2, 2, rl.RED);
        //         rl.DrawCubeWires(center, 2, 2, 2, rl.BLACK);
        //
        //         rlgl.rlPopMatrix();
        //     }
        //     rl.EndMode3D();
        // }
        // rl.EndDrawing();
    }
}

fn drawDuck(model: rl.struct_Model, rotation_x: *f32, rotation_y: *f32) void {
    const camera: rl.Camera3D = .{
        .position = .{
            .x = 4,
            .y = 3,
            .z = 6,
        },
        .target = .{
            .x = 0,
            .y = 0,
            .z = 0,
        },
        .up = .{
            .x = 0,
            .y = 1,
            .z = 0,
        },
        .fovy = 45,
        .projection = rl.CAMERA_PERSPECTIVE,
    };
    const center: rl.Vector3 = .{
        .x = 0,
        .y = 0,
        .z = 0,
    };

    const step = 90.0 * rl.GetFrameTime();

    if (rl.IsKeyDown(rl.KEY_LEFT)) rotation_x.* -= step;
    if (rl.IsKeyDown(rl.KEY_RIGHT)) rotation_x.* += step;
    if (rl.IsKeyDown(rl.KEY_UP)) rotation_y.* -= step;
    if (rl.IsKeyDown(rl.KEY_DOWN)) rotation_y.* += step;

    rl.BeginDrawing();
    {
        rl.ClearBackground(rl.RAYWHITE);
        rl.BeginMode3D(camera);
        {
            rlgl.rlPushMatrix();

            rlgl.rlRotatef(rotation_x.*, 1, 0, 0);
            rlgl.rlRotatef(rotation_y.*, 0, 1, 0);

            rl.DrawModel(model, center, 1.0, rl.WHITE);

            rlgl.rlPopMatrix();
        }
        rl.EndMode3D();
    }
    rl.EndDrawing();
}

test "simple test" {
    const gpa = std.testing.allocator;
    var list: std.ArrayList(i32) = .empty;
    defer list.deinit(gpa); // Try commenting this out and see if zig detects the memory leak!
    try list.append(gpa, 42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
