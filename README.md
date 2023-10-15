# NULID
This is an implementation of the [ULID](https://github.com/ulid/spec)
spec in Nim!

## Compile Flags
`-d:nulidInsecureRandom`: Uses `std/random` instead of `std/sysrand`.

## Usage
```nim
let gen = NULIDGenerator()
let nulid = gen.nulidSync()

echo nulid
```
