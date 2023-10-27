# This is just an example to get you started. You may wish to put all of your
# tests into a single file, or separate them into multiple `test1`, `test2`
# etc. files (better names are recommended, just make sure the name starts with
# the letter 't').
#
# To run these tests, simply execute `nimble test`.

import unittest

import pkg/nint128

import nulid

test "ULID Generation":
  for _ in 0..5:
    let ulid = ulid()
    echo ulid

test "ULID Parsing":
  let ulidStr = "01H999MBGTEA8BDS0M5AWEBB1A"
  let ulid = ULID(timestamp: 1693602950682,
    randomness: u128("541019288874337045949482"))

  check ULID.parse(ulidStr) == ulid

test "ULID Int128 Conversion":
  let ulid = ULID.parse("01H999MBGTEA8BDS0M5AWEBB1A")

  check ULID.fromInt128(ulid.toInt128()) == ulid

test "ULID Binary Format":
  let
    ulid = ULID.parse("01H999MBGTEA8BDS0M5AWEBB1A")
    ulidBytes = [1.byte, 138, 82, 154, 46, 26, 114, 144, 182, 228, 20, 42, 184, 229, 172, 42]

  check ulid == ULID.fromBytes(ulidBytes)
  check ulid.toBytes == ulidBytes
