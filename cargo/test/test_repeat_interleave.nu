use std assert
use std/testing *

@test
def "Test repeat interleave scalar - basic" [] {
  let input_data = $in
  let x = ([1 2 3] | torch tensor)
  let r1 = ($x | torch repeat_interleave 2 | torch value)
  # Each element repeated 2 times: [1, 2, 3] -> [1, 1, 2, 2, 3, 3]
  assert ($r1 == [1 1 2 2 3 3])
}

@test
def "Test repeat interleave tensor - per-element counts" [] {
  let input_data = $in
  let x = ([1 2 3] | torch tensor)
  let rep = ([1 2 3] | torch tensor --dtype int64)
  let r2 = ($x | torch repeat_interleave $rep | torch value)
  # Element-wise: 1 once, 2 twice, 3 three times
  let exp2 = [1 2 2 3 3 3]
  assert ($r2 == $exp2)
}

@test
def "Test repeat interleave with dim 0" [] {
  let input_data = $in
  let m = ([[1 2] [3 4]] | torch tensor)
  let r3 = ($m | torch repeat_interleave 2 --dim 0 | torch shape)
  # [2, 2] with dim 0 repeated 2 times becomes [4, 2]
  assert ($r3 == [4 2])
}

@test
def "Test repeat interleave with dim 1" [] {
  let input_data = $in
  let m = ([[1 2] [3 4]] | torch tensor)
  let result = ($m | torch repeat_interleave 3 --dim 1 | torch shape)
  # [2, 2] with dim 1 repeated 3 times becomes [2, 6]
  assert ($result == [2 6])
}

@test
def "Test repeat interleave identity - repeat by 1" [] {
  let input_data = $in
  let x = ([1 2 3 4] | torch tensor)
  let result = ($x | torch repeat_interleave 1 | torch value)
  # Repeating by 1 preserves values
  assert ($result == [1 2 3 4])
}

@test
def "Test repeat interleave values preserved" [] {
  let input_data = $in
  let m = ([[1 2] [3 4]] | torch tensor)
  let result = ($m | torch repeat_interleave 2 --dim 0 | torch value)
  # Each row repeated twice
  assert ($result == [[1 2] [1 2] [3 4] [3 4]])
}

@test
def "Test repeat interleave 3D tensor" [] {
  let input_data = $in
  let t = torch full [2 3 4] 1
  let result = ($t | torch repeat_interleave 2 --dim 1 | torch shape)
  # [2, 3, 4] with dim 1 repeated 2 times becomes [2, 6, 4]
  assert ($result == [2 6 4])
}

@test
def "Error case with invalid tensor ID" [] {
  let input_data = $in
  try {
    "invalid-uuid" | torch repeat_interleave 2
    error make {msg: "Expected error from invalid tensor ID"}
  } catch {
    # expected
  }
}

@test
def "Error case with zero repeat count" [] {
  let input_data = $in
  try {
    let x = ([1 2 3] | torch tensor)
    $x | torch repeat_interleave 0
    error make {msg: "Expected error from zero repeat count"}
  } catch {
    # expected - repeat count must be > 0
  }
}

@test
def "Error case with negative repeat count" [] {
  let input_data = $in
  try {
    let x = ([1 2 3] | torch tensor)
    $x | torch repeat_interleave (-1)
    error make {msg: "Expected error from negative repeat count"}
  } catch {
    # expected - repeat count must be > 0
  }
}

@test
def "Error case with invalid repeats tensor ID" [] {
  let input_data = $in
  try {
    let x = ([1 2 3] | torch tensor)
    $x | torch repeat_interleave "invalid-uuid"
    error make {msg: "Expected error from invalid repeats tensor ID"}
  } catch {
    # expected
  }
}
