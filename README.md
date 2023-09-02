# NULID
This is an implementation of the [ULID](https://github.com/ulid/spec)
spec in Nim!

## Usage
```nim
let gen = NULIDGenerator()
let nulid = gen.nulidSync()

echo nulid
```
