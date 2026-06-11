//! The declarative op table (issue 0005): one row per tensor operation,
//! read by the daemon (dispatch/validation) and the thin client (argument
//! parsing, usage, `torch ops`). Deliberately has no tch dependency.
//!
//! Table-level invariant: variadic-tensor ops take ALL non-tensor parameters
//! as flags, never trailing positionals — with unbounded tensor slots there
//! is no way to tell where tensors end and a positional scalar begins.

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Arity {
    Exactly(usize),
    AtLeast(usize),
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ParamKind {
    /// Integer (e.g. --dim 0, seed)
    Int,
    /// Float (e.g. --rtol 1e-5)
    Float,
    /// Number, int or float (e.g. a fill value, an exponent)
    Scalar,
    /// JSON list of integers (e.g. a shape: '[2,3]')
    IntList,
    /// Presence-only flag (e.g. --keepdim, --descending)
    Bool,
    /// String (e.g. --dtype float32; einsum's equation later)
    Str,
}

#[derive(Debug, Clone, Copy)]
pub struct ParamSpec {
    pub name: &'static str,
    pub kind: ParamKind,
    /// Positional params follow the tensor slots, in spec order; the rest
    /// are flags (`--name value`, or presence-only for Bool).
    pub positional: bool,
    pub required: bool,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ResultKind {
    /// N new registry handles (1 for most ops; sort returns 2).
    Handles(usize),
    /// A plain JSON value (e.g. allclose's bool).
    Value,
    /// Nothing (e.g. manual_seed).
    None,
}

#[derive(Debug, Clone, Copy)]
pub struct OpSpec {
    pub name: &'static str,
    pub category: &'static str,
    pub tensors: Arity,
    pub params: &'static [ParamSpec],
    pub results: ResultKind,
    /// Elementwise ops that follow PyTorch broadcasting get a Rust-side
    /// broadcastability pre-check for quality errors.
    pub broadcasts: bool,
    pub summary: &'static str,
}

const fn flag(name: &'static str, kind: ParamKind) -> ParamSpec {
    ParamSpec {
        name,
        kind,
        positional: false,
        required: false,
    }
}

const fn pos(name: &'static str, kind: ParamKind) -> ParamSpec {
    ParamSpec {
        name,
        kind,
        positional: true,
        required: true,
    }
}

pub static OPS: &[OpSpec] = &[
    OpSpec {
        name: "add",
        category: "pointwise",
        tensors: Arity::Exactly(2),
        params: &[],
        results: ResultKind::Handles(1),
        broadcasts: true,
        summary: "elementwise sum (broadcasting)",
    },
    OpSpec {
        name: "sub",
        category: "pointwise",
        tensors: Arity::Exactly(2),
        params: &[],
        results: ResultKind::Handles(1),
        broadcasts: true,
        summary: "elementwise difference (broadcasting)",
    },
    OpSpec {
        name: "sin",
        category: "pointwise",
        tensors: Arity::Exactly(1),
        params: &[],
        results: ResultKind::Handles(1),
        broadcasts: false,
        summary: "elementwise sine",
    },
    OpSpec {
        name: "pow",
        category: "pointwise",
        tensors: Arity::Exactly(1),
        params: &[pos("exponent", ParamKind::Scalar)],
        results: ResultKind::Handles(1),
        broadcasts: false,
        summary: "elementwise power with a scalar exponent",
    },
    OpSpec {
        name: "clamp",
        category: "pointwise",
        tensors: Arity::Exactly(1),
        params: &[
            flag("min", ParamKind::Scalar),
            flag("max", ParamKind::Scalar),
        ],
        results: ResultKind::Handles(1),
        broadcasts: false,
        summary: "clamp values into [min, max] (at least one bound required)",
    },
    OpSpec {
        name: "sum",
        category: "reduction",
        tensors: Arity::Exactly(1),
        params: &[
            flag("dim", ParamKind::Int),
            flag("keepdim", ParamKind::Bool),
        ],
        results: ResultKind::Handles(1),
        broadcasts: false,
        summary: "sum over all elements, or along --dim",
    },
    OpSpec {
        name: "mean",
        category: "reduction",
        tensors: Arity::Exactly(1),
        params: &[
            flag("dim", ParamKind::Int),
            flag("keepdim", ParamKind::Bool),
        ],
        results: ResultKind::Handles(1),
        broadcasts: false,
        summary: "mean over all elements, or along --dim (float32, v1 fidelity)",
    },
    OpSpec {
        name: "eq",
        category: "comparison",
        tensors: Arity::Exactly(2),
        params: &[],
        results: ResultKind::Handles(1),
        broadcasts: true,
        summary: "elementwise equality (returns a Bool tensor)",
    },
    OpSpec {
        name: "allclose",
        category: "comparison",
        tensors: Arity::Exactly(2),
        params: &[
            flag("rtol", ParamKind::Float),
            flag("atol", ParamKind::Float),
        ],
        results: ResultKind::Value,
        broadcasts: true,
        summary: "true if all elements are close (returns a JSON bool)",
    },
    OpSpec {
        name: "sort",
        category: "comparison",
        tensors: Arity::Exactly(1),
        params: &[
            flag("dim", ParamKind::Int),
            flag("descending", ParamKind::Bool),
        ],
        results: ResultKind::Handles(2),
        broadcasts: false,
        summary: "sort along --dim (default last); returns values and indices",
    },
    OpSpec {
        name: "mm",
        category: "linalg",
        tensors: Arity::Exactly(2),
        params: &[],
        results: ResultKind::Handles(1),
        broadcasts: false,
        summary: "matrix multiply of two 2-D tensors",
    },
    OpSpec {
        name: "cat",
        category: "shape",
        tensors: Arity::AtLeast(2),
        params: &[flag("dim", ParamKind::Int)],
        results: ResultKind::Handles(1),
        broadcasts: false,
        summary: "concatenate tensors along --dim (default 0)",
    },
    OpSpec {
        name: "full",
        category: "creation",
        tensors: Arity::Exactly(0),
        params: &[
            pos("shape", ParamKind::IntList),
            pos("value", ParamKind::Scalar),
            flag("dtype", ParamKind::Str),
        ],
        results: ResultKind::Handles(1),
        broadcasts: false,
        summary: "a tensor of the given shape filled with a value",
    },
    OpSpec {
        name: "randn",
        category: "creation",
        tensors: Arity::Exactly(0),
        params: &[
            pos("shape", ParamKind::IntList),
            flag("dtype", ParamKind::Str),
        ],
        results: ResultKind::Handles(1),
        broadcasts: false,
        summary: "standard-normal random tensor (float kinds only)",
    },
    OpSpec {
        name: "manual_seed",
        category: "utility",
        tensors: Arity::Exactly(0),
        params: &[pos("seed", ParamKind::Int)],
        results: ResultKind::None,
        broadcasts: false,
        summary: "seed the random number generator",
    },
];

pub fn find(name: &str) -> Option<&'static OpSpec> {
    OPS.iter().find(|spec| spec.name == name)
}

/// Categories in display order (each category appears once).
pub fn categories() -> Vec<&'static str> {
    let mut seen = Vec::new();
    for spec in OPS {
        if !seen.contains(&spec.category) {
            seen.push(spec.category);
        }
    }
    seen
}

