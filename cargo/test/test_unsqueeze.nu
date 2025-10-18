use std assert
use std/testing *

@test
def "Test unsqueeze with pipeline input" [] {
  let input_data = $in
  let t = torch full [2 3] 1
  let result = ($t | torch unsqueeze 0 | torch shape)
  # [2, 3] with dim 0 unsqueezed becomes [1, 2, 3]
  assert ($result == [1 2 3])
}

@test
def "Test unsqueeze at end" [] {
  let input_data = $in
  let t = torch full [2 3] 1
  let result = ($t | torch unsqueeze 2 | torch shape)
  # [2, 3] with dim 2 unsqueezed becomes [2, 3, 1]
  assert ($result == [2 3 1])
}

@test
def "Test unsqueeze in middle" [] {
  let input_data = $in
  let t = torch full [2 3] 1
  let result = ($t | torch unsqueeze 1 | torch shape)
  # [2, 3] with dim 1 unsqueezed becomes [2, 1, 3]
  assert ($result == [2 1 3])
}

@test
def "Test unsqueeze 1D tensor" [] {
  let input_data = $in
  let t = torch tensor [1 2 3]
  let result = ($t | torch unsqueeze 0 | torch shape)
  # [3] with dim 0 unsqueezed becomes [1, 3]
  assert ($result == [1 3])
}

@test
def "Test unsqueeze scalar" [] {
  let input_data = $in
  let t = torch tensor 42
  let result = ($t | torch unsqueeze 0 | torch shape)
  # [] (scalar) with dim 0 unsqueezed becomes [1]
  assert ($result == [1])
}

@test
def "Test unsqueeze preserves values" [] {
  let input_data = $in
  let t = torch tensor [[1 2 3] [4 5 6]]
  let result = ($t | torch unsqueeze 0 | torch value)
  # Values should be preserved after unsqueeze
  assert ($result == [[[1 2 3] [4 5 6]]])
}

@test
def "Test unsqueeze multiple times" [] {
  let input_data = $in
  let t = torch full [2 3] 1
  let result = ($t | torch unsqueeze 0 | torch unsqueeze 0 | torch shape)
  # [2, 3] -> [1, 2, 3] -> [1, 1, 2, 3]
  assert ($result == [1 1 2 3])
}

@test
def "Test unsqueeze then squeeze" [] {
  let input_data = $in
  let t = torch tensor [[1 2 3]]
  let result = ($t | torch unsqueeze 0 | torch squeeze 0 | torch shape)
  # Adding and removing dimension should return to original shape
  assert ($result == [1 3])
}

@test
def "Test unsqueeze 3D tensor" [] {
  let input_data = $in
  let t = torch full [2 3 4] 1
  let result = ($t | torch unsqueeze 2 | torch shape)
  # [2, 3, 4] with dim 2 unsqueezed becomes [2, 3, 1, 4]
  assert ($result == [2 3 1 4])
}

@test
def "Test unsqueeze at various positions" [] {
  let input_data = $in
  let t = torch full [3 4] 1
  let r0 = ($t | torch unsqueeze 0 | torch shape)
  let r1 = ($t | torch unsqueeze 1 | torch shape)
  let r2 = ($t | torch unsqueeze 2 | torch shape)
  # Test unsqueezing at all valid positions
  assert ($r0 == [1 3 4])
  assert ($r1 == [3 1 4])
  assert ($r2 == [3 4 1])
}

@test
def "Error case with invalid tensor ID" [] {
  let input_data = $in
  try {
    "invalid-uuid" | torch unsqueeze 0
    error make {msg: "Expected error from invalid tensor ID"}
  } catch {
    # expected
  }
}

@test
def "Error case with invalid dimension" [] {
  let input_data = $in
  try {
    let t = torch full [2 3] 1
    $t | torch unsqueeze 5
    error make {msg: "Expected error from invalid dimension"}
  } catch {
    # expected
  }
}

@test
def "Error case with negative dimension" [] {
  let input_data = $in
  try {
    let t = torch full [2 3] 1
    $t | torch unsqueeze (-1)
    error make {msg: "Expected error from negative dimension"}
  } catch {
    # expected
  }
}
