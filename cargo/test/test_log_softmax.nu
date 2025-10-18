use std assert
use std/testing *

@test
def "Test log_softmax 1D - pipeline form" [] {
  let input_data = $in
  let t = ([1 2 3] | torch tensor)
  let result = ($t | torch log_softmax --dim 0 | torch value | get 0 | math round)
  # log_softmax first element should be approximately -2
  assert ($result == -2)
}

@test
def "Test log_softmax 1D - argument form" [] {
  let input_data = $in
  let t = ([1 2 3] | torch tensor)
  let result = (torch log_softmax $t --dim 0 | torch value | get 0 | math round)
  # log_softmax first element should be approximately -2
  assert ($result == -2)
}

@test
def "Test log_softmax 2D dim 0" [] {
  let input_data = $in
  let t = ([[1 2] [3 4]] | torch tensor)
  let result = ($t | torch log_softmax --dim 0 | torch value)
  # Result should be negative (logs of probabilities)
  assert ($result.0.0 < 0)
  assert ($result.0.1 < 0)
}

@test
def "Test log_softmax 2D dim 1" [] {
  let input_data = $in
  let t = ([[1 2] [3 4]] | torch tensor)
  let result = ($t | torch log_softmax --dim 1 | torch value)
  # Result should be negative (logs of probabilities)
  assert ($result.0.0 < 0)
  assert ($result.1.0 < 0)
}

@test
def "Test log_softmax default dim - last dimension" [] {
  let input_data = $in
  let t = ([[1 2 3] [4 5 6]] | torch tensor)
  let result = ($t | torch log_softmax | torch value)
  # Default should be last dim (dim 1 for 2D)
  # All values should be negative
  assert ($result.0.0 < 0)
  assert ($result.1.0 < 0)
}

@test
def "Test log_softmax preserves shape" [] {
  let input_data = $in
  let t = ([[1 2] [3 4]] | torch tensor)
  let result = ($t | torch log_softmax --dim 1 | torch shape)
  # Shape should be preserved
  assert ($result == [2 2])
}

@test
def "Test log_softmax 3D tensor" [] {
  let input_data = $in
  let t = torch full [2 3 4] 1
  let result = ($t | torch log_softmax --dim 2 | torch shape)
  # Shape preserved
  assert ($result == [2 3 4])
}

@test
def "Test log_softmax with dtype" [] {
  let input_data = $in
  let t = ([1 2 3] | torch tensor)
  let result = ($t | torch log_softmax --dim 0 --dtype float64 | torch value)
  # All values should be negative
  assert ($result.0 < 0)
  assert ($result.1 < 0)
  assert ($result.2 < 0)
}

@test
def "Test log_softmax uniform input" [] {
  let input_data = $in
  let t = ([1 1 1] | torch tensor)
  let result = ($t | torch log_softmax --dim 0 | torch value)
  # Uniform input: log(1/3) ≈ -1.099
  assert ((($result.0 - (-1.099)) | math abs) < 0.01)
  assert ((($result.1 - (-1.099)) | math abs) < 0.01)
  assert ((($result.2 - (-1.099)) | math abs) < 0.01)
}

@test
def "Test log_softmax relation to softmax" [] {
  let input_data = $in
  let t = ([1 2 3] | torch tensor)
  let log_sm = ($t | torch log_softmax --dim 0 | torch value)
  let sm = ($t | torch softmax --dim 0 | torch value)
  # log_softmax(x) ≈ log(softmax(x))
  # Check first element: log(sm[0]) ≈ log_sm[0]
  let log_of_sm = ($sm.0 | math ln)
  assert ((($log_sm.0 - $log_of_sm) | math abs) < 0.001)
}

@test
def "Error case - invalid tensor ID" [] {
  let input_data = $in
  try {
    "invalid-uuid" | torch log_softmax
    error make {msg: "Expected error from invalid tensor ID"}
  } catch {
    # expected
  }
}

@test
def "Error case - invalid dimension" [] {
  let input_data = $in
  let t = ([[1 2] [3 4]] | torch tensor)
  try {
    $t | torch log_softmax --dim 5
    error make {msg: "Expected error from invalid dimension"}
  } catch {
    # expected - dim 5 out of bounds for 2D tensor
  }
}

@test
def "Error case - negative dimension" [] {
  let input_data = $in
  let t = ([[1 2] [3 4]] | torch tensor)
  try {
    $t | torch log_softmax --dim (-1)
    error make {msg: "Expected error from negative dimension"}
  } catch {
    # expected
  }
}
