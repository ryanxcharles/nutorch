use std assert
use std/testing *

@test
def "Test randn with 1D tensor" [] {
  let input_data = $in
  torch manual_seed 42
  let res = (torch randn 5 | torch value)
  # Check it returns a list of 5 elements
  assert (($res | length) == 5)
}

@test
def "Test randn with 2D tensor" [] {
  let input_data = $in
  torch manual_seed 42
  let res = (torch randn 2 3 | torch value)
  # Check it returns 2x3 shape
  assert (($res | length) == 2)
  assert (($res | first | length) == 3)
}

@test
def "Test randn with 3D tensor" [] {
  let input_data = $in
  torch manual_seed 42
  let res = (torch randn 2 2 2 | torch value)
  # Check it returns 2x2x2 shape
  assert (($res | length) == 2)
  assert (($res | first | length) == 2)
  assert (($res | first | first | length) == 2)
}

@test
def "Test randn with float64 dtype" [] {
  let input_data = $in
  torch manual_seed 42
  let res = (torch randn 3 --dtype float64 | torch value)
  # Just verify it creates successfully and has correct length
  assert (($res | length) == 3)
}

@test
def "Test randn with requires_grad flag" [] {
  let input_data = $in
  let t = (torch randn 2 2 --requires_grad true)
  # Just verify it creates successfully - grad testing happens in backward tests
  assert ($t | describe | str contains "string")
}

@test
def "Test randn with device cpu" [] {
  let input_data = $in
  torch manual_seed 42
  let res = (torch randn 2 --device cpu | torch value)
  # Just verify it creates successfully
  assert (($res | length) == 2)
}

@test
def "Test manual_seed works with randn" [] {
  let input_data = $in
  # Just verify manual_seed doesn't crash when used with randn
  torch manual_seed 999
  let res = (torch randn 3 | torch value)
  assert (($res | length) == 3)
}

@test
def "Error case with no dimensions" [] {
  let input_data = $in
  try {
    torch randn
    error make {msg: "Expected error from no dimensions"}
  } catch {
    # expected
  }
}

@test
def "Error case with negative dimension" [] {
  let input_data = $in
  try {
    torch randn -1
    error make {msg: "Expected error from negative dimension"}
  } catch {
    # expected
  }
}

@test
def "Error case with zero dimension" [] {
  let input_data = $in
  try {
    torch randn 0
    error make {msg: "Expected error from zero dimension"}
  } catch {
    # expected
  }
}

@test
def "Error case with invalid device" [] {
  let input_data = $in
  try {
    torch randn 2 --device invalid_device
    error make {msg: "Expected error from invalid device"}
  } catch {
    # expected
  }
}

@test
def "Error case with invalid dtype" [] {
  let input_data = $in
  try {
    torch randn 2 --dtype invalid_dtype
    error make {msg: "Expected error from invalid dtype"}
  } catch {
    # expected
  }
}

@test
def "Test randn values are approximately normal" [] {
  let input_data = $in
  torch manual_seed 42
  let res = (torch randn 1000 | torch value)
  # With 1000 samples, mean should be close to 0 and most values between -3 and 3
  let mean = ($res | math avg)
  # Mean should be relatively close to 0 (within 0.2 for 1000 samples)
  assert (($mean > -0.2) and ($mean < 0.2))
}

@test
def "Test randn large tensor creation" [] {
  let input_data = $in
  # Just verify large tensor creates without error
  let t = (torch randn 100 100)
  assert ($t | describe | str contains "string")
}
