`easyrest` is a thin REST client for Haxe 4.

It is built around typed operations: `GenericRestOperation`/`GetOperation` describe a request/response pair whose payload and response are `jsonmodel` (un)serializable (with `NoPayload`/`NoResponse` marking operations that omit either side), and `RestClient` executes an operation over HTTP, raising typed exceptions (`exceptions.GetPayloadProvidedException`, `exceptions.NonUnserializableResponsePayloadClass`) for misuse.

All source lives under `src/easyrest` (`easyrest` package and its subpackages).
