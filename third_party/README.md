# Vendored dependencies

Windows Discord video transport를 네트워크 다운로드 없이 재현하기 위해 아래 upstream 소스를 고정한다.

| 경로 | 버전 | 출처 | 라이선스 |
| --- | --- | --- | --- |
| `flutter_webrtc/` | 1.5.2 | https://github.com/flutter-webrtc/flutter-webrtc | MIT (`LICENSE`, `NOTICE`) |
| `libdatachannel/` | 0.24.3 | https://github.com/paullouisageneau/libdatachannel | MPL-2.0 (`LICENSE`) |
| `mbedtls/` | 3.6.6 LTS | https://github.com/Mbed-TLS/mbedtls | Apache-2.0 또는 GPL-2.0-or-later (`LICENSE`) |

`flutter_webrtc`의 Windows plugin에는 Discord Voice Gateway SDP, `libdatachannel` RTP, DAVE H264 encrypt/decrypt, Media Foundation H264 encode/decode를 연결하는 `discord_*` C++ 파일과 method-channel 진입점을 추가했다. `libdatachannel`은 Discord의 H264 packetization에 필요한 source·timestamp metadata를 노출하도록 최소 수정했다. mbedTLS는 수정하지 않고 `libdatachannel`의 static TLS backend로 빌드한다.

mbedTLS 3.6.6이 고정한 `mbedtls-framework` commit `dff9da04438d712f7647fd995bc90fadd0c0e2ce`의 `framework/data_files/`는 upstream protocol test fixture지만, private-key marker가 포함되어 공개 저장소의 secret scanning과 push protection을 유발한다. Windows 빌드는 `ENABLE_TESTING=OFF`와 `ENABLE_PROGRAMS=OFF`를 사용하고 이 디렉터리를 참조하지 않으므로 공개 배포본에서는 제외한다. 애플리케이션 credential이나 사용자 token은 이 디렉터리에 저장하지 않는다.
