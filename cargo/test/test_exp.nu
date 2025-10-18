use std assert
use std/testing *

@test
def "Test exp with pipeline input" [] {
  let input_data = $in
  let t = torch tensor [0 1 2]
  let result = ($t | torch exp | torch value)
  # e^0 = 1, e^1 ≈ 2.718, e^2 ≈ 7.389
  assert (($result | get 0) > 0.99 and ($result | get 0) < 1.01)
  assert (($result | get 1) > 2.71 and ($result | get 1) < 2.72)
  assert (($result | get 2) > 7.38 and ($result | get 2) < 7.40)
}

@test
def "Test exp with argument input" [] {
  let input_data = $in
  let t = torch tensor [0 1 2]
  let result = (torch exp $t | torch value)
  # e^0 = 1, e^1 ≈ 2.718, e^2 ≈ 7.389
  assert (($result | get 0) > 0.99 and ($result | get 0) < 1.01)
  assert (($result | get 1) > 2.71 and ($result | get 1) < 2.72)
  assert (($result | get 2) > 7.38 and ($result | get 2) < 7.40)
}

@test
def "Test exp with 2D tensor" [] {
  let input_data = $in
  let t = torch tensor [[0 1] [2 3]]
  let result = ($t | torch exp | torch value)
  # Verify shape is preserved
  assert (($result | length) == 2)
  assert (($result | get 0 | length) == 2)
  # e^3 ≈ 20.085
  assert (($result | get 1 | get 1) > 20.0 and ($result | get 1 | get 1) < 20.1)
}

@test
def "Test exp with negative values" [] {
  let input_data = $in
  let t = torch tensor [-2 -1 0]
  let result = ($t | torch exp | torch value)
  # e^-2 ≈ 0.135, e^-1 ≈ 0.368, e^0 = 1
  assert (($result | get 0) > 0.13 and ($result | get 0) < 0.14)
  assert (($result | get 1) > 0.36 and ($result | get 1) < 0.37)
  assert (($result | get 2) > 0.99 and ($result | get 2) < 1.01)
}

@test
def "Test exp with zero" [] {
  let input_data = $in
  let t = torch tensor [0 0 0]
  let result = (torch exp $t | torch value)
  # e^0 = 1
  assert (($result | get 0) == 1)
  assert (($result | get 1) == 1)
  assert (($result | get 2) == 1)
}

@test
def "Test exp with small values" [] {
  let input_data = $in
  let t = torch tensor [0.1 0.5 1.0]
  let result = ($t | torch exp | torch value)
  # e^0.1 ≈ 1.105, e^0.5 ≈ 1.649, e^1 ≈ 2.718
  assert (($result | get 0) > 1.10 and ($result | get 0) < 1.11)
  assert (($result | get 1) > 1.64 and ($result | get 1) < 1.65)
  assert (($result | get 2) > 2.71 and ($result | get 2) < 2.72)
}

@test
def "Test exp with large negative values" [] {
  let input_data = $in
  let t = torch tensor [-5 -10 -20]
  let result = ($t | torch exp | torch value)
  # For large negative x, e^x approaches 0
  assert (($result | get 0) < 0.01)
  assert (($result | get 1) < 0.0001)
  assert (($result | get 2) < 0.000001)
}

@test
def "Test exp chaining" [] {
  let input_data = $in
  let t = torch tensor [0 0.5 1.0]
  let result = ($t | torch exp | torch exp | torch value)
  # exp(exp(x)) should be valid
  assert (($result | length) == 3)
  # exp(exp(0)) = exp(1) ≈ 2.718
  assert (($result | get 0) > 2.71 and ($result | get 0) < 2.72)
}

@test
def "Test exp with mixed signs" [] {
  let input_data = $in
  let t = torch tensor [-1 0 1]
  let result = (torch exp $t | torch value)
  assert (($result | get 0) > 0.36 and ($result | get 0) < 0.37)
  assert (($result | get 1) > 0.99 and ($result | get 1) < 1.01)
  assert (($result | get 2) > 2.71 and ($result | get 2) < 2.72)
}

@test
def "Error case with invalid tensor ID" [] {
  let input_data = $in
  try {
    torch exp "invalid-uuid"
    error make {msg: "Expected error from invalid tensor ID"}
  } catch {
    # expected
  }
}

@test
def "Error case with no tensor provided" [] {
  let input_data = $in
  try {
    torch exp
    error make {msg: "Expected error from no tensor"}
  } catch {
    # expected
  }
}

@test
def "Error case with both pipeline and argument" [] {
  let input_data = $in
  try {
    let t1 = torch tensor [1 2 3]
    let t2 = torch tensor [4 5 6]
    $t1 | torch exp $t2
    error make {msg: "Expected error from conflicting input"}
  } catch {
    # expected
  }
}
