fn first<A, B>((value, _): (A, i32), y: B) -> A
where
    B: Clone,
{
    value
}

// foo is generic over A and B

fn foo1<A, B>(x: A, y: B) {}

fn foo2<T>(x: &[T], y: &[T; 1])
where
    T: Clone,
{
    // details elided
}

fn test() {
    let x = [1u8];
    foo2(&x, &x);
    foo2(&[1, 2], &x);
}

extern "Rust" fn foo3() {}

// async fn regular_example() { } // TODO: Not yet supported

// Requires std::fmt;
// fn documented() {
//     #![doc = "Example"]
// }
