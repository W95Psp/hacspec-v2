// // This function borrows a slice.
// fn analyze_slice(slice: &[i32]) {
//     let _ = slice[0];
//     let _ = slice.len();
// }

// fn test(){
//     // Fixed-size array (type signature is superfluous).
//     let xs: [i32; 5] = [1, 2, 3, 4, 5];

//     // All elements can be initialized to the same value.
//     let ys: [i32; 500] = [0; 500];

//     // Indexing starts at 0.
//     let _ = xs[0];
//     let _ = xs[1];

//     // `len` returns the count of elements in the array.
//     let _ = xs.len();

//     // Arrays can be automatically borrowed as slices.
//     analyze_slice(&xs);

//     // Slices can point to a section of an array.
//     // They are of the form [starting_index..ending_index].
//     // `starting_index` is the first position in the slice.
//     // `ending_index` is one more than the last position in the slice.
//     analyze_slice(&ys[1 .. 4]);

//     // Example of empty slice `&[]`:
//     let empty_array: [u32; 0] = [];
//     assert_eq!(&empty_array, &[]);
//     assert_eq!(&empty_array, &[][..]); // Same but more verbose
// }
