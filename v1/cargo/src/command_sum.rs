use nu_plugin::{PluginCommand};
use nu_protocol::{
    Category, Example, LabeledError, PipelineData, Signature, SyntaxShape, Type, Value,
};
use tch::Tensor;
use uuid::Uuid;

use crate::get_kind_from_call;
use crate::NutorchPlugin;
use crate::TENSOR_REGISTRY;

// torch sum  ---------------------------------------------------------------
//
// Compute the sum of tensor elements along specified dimensions or over all elements.
// Accept the tensor ID either from the pipeline or as a single argument.
// -------------------------------------------------------------------------
pub struct CommandSum;

impl PluginCommand for CommandSum {
    type Plugin = NutorchPlugin;

    fn name(&self) -> &str {
        "torch sum"
    }

    fn description(&self) -> &str {
        "Compute the sum of tensor elements. (similar to torch.sum() or tensor.sum() in PyTorch)"
    }

    fn signature(&self) -> Signature {
        Signature::build("torch sum")
            .input_output_types(vec![
                (Type::String, Type::String),  // pipeline-in
                (Type::Nothing, Type::String), // arg-in
            ])
            .optional(
                "tensor_id",
                SyntaxShape::String,
                "ID of the tensor (if not provided via pipeline)",
            )
            .named(
                "dtype",
                SyntaxShape::String,
                "Data type of the result tensor (default: same as input)",
                None,
            )
            .named(
                "dim",
                SyntaxShape::Int,
                "Dimension along which to compute sum (default: over all elements)",
                None,
            )
            .named(
                "keepdim",
                SyntaxShape::Boolean,
                "Whether to keep the reduced dimension as size 1 (default: false)",
                None,
            )
            .category(Category::Custom("torch".into()))
    }

    fn examples(&self) -> Vec<Example> {
        vec![
            Example {
                description: "Compute sum over all elements via pipeline",
                example: "let t = ([1 2 3 4 5] | torch tensor); $t | torch sum | torch value",
                result: None,
            },
            Example {
                description: "Compute sum over all elements via argument",
                example: "let t = ([1 2 3 4 5] | torch tensor); torch sum $t | torch value",
                result: None,
            },
            Example {
                description: "Compute sum along a specific dimension with keepdim",
                example: "let t = ([[1 2 3] [4 5 6]] | torch tensor); $t | torch sum --dim 1 --keepdim true | torch value",
                result: None,
            }
        ]
    }

    fn run(
        &self,
        _plugin: &NutorchPlugin,
        _engine: &nu_plugin::EngineInterface,
        call: &nu_plugin::EvaluatedCall,
        input: PipelineData,
    ) -> Result<PipelineData, LabeledError> {
        // ── dual input: pipeline OR argument (not both) ───────────────
        let piped = match input {
            PipelineData::Empty => None,
            PipelineData::Value(v, _span) => Some(v),
            _ => {
                return Err(LabeledError::new("Unsupported input")
                    .with_label("Only Empty or single Value inputs are supported", call.head))
            }
        };
        let arg0 = call.nth(0);

        let tensor_id = match (piped, arg0) {
            (Some(_), Some(_)) => {
                return Err(LabeledError::new("Conflicting input").with_label(
                    "Provide tensor ID via pipeline OR argument, not both",
                    call.head,
                ))
            }
            (None, None) => {
                return Err(LabeledError::new("Missing input").with_label(
                    "Tensor ID must be supplied via pipeline or argument",
                    call.head,
                ))
            }
            (Some(v), None) => v.as_str().map(|s| s.to_string()).map_err(|_| {
                LabeledError::new("Invalid input")
                    .with_label("Pipeline input must be a tensor ID (string)", call.head)
            })?,
            (None, Some(a)) => a.as_str().map(|s| s.to_string()).map_err(|_| {
                LabeledError::new("Invalid input")
                    .with_label("Argument must be a tensor ID (string)", call.head)
            })?,
        };

        // ── fetch tensor from registry ────────────────────────────────
        let mut reg = TENSOR_REGISTRY.lock().unwrap();
        let tensor = reg
            .get(&tensor_id)
            .ok_or_else(|| {
                LabeledError::new("Tensor not found").with_label("Invalid tensor ID", call.head)
            })?
            .shallow_clone();

        // ── get dtype for result ──────────────────────────────────────
        let kind = get_kind_from_call(call)?;

        // ── compute sum ───────────────────────────────────────────────
        let dim_opt: Option<i64> = call.get_flag("dim")?;
        let keepdim = call.get_flag::<bool>("keepdim")?.unwrap_or(false);
        let result_tensor: Tensor = match dim_opt {
            Some(dim) => {
                let num_dims = tensor.size().len() as i64;
                if dim < 0 || dim >= num_dims {
                    return Err(LabeledError::new("Invalid dimension").with_label(
                        format!(
                            "Dimension {dim} out of bounds for tensor with {num_dims} dimensions"
                        ),
                        call.head,
                    ));
                }
                // Use sum_dim_intlist for dimension-specific sum
                tensor.sum_dim_intlist(&[dim][..], keepdim, kind)
            }
            None => tensor.sum(kind), // Sum over all elements
        };

        // ── store result in registry and return ID ────────────────────
        let new_id = Uuid::new_v4().to_string();
        reg.insert(new_id.clone(), result_tensor);
        Ok(PipelineData::Value(Value::string(new_id, call.head), None))
    }
}
