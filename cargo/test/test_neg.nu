use std assert
use std/testing *

@test
def "Test neg with pipeline input" [] {
  let input_data = $in
  let t = torch tensor [1 2 3]
  let result = ($t | torch neg | torch value)
  assert ($result == [-1 -2 -3])
}

@test
def "Test neg with argument input" [] {
  let input_data = $in
  let t = torch tensor [1 2 3]
  let result = (torch neg $t | torch value)
  assert ($result == [-1 -2 -3])
}

@test
def "Test neg with 2D tensor" [] {
  let input_data = $in
  let t = torch tensor [[1 2] [3 4]]
  let result = ($t | torch neg | torch value)
  assert ($result == [[-1 -2] [-3 -4]])
}

@test
def "Test neg with negative numbers" [] {
  let input_data = $in
  let t = torch tensor [-5 -3 -1]
  let result = (torch neg $t | torch value)
  assert ($result == [5 3 1])
}

@test
def "Test neg with floats" [] {
  let input_data = $in
  let t = torch tensor [1.5 -2.5 3.0]
  let result = ($t | torch neg | torch value)
  assert ($result == [-1.5 2.5 -3.0])
}

@test
def "Test neg with zeros" [] {
  let input_data = $in
  let t = torch tensor [0 0 0]
  let result = (torch neg $t | torch value)
  assert ($result == [0 0 0])
}

@test
def "Test neg with mixed positive and negative" [] {
  let input_data = $in
  let t = torch tensor [1 -2 3 -4]
  let result = ($t | torch neg | torch value)
  assert ($result == [-1 2 -3 4])
}

@test
def "Test neg double negation" [] {
  let input_data = $in
  let t = torch tensor [5 10 15]
  let result = ($t | torch neg | torch neg | torch value)
  assert ($result == [5 10 15])
}

@test
def "Test neg with 3D tensor" [] {
  let input_data = $in
  let t = torch tensor [[[1 2] [3 4]] [[5 6] [7 8]]]
  let result = ($t | torch neg | torch value)
  assert ($result == [[[-1 -2] [-3 -4]] [[-5 -6] [-7 -8]]])
}

@test
def "Error case with invalid tensor ID" [] {
  let input_data = $in
  try {
    torch neg "invalid-uuid"
    error make {msg: "Expected error from invalid tensor ID"}
  } catch {
    # expected
  }
}

@test
def "Error case with no tensor provided" [] {
  let input_data = $in
  try {
    torch neg
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
    $t1 | torch neg $t2
    error make {msg: "Expected error from conflicting input"}
  } catch {
    # expected
  }
}
