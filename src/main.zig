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

fn handle_ball_movement(ball: *Ball, paddle: *Paddle, comptime screenWidth: i32, comptime screenHeight: i32, bricks: []Brick, score: *i32, lives: *i32) void {
    ball.x += ball.dx;
    ball.y += ball.dy;

    if (ball.x <= 0 or ball.x >= screenWidth) {
        ball.dx *= -1;
    }
    if (ball.y <= 0) {
        ball.dy *= -1;
    }

    if (ball.y >= screenHeight) {
        reset_game(paddle, ball, bricks, screenWidth, screenHeight, score, lives);
    }

    if (ball.x + ball.radius <= paddle.x + paddle.width and
        ball.x - ball.radius >= paddle.x and
        ball.y + ball.radius >= paddle.y and
        ball.y - ball.radius <= paddle.y + paddle.height)
    {
        ball.dy *= -1;
    }
}

fn reset_game(paddle: *Paddle, ball: *Ball, bricks: []Brick, comptime screenWidth: i32, comptime screenHeight: i32, score: *i32, lives: *i32) void {
    paddle.* = Paddle{
        .x = screenWidth / 2 - 100,
        .y = screenHeight / 2 + 200,
        .width = 200,
        .height = 20,
        .color = .light_gray,
    };

    ball.* = Ball{
        .x = screenWidth / 2,
        .y = screenHeight / 2,
        .radius = 5.0,
        .dx = 2,
        .dy = -2,
        .color = .red,
    };

    if (lives.* <= 0) {
        lives.* = 3;
        score.* = 0;
        handle_brick_generation(bricks);
    } else {
        lives.* -= 1;
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

fn reset_score(score: *i32, lives: *i32) void {
    score.* = 0;
    lives.* -= 1;
}

fn draw_score(score: *i32) void {
    rl.drawText(rl.textFormat("Score: %08i", .{score.*}), 0, 0, 20, rl.Color.white);
}

fn draw_lives(lives: *i32) void {
    rl.drawText(rl.textFormat("Lives: %08i", .{lives.*}), 240, 240, 20, rl.Color.white);
}

const GameState = enum {
    MainMenu,
    Playing,
    Paused,
    GameOver,
    GameWon,
};

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

    //   const texture = rl.loadTexture("assets/dungeon_sheet.png");
    //    defer rl.unloadTexture(texture);

    var score: i32 = 0;

    handle_brick_generation(bricks);

    var game_state: GameState = .MainMenu;
    var lives: i32 = 3;

    while (!rl.windowShouldClose()) {
        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(.black);

        switch (game_state) {
            .MainMenu => {
                rl.drawText("BREAKOUT", 260, 150, 40, rl.Color.red);
                rl.drawText("Press ENTER to start", 240, 250, 20, rl.Color.white);

                if (rl.isKeyPressed(.enter)) {
                    game_state = .Playing;
                }

                reset_game(&paddle, &ball, bricks, screenWidth, screenHeight, &score, &lives);
            },
            .Playing => {
                draw_score(&score);
                draw_lives(&lives);

                //                rl.drawTexture(texture, 0, 0, rl.Color.white);

                rl.drawRectangle(@intFromFloat(paddle.x), @intFromFloat(paddle.y), @intFromFloat(paddle.width), @intFromFloat(paddle.height), paddle.color);
                rl.drawCircle(@intFromFloat(ball.x), @intFromFloat(ball.y), ball.radius, ball.color);

                handle_paddle_input(&paddle);

                handle_ball_movement(&ball, &paddle, screenWidth, screenHeight, bricks, &score, &lives);

                draw_bricks(bricks);

                handle_brick_collision(&bricks, &ball, &score);

                if (score == bricks.len) {
                    game_state = .GameWon;
                }

                if (lives <= 0) {
                    game_state = .GameOver;
                }

                if (rl.isKeyPressed(.enter)) {
                    game_state = .Paused;
                }
            },
            .GameWon => {
                rl.drawText("GAME WON", 260, 150, 40, rl.Color.green);
                rl.drawText("Press ENTER to return to menu", 240, 250, 20, rl.Color.white);
                if (rl.isKeyPressed(.enter)) {
                    game_state = .MainMenu;
                }
            },
            .Paused => {
                rl.drawText("PAUSED", 260, 150, 40, rl.Color.red);
                rl.drawText("Press ENTER to resume", 240, 250, 20, rl.Color.white);
                rl.drawText("Press Q to quit", 240, 250, 20, rl.Color.white);

                if (rl.isKeyPressed(.enter)) {
                    game_state = .Playing;
                }
            },
            .GameOver => {
                rl.drawText("GAME OVER", 260, 150, 40, rl.Color.red);
                rl.drawText("Press ENTER to return to menu", 240, 250, 20, rl.Color.white);
                if (rl.isKeyPressed(.enter)) {
                    game_state = .MainMenu;
                }
            },
        }
    }
}
