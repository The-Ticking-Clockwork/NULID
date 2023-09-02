import std/[
  asyncdispatch,
  sysrand,
  times
]

import pkg/[
  crockfordb32,
  nint128
]

const HighUint80 = u128("1208925819614629174706176")

type
  NULID* = object
    timestamp*: int64 = 0
    randomness*: UInt128 = 0.u128

  NULIDGenerator* = ref object
    lastTime: int64 = 0
    random: UInt128 = u128(0)

proc randomBits(): UInt128 =
  let rnd = urandom(10)

  result = UInt128.fromBytesBE(
    [0.byte, 0, 0, 0, 0, 0, rnd[0], rnd[1], rnd[2], rnd[3],
    rnd[4], rnd[5], rnd[6], rnd[7], rnd[8], rnd[9]]
  )

template getTime: int64 = (epochTime() * 1000).int64

proc wait(gen: NULIDGenerator): Future[int64] {.async.} =
  result = getTime()

  while result <= gen.lastTime:
    await sleepAsync(1)
    result = getTime()

proc nulid*(gen: NULIDGenerator): Future[NULID] {.async.} =
  var now = getTime()

  if now < gen.lastTime:
    raise newException(OSError, "Time went backwards!")

  if gen.lastTime == now:
    inc gen.random

    if gen.random == HighUInt80:
      now = await gen.wait()

  else:
    gen.random = randomBits()

  result.timestamp = now
  result.randomness = gen.random

proc nulidSync*(gen: NULIDGenerator): NULID = waitFor gen.nulid()

proc parseNulid*(ulidStr: string): NULID =
  result.timestamp = int64.decode(ulidStr[0..9])
  result.randomness = UInt128.decode(ulidStr[10..25])

proc `$`*(ulid: NULID): string =
  var res = i128(ulid.timestamp)

  res = res shl 80
  res.hi += cast[int64](ulid.randomness.hi)
  res.lo += ulid.randomness.lo

  result = '0' & Int128.encode(res, 26)

proc `==`*(a: NULID, b: string): bool = a == parseNulid(b)
