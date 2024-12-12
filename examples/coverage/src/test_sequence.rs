fn test() {
    // Tuple
    let _: () = ();
    let _: (u8, u16, i8) = (1, 2, 3);
    let _: u8 = (1, 2).0;
    let _: u8 = (1,).0;
    let _: u8 = (1, 2, 3, 4, 5).3;

    // Array
    let _: [u8; 0] = [];
    let _: [&str; 3] = ["23", "a", "hllo"];
    let _: [u8; 14] = [2; 14];

    // Slice
    let _: &[u8] = &[1, 2, 3, 4];
    let _: &[&str] = &[];
}
