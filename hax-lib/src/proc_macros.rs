//! This module re-exports macros from `hax-lib-macros` since a
//! proc-macro crate cannot export anything but procedural macros.

pub use hax_lib_macros::{
    attributes, ensures, exclude, impl_fn_decoration, include, lemma, loop_invariant, opaque,
    opaque_type, refinement_type, requires, trait_fn_decoration, transparent,
};

pub use hax_lib_macros::{
    process_init, process_read, process_write, protocol_messages, pv_constructor, pv_handwritten,
};

include!(concat!(env!("OUT_DIR"), "/proc_macros_generated.rs"));
