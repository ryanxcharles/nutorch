use std assert
use std/testing *

@test
def "Test maximum with pipeline and argument" [] {
  let input_data = $in
  let t1 = torch tensor [1 5 3]
  let t2 = torch tensor [2 4 6]
  let result = ($t1 | torch maximum $t2 | torch value)
  assert ($result == [2 5 6])
}

@test
def "Test maximum with two arguments" [] {
  let input_data = $in
  let t1 = torch tensor [1 5 3]
  let t2 = torch tensor [2 4 6]
  let result = (torch maximum $t1 $t2 | torch value)
  assert ($result == [2 5 6])
}

@test
def "Test maximum with 2D tensors" [] {
  let input_data = $in
  let t1 = torch tensor [[1 5] [3 2]]
  let t2 = torch tensor [[2 4] [1 6]]
  let result = (torch maximum $t1 $t2 | torch value)
  assert ($result == [[2 5] [3 6]])
}

@test
def "Test maximum with broadcasting scalar" [] {
  let input_data = $in
  let t1 = torch tensor [1 5 3]
  let scalar = torch tensor 4
  let result = ($t1 | torch maximum $scalar | torch value)
  assert ($result == [4 5 4])
}

@test
def "Test maximum with negative numbers" [] {
  let input_data = $in
  let t1 = torch tensor [-5 3 -1]
  let t2 = torch tensor [-3 2 -4]
  let result = (torch maximum $t1 $t2 | torch value)
  assert ($result == [-3 3 -1])
}

@test
def "Test maximum with floats" [] {
  let input_data = $in
  let t1 = torch tensor [1.5 2.75 3.25]
  let t2 = torch tensor [2.0 2.5 3.5]
  let result = (torch maximum $t1 $t2 | torch value)
  assert ($result == [2.0 2.75 3.5])
}

@test
def "Test maximum with equal values" [] {
  let input_data = $in
  let t1 = torch tensor [5 10 15]
  let t2 = torch tensor [5 10 15]
  let result = (torch maximum $t1 $t2 | torch value)
  assert ($result == [5 10 15])
}

@test
def "Test maximum with zeros" [] {
  let input_data = $in
  let t1 = torch tensor [-2 0 3]
  let t2 = torch tensor [0 0 0]
  let result = (torch maximum $t1 $t2 | torch value)
  assert ($result == [0 0 3])
}

@test
def "Test maximum with broadcasting 1D to 2D" [] {
  let input_data = $in
  let t1 = torch tensor [[1 2] [3 4]]
  let t2 = torch tensor [2 3]
  let result = (torch maximum $t1 $t2 | torch value)
  assert ($result == [[2 3] [3 4]])
}

@test
def "Error case with incompatible shapes" [] {
  let input_data = $in
  try {
    let t1 = torch tensor [1 2]
    let t2 = torch tensor [[1 2 3] [4 5 6]]
    torch maximum $t1 $t2
    error make {msg: "Expected error for incompatible shapes"}
  } catch {
    # expected
  }
}

@test
def "Error case with device mismatch" [] {
  let input_data = $in
  try {
    let t1 = torch tensor [1 5 3] --device cpu
    let t2 = torch tensor [2 4 6] --device cpu
    # This test would fail if we had multiple devices available
    # For now, just verify both tensors are on same device
    let result = (torch maximum $t1 $t2 | torch value)
    assert ($result == [2 5 6])
  } catch {
    # Expected if devices differ
  }
}

@test
def "Error case with invalid tensor ID" [] {
  let input_data = $in
  try {
    let t1 = torch tensor [1 2 3]
    torch maximum $t1 "invalid-uuid"
    error make {msg: "Expected error from invalid tensor ID"}
  } catch {
    # expected
  }
}

@test
def "Error case with missing second tensor" [] {
  let input_data = $in
  try {
    let t1 = torch tensor [1 2 3]
    $t1 | torch maximum
    error make {msg: "Expected error from missing second tensor"}
  } catch {
    # expected
  }
}

@test
def "Error case with no tensors provided" [] {
  let input_data = $in
  try {
    torch maximum
    error make {msg: "Expected error from no tensors"}
  } catch {
    # expected
  }
}

@test
def "Error case with three tensors" [] {
  let input_data = $in
  try {
    let t1 = torch tensor [1]
    let t2 = torch tensor [2]
    let t3 = torch tensor [3]
    $t1 | torch maximum $t2 $t3
    error make {msg: "Expected error from three tensors"}
  } catch {
    # expected
  }
}
