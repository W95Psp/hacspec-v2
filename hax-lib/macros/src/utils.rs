use crate::prelude::*;
use crate::rewrite_self::*;

/// `HaxQuantifiers` makes polymorphic expression inlining functions available
pub struct HaxQuantifiers;
impl ToTokens for HaxQuantifiers {
    fn to_tokens(&self, tokens: &mut proc_macro2::TokenStream) {
        quote! {
            use ::hax_lib::fstar::prop as fstar;
            use ::hax_lib::coq::prop as coq;
            use ::hax_lib::proverif::prop as proverif;
        }
        .to_tokens(tokens)
    }
}

/// Meta informations about functions decorations
pub enum FnDecorationKind {
    Requires,
    Ensures { ret_binder: Pat },
    Decreases,
}

impl ToString for FnDecorationKind {
    fn to_string(&self) -> String {
        match self {
            FnDecorationKind::Requires => "requires".to_string(),
            FnDecorationKind::Ensures { .. } => "ensures".to_string(),
            FnDecorationKind::Decreases { .. } => "decreases".to_string(),
        }
    }
}

impl From<FnDecorationKind> for AssociationRole {
    fn from(kind: FnDecorationKind) -> Self {
        match &kind {
            FnDecorationKind::Requires => AssociationRole::Requires,
            FnDecorationKind::Ensures { .. } => AssociationRole::Ensures,
            FnDecorationKind::Decreases => AssociationRole::Decreases,
        }
    }
}

/// Merge two `syn::Generics`, respecting lifetime orders
pub(crate) fn merge_generics(x: Generics, y: Generics) -> Generics {
    Generics {
        lt_token: x.lt_token.or(y.lt_token),
        gt_token: x.gt_token.or(y.gt_token),
        params: {
            let lts = x
                .lifetimes()
                .chain(y.lifetimes())
                .cloned()
                .map(GenericParam::Lifetime);
            let not_lts = x
                .params
                .clone()
                .into_iter()
                .filter(|p| !matches!(p, GenericParam::Lifetime(_)))
                .chain(
                    y.params
                        .clone()
                        .into_iter()
                        .filter(|p| !matches!(p, GenericParam::Lifetime(_))),
                );
            lts.chain(not_lts).collect()
        },
        where_clause: match (x.where_clause, y.where_clause) {
            (Some(wx), Some(wy)) => Some(syn::WhereClause {
                where_token: wx.where_token,
                predicates: wx.predicates.into_iter().chain(wy.predicates).collect(),
            }),
            (Some(w), None) | (None, Some(w)) => Some(w),
            (None, None) => None,
        },
    }
}

/// Transform every `x: &mut T` input into `x: &T` in a signature, and
/// returns a list of such transformed `x: &T` inputs
fn unmut_references_in_inputs(sig: &mut Signature) -> Vec<FnArg> {
    let mut mutable_inputs = vec![];
    for input in &mut sig.inputs {
        if let Some(mutability) = match input {
            FnArg::Receiver(syn::Receiver {
                reference: Some(_),
                mutability,
                ..
            }) => Some(mutability),
            FnArg::Typed(syn::PatType { ty, .. }) => {
                use std::borrow::BorrowMut;
                if let syn::Type::Reference(syn::TypeReference { mutability, .. }) = ty.borrow_mut()
                {
                    Some(mutability)
                } else {
                    None
                }
            }
            _ => None,
        } {
            if mutability.is_some() {
                *mutability = None;
                mutable_inputs.push(input.clone());
            }
        }
    }
    mutable_inputs
}

/// Expects a `FnArg` to be a simple variable pattern
fn expect_fn_arg_var_pat(arg: &FnArg) -> Option<(String, syn::Type)> {
    match arg {
        FnArg::Receiver(recv) => Some(("self".into(), *recv.ty.clone())),
        FnArg::Typed(pat_type) => match &*pat_type.pat {
            syn::Pat::Wild(_) => Some(("".into(), *pat_type.ty.clone())),
            syn::Pat::Ident(pat_ident) => {
                Some((format!("{}", pat_ident.ident), *pat_type.ty.clone()))
            }
            _ => None,
        },
    }
}

pub(crate) enum NotFutureExpr {
    BadNumberOfArgs,
    ArgNotIdent,
}

/// `expect_future_expr(e)` tries to match the pattern
/// `future(<syn::Ident>)` in expression `e`
pub(crate) fn expect_future_expr(e: &Expr) -> Option<std::result::Result<Ident, NotFutureExpr>> {
    if let Expr::Call(call) = e {
        if call.func.is_ident("future") {
            return Some(match call.args.iter().collect::<Vec<_>>().as_slice() {
                [arg] => arg.expect_ident().ok_or(NotFutureExpr::ArgNotIdent),
                _ => Err(NotFutureExpr::BadNumberOfArgs),
            });
        }
    }
    None
}

/// Rewrites `future(x)` nodes in an expression when (1) `x` is an
/// ident and (2) the ident `x` is contained in the HashSet.
struct RewriteFuture(HashSet<String>);
impl VisitMut for RewriteFuture {
    fn visit_expr_mut(&mut self, e: &mut Expr) {
        syn::visit_mut::visit_expr_mut(self, e);
        let error = match expect_future_expr(e) {
            Some(Ok(arg)) => {
                let arg = format!("{}", arg);
                if self.0.contains(&arg) {
                    let arg = create_future_ident(&arg);
                    *e = parse_quote! {#arg};
                    return;
                }
                Some(format!("Cannot find an input `{arg}` of type `&mut _`. In the context, `future` can be called on the following inputs: {:?}.", self.0))
            }
            Some(Err(error_kind)) => {
                let message = match error_kind {
                    NotFutureExpr::BadNumberOfArgs => {
                        "`future` can only be called with one argument: a `&mut` input name"
                    }
                    NotFutureExpr::ArgNotIdent => {
                        "`future` can only be called with an `&mut` input name"
                    }
                };
                let help_message = match self.0.iter().next() {
                    None => " In the context, there is no `&mut` input.".to_string(),
                    Some(var) => {
                        format!(" For example, in the context you can write `future({var})`.")
                    }
                };
                Some(format!("{message}.{}", help_message))
            }
            None => None,
        };
        if let Some(error) = error {
            *e = parse_quote! {::std::compile_error!(#error)};
        }
    }
}

fn create_future_ident(name: &str) -> syn::Ident {
    proc_macro2::Ident::new(&format!("{name}_future"), proc_macro2::Span::call_site())
}

/// The engine translates functions of arity zero to functions that
/// takes exactly one unit argument. The zero-arity functions we
/// generate are translated correctly as well. But in the case of a
/// `ensures` clause, that's an issue: we produce a function of arity
/// one, whose first argument is the result of the function. Instead,
/// we need a function of arity two.
/// `fix_signature_arity` adds a `unit` if needed.
fn add_unit_to_sig_if_needed(signature: &mut Signature) {
    if signature.inputs.is_empty() {
        signature.inputs.push(parse_quote! {_: ()})
    }
}

/// Common logic when generating a function decoration
pub fn make_fn_decoration(
    mut phi: Expr,
    mut signature: Signature,
    kind: FnDecorationKind,
    mut generics: Option<Generics>,
    self_type: Option<Type>,
) -> (TokenStream, AttrPayload) {
    let self_ident: Ident = syn::parse_quote! {self_};
    let error = {
        let mut rewriter = RewriteSelf::new(self_ident, self_type);
        rewriter.visit_expr_mut(&mut phi);
        rewriter.visit_signature_mut(&mut signature);
        if let Some(generics) = generics.as_mut() {
            rewriter.visit_generics_mut(generics);
        }
        rewriter.get_error()
    };
    let uid = ItemUid::fresh();
    let mut_ref_inputs = unmut_references_in_inputs(&mut signature);
    let decoration = {
        let decoration_sig = {
            let mut sig = signature.clone();
            sig.ident = format_ident!("{}", kind.to_string());
            if let FnDecorationKind::Ensures { ret_binder } = &kind {
                add_unit_to_sig_if_needed(&mut sig);
                let output_typ = match sig.output {
                    syn::ReturnType::Default => parse_quote! {()},
                    syn::ReturnType::Type(_, t) => t,
                };
                let mut_ref_inputs = mut_ref_inputs
                    .iter()
                    .map(|mut_ref_input| {
                        expect_fn_arg_var_pat(mut_ref_input).expect(
                            "Every `&mut` input of a function annotated with a `ensures` clause is expected to be a simple variable pattern.",
                        )
                    });
                let mut rewrite_future =
                    RewriteFuture(mut_ref_inputs.clone().map(|x| x.0).collect());
                rewrite_future.visit_expr_mut(&mut phi);
                let (mut pats, mut tys): (Vec<_>, Vec<_>) = mut_ref_inputs
                    .map(|(name, ty)| {
                        (
                            create_future_ident(&name).to_token_stream(),
                            ty.to_token_stream(),
                        )
                    })
                    .unzip();

                let is_output_typ_unit = if let syn::Type::Tuple(tuple) = &*output_typ {
                    tuple.elems.is_empty()
                } else {
                    false
                };

                if !is_output_typ_unit || pats.is_empty() {
                    pats.push(ret_binder.to_token_stream());
                    tys.push(quote! {#output_typ});
                }

                sig.inputs
                    .push(syn::parse_quote! {(#(#pats),*): (#(#tys),*)});
            }
            if let Some(generics) = generics {
                sig.generics = merge_generics(generics, sig.generics);
            }
            sig.output = if let FnDecorationKind::Decreases = &kind {
                syn::parse_quote! { -> Box<dyn Any> }
            } else {
                syn::parse_quote! { -> impl Into<::hax_lib::Prop> }
            };
            sig
        };
        let uid_attr = AttrPayload::Uid(uid.clone());
        let late_skip = &AttrPayload::ItemStatus(ItemStatus::Included { late_skip: true });
        let any_trait = if let FnDecorationKind::Decreases = &kind {
            phi = parse_quote! {Box::new(#phi)};
            quote! {#AttrHaxLang #[allow(unused)] trait Any {} impl<T> Any for T {}}
        } else {
            quote! {}
        };
        let quantifiers = if let FnDecorationKind::Decreases = &kind {
            None
        } else {
            Some(HaxQuantifiers)
        };
        let future = if let FnDecorationKind::Ensures { .. } = &kind {
            quote! { #late_skip #AttrHaxLang fn future<T>(x: &mut T) -> &T { x } }
        } else {
            quote! {}
        };
        use AttrPayload::NeverErased;
        quote! {
            #[cfg(#DebugOrHaxCfgExpr)]
            #late_skip
            const _: () = {
                #quantifiers
                #any_trait
                #future
                #uid_attr
                #late_skip
                #[allow(unused)]
                #NeverErased
                #decoration_sig {
                    #phi
                }
            };
        }
    };

    let assoc_attr = AttrPayload::AssociatedItem {
        role: kind.into(),
        item: uid,
    };
    (quote! {#error #decoration}, assoc_attr)
}
