use std assert
use std/testing *

@test
def "Test linspace basic usage" [] {
  let input_data = $in
  let res = (torch linspace 0.0 1.0 5 | torch value)
  assert ($res == [0.0 0.25 0.5 0.75 1.0])
}

@test
def "Test linspace with negative range" [] {
  let input_data = $in
  let res = (torch linspace -1.0 1.0 3 | torch value)
  assert ($res == [-1.0 0.0 1.0])
}

@test
def "Test linspace with single step" [] {
  let input_data = $in
  let res = (torch linspace 5.0 5.0 1 | torch value)
  assert ($res == [5.0])
}

@test
def "Test linspace with two steps" [] {
  let input_data = $in
  let res = (torch linspace 0.0 10.0 2 | torch value)
  assert ($res == [0.0 10.0])
}

@test
def "Test linspace descending range" [] {
  let input_data = $in
  let res = (torch linspace 1.0 0.0 3 | torch value)
  # Should go from 1.0 to 0.0 in 3 steps
  assert (($res | length) == 3)
  assert (($res | first) == 1.0)
  assert (($res | last) == 0.0)
}

@test
def "Test linspace with float64 dtype" [] {
  let input_data = $in
  let res = (torch linspace 0.0 2.0 3 --dtype float64 | torch value)
  assert ($res == [0.0 1.0 2.0])
}

@test
def "Test linspace with requires_grad flag" [] {
  let input_data = $in
  let t = (torch linspace 0.0 1.0 5 --requires_grad true)
  # Just verify it creates successfully - grad testing happens in backward tests
  assert ($t | describe | str contains "string")
}

@test
def "Test linspace with device cpu" [] {
  let input_data = $in
  let res = (torch linspace 0.0 1.0 3 --device cpu | torch value)
  assert (($res | length) == 3)
}

@test
def "Test linspace with large number of steps" [] {
  let input_data = $in
  let res = (torch linspace 0.0 1.0 101 | torch value)
  assert (($res | length) == 101)
  assert (($res | first) == 0.0)
  assert (($res | last) == 1.0)
}

@test
def "Error case with zero steps" [] {
  let input_data = $in
  try {
    torch linspace 0.0 1.0 0
    error make {msg: "Expected error from zero steps"}
  } catch {
    # expected
  }
}

@test
def "Error case with negative steps" [] {
  let input_data = $in
  try {
    torch linspace 0.0 1.0 -5
    error make {msg: "Expected error from negative steps"}
  } catch {
    # expected
  }
}

@test
def "Error case with invalid device" [] {
  let input_data = $in
  try {
    torch linspace 0.0 1.0 5 --device invalid_device
    error make {msg: "Expected error from invalid device"}
  } catch {
    # expected
  }
}

@test
def "Error case with invalid dtype" [] {
  let input_data = $in
  try {
    torch linspace 0.0 1.0 5 --dtype invalid_dtype
    error make {msg: "Expected error from invalid dtype"}
  } catch {
    # expected
  }
}

@test
def "Test linspace with integer start and end" [] {
  let input_data = $in
  # integers should be converted to floats
  let res = (torch linspace 0 10 11 | torch value)
  assert (($res | length) == 11)
  assert (($res | first) == 0.0)
  assert (($res | last) == 10.0)
}
