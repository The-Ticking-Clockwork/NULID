# This is just an example to get you started. You may wish to put all of your
# tests into a single file, or separate them into multiple `test1`, `test2`
# etc. files (better names are recommended, just make sure the name starts with
# the letter 't').
#
# To run these tests, simply execute `nimble test`.
import std/[
  unittest,
  json
]

const UlidRandStr = "541019288874337045949482"

when not defined(js):
  import nint128

  const UlidRand = u128(UlidRandStr)
else:
  import std/jsbigints

  let UlidRand = big(UlidRandStr)

import nulid

test "ULID Generation":
  for _ in 0..5:
    let ulid = ulid()
    echo ulid

test "ULID Parsing":
  let ulidStr = "01H999MBGTEA8BDS0M5AWEBB1A"
  let ulid = ULID(timestamp: 1693602950682,
    randomness: UlidRand)

  check ULID.parse(ulidStr) == ulid

test "ULID Int128 Conversion":
  let ulid = ULID.parse("01H999MBGTEA8BDS0M5AWEBB1A")

  check ULID.fromInt128(ulid.toInt128()) == ulid

when not defined(js):
  # Not planned to be implemented yet for the JS backend

  test "ULID Binary Format":
    let
      ulid = ULID.parse("01H999MBGTEA8BDS0M5AWEBB1A")
      ulidBytes = [1.byte, 138, 82, 154, 46, 26, 114, 144, 182, 228, 20, 42, 184, 229, 172, 42]

    check ulid == ULID.fromBytes(ulidBytes)
    check ulid.toBytes == ulidBytes

test "ULID std/json support":
  let ulid = ULID.parse("01H999MBGTEA8BDS0M5AWEBB1A")

  check (%ulid).getStr() == "01H999MBGTEA8BDS0M5AWEBB1A"
  check (%ulid).to(ULID) == ulid