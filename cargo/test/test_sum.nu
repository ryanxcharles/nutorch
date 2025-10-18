use std assert
use std/testing *

@test
def "Test sum with pipeline input" [] {
  let input_data = $in
  let t = ([1 2 3 4 5] | torch tensor)
  let result = ($t | torch sum | torch value)
  # Sum of [1,2,3,4,5] = 15
  assert ($result == 15)
}

@test
def "Test sum with argument input" [] {
  let input_data = $in
  let t = ([1 2 3 4 5] | torch tensor)
  let result = (torch sum $t | torch value)
  # Sum of [1,2,3,4,5] = 15
  assert ($result == 15)
}

@test
def "Test sum with 2D tensor all elements" [] {
  let input_data = $in
  let t = ([[1 2 3] [4 5 6]] | torch tensor)
  let result = ($t | torch sum | torch value)
  # Sum of all elements = 1+2+3+4+5+6 = 21
  assert ($result == 21)
}

@test
def "Test sum with 2D tensor along dim 0" [] {
  let input_data = $in
  let t = ([[1 2 3] [4 5 6]] | torch tensor)
  let result = ($t | torch sum --dim 0 | torch value)
  # Sum along rows: [1+4, 2+5, 3+6] = [5, 7, 9]
  assert ($result == [5 7 9])
}

@test
def "Test sum with 2D tensor along dim 1" [] {
  let input_data = $in
  let t = ([[1 2 3] [4 5 6]] | torch tensor)
  let result = ($t | torch sum --dim 1 | torch value)
  # Sum along columns: [1+2+3, 4+5+6] = [6, 15]
  assert ($result == [6 15])
}

@test
def "Test sum with keepdim true" [] {
  let input_data = $in
  let t = ([[1 2 3] [4 5 6]] | torch tensor)
  let result = ($t | torch sum --dim 1 --keepdim true | torch value)
  # Sum with keepdim should preserve dimensions as [[6], [15]]
  assert ($result == [[6] [15]])
}

@test
def "Test sum with keepdim false" [] {
  let input_data = $in
  let t = ([[1 2 3] [4 5 6]] | torch tensor)
  let result = ($t | torch sum --dim 1 --keepdim false | torch value)
  # Sum with keepdim false reduces dimensions to [6, 15]
  assert ($result == [6 15])
}

@test
def "Test sum with floats" [] {
  let input_data = $in
  let t = ([1.5 2.5 3.5 4.5] | torch tensor)
  let result = (torch sum $t | torch value)
  # Sum = 1.5+2.5+3.5+4.5 = 12.0
  assert ($result == 12.0)
}

@test
def "Test sum with negative numbers" [] {
  let input_data = $in
  let t = ([-2 -1 0 1 2] | torch tensor)
  let result = ($t | torch sum | torch value)
  # Sum of [-2,-1,0,1,2] = 0
  assert ($result == 0)
}

@test
def "Test sum with all zeros" [] {
  let input_data = $in
  let t = ([0 0 0 0] | torch tensor)
  let result = (torch sum $t | torch value)
  assert ($result == 0)
}

@test
def "Test sum with 3D tensor" [] {
  let input_data = $in
  let t = ([[[1 2] [3 4]] [[5 6] [7 8]]] | torch tensor)
  let result = ($t | torch sum | torch value)
  # Sum of all elements = 1+2+3+4+5+6+7+8 = 36
  assert ($result == 36)
}

@test
def "Test sum with 3D tensor along dim 0" [] {
  let input_data = $in
  let t = ([[[1 2] [3 4]] [[5 6] [7 8]]] | torch tensor)
  let result = ($t | torch sum --dim 0 | torch value)
  # Sum along first dimension
  assert ($result == [[6 8] [10 12]])
}

@test
def "Test sum with single element" [] {
  let input_data = $in
  let t = ([42] | torch tensor)
  let result = ($t | torch sum | torch value)
  # Sum of a single element returns a scalar, not a list
  assert ($result == 42)
}

@test
def "Test sum with large numbers" [] {
  let input_data = $in
  let t = ([100 200 300 400 500] | torch tensor)
  let result = ($t | torch sum | torch value)
  # Sum = 1500
  assert ($result == 1500)
}

@test
def "Error case with invalid tensor ID" [] {
  let input_data = $in
  try {
    torch sum "invalid-uuid"
    error make {msg: "Expected error from invalid tensor ID"}
  } catch {
    # expected
  }
}

@test
def "Error case with no tensor provided" [] {
  let input_data = $in
  try {
    torch sum
    error make {msg: "Expected error from no tensor"}
  } catch {
    # expected
  }
}

@test
def "Error case with both pipeline and argument" [] {
  let input_data = $in
  try {
    let t1 = ([1 2 3] | torch tensor)
    let t2 = ([4 5 6] | torch tensor)
    $t1 | torch sum $t2
    error make {msg: "Expected error from conflicting input"}
  } catch {
    # expected
  }
}

@test
def "Error case with invalid dimension" [] {
  let input_data = $in
  try {
    let t = ([1 2 3] | torch tensor)
    $t | torch sum --dim 5
    error make {msg: "Expected error from invalid dimension"}
  } catch {
    # expected
  }
}

@test
def "Error case with negative dimension" [] {
  let input_data = $in
  try {
    let t = ([1 2 3] | torch tensor)
    $t | torch sum --dim -1
    error make {msg: "Expected error from negative dimension"}
  } catch {
    # expected
  }
}
