use std assert
use std/testing *

@test
def "Test repeat 1D basic" [] {
  let input_data = $in
  let r1 = ([1 2] | torch tensor | torch repeat 3 | torch shape)
  # [2] repeated 3 times becomes [6]
  assert ($r1 == [6])
}

@test
def "Test repeat 1D with two dimensions" [] {
  let input_data = $in
  let t = ([1 2 3] | torch tensor)
  let result = ($t | torch repeat 2 4 | torch shape)
  # [3] with sizes [2, 4] auto-expands to [1, 3] then repeats to [2, 12]
  assert ($result == [2 12])
}

@test
def "Test repeat 2D basic" [] {
  let input_data = $in
  let t = ([[1 2] [3 4]] | torch tensor)
  let result = ($t | torch repeat 2 3 | torch shape)
  # [2, 2] repeated [2, 3] becomes [4, 6]
  assert ($result == [4 6])
}

@test
def "Test repeat identity - repeat by 1" [] {
  let input_data = $in
  let t = ([[1 2] [3 4]] | torch tensor)
  let result = ($t | torch repeat 1 1 | torch shape)
  # Repeating by 1 preserves shape
  assert ($result == [2 2])
}

@test
def "Test repeat 3D tensor" [] {
  let input_data = $in
  let t = torch full [2 3 4] 1
  let result = ($t | torch repeat 1 2 3 | torch shape)
  # [2, 3, 4] repeated [1, 2, 3] becomes [2, 6, 12]
  assert ($result == [2 6 12])
}

@test
def "Test repeat scalar" [] {
  let input_data = $in
  let t = (42 | torch tensor)
  let result = ($t | torch repeat 5 | torch shape)
  # Scalar [] with sizes [5] auto-expands to [1] then repeats to [5]
  assert ($result == [5])
}

@test
def "Test repeat preserves values" [] {
  let input_data = $in
  let t = ([1 2] | torch tensor)
  let result = ($t | torch repeat 3 | torch value)
  # [1, 2] repeated 3 times becomes [1, 2, 1, 2, 1, 2]
  assert ($result == [1 2 1 2 1 2])
}

@test
def "Error case with invalid tensor ID" [] {
  let input_data = $in
  try {
    "invalid-uuid" | torch repeat 2
    error make {msg: "Expected error from invalid tensor ID"}
  } catch {
    # expected
  }
}

@test
def "Error case with no sizes" [] {
  let input_data = $in
  try {
    let t = ([1 2 3] | torch tensor)
    $t | torch repeat
    error make {msg: "Expected error from empty sizes"}
  } catch {
    # expected - at least one size must be provided
  }
}

@test
def "Error case with negative size" [] {
  let input_data = $in
  try {
    let t = ([1 2 3] | torch tensor)
    $t | torch repeat -1
    error make {msg: "Expected error from negative size"}
  } catch {
    # expected - sizes must be at least 1
  }
}

@test
def "Error case with zero size" [] {
  let input_data = $in
  try {
    let t = ([1 2 3] | torch tensor)
    $t | torch repeat 0
    error make {msg: "Expected error from zero size"}
  } catch {
    # expected - sizes must be at least 1
  }
}
