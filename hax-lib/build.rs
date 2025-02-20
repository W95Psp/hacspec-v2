use std::env;
use std::fs;
use std::path::Path;

const FSTAR_EXTRA: &str = r"
pub use hax_lib_macros::fstar_options as options;
pub use hax_lib_macros::fstar_verification_status as verification_status;
";

fn main() {
    let code = |backend: &str, extra: &str| {
        format!(
            r#"
pub use hax_lib_macros::{backend}_expr as {backend};
#[doc(hidden)]
pub use hax_lib_macros::{backend}_unsafe_expr;
#[doc(hidden)]
pub use hax_lib_macros::{backend}_prop_expr;

/// Procedular macros that have an effect only for the backend {backend}.
pub mod {backend} {{
    #[doc(hidden)]
    pub use hax_lib_macros::{backend}_unsafe_expr as unsafe_expr;
    pub use hax_lib_macros::{backend}_prop_expr as prop;
    pub use hax_lib_macros::{backend}_after as after;
    pub use hax_lib_macros::{backend}_before as before;
    pub use hax_lib_macros::{backend}_replace as replace;
    pub use hax_lib_macros::{backend}_replace_body as replace_body;

    {extra}
}}
"#
        )
    };

    let out_dir = env::var_os("OUT_DIR").unwrap();
    let dest_path = Path::new(&out_dir).join("proc_macros_generated.rs");
    fs::write(
        &dest_path,
        [
            code("fstar", FSTAR_EXTRA),
            code("proverif", ""),
            code("coq", ""),
        ]
        .join("\n"),
    )
    .unwrap();

    println!("cargo::rerun-if-changed=build.rs");
}
