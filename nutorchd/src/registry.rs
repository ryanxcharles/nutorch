//! The tensor registry: the daemon-owned map from string handles to live
//! tensors. Ported from v1's TENSOR_REGISTRY concept (v1/cargo/src/lib.rs),
//! minus the global static — the daemon owns one instance for its lifetime.
//!
//! Issue 0006: entries carry created/touched timestamps so `torch tensors`
//! can report age and idleness. Touching is explicit (`touch`), never a
//! side effect of `get` — dispatch decides what counts as "use".

use std::collections::HashMap;
use std::time::Instant;
use tch::Tensor;

pub struct Entry {
    pub tensor: Tensor,
    pub created: Instant,
    pub touched: Instant,
}

/// One row of `list()`: everything `torch tensors` shows.
pub struct Listing {
    pub handle: String,
    pub shape: Vec<i64>,
    pub kind: tch::Kind,
    pub bytes: u64,
    pub age_secs: u64,
    pub idle_secs: u64,
}

#[derive(Default)]
pub struct Registry {
    tensors: HashMap<String, Entry>,
}

impl Registry {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn insert(&mut self, tensor: Tensor) -> String {
        let handle = uuid::Uuid::new_v4().to_string();
        let now = Instant::now();
        self.tensors.insert(
            handle.clone(),
            Entry {
                tensor,
                created: now,
                touched: now,
            },
        );
        handle
    }

    pub fn get(&self, handle: &str) -> Option<&Tensor> {
        self.tensors.get(handle).map(|entry| &entry.tensor)
    }

    /// Mark a tensor as used. A no-op on an absent handle, so the table's
    /// touch pass stays harmless when resolution is about to error.
    pub fn touch(&mut self, handle: &str) {
        if let Some(entry) = self.tensors.get_mut(handle) {
            entry.touched = Instant::now();
        }
    }

    pub fn remove(&mut self, handle: &str) -> Option<Entry> {
        self.tensors.remove(handle)
    }

    /// Empty the registry; returns how many tensors were freed.
    pub fn clear(&mut self) -> usize {
        let count = self.tensors.len();
        self.tensors.clear();
        count
    }

    pub fn contains(&self, handle: &str) -> bool {
        self.tensors.contains_key(handle)
    }

    pub fn len(&self) -> usize {
        self.tensors.len()
    }

    pub fn is_empty(&self) -> bool {
        self.tensors.is_empty()
    }

    /// Approximate bytes held: Σ numel × element size. (Removed as dead code
    /// in issue 0002; legitimately needed by `status` since issue 0004.)
    pub fn approx_bytes(&self) -> u64 {
        self.tensors
            .values()
            .map(|e| e.tensor.numel() as u64 * e.tensor.kind().elt_size_in_bytes() as u64)
            .sum()
    }

    /// All entries, oldest-created first (the natural order for "what has
    /// been sitting here").
    pub fn list(&self) -> Vec<Listing> {
        let now = Instant::now();
        let mut rows: Vec<(&String, &Entry)> = self.tensors.iter().collect();
        rows.sort_by_key(|(_, entry)| entry.created);
        rows.into_iter()
            .map(|(handle, entry)| Listing {
                handle: handle.clone(),
                shape: entry.tensor.size(),
                kind: entry.tensor.kind(),
                bytes: entry.tensor.numel() as u64 * entry.tensor.kind().elt_size_in_bytes() as u64,
                age_secs: now.duration_since(entry.created).as_secs(),
                idle_secs: now.duration_since(entry.touched).as_secs(),
            })
            .collect()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::time::Duration;

    #[test]
    fn insert_returns_distinct_uuid_handles() {
        let mut registry = Registry::new();
        let a = registry.insert(Tensor::from(1.0));
        let b = registry.insert(Tensor::from(2.0));
        assert_ne!(a, b);
        assert!(registry.get(&a).is_some());
        assert!(registry.get(&b).is_some());
        assert!(registry.get("not-a-handle").is_none());
    }

    #[test]
    fn list_is_oldest_first_with_correct_fields() {
        let mut registry = Registry::new();
        let a = registry.insert(Tensor::from_slice(&[1.0f32, 2.0, 3.0]));
        std::thread::sleep(Duration::from_millis(15));
        let b = registry.insert(Tensor::from_slice(&[1i64, 2]));
        let rows = registry.list();
        assert_eq!(rows.len(), 2);
        assert_eq!(rows[0].handle, a);
        assert_eq!(rows[1].handle, b);
        assert_eq!(rows[0].shape, vec![3]);
        assert_eq!(rows[0].kind, tch::Kind::Float);
        assert_eq!(rows[0].bytes, 12);
        assert_eq!(rows[1].kind, tch::Kind::Int64);
        assert_eq!(rows[1].bytes, 16);
    }

    #[test]
    fn touch_resets_idle_but_get_does_not() {
        let mut registry = Registry::new();
        let a = registry.insert(Tensor::from(1.0));
        std::thread::sleep(Duration::from_millis(1100));
        let idle = registry.list()[0].idle_secs;
        assert!(idle >= 1, "expected idle >= 1s, got {idle}");
        let _ = registry.get(&a); // reads do not touch
        assert!(registry.list()[0].idle_secs >= 1);
        registry.touch(&a);
        assert_eq!(registry.list()[0].idle_secs, 0);
        // age keeps growing regardless of touch
        assert!(registry.list()[0].age_secs >= 1);
        registry.touch("not-a-handle"); // no-op, no panic
    }
}
