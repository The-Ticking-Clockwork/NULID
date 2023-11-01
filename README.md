# NULID
This is an implementation of the [ULID](https://github.com/ulid/spec)
spec in Nim!

This supports [`jsony`](https://github.com/treeform/jsony) and
[`debby`](https://github.com/treeform/debby) out of the box too!

Random fun fact: I coded the initial code for ULID generation on my phone
via Termux!

## Compile Flags
`-d:nulidInsecureRandom`: Uses `std/random` instead of `std/sysrand`.

`-d:nulidNoLocks`: Disables any usage of locks within the program.

The JS backend automatically defines `-d:nulidNoLocks` while Nimscript
defines both of these flags.


## Usage
```nim
let gen = initUlidGenerator()
let ulid = gen.ulid()

echo ulid
```
