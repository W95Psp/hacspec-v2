use quote::quote;
use syn::{parse, parse_macro_input};

/// This macro takes an `fn` as the basis of an `InitialState` implementation
/// for the state type that is returned by the `fn` (on success).
///
/// The `fn` is expected to build the state type specified as a `Path` attribute
/// argument from a `Vec<u8>`, i.e. the signature should be compatible with
/// `TryFrom<Vec<u8>>` for the state type given as argument to the macro.
///
/// Example:
/// ```ignore
/// pub struct A0 {
///   data: u8,
/// }
///
/// #[hax_lib_protocol_macros::init(A0)]
/// fn init_a(prologue: Vec<u8>) -> ProtocolResult<A0> {
///     if prologue.len() < 1 {
///        return Err(ProtocolError::InvalidPrologue);
///     }
///     Ok(A0 { data: prologue[0] })
/// }
///
/// // The following is generated by the macro:
/// #[hax_lib_macros::exclude]
/// impl TryFrom<Vec<u8>> for A0 {
///     type Error = ProtocolError;
///     fn try_from(value: Vec<u8>) -> Result<Self, Self::Error> {
///         init_a(value)
///     }
/// }
/// #[hax_lib_macros::exclude]
/// impl InitialState for A0 {
///     fn init(prologue: Option<Vec<u8>>) -> ProtocolResult<Self> {
///         if let Some(prologue) = prologue {
///             prologue.try_into()
///         } else {
///             Err(ProtocolError::InvalidPrologue)
///         }
///     }
/// }
/// ```
#[proc_macro_attribute]
pub fn init(
    attr: proc_macro::TokenStream,
    item: proc_macro::TokenStream,
) -> proc_macro::TokenStream {
    let mut output = quote!(#[hax_lib_macros::process_init]);
    output.extend(proc_macro2::TokenStream::from(item.clone()));

    let input: syn::ItemFn = parse_macro_input!(item);
    let return_type: syn::Path = parse_macro_input!(attr);
    let name = input.sig.ident;

    let expanded = quote!(
        #[hax_lib_macros::exclude]
        impl TryFrom<Vec<u8>> for #return_type {
            type Error = ProtocolError;

            fn try_from(value: Vec<u8>) -> Result<Self, Self::Error> {
                #name(value)
            }
        }

        #[hax_lib_macros::exclude]
        impl InitialState for #return_type {
            fn init(prologue: Option<Vec<u8>>) -> ProtocolResult<Self> {
                if let Some(prologue) = prologue {
                    prologue.try_into()
                } else {
                    Err(ProtocolError::InvalidPrologue)
                }
            }
        }
    );
    output.extend(expanded);

    output.into()
}

/// This macro takes an `fn` as the basis of an `InitialState` implementation
/// for the state type that is returned by the `fn` (on success).
///
/// The `fn` is expected to build the state type specified as a `Path` attribute
/// argument without additional input.
/// Example:
/// ```ignore
/// pub struct B0 {}
///
/// #[hax_lib_protocol_macros::init_empty(B0)]
/// fn init_b() -> ProtocolResult<B0> {
///    Ok(B0 {})
/// }
///
/// // The following is generated by the macro:
/// #[hax_lib_macros::exclude]
/// impl InitialState for B0 {
///     fn init(prologue: Option<Vec<u8>>) -> ProtocolResult<Self> {
///         if let Some(_) = prologue {
///             Err(ProtocolError::InvalidPrologue)
///         } else {
///             init_b()
///         }
///     }
/// }
/// ```
#[proc_macro_error::proc_macro_error]
#[proc_macro_attribute]
pub fn init_empty(
    attr: proc_macro::TokenStream,
    item: proc_macro::TokenStream,
) -> proc_macro::TokenStream {
    let mut output = quote!(#[hax_lib_macros::process_init]);
    output.extend(proc_macro2::TokenStream::from(item.clone()));

    let input: syn::ItemFn = parse_macro_input!(item);
    let return_type: syn::Path = parse_macro_input!(attr);
    let name = input.sig.ident;

    let expanded = quote!(
        #[hax_lib_macros::exclude]
        impl InitialState for #return_type {
            fn init(prologue: Option<Vec<u8>>) -> ProtocolResult<Self> {
                if let Some(_) = prologue {
                    Err(ProtocolError::InvalidPrologue)
                } else {
                    #name()
                }
            }
        }
    );
    output.extend(expanded);

    return output.into();
}

/// A structure to parse transition tuples from `read` and `write` macros.
struct Transition {
    /// `Path` to the current state type of the transition.
    pub current_state: syn::Path,
    /// `Path` to the destination state type of the transition.
    pub next_state: syn::Path,
    /// `Path` to the message type this transition is based on.
    pub message_type: syn::Path,
}

