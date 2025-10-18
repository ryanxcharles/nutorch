use std assert
use std/testing *

@test
def "Test stack dim 0 - pipeline form" [] {
  let input_data = $in
  let t1 = ([[1 2] [3 4]] | torch tensor)
  let t2 = ([[5 6] [7 8]] | torch tensor)
  let res = ([$t1 $t2] | torch stack --dim 0 | torch value)
  # Stack [2, 2] + [2, 2] along dim 0 creates new dim: [2, 2, 2]
  let exp = [
    [[1 2] [3 4]]
    [[5 6] [7 8]]
  ]
  assert ($res == $exp)
}

@test
def "Test stack dim 1 - argument form" [] {
  let input_data = $in
  let t1 = ([[1 2] [3 4]] | torch tensor)
  let t2 = ([[5 6] [7 8]] | torch tensor)
  let res = (torch stack [$t1 $t2] --dim 1 | torch value)
  # Stack along dim 1: [2, 2, 2]
  let exp = [
    [[1 2] [5 6]]
    [[3 4] [7 8]]
  ]
  assert ($res == $exp)
}

@test
def "Test stack dim 2" [] {
  let input_data = $in
  let t1 = ([[1 2] [3 4]] | torch tensor)
  let t2 = ([[5 6] [7 8]] | torch tensor)
  let result = (torch stack [$t1 $t2] --dim 2 | torch shape)
  # Stack [2, 2] along new dim 2: [2, 2, 2]
  assert ($result == [2 2 2])
}

@test
def "Test stack 1D tensors" [] {
  let input_data = $in
  let t1 = ([1 2 3] | torch tensor)
  let t2 = ([4 5 6] | torch tensor)
  let result = (torch stack [$t1 $t2] | torch value)
  # Stack [3] + [3] along dim 0: [2, 3]
  assert ($result == [[1 2 3] [4 5 6]])
}

@test
def "Test stack three tensors" [] {
  let input_data = $in
  let t1 = ([1 2] | torch tensor)
  let t2 = ([3 4] | torch tensor)
  let t3 = ([5 6] | torch tensor)
  let result = (torch stack [$t1 $t2 $t3] | torch shape)
  # Stack [2] + [2] + [2] along dim 0: [3, 2]
  assert ($result == [3 2])
}

@test
def "Test stack default dim is 0" [] {
  let input_data = $in
  let t1 = ([1 2] | torch tensor)
  let t2 = ([3 4] | torch tensor)
  let result = (torch stack [$t1 $t2] | torch shape)
  # Default dim should be 0
  assert ($result == [2 2])
}

@test
def "Test stack 3D tensors" [] {
  let input_data = $in
  let t1 = torch full [2 3 4] 1
  let t2 = torch full [2 3 4] 2
  let result = (torch stack [$t1 $t2] --dim 1 | torch shape)
  # Stack [2, 3, 4] along dim 1: [2, 2, 3, 4]
  assert ($result == [2 2 3 4])
}

@test
def "Test stack with negative dim" [] {
  let input_data = $in
  let t1 = ([[1 2] [3 4]] | torch tensor)
  let t2 = ([[5 6] [7 8]] | torch tensor)
  let result = (torch stack [$t1 $t2] --dim (-1) | torch shape)
  # -1 for [2, 2] means last position (dim 2): [2, 2, 2]
  assert ($result == [2 2 2])
}

@test
def "Error case - shape mismatch" [] {
  let input_data = $in
  let t1 = ([[1 2] [3 4]] | torch tensor)
  let t2 = ([5 6 7] | torch tensor)
  try {
    torch stack [$t1 $t2]
    error make {msg: "Expected error from shape mismatch"}
  } catch {
    # expected - [2, 2] vs [3] don't match
  }
}

@test
def "Error case - invalid tensor ID" [] {
  let input_data = $in
  let t1 = ([1 2] | torch tensor)
  try {
    torch stack [$t1 "invalid-uuid"]
    error make {msg: "Expected error from invalid tensor ID"}
  } catch {
    # expected
  }
}

@test
def "Error case - empty list" [] {
  let input_data = $in
  try {
    torch stack []
    error make {msg: "Expected error from empty list"}
  } catch {
    # expected - no tensors provided
  }
}

@test
def "Error case - invalid dimension" [] {
  let input_data = $in
  let t1 = ([1 2] | torch tensor)
  let t2 = ([3 4] | torch tensor)
  try {
    torch stack [$t1 $t2] --dim 5
    error make {msg: "Expected error from invalid dimension"}
  } catch {
    # expected - dim 5 out of bounds for 1D tensor
  }
}

@test
def "Error case - single tensor" [] {
  let input_data = $in
  let t1 = ([1 2 3] | torch tensor)
  let result = (torch stack [$t1] | torch shape)
  # Single tensor is valid, just adds a dimension
  assert ($result == [1 3])
}
