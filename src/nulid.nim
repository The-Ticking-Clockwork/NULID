import std/[
  asyncdispatch,
  sysrand,
  times
]

import pkg/[
  crockfordb32,
  nint128
]

import pkg/nint128/vendor/stew/endians2

const HighUint80 = u128("1208925819614629174706176")

type
  NULID* = object
    timestamp*: int64 = 0
    randomness*: UInt128 = 0.u128

  NULIDGenerator* = ref object
    lastTime: int64 = 0
    random: UInt128 = u128(0)

func swapBytes(x: Int128): Int128 =
  result.lo = swapBytes(cast[uint64](x.hi))
  result.hi = cast[int64](swapBytes(x.lo))

proc toArray*[T](oa: openArray[T], size: static Slice[int]): array[size.len, T] =
  result[0..<size.len] = oa[size]

proc randomBits(): UInt128 =
  let rnd = urandom(10)

  result = UInt128.fromBytesBE(@[0.byte, 0, 0, 0, 0, 0] & rnd)

template getTime: int64 = (epochTime() * 1000).int64

proc wait(gen: NULIDGenerator): Future[int64] {.async.} =
  result = getTime()

  while result <= gen.lastTime:
    await sleepAsync(1)
    result = getTime()

proc nulid*(gen: NULIDGenerator, timestamp: int64 = 0): Future[NULID] {.async.} =
  if timestamp == 0:
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

  else:
    result.timestamp = timestamp
  result.randomness = gen.random

proc nulidSync*(gen: NULIDGenerator, timestamp: int64 = 0): NULID =
  result = waitFor gen.nulid(timestamp)

proc toInt128*(ulid: NULID): Int128 =
  result = i128(ulid.timestamp) shl 80

  result.hi += cast[int64](ulid.randomness.hi)
  result.lo += ulid.randomness.lo

proc fromInt128*(_: typedesc[NULID], val: Int128): NULID =
  result.timestamp = (val shr 16).hi
  result.randomness = UInt128(
    hi: cast[uint64]((val.hi shl 48) shr 48),
    lo: val.lo
  )

proc toBytes*(ulid: NULID): array[16, byte] =
  when cpuEndian == littleEndian:
    return cast[array[16, byte]](ulid.toInt128().swapBytes())

  else:
    return cast[array[16, byte]](ulid.toInt128())

proc fromBytes*(_: typedesc[NULID], ulidBytes: openArray[byte]): NULID =
  if ulidBytes.len != 16:
    raise newException(RangeDefect, "Given byte array must be 16 bytes long!")

  when cpuEndian == littleEndian:
    return NULID.fromInt128(cast[Int128](ulidBytes.toArray(0..15)).swapBytes())

  else:
    return NULID.fromInt128(cast[Int128](ulidBytes.toArray(0..15)))

proc parseNulid*(ulidStr: string): NULID =
  if ulidStr.len != 26:
    raise newException(RangeDefect, "Invalid ULID! Must be 26 characters long!")

  result.timestamp = int64.decode(ulidStr[0..9])
  result.randomness = UInt128.decode(ulidStr[10..25])

proc `$`*(ulid: NULID): string =
  result = '0' & Int128.encode(ulid.toInt128(), 26)
