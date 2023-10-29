import nint128

const
  HighInt48* = 281474976710655'i64
  HighUint80* = u128("1208925819614629174706176")

# No sysrand on the JS backend nor VM.
const InsecureRandom* = defined(nulidInsecureRandom) or defined(js) or defined(nimvm)
const NoLocks* = defined(nulidNoLocks) or defined(js) or defined(nimvm)

# Support for other libraries
{.warning[UnusedImport]:off.}
const
  HasJsony* = compiles do: import jsony

  HasDebby* = compiles do: import debby/common