import std/[
  asyncdispatch,
  times
]

import pkg/[
  crockfordb32,
  nint128
]

import ./nulid/private/[
  dochelpers,
  constants
]

import ./nulid/private/stew/endians2

fmtCmnt "NULID Version: {NulidVersion}"

when InsecureRandom:
  import std/random

else:
  import std/sysrand

const HighUint80 = u128("1208925819614629174706176")

type
  NULID* = object
    ## An object representing a ULID.
    timestamp*: int64
    randomness*: UInt128

  NULIDGenerator* = ref object
    ## A NULID generator object, contains details needed to follow the spec.
    ## A generator was made to be compliant with the NULID spec and also to be
    ## threadsafe not use globals that could change.
    lastTime: int64 # Timestamp of last ULID
    random: UInt128 # A random number

    when InsecureRandom:
      rand: Rand # Random generator when using insecure random

proc initNulidGenerator*(): NULIDGenerator =
  ## Initialises a `NULIDGenerator` for use.
  result = NULIDGenerator(lastTime: 0, random: 0.u128)

  when InsecureRandom:
    result.rand = initRand()

# Discouraged to use it but it's fine for single-threaded apps really
let globalGen = initNulidGenerator()

func swapBytes(x: Int128): Int128 =
  result.lo = swapBytes(cast[uint64](x.hi))
  result.hi = cast[int64](swapBytes(x.lo))

func toArray[T](oa: openArray[T], size: static Slice[int]): array[size.len, T] =
  result[0..<size.len] = oa[size]

proc randomBits(n: NULIDGenerator): UInt128 =
  var arr: array[16, byte]

  when InsecureRandom:
    var rnd: array[10, byte]

    rnd[0..7] = cast[array[8, byte]](n.rand.next())
    rnd[8..9] = cast[array[2, byte]](n.rand.rand(high(int16)).int16)

    arr[6..15] = rnd

  else:
    var rnd: array[10, byte]

    if not urandom(rnd):
      raise newException(OSError, "Was unable to use a secure source of randomness! " &
        "Please either compile with `-d:nulidInsecureRandom` or fix this!")

    arr[6..15] = rnd

  result = UInt128.fromBytesBE(arr)

template getTime: int64 = (epochTime() * 1000).int64

proc wait(gen: NULIDGenerator): Future[int64] {.async.} =
  result = getTime()

  while result <= gen.lastTime:
    await sleepAsync(1)
    result = getTime()

proc nulid*(gen: NULIDGenerator, timestamp: int64 = 0): Future[NULID] {.async.} =
  ## Asynchronously generate a `NULID`.
  if timestamp == 0:
    var now = getTime()

    if now < gen.lastTime:
      raise newException(OSError, "Time went backwards!")

    if gen.lastTime == now:
      inc gen.random

      if gen.random == HighUInt80:
        now = await gen.wait()

    else:
      gen.random = gen.randomBits()

    result.timestamp = now

  else:
    result.timestamp = timestamp
  result.randomness = gen.random

proc nulidSync*(gen: NULIDGenerator, timestamp: int64 = 0): NULID =
  ## Synchronously generate a `NULID`.
  result = waitFor gen.nulid(timestamp)

proc nulid*(timestamp: int64 = 0): Future[NULID] =
  ## Asynchronously generate a `NULID` using the global generator.
  result = nulid(globalGen, timestamp)

proc nulidSync*(timestamp: int64 = 0): NULID =
  ## Synchronously generate a `NULID` using the global generator.
  runnableExamples:
    echo nulidSync()

  result = waitFor nulid(timestamp)

func toInt128*(ulid: NULID): Int128 =
  ## Allows for a ULID to be converted to an Int128.
  runnableExamples:
    echo nulidSync().toInt128()

  result = i128(ulid.timestamp) shl 80

  result.hi += cast[int64](ulid.randomness.hi)
  result.lo += ulid.randomness.lo

func fromInt128*(_: typedesc[NULID], val: Int128): NULID =
  ## Parses an Int128 to a NULID.
  result.timestamp = (val shr 16).hi
  result.randomness = UInt128(
    hi: cast[uint64]((val.hi shl 48) shr 48),
    lo: val.lo
  )

func toBytes*(ulid: NULID): array[16, byte] =
  ## Allows for a NULID to be converted to a byte array.
  runnableExamples:
    let
      ulid = parseNulid("01H999MBGTEA8BDS0M5AWEBB1A")
      ulidBytes = [1.byte, 138, 82, 154, 46, 26, 114, 144, 182, 228, 20, 42, 184, 229, 172, 42]

    echo ulid == NULID.fromBytes(ulidBytes)

  when cpuEndian == littleEndian:
    return cast[array[16, byte]](ulid.toInt128().swapBytes())

  else:
    return cast[array[16, byte]](ulid.toInt128())

func fromBytes*(_: typedesc[NULID], ulidBytes: openArray[byte]): NULID =
  ## Parses a byte array to a NULID.
  if ulidBytes.len != 16:
    raise newException(RangeDefect, "Given byte array must be 16 bytes long!")

  when cpuEndian == littleEndian:
    return NULID.fromInt128(cast[Int128](ulidBytes.toArray(0..15)).swapBytes())

  else:
    return NULID.fromInt128(cast[Int128](ulidBytes.toArray(0..15)))

func parseNulid*(ulidStr: string): NULID =
  ## Parses a string to a NULID.
  runnableExamples:
    echo parseNulid("01H999MBGTEA8BDS0M5AWEBB1A")

  if ulidStr.len != 26:
    raise newException(RangeDefect, "Invalid ULID! Must be 26 characters long!")

  result.timestamp = int64.decode(ulidStr[0..9])
  result.randomness = UInt128.decode(ulidStr[10..25])

func `$`*(ulid: NULID): string =
  ## Returns the string representation of a ULID.
  runnableExamples:
    echo nulidSync()

  result = Int128.encode(ulid.toInt128(), 26)
