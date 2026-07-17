# libdave for Windows

This directory vendors the official Discord `libdave` Windows x64 binary used
for DAVE end-to-end media encryption.

- Version: `1.1.1`
- Upstream: <https://github.com/discord/libdave/releases/tag/v1.1.1>
- Artifact: `libdave_windows_X64_BORINGSSL.zip`
- Architecture: Windows x64
- SHA-256 (`libdave.dll`):
  `CDD3AD04EC5F5588E320594D2ABE878DA7BA5385B254F207D86C8CB1649739BD`

The notices for libdave and its bundled dependencies are under `licenses/`.
The root CMake install step copies the DLL beside the application executable and
the notices to `data/licenses/libdave`.
