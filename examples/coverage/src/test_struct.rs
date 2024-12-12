struct foo<'a, T, const N: usize> {
    bar: &'a T,
    baz: [T; N],
    qux: u8,
}

// Point {x: 10.0, y: 20.0};
// NothingInMe {};
// TuplePoint(10.0, 20.0);
// TuplePoint { 0: 10.0, 1: 20.0 }; // Results in the same value as the above line
// let u = game::User {name: "Joe", age: 35, score: 100_000};
// some_fn::<Cookie>(Cookie);

fn test() {
    {
        struct Gamma;
        let a = Gamma; // Gamma unit value.
        let b = Gamma {}; // Exact same value as `a`.
    }
    {
        struct Position(i32, i32, i32);
        Position(0, 0, 0); // Typical way of creating a tuple struct.
        let c = Position; // `c` is a function that takes 3 arguments.
        let pos = c(8, 6, 7); // Creates a `Position` value.
    }
    {
        struct Color(u8, u8, u8);
        let c1 = Color(0, 0, 0); // Typical way of creating a tuple struct.
        let c2 = Color {
            0: 255,
            1: 127,
            2: 0,
        }; // Specifying fields by index.
        let c3 = Color { 1: 0, ..c2 }; // Fill out all other fields using a base struct.
    }
    {
        struct PointA {
            x: i32,
            y: i32,
        }
        let p = PointA { x: 10, y: 11 };
        let px: i32 = p.x;

        let mut p2 = PointA { x: 10, y: 11 };
        p2.x = 10;
        p2.y = 14;
    }
    {
        struct PointB(i32, i32);
        let p = PointB(10, 11);
        let px: i32 = match p {
            PointB(x, _) => x,
        };
    }
    {
        struct CookieA;
        let c = [CookieA, CookieA {}, CookieA, CookieA {}];
    }
    {
        struct Cookie {}
        const Cookie: Cookie = Cookie {};
        let c = [Cookie, Cookie {}, Cookie, Cookie {}];
    }
}
