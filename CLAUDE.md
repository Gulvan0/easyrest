This is the easyrest library's own source repository, distributed as a haxelib library (see `haxelib.json`).

`easyrest` is a thin REST client built around typed operations: `GenericRestOperation`/`GetOperaton` describe a request/response pair whose payload and response are `jsonmodel` (un)serializable (with `NoPayload`/`NoResponse` marking operations that omit either side), and `RestClient` executes an operation over HTTP, raising typed exceptions (`exceptions.GetPayloadProvidedException`, `exceptions.NonUnserializableResponsePayloadClass`) for misuse. All source lives under `src/easyrest` (`easyrest` package and its subpackages).

ANY AMBIGUITY OR MANUAL GAP SURFACING DURING IMPLEMENTATION SHOULD NOT BE RESOLVED SILENTLY. Instead, explicitly ask the question.

# Code style conventions

See `code_style.md`.

# Dependencies

- `jsonmodel` - JSON (un)serialization of request/response payloads.
- `http` - the underlying HTTP client/request/response types.

See `haxelib.json`'s `dependencies` for the authoritative list.
