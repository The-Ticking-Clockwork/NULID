# NULID
This is an implementation of the [ULID](https://github.com/ulid/spec)
spec in Nim!

Random fun fact: I coded the initial code for ULID generation on my phone
via Termux!

## Compile Flags
`-d:nulidInsecureRandom`: Uses `std/random` instead of `std/sysrand`.

## Usage
```nim
let gen = initUlidGenerator()
let ulid = gen.ulid()

echo ulid
```
