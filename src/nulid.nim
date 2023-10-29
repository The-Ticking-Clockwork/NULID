import std/[
  times,
  os
]

import crockfordb32
import nint128

import ./nulid/private/constants
import ./nulid/private/stew/endians2

when InsecureRandom:
  import std/random

else:
  import std/sysrand

when not NoLocks:
  import std/rlocks

##[
Note: There are 2 defines that can be passed to the compiler to trigger different
functionality in this library at runtime, they are listed here:
  - `--define:nulidInsecureRandom`: Uses `std/random` instead of `std/sysrand`.
  - `--define:nulidNoLocks`

The JS backend and Nimscript use both of these flags by default (whether either work
with NULID is untested).
]##

type
  ULID* = object
    ## An object representing a ULID.
    timestamp*: int64
    randomness*: UInt128

  ULIDGenerator* = ref object
    ## A `ULID` generator object, contains details needed to follow the spec.
    ## A generator was made to be compliant with the ULID spec and also to be
    ## threadsafe not use globals that could change.
    when NoLocks:
      lastTime: int64 # Timestamp of last ULID, 48 bits
      random: UInt128 # A random number, 80 bits

      when InsecureRandom:
        rand: Rand # Random generator when using insecure random

    else:
      lock*: RLock
      lastTime {.guard: lock.}: int64 # Timestamp of last ULID, 48 bits
      random {.guard: lock.}: UInt128 # A random number, 80 bits

      when InsecureRandom:
        rand {.guard: lock.}: Rand # Random generator when using insecure random

template withLock(gen: ULIDGenerator, body: typed) =
  when NoLocks:
    body
  else:
    {.cast(gcsafe).}:
      gen.lock.withRLock:
        body

proc initUlidGenerator*(): ULIDGenerator =
  ## Initialises a `ULIDGenerator` for use.
  when NoLocks:
    result = ULIDGenerator(lastTime: 0, random: 0.u128)
  else:
    result = ULIDGenerator(lock: RLock(), lastTime: 0, random: 0.u128)
    initRLock(result.lock)

  when InsecureRandom:
    result.withLock:
      result.rand = initRand()

let globalGen = initUlidGenerator()

func swapBytes(x: Int128): Int128 =
  result.lo = swapBytes(cast[uint64](x.hi))
  result.hi = cast[int64](swapBytes(x.lo))

func toArray[T](oa: openArray[T], size: static Slice[int]): array[size.len, T] =
  result[0..<size.len] = oa[size]

proc randomBits(n: ULIDGenerator): UInt128 {.gcsafe.} =
  var arr: array[16, byte]

  when InsecureRandom:
    var rnd: array[10, byte]

    n.withLock:
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

proc wait(gen: ULIDGenerator): int64 {.gcsafe.} =
  result = getTime()

  gen.withLock:
    while result <= gen.lastTime:
      sleep(1)
      result = getTime()

      if result < gen.lastTime:
        raise newException(OSError, "Time went backwards!")

proc ulid*(gen: ULIDGenerator, timestamp = 0'i64, randomness = u128(0)): ULID =
  ## Generate a `ULID`, if timestamp is equal to `0`, the `randomness` parameter
  ## will be ignored.
  runnableExamples:
    let gen = initUlidGenerator()

    echo gen.ulid()

  if timestamp == 0:
    var now = getTime()

    gen.withLock:
      if gen.lastTime == now:
        inc gen.random

        if gen.random == HighUInt80:
          now = gen.wait()
          gen.random = gen.randomBits()

      else:
        gen.random = gen.randomBits()

      result.randomness = gen.random

    result.timestamp = now

  else:
    result.timestamp = clamp(timestamp, 0, HighInt48)
    result.randomness = clamp(randomness, low(UInt128), HighUint80)

proc ulid*(timestamp = 0'i64, randomness = u128(0)): ULID =
  ## Generate a `ULID` using the global generator.
  ##
  ## See also:
  ## * `ulid(ULIDGenerator, int64, UInt128) <#ulid,ULIDGenerator,int64>`_
  runnableExamples:
    echo ulid()

  result = ulid(globalGen, timestamp)

func toInt128*(ulid: ULID): Int128 =
  ## Allows for a `ULID` to be converted to an Int128.
  runnableExamples:
    echo ulid().toInt128()

  result = i128(ulid.timestamp) shl 80

  result.hi += cast[int64](ulid.randomness.hi)
  result.lo += ulid.randomness.lo

func fromInt128*(_: typedesc[ULID], val: Int128): ULID =
  ## Parses an Int128 to a ULID.
  result.timestamp = (val shr 16).hi
  result.randomness = UInt128(
    hi: cast[uint64]((val.hi shl 48) shr 48),
    lo: val.lo
  )

func toBytes*(ulid: ULID): array[16, byte] =
  ## Allows for a `ULID` to be converted to a byte array for the binary format.
  runnableExamples:
    let
      ulid = ULID.parse("01H999MBGTEA8BDS0M5AWEBB1A")
      ulidBytes = [1.byte, 138, 82, 154, 46, 26, 114, 144, 182, 228, 20, 42, 184, 229, 172, 42]

    assert ulid == ULID.fromBytes(ulidBytes)

  when cpuEndian == littleEndian:
    return cast[array[16, byte]](ulid.toInt128().swapBytes())

  else:
    return cast[array[16, byte]](ulid.toInt128())

func fromBytes*(_: typedesc[ULID], ulidBytes: openArray[byte]): ULID =
  ## Parses a byte array to a `ULID.`.
  if ulidBytes.len != 16:
    raise newException(RangeDefect, "Given byte array must be 16 bytes long!")

  when cpuEndian == littleEndian:
    return ULID.fromInt128(cast[Int128](ulidBytes.toArray(0..15)).swapBytes())

  else:
    return ULID.fromInt128(cast[Int128](ulidBytes.toArray(0..15)))

func parse*(_: typedesc[ULID], ulidStr: string): ULID =
  ## Parses a `ULID` from a string.
  runnableExamples:
    echo ULID.parse("01H999MBGTEA8BDS0M5AWEBB1A")

  if ulidStr.len != 26:
    raise newException(RangeDefect, "Invalid ULID! Must be 26 characters long!")

  result.timestamp = int64.decode(ulidStr[0..9])
  result.randomness = UInt128.decode(ulidStr[10..25])

proc `==`*(a, b: ULID): bool = a.toInt128() == b.toInt128()

func `$`*(ulid: ULID): string =
  ## Returns the string representation of a ULID.
  runnableExamples:
    echo $ulid()

  result = Int128.encode(ulid.toInt128(), 26)

when HasJsony:
  import jsony

  proc dumpHook*(s: var string, ulid: ULID) = s.dumpHook($ulid)
  proc parseHook*(s: string, i: var int, ulid: var ULID) =
    var res: string
    parseHook(s, i, res)
    ulid = ULID.parse(res)

when HasDebby:
  import std/sequtils
  import debby/common

  func sqlDumpHook*(v: ULID): string = sqlDumpHook(cast[Bytes](v.toBytes().toSeq()))
  func sqlParseHook*(data: string, v: var ULID) =
    var res: Bytes
    sqlParseHook(data, res)
    v = ULID.fromBytes(cast[seq[byte]](res))