use std assert
use std/testing *

@test
def "Test max with pipeline input" [] {
  let input_data = $in
  let t = torch tensor [1 5 3 2 4]
  let result = ($t | torch max | torch value)
  # Max of [1,5,3,2,4] = 5
  assert ($result == 5)
}

@test
def "Test max with argument input" [] {
  let input_data = $in
  let t = torch tensor [1 5 3 2 4]
  let result = (torch max $t | torch value)
  # Max of [1,5,3,2,4] = 5
  assert ($result == 5)
}

@test
def "Test max with 2D tensor all elements" [] {
  let input_data = $in
  let t = torch tensor [[1 2 3] [4 5 6]]
  let result = ($t | torch max | torch value)
  # Max of all elements = 6
  assert ($result == 6)
}

@test
def "Test max with 2D tensor along dim 0" [] {
  let input_data = $in
  let t = torch tensor [[1 5 3] [4 2 6]]
  let result = ($t | torch max --dim 0 | torch value)
  # Max along rows: [max(1,4), max(5,2), max(3,6)] = [4, 5, 6]
  assert ($result == [4 5 6])
}

@test
def "Test max with 2D tensor along dim 1" [] {
  let input_data = $in
  let t = torch tensor [[1 5 3] [4 2 6]]
  let result = ($t | torch max --dim 1 | torch value)
  # Max along columns: [max(1,5,3), max(4,2,6)] = [5, 6]
  assert ($result == [5 6])
}

@test
def "Test max with keepdim true" [] {
  let input_data = $in
  let t = torch tensor [[1 5 3] [4 2 6]]
  let result = ($t | torch max --dim 1 --keepdim true | torch value)
  # Max with keepdim should preserve dimensions as [[5], [6]]
  assert ($result == [[5] [6]])
}

@test
def "Test max with keepdim false" [] {
  let input_data = $in
  let t = torch tensor [[1 5 3] [4 2 6]]
  let result = ($t | torch max --dim 1 --keepdim false | torch value)
  # Max with keepdim false reduces dimensions to [5, 6]
  assert ($result == [5 6])
}

@test
def "Test max with negative numbers" [] {
  let input_data = $in
  let t = torch tensor [-5 -2 -8 -1 -10]
  let result = (torch max $t | torch value)
  # Max of negative numbers = -1
  assert ($result == -1)
}

@test
def "Test max with mixed positive and negative" [] {
  let input_data = $in
  let t = torch tensor [-5 3 -2 8 -1]
  let result = ($t | torch max | torch value)
  # Max = 8
  assert ($result == 8)
}

@test
def "Test max with all zeros" [] {
  let input_data = $in
  let t = torch tensor [0 0 0 0]
  let result = (torch max $t | torch value)
  assert ($result == 0)
}

@test
def "Test max with floats" [] {
  let input_data = $in
  let t = torch tensor [1.5 3.75 2.25 3.5]
  let result = ($t | torch max | torch value)
  # Max = 3.75
  assert ($result == 3.75)
}

@test
def "Test max with 3D tensor" [] {
  let input_data = $in
  let t = torch tensor [[[1 2] [3 4]] [[5 6] [7 8]]]
  let result = ($t | torch max | torch value)
  # Max of all elements = 8
  assert ($result == 8)
}

@test
def "Test max with 3D tensor along dim 0" [] {
  let input_data = $in
  let t = torch tensor [[[1 2] [3 4]] [[5 6] [7 8]]]
  let result = ($t | torch max --dim 0 | torch value)
  # Max along first dimension
  assert ($result == [[5 6] [7 8]])
}

@test
def "Error case with invalid tensor ID" [] {
  let input_data = $in
  try {
    torch max "invalid-uuid"
    error make {msg: "Expected error from invalid tensor ID"}
  } catch {
    # expected
  }
}

@test
def "Error case with no tensor provided" [] {
  let input_data = $in
  try {
    torch max
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
    $t1 | torch max $t2
    error make {msg: "Expected error from conflicting input"}
  } catch {
    # expected
  }
}

@test
def "Error case with invalid dimension" [] {
  let input_data = $in
  try {
    let t = torch tensor [1 2 3]
    $t | torch max --dim 5
    error make {msg: "Expected error from invalid dimension"}
  } catch {
    # expected
  }
}

@test
def "Error case with negative dimension" [] {
  let input_data = $in
  try {
    let t = torch tensor [1 2 3]
    $t | torch max --dim -1
    error make {msg: "Expected error from negative dimension"}
  } catch {
    # expected
  }
}
