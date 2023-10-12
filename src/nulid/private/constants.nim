# No sysrand on the JS backend nor VM
const InsecureRandom* = defined(nulidInsecureRandom) or defined(js) or defined(nimvm)

const NulidVersion* = "0.2.4"