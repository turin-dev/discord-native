# libopus for Windows

This directory vendors the Windows x64 libopus binary matched by
`opus_dart` 3.0.1 for Discord's real-time Opus audio codec.

- libopus version: `1.3.1`
- Binary source: `opus_flutter_windows` 3.0.0 package
- Upstream codec: <https://opus-codec.org/>
- Architecture: Windows x64
- SHA-256 (`libopus.dll`):
  `7942C0110A5835C7F2A027382F15B850244BC80712DCB688B79CD61C73263712`

The Opus license is under `licenses/`. The root CMake install step copies the
DLL beside the application executable and the notice to
`data/licenses/libopus`.
