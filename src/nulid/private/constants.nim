import nint128

const
  HighInt48* = 281474976710655'i64
  HighUint80* = u128("1208925819614629174706176")

# No sysrand on the JS backend nor VM (though neither is expected to work).
const InsecureRandom* = defined(nulidInsecureRandom) or defined(js) or defined(nimvm)
