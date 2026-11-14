pub enum Shape {
    Circle { radius: f64 },
    Rectangle(f64, f64),
    Empty,
}

#[repr(u8)]
enum Level {
    Low = 1,
    High = 2,
}

impl Shape {
    fn area(&self) -> f64 {
        0.0
    }
}

struct Point {
    x: i32,
}