impl OpSpec {
    pub fn positional_params(&self) -> impl Iterator<Item = &'static ParamSpec> {
        self.params.iter().filter(|p| p.positional)
    }

    pub fn usage(&self) -> String {
        let mut usage = format!("usage: torch {}", self.name);
        match self.tensors {
            Arity::Exactly(n) => {
                for i in 0..n {
                    usage.push_str(&format!(" <t{}>", i + 1));
                }
            }
            Arity::AtLeast(n) => usage.push_str(&format!(" <t1>... (at least {n})")),
        }
        for param in self.positional_params() {
            usage.push_str(&format!(" <{}>", param.name));
        }
        for param in self.params.iter().filter(|p| !p.positional) {
            match param.kind {
                ParamKind::Bool => usage.push_str(&format!(" [--{}]", param.name)),
                _ => usage.push_str(&format!(" [--{} <{:?}>]", param.name, param.kind)),
            }
        }
        usage
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn table_names_are_unique_and_findable() {
        for spec in OPS {
            assert_eq!(find(spec.name).unwrap().name, spec.name);
        }
        let mut names: Vec<_> = OPS.iter().map(|s| s.name).collect();
        names.sort();
        names.dedup();
        assert_eq!(names.len(), OPS.len(), "duplicate op names");
    }

    #[test]
    fn variadic_ops_have_no_positional_params() {
        for spec in OPS {
            if matches!(spec.tensors, Arity::AtLeast(_)) {
                assert_eq!(
                    spec.positional_params().count(),
                    0,
                    "{}: variadic ops take all non-tensor params as flags",
                    spec.name
                );
            }
        }
    }

    #[test]
    fn table_has_fifteen_ops() {
        assert_eq!(OPS.len(), 15);
    }
}
