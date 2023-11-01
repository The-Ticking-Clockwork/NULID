const
  LowInt48* = 0'i64
  HighInt48* = 281474976710655'i64

const
  HighUint80Str = "1208925819614629174706176"
  TimestampBitmaskStr = "340282366920937254537554992802593505280"
  RandomnessBitmaskStr = "1208925819614629174706175"

when not defined(js):
  import nint128

  const
    LowUint80* = u128(0)
    HighUint80* = u128(HighUint80Str)

    #TimestampBitmask = big(TimestampBitmaskStr)
    #RandomnessBitmask = big(RandomnessBitmaskStr)

else:
  import std/[
    jsbigints
  ]

  let
    LowUint80* = big(0)
    HighUint80* = big(HighUint80Str)

    HighInt128* = big("340282366920938463463374607431768211455")

    TimestampBitmask* = big(TimestampBitmaskStr)
    RandomnessBitmask* = big(RandomnessBitmaskStr)


# No sysrand on the JS backend nor VM.
const InsecureRandom* = defined(nulidInsecureRandom) or defined(nimscript)
const NoLocks* = defined(nulidNoLocks) or defined(js) or defined(nimscript)

# Support for other libraries
{.warning[UnusedImport]:off.}
const
  HasJsony* = compiles do: import jsony

  HasDebby* = compiles do: import debby/common
