use std assert
use std/testing *

@test
def "Test detach with pipeline input" [] {
  let input_data = $in
  let t = torch tensor [1 2 3] --requires_grad true
  let detached = ($t | torch detach)
  # Values should be the same
  assert (($t | torch value) == ($detached | torch value))
  # IDs should be different
  assert ($t != $detached)
}

@test
def "Test detach with argument input" [] {
  let input_data = $in
  let t = torch tensor [1 2 3] --requires_grad true
  let detached = (torch detach $t)
  # Values should be the same
  assert (($t | torch value) == ($detached | torch value))
  # IDs should be different
  assert ($t != $detached)
}

@test
def "Test detach with 2D tensor" [] {
  let input_data = $in
  let t = torch tensor [[1 2] [3 4]] --requires_grad true
  let detached = ($t | torch detach | torch value)
  assert ($detached == [[1 2] [3 4]])
}

@test
def "Test detach preserves values" [] {
  let input_data = $in
  let t = torch tensor [1.5 2.5 3.5] --requires_grad true
  let detached = (torch detach $t | torch value)
  assert ($detached == [1.5 2.5 3.5])
}

@test
def "Test detach without requires_grad" [] {
  let input_data = $in
  # Detaching a tensor that doesn't track gradients should still work
  let t = torch tensor [5 10 15]
  let detached = ($t | torch detach | torch value)
  assert ($detached == [5 10 15])
}

@test
def "Test detach with negative values" [] {
  let input_data = $in
  let t = torch tensor [-5 -3 -1] --requires_grad true
  let detached = (torch detach $t | torch value)
  assert ($detached == [-5 -3 -1])
}

@test
def "Test detach with zeros" [] {
  let input_data = $in
  let t = torch tensor [0 0 0] --requires_grad true
  let detached = ($t | torch detach | torch value)
  assert ($detached == [0 0 0])
}

@test
def "Test detach with 3D tensor" [] {
  let input_data = $in
  let t = torch tensor [[[1 2] [3 4]] [[5 6] [7 8]]] --requires_grad true
  let detached = ($t | torch detach | torch value)
  assert ($detached == [[[1 2] [3 4]] [[5 6] [7 8]]])
}

@test
def "Test detach chaining" [] {
  let input_data = $in
  let t = torch tensor [1 2 3] --requires_grad true
  # Detaching twice should work
  let result = ($t | torch detach | torch detach | torch value)
  assert ($result == [1 2 3])
}

@test
def "Test detach after operations" [] {
  let input_data = $in
  let t1 = torch tensor [1 2 3] --requires_grad true
  let t2 = torch tensor [4 5 6]
  let result = ($t1 | torch add $t2 | torch detach | torch value)
  assert ($result == [5 7 9])
}

@test
def "Error case with invalid tensor ID" [] {
  let input_data = $in
  try {
    torch detach "invalid-uuid"
    error make {msg: "Expected error from invalid tensor ID"}
  } catch {
    # expected
  }
}

@test
def "Error case with no tensor provided" [] {
  let input_data = $in
  try {
    torch detach
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
    $t1 | torch detach $t2
    error make {msg: "Expected error from conflicting input"}
  } catch {
    # expected
  }
}
