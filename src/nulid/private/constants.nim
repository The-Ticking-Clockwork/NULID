import nint128

const HighUint80* = u128("1208925819614629174706176")
# No sysrand on the JS backend nor VM (does this even work on either?)
const InsecureRandom* = defined(nulidInsecureRandom) or defined(js) or defined(nimvm)
