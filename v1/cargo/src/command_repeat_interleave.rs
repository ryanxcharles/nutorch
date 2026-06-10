use nu_plugin::{PluginCommand};
use nu_protocol::{
    Category, Example, LabeledError, PipelineData, Signature, SyntaxShape, Type, Value,
};
use tch::Kind;
use uuid::Uuid;

use crate::NutorchPlugin;
use crate::TENSOR_REGISTRY;


// torch repeat_interleave ---------------------------------------------------
// Usage examples
//
//   $x | torch repeat_interleave 3                     # scalar repeat
//   $x | torch repeat_interleave $rep_tensor           # tensor repeat counts
//   $x | torch repeat_interleave 2 --dim 1
//   $x | torch repeat_interleave $rep_tensor --output-size 12
//
// Source tensor MUST be provided by pipeline.
// ---------------------------------------------------------------------------
pub struct CommandRepeatInterleave;

impl PluginCommand for CommandRepeatInterleave {
    type Plugin = NutorchPlugin;

    fn name(&self) -> &str {
        "torch repeat_interleave"
    }

    fn description(&self) -> &str {
        "Repeat elements of a tensor. Supports scalar repeat count or per-element counts via tensor. (similar to tensor.repeat_interleave() in PyTorch)"
    }

    fn signature(&self) -> Signature {
        Signature::build("torch repeat_interleave")
            // pipeline input must be a tensor-id string, result is tensor-id
            .input_output_types(vec![(Type::String, Type::String)])
            .required(
                "repeats",
                SyntaxShape::Any,
                "Repeat factor (integer) or tensor ID",
            )
            .named(
                "dim",
                SyntaxShape::Int,
                "Dimension along which to repeat (default: flatten)",
                None,
            )
            .named(
                "output_size",
                SyntaxShape::Int,
                "Optional output size hint",
                None,
            )
            .category(Category::Custom("torch".into()))
    }

    fn examples(&self) -> Vec<Example> {
        vec![
            Example {
                description: "Scalar repeat",
                example: r#"
let x = ([1 2 3] | torch tensor)
$x | torch repeat_interleave 2 | torch value   # -> [1 1 2 2 3 3]
"#
                .trim(),
                result: None,
            },
            Example {
                description: "Per-element repeat counts (tensor)",
                example: r#"
let x   = ([10 20 30] | torch tensor)
let rep = ([1 2 3]    | torch tensor --dtype int64)
$x | torch repeat_interleave $rep | torch value
"#
                .trim(),
                result: None,
            },
        ]
    }

    fn run(
        &self,
        _plugin: &NutorchPlugin,
        _engine: &nu_plugin::EngineInterface,
        call: &nu_plugin::EvaluatedCall,
        input: PipelineData,
    ) -> Result<PipelineData, LabeledError> {
        // ── source tensor must come through pipeline ───────────────────
        // Pipeline-only design matches other shape ops
        let PipelineData::Value(src_val, _) = input else {
            return Err(LabeledError::new("Missing input")
                .with_label("Source tensor ID must be piped in", call.head));
        };
        let src_id = src_val.as_str()?.to_string();

        // ── required 'repeats' argument (int or tensor ID) ────────────
        // Supports two modes: scalar repeat or per-element repeat counts
        let repeats_val = call
            .nth(0)
            .ok_or_else(|| {
                LabeledError::new("Missing repeats")
                    .with_label("Provide repeat count (int) or tensor ID", call.head)
            })?
            .clone();

        // ── optional named flags ───────────────────────────────────────
        let dim_opt: Option<i64> = call.get_flag("dim")?;
        let osize_opt: Option<i64> = call.get_flag("output_size")?;

        // ── fetch source tensor ────────────────────────────────────────
        let mut reg = TENSOR_REGISTRY.lock().unwrap();
        let src = reg
            .get(&src_id)
            .ok_or_else(|| {
                LabeledError::new("Tensor not found")
                    .with_label("Invalid source tensor ID", call.head)
            })?
            .shallow_clone();

        // ── branch: int repeat vs tensor repeat ───────────────────────
        // Two modes: scalar repeat (int) or per-element repeat (tensor)
        let result = if let Ok(rep_int) = repeats_val.as_int() {
            // Scalar repeat mode: repeat each element rep_int times
            if rep_int <= 0 {
                return Err(LabeledError::new("Invalid repeats")
                    .with_label("Repeat count must be > 0", call.head));
            }
            src.repeat_interleave_self_int(rep_int, dim_opt, osize_opt)
        } else {
            // Tensor repeat mode: per-element repeat counts
            let rep_id = repeats_val.as_str()?.to_string();
            let rep_t = reg
                .get(&rep_id)
                .ok_or_else(|| {
                    LabeledError::new("Tensor not found")
                        .with_label("Invalid repeats tensor ID", call.head)
                })?
                .shallow_clone();

            // Ensure repeat tensor is Int64 (tch-rs requirement)
            let rep_t = if rep_t.kind() == Kind::Int64 {
                rep_t
            } else {
                rep_t.to_kind(Kind::Int64)
            };

            src.repeat_interleave_self_tensor(&rep_t, dim_opt, osize_opt)
        };

        // ── store & return ─────────────────────────────────────────────
        let new_id = Uuid::new_v4().to_string();
        reg.insert(new_id.clone(), result);
        Ok(PipelineData::Value(Value::string(new_id, call.head), None))
    }
}
