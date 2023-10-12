# This is just an example to get you started. You may wish to put all of your
# tests into a single file, or separate them into multiple `test1`, `test2`
# etc. files (better names are recommended, just make sure the name starts with
# the letter 't').
#
# To run these tests, simply execute `nimble test`.

import unittest

import pkg/nint128

import nulid

test "NULID Generation":
  for _ in 0..5:
    let nulid = nulidSync()
    echo nulid

test "NULID Parsing":
  let nulidStr = "01H999MBGTEA8BDS0M5AWEBB1A"
  let nulid = NULID(timestamp: 1693602950682,
    randomness: u128("541019288874337045949482"))

  check parseNulid(nulidStr) == nulid

test "NULID Int128 Conversion":
  let nulid = parseNulid("01H999MBGTEA8BDS0M5AWEBB1A")

  check NULID.fromInt128(nulid.toInt128()) == nulid

test "NULID Binary Format":
  let
    nulid = parseNulid("01H999MBGTEA8BDS0M5AWEBB1A")
    nulidBytes = [1.byte, 138, 82, 154, 46, 26, 114, 144, 182, 228, 20, 42, 184, 229, 172, 42]

  check nulid == NULID.fromBytes(nulidBytes)
  check nulid.toBytes == nulidBytes