impl syn::parse::Parse for Transition {
    fn parse(input: parse::ParseStream) -> syn::Result<Self> {
        use syn::spanned::Spanned;
        let punctuated =
            syn::punctuated::Punctuated::<syn::Path, syn::Token![,]>::parse_terminated(input)?;
        if punctuated.len() != 3 {
            Err(syn::Error::new(
                punctuated.span(),
                "Insufficient number of arguments",
            ))
        } else {
            let mut args = punctuated.into_iter();
            Ok(Self {
                current_state: args.next().unwrap(),
                next_state: args.next().unwrap(),
                message_type: args.next().unwrap(),
            })
        }
    }
}

/// Macro deriving a `WriteState` implementation for the origin state type,
/// generating a message of `message_type` and a new state, as indicated by the
/// transition tuple.
///
/// Example:
/// ```ignore
/// #[hax_lib_protocol_macros::write(A0, A1, Message)]
/// fn write_ping(state: A0) -> ProtocolResult<(A1, Message)> {
///    Ok((A1 {}, Message::Ping(state.data)))
/// }
///
/// // The following is generated by the macro:
/// #[hax_lib_macros::exclude]
/// impl TryFrom<A0> for (A1, Message) {
///    type Error = ProtocolError;
///
///    fn try_from(value: A0) -> Result<Self, Self::Error> {
///       write_ping(value)
///    }
/// }
///
/// #[hax_lib_macros::exclude]
/// impl WriteState for A0 {
///    type NextState = A1;
///    type Message = Message;
///
///    fn write(self) -> ProtocolResult<(Self::NextState, Message)> {
///        self.try_into()
///    }
/// }
/// ```
#[proc_macro_attribute]
pub fn write(
    attr: proc_macro::TokenStream,
    item: proc_macro::TokenStream,
) -> proc_macro::TokenStream {
    let mut output = quote!(#[hax_lib_macros::process_write]);
    output.extend(proc_macro2::TokenStream::from(item.clone()));

    let input: syn::ItemFn = parse_macro_input!(item);
    let Transition {
        current_state,
        next_state,
        message_type,
    } = parse_macro_input!(attr);

    let name = input.sig.ident;

    let expanded = quote!(
        #[hax_lib_macros::exclude]
        impl TryFrom<#current_state> for (#next_state, #message_type) {
            type Error = ProtocolError;

            fn try_from(value: #current_state) -> Result<Self, Self::Error> {
                #name(value)
            }
        }

        #[hax_lib_macros::exclude]
        impl WriteState for #current_state {
            type NextState = #next_state;
            type Message = #message_type;

            fn write(self) -> ProtocolResult<(Self::NextState, Self::Message)> {
                self.try_into()
            }
        }
    );
    output.extend(expanded);

    output.into()
}

/// Macro deriving a `ReadState` implementation for the destination state type,
/// consuming a message of `message_type` and the current state, as indicated by
/// the transition tuple.
///
/// Example:
/// ```ignore
/// #[hax_lib_protocol_macros::read(A1, A2, Message)]
/// fn read_pong(_state: A1, msg: Message) -> ProtocolResult<A2> {
///     match msg {
///         Message::Ping(_) => Err(ProtocolError::InvalidMessage),
///         Message::Pong(received) => Ok(A2 { received }),
///     }
/// }
/// // The following is generated by the macro:
/// #[hax_lib_macros::exclude]
/// impl TryFrom<(A1, Message)> for A2 {
///     type Error = ProtocolError;
///     fn try_from((state, msg): (A1, Message)) -> Result<Self, Self::Error> {
///         read_pong(state, msg)
///     }
/// }
/// #[hax_lib_macros::exclude]
/// impl ReadState<A2> for A1 {
///     type Message = Message;
///     fn read(self, msg: Message) -> ProtocolResult<A2> {
///         A2::try_from((self, msg))
///     }
/// }
/// ```
#[proc_macro_attribute]
pub fn read(
    attr: proc_macro::TokenStream,
    item: proc_macro::TokenStream,
) -> proc_macro::TokenStream {
    let mut output = quote!(#[hax_lib_macros::process_read]);
    output.extend(proc_macro2::TokenStream::from(item.clone()));

    let input: syn::ItemFn = parse_macro_input!(item);
    let Transition {
        current_state,
        next_state,
        message_type,
    } = parse_macro_input!(attr);

    let name = input.sig.ident;

    let expanded = quote!(
        #[hax_lib_macros::exclude]
        impl TryFrom<(#current_state, #message_type)> for #next_state {
            type Error = ProtocolError;

            fn try_from((state, msg): (#current_state, #message_type)) -> Result<Self, Self::Error> {
                #name(state, msg)
            }
        }

        #[hax_lib_macros::exclude]
        impl ReadState<#next_state> for #current_state {
            type Message = #message_type;
            fn read(self, msg: Self::Message) -> ProtocolResult<#next_state> {
                #next_state::try_from((self, msg))
            }
        }
    );
    output.extend(expanded);

    output.into()
}
