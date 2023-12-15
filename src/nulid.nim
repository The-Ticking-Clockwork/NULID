import std/[
  times
]

import crockfordb32

import ./nulid/private/constants

when not defined(js):
  import std/os
  import nint128

  import ./nulid/private/stew/endians2

else:
  import std/jsbigints

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

The JS backend used `-d:nulidNoLocks` by default and Nimscript uses both.
these flags by default (whether either work with NULID is untested).
]##

when not defined(js):
  type UInt128DropIn = UInt128

else:
  type UInt128DropIn = JsBigInt

type
  ULIDError* = object of CatchableError
  ULIDDefect* = object of Defect

  ULIDGenerationError* = object of ULIDError
  ULIDGenerationDefect* = object of ULIDDefect

  ULID* = object
    ## An object representing a ULID.
    timestamp*: int64
    when not defined(js):
      randomness*: UInt128
    else:
      randomness*: JsBigInt

  ULIDGenerator* = ref object
    ## A `ULID` generator object, contains details needed to follow the spec.
    ## A generator was made to be compliant with the ULID spec and also to be
    ## threadsafe not use globals that could change.
    when NoLocks:
      lastTime: int64 # Timestamp of last ULID, 48 bits
      when not defined(js):
        random: UInt128 # A random number, 80 bits
      else:
        random: JsBigInt

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
      acquire(gen.lock)

    {.locks: [gen.lock].}:
      try:
        body
      finally:
        {.cast(gcsafe).}:
          release(gen.lock)


proc initUlidGenerator*(): ULIDGenerator =
  ## Initialises a `ULIDGenerator` for use.
  when NoLocks:
    result = ULIDGenerator(lastTime: LowInt48, random: LowUint80)
  else:
    result = ULIDGenerator(lock: RLock(), lastTime: LowInt48, random: LowUint80)
    initRLock(result.lock)

  when InsecureRandom:
    result.withLock:
      result.rand = initRand()


let globalGen = initUlidGenerator()


when not defined(js):
  func swapBytes(x: Int128): Int128 =
    result.lo = swapBytes(cast[uint64](x.hi))
    result.hi = cast[int64](swapBytes(x.lo))


func toArray[T](oa: openArray[T], size: static Slice[int]): array[size.len, T] =
  result[0..<size.len] = oa[size]


proc randomBits(n: ULIDGenerator): UInt128DropIn {.gcsafe.} =
  var arr: array[16, byte]

  when InsecureRandom:
    var rnd: array[10, byte]

    n.withLock:
      when not defined(js):
        rnd[0..7] = cast[array[8, byte]](n.rand.next())
        rnd[8..9] = cast[array[2, byte]](n.rand.rand(high(uint16)).uint16)

      else:
        for i in 0..9:
          rnd[i] = n.rand.rand(high(byte)).byte

    arr[6..15] = rnd

  else:
    var rnd: array[10, byte]

    if not urandom(rnd):
      raise newException(ULIDGenerationDefect, "Was unable to use a secure source of randomness! " &
        "Please either compile with `-d:nulidInsecureRandom` or fix this somehow!")

    arr[6..15] = rnd

  when not defined(js):
    result = UInt128.fromBytesBE(arr)

  else:
    for i in arr:
      result = result shl 8'big
      result += big(i)


template getTime: int64 = (epochTime() * 1000).int64


proc wait(gen: ULIDGenerator): int64 {.gcsafe.} =
  when not defined(js):
    result = getTime()

    gen.withLock:
      while result <= gen.lastTime:
        sleep(1)
        result = getTime()

        if result < gen.lastTime:
          raise newException(ULIDGenerationError, "Time went backwards!")

  else:
    raise newException(ULIDGenerationError, "Couldn't generate ULID! Try again in a millisecond.")


proc ulid*(gen: ULIDGenerator, timestamp = LowInt48, randomness = LowUint80): ULID {.gcsafe.} =
  ## Generate a `ULID`, if timestamp is equal to `0`, the `randomness` parameter
  ## will be ignored.
  ##
  ## See also:
  ## * `ulid(int64, UInt128) <#ulid_2>`_
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
    result.timestamp = clamp(timestamp, LowInt48, HighInt48)
    result.randomness = clamp(randomness, LowUint80, HighUint80)


proc ulid*(timestamp = LowInt48, randomness = LowUint80): ULID =
  ## Generate a `ULID` using the global generator.
  ##
  ## See also:
  ## * `ulid(ULIDGenerator, int64, UInt128) <#ulid,ULIDGenerator>`_
  runnableExamples:
    echo ulid()

  result = ulid(globalGen, timestamp)


when not defined(js):
  func toInt128*(ulid: ULID): Int128 =
    ## Allows for a `ULID` to be converted to an `Int128`.
    ##
    ## **Note:** On the JS backend this returns a `JsBigInt` from `std/jsbigints`
    runnableExamples:
      echo ulid().toInt128()

    result = i128(ulid.timestamp) shl 80

    result.hi += cast[int64](ulid.randomness.hi)
    result.lo += ulid.randomness.lo


  func fromInt128*(_: typedesc[ULID], val: Int128): ULID =
    ## Parses an `Int128` to a `ULID`.
    ##
    ## **Note:** On the JS backend this accepts a `JsBigInt` from `std/jsbigints`
    result.timestamp = (val shr 16).hi
    result.randomness = UInt128(
      hi: cast[uint64]((val.hi shl 48) shr 48),
      lo: val.lo
    )


else:
  func toInt128*(ulid: ULID): JsBigInt =
    ## Allows for a `ULID` to be converted to a `JsBigInt`.
    ##
    ## **Note:** On the native backends this returns an `Int128` from `nint128`.
    runnableExamples:
      echo ulid().toInt128()

    result = big(ulid.timestamp) shl 80'big
    result += ulid.randomness


  proc fromInt128*(_: typedesc[ULID], val: JsBigInt): ULID =
    ## Parses an `JsBigInt` to a `ULID`.
    ##
    ## **Note:** On the native backends this accepts an `Int128` from `nint128`
    assert val <= HighInt128

    result.timestamp = ((val and TimestampBitmask) shr 80'big).toNumber().int64
    result.randomness = val and RandomnessBitmask


when not defined(js):
  func toBytes*(ulid: ULID): array[16, byte] =
    ## Allows for a `ULID` to be converted to a byte array for the binary format.
    ##
    ## **Note:** This isn't available for the JS backend.
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
    ##
    ## **Note:** This isn't available for the JS backend.

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
  when not defined(js):
    result.randomness = UInt128.decode(ulidStr[10..25])
  else:
    result.randomness = JsBigInt.decode(ulidStr[10..25])


proc `==`*(a, b: ULID): bool = a.toInt128() == b.toInt128()


func `$`*(ulid: ULID): string =
  ## Returns the string representation of a ULID.
  runnableExamples:
    echo $ulid()

  when not defined(js):
    result = Int128.encode(ulid.toInt128(), 26)
  else:
    result = JsBigInt.encode(ulid.toInt128(), 26)


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
