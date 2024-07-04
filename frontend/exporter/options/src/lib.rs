use schemars::JsonSchema;
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize, JsonSchema)]
pub enum Glob {
    One,  // *
    Many, // **
}

#[derive(Debug, Clone, Serialize, Deserialize, JsonSchema)]
pub enum NamespaceChunk {
    Glob(Glob),
    Exact(String),
}

impl std::convert::From<&str> for NamespaceChunk {
    fn from(s: &str) -> Self {
        match s {
            "*" => NamespaceChunk::Glob(Glob::One),
            "**" => NamespaceChunk::Glob(Glob::Many),
            _ => NamespaceChunk::Exact(String::from(s)),
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, JsonSchema)]
pub struct Namespace {
    pub chunks: Vec<NamespaceChunk>,
}

impl std::convert::From<String> for Namespace {
    fn from(s: String) -> Self {
        Namespace {
            chunks: s
                .split("::")
                .into_iter()
                .filter(|s| s.len() > 0)
                .map(|s| NamespaceChunk::from(s))
                .collect(),
        }
    }
}

impl Namespace {
    pub fn matches(&self, path: &Vec<String>) -> bool {
        fn aux(pattern: &[NamespaceChunk], path: &[String]) -> bool {
            match (pattern, path) {
                ([], []) => true,
                ([NamespaceChunk::Exact(x), pattern @ ..], [y, path @ ..]) => {
                    x == y && aux(pattern, path)
                }
                ([NamespaceChunk::Glob(Glob::One), pattern @ ..], [_, path @ ..]) => {
                    aux(pattern, path)
                }
                ([NamespaceChunk::Glob(Glob::Many), pattern @ ..], []) => aux(pattern, path),
                ([NamespaceChunk::Glob(Glob::Many), pattern_tl @ ..], [_path_hd, path_tl @ ..]) => {
                    aux(pattern_tl, path) || aux(pattern, path_tl)
                }
                _ => false,
            }
        }
        aux(self.chunks.as_slice(), path.as_slice())
    }
}

#[derive(Default, Debug, Clone)]
pub struct Options {
    pub inline_macro_calls: Vec<Namespace>,
    /// Whether to emit errors or downgrade them as warnings.
    pub downgrade_errors: bool,
}
