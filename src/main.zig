const std = @import("std");
const rl = @import("raylib");

const Paddle = struct {
    x: f32,
    y: f32,
    width: f32,
    height: f32,
    color: rl.Color,
};

const Ball = struct {
    x: f32,
    y: f32,
    radius: f32,
    dx: f32,
    dy: f32,
    color: rl.Color,
};

const Brick = struct {
    x: f32,
    y: f32,
    width: f32,
    height: f32,
    color: rl.Color,
    visible: bool,
    durability: f32,
};

fn handle_paddle_input(paddle: *Paddle) void {
    if (rl.isKeyDown(.right)) {
        paddle.x += 5;
    }
    if (rl.isKeyDown(.left)) {
        paddle.x -= 5;
    }
}

fn handle_ball_movement(ball: *Ball, paddle: *Paddle, comptime screenWidth: i32, comptime screenHeight: i32, score: *i32) void {
    ball.x += ball.dx;
    ball.y += ball.dy;

    if (ball.x <= 0 or ball.x >= screenWidth) {
        ball.dx *= -1;
    }
    if (ball.y <= 0) {
        ball.dy *= -1;
    }

    if (ball.y >= screenHeight) {
        ball.x = screenWidth / 2;
        ball.y = screenHeight / 2;
        ball.dx = 2;
        ball.dy = -2;
        reset_score(score);
    }

    if (ball.x + ball.radius <= paddle.x + paddle.width and
        ball.x - ball.radius >= paddle.x and
        ball.y + ball.radius >= paddle.y and
        ball.y - ball.radius <= paddle.y + paddle.height)
    {
        ball.dy *= -1;
    }
}

fn handle_brick_generation(bricks: []Brick) void {
    const padding = 10.0;
    const offset_x = 10.0;
    const offset_y = 10.0;

    for (bricks, 0..) |*brick, i| {
        const x = (i % 10);
        const y = (i / 10);

        brick.* = Brick{
            .x = offset_x + @as(f32, @floatFromInt(x)) * (100 + padding),
            .y = offset_y + @as(f32, @floatFromInt(y)) * (40 + padding),
            .width = 50,
            .height = 40,
            .color = .green,
            .visible = true,
            .durability = 1,
        };
    }
}

fn draw_bricks(bricks: []Brick) void {
    for (bricks) |*brick| {
        if (!brick.visible) continue;
        rl.drawRectangle(@intFromFloat(brick.x), @intFromFloat(brick.y), @intFromFloat(brick.width), @intFromFloat(brick.height), brick.color);
    }
}

fn handle_brick_collision(bricks: *[]Brick, ball: *Ball, score: *i32) void {
    for (bricks.*) |*brick| {
        if (!brick.visible) continue;

        const ball_left = ball.x - ball.radius;
        const ball_right = ball.x + ball.radius;
        const ball_top = ball.y - ball.radius;
        const ball_bottom = ball.y + ball.radius;

        const brick_left = brick.x;
        const brick_right = brick.x + brick.width;
        const brick_top = brick.y;
        const brick_bottom = brick.y + brick.height;

        const collision =
            ball_right >= brick_left and ball_left <= brick_right and
            ball_bottom >= brick_top and ball_top <= brick_bottom;

        if (collision) {
            update_score(score);
            brick.visible = false;
            ball.dy *= -1;
            break;
        }
    }
}

fn update_score(score: *i32) void {
    score.* += 1;
}

fn reset_score(score: *i32) void {
    score.* = 0;
    std.debug.print("Score reset to 0\n", .{});
}

fn draw_score(score: *i32) void {
    rl.drawText(rl.textFormat("Score: %08i", .{score.*}), 0, 0, 20, rl.Color.white);
}

pub fn main() !void {
    const screenWidth = 800;
    const screenHeight = 450;

    rl.initWindow(screenWidth, screenHeight, "Breakout");
    defer rl.closeWindow();

    rl.setTargetFPS(60);

    var paddle = Paddle{
        .x = screenWidth / 2 - 100,
        .y = screenHeight / 2 + 200,
        .width = 200,
        .height = 20,
        .color = .light_gray,
    };

    var ball = Ball{
        .x = screenWidth / 2,
        .y = screenHeight / 2,
        .radius = 5.0,
        .dx = 2,
        .dy = -2,
        .color = .red,
    };

    const allocator = std.heap.page_allocator;
    var bricks = try allocator.alloc(Brick, 30);
    defer allocator.free(bricks);

    var score: i32 = 0;

    handle_brick_generation(bricks);

    while (!rl.windowShouldClose()) {
        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(.black);

        rl.drawRectangle(@intFromFloat(paddle.x), @intFromFloat(paddle.y), @intFromFloat(paddle.width), @intFromFloat(paddle.height), paddle.color);
        rl.drawCircle(@intFromFloat(ball.x), @intFromFloat(ball.y), ball.radius, ball.color);

        handle_paddle_input(&paddle);

        handle_ball_movement(&ball, &paddle, screenWidth, screenHeight, &score);

        draw_bricks(bricks);
        handle_brick_collision(&bricks, &ball, &score);

        draw_score(&score);
    }
}
