// enum SomeEnum<T> {
//     None,
//     Some(T),
// }

// trait SomeTrait {
//     fn some_fun(&self) -> Self;
// }

// impl<T> SomeTrait for SomeEnum<T>
// where
//     T: SomeTrait,
// {
//     #[inline]
//     fn some_fun(&self) -> Self {
//         match self {
//             SomeEnum::Some(x) => SomeEnum::Some(x.some_fun()),
//             SomeEnum::None => SomeEnum::None,
//         }
//     }
// }
