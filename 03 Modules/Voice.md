---
type: module
status: active
tags: [voice, gateway, udp, opus, dave, video, webrtc, go-live, ptt]
source_paths: [lib/features/voice/, lib/features/video/, lib/features/system/, lib/app/global_push_to_talk_dispatcher.dart, lib/features/workspace/presentation/workspace_voice_controls.dart, third_party/flutter_webrtc/, third_party/libdatachannel/, windows/libdave/, windows/libopus/]
reviewed_at: 2026-07-18
confidence: high
aliases: [Voice]
---

# Voice

`DiscordVoiceCoordinator`는 Main Gateway의 `VOICE_STATE_UPDATE`와 `VOICE_SERVER_UPDATE`를 순서와 무관하게 합쳐 Voice 자격 정보를 만들고, Voice Gateway와 미디어 엔진의 수명주기를 조정한다. Workspace의 type 2 음성 채널과 type 13 Stage 채널에서 참가·퇴장할 수 있으며 mute, deafen, 입력 감지, 푸시투토크와 사용자별 0–200% 음량을 제어한다.

## Voice Gateway와 DAVE

`DiscordVoiceGatewayClient`는 Voice Gateway v8에 연결해 OP0 Identify, OP8 Hello, OP3 Heartbeat, OP2 Ready, UDP IP discovery, OP1 Select Protocol과 OP4 Session Description을 처리한다. heartbeat와 OP7 Resume은 마지막 JSON 또는 binary message sequence를 `seq_ack`로 보낸다. OP11·OP13 참가자 이벤트는 초기 Session Description보다 먼저 도착해도 보존한다.

Voice E2EE는 공식 `libdave` Windows DLL을 FFI로 열어 DAVE v1 MLS key package, external sender, proposal, commit, welcome과 protocol transition을 처리한다. 서버 binary DAVE message의 16-bit sequence와 opcode를 분리하고, 송수신 Opus frame은 participant별 DAVE ratchet으로 보호·해제한다.

WebRTC video에서도 같은 DAVE session을 사용한다. H264 access unit은 송신 전에 video codec으로 보호하고, 수신 frame은 `video_ssrc`의 사용자 매핑으로 DAVE를 해제한 뒤 renderer에 전달한다. DAVE가 요구되는 session에서 native encryptor/decryptor handle이 없으면 SDP answer 적용 전에 실패한다.

지원 transport encryption은 `aead_aes256_gcm_rtpsize` 우선, `aead_xchacha20_poly1305_rtpsize` 필수 fallback이다. RTP payload type은 Opus `0x78`이며 sequence, timestamp와 32-bit nonce wrap을 보존한다.

## 오디오 파이프라인

송신 경로는 `record` PCM16 48 kHz stereo → 20 ms frame 조립 → VAD 또는 PTT gate → native `libopus` encode → DAVE → RTP AEAD → UDP다. 발화를 시작하기 전에 OP5 Speaking을 보내고, 중지할 때 Opus silence frame 5개를 보낸 뒤 Speaking을 해제한다.

수신 경로는 UDP → RTP AEAD → SSRC별 사용자 매핑 → DAVE → 사용자별 Opus decoder → `flutter_soloud` PCM stream이다. 작은 RTP sequence gap은 최대 5개 packet-loss concealment frame으로 보완하고, 참가자가 나가면 decoder와 playback stream을 함께 정리한다. 설정의 microphone ID는 `record` 장치에, output device ID는 SoLoud backend 초기화에 적용한다.

VAD는 normalized RMS 임계값과 10 frame hangover를 사용한다. PTT는 UI pointer press뿐 아니라 Windows 전역 F1–F12 key binding을 지원한다. 미디어가 active이고 입력 모드가 PTT인 동안에만 `WindowsDesktopSystemBridge`가 선택한 단일 virtual key의 현재 상태를 16ms 간격으로 확인하고 press/release 변화만 음성 엔진에 전달하므로, 대기 상태에서는 polling 비용이 없고 키 입력 자체를 가로채거나 다른 키를 기록하지 않는다. release delay는 0–2000ms로 설정할 수 있으며 기본값은 20ms다. fresh Voice session 재협상 뒤에도 입력 모드는 보존된다.

## 카메라와 Go Live

카메라는 Main Gateway OP4의 `self_video`와 기존 Voice Gateway 연결의 WebRTC Select Protocol을 사용한다. `flutter_webrtc`의 Windows capture stream을 native Media Foundation H264 encoder가 access unit으로 변환하고, vendored `libdatachannel`의 H264 RTP packetizer가 Discord RTC 연결로 보낸다. 수신은 H264 depacketizer → DAVE 해제 → Media Foundation decoder → I420 `MediaStream` 순서이며 사용자별 video tile로 표시한다. encoder와 decoder queue는 유한 크기이고 overflow 뒤에는 다음 keyframe부터 복구한다.

Go Live는 일반 음성·카메라 연결과 병렬인 별도 Voice Gateway/WebRTC 연결이다. 방송은 Main Gateway OP18 `CREATE_STREAM` 뒤 `STREAM_CREATE`의 `rtc_server_id`·`rtc_channel_id`와 `STREAM_SERVER_UPDATE`의 token·endpoint를 합쳐 화면 capture source로 연결한다. OP22는 capture track과 서버 pause 상태를 함께 바꾸고, OP19는 별도 RTC와 capture를 정리한다.

시청은 참가자의 `self_stream`으로 만든 stream key를 OP20에 보내고 local video source나 마이크 capture가 없는 receive-only WebRTC 연결을 연다. 원격 H264 preview는 기존 카메라 preview와 불변 map으로 합쳐진다. `STREAM_DELETE`, endpoint 제거, 연결 실패는 별도 stream 리소스만 정리하므로 기본 음성 통화는 유지된다.

## 연결 복구

heartbeat ACK 누락, close code 4015와 일반적인 일시 단절은 같은 endpoint에 새 WebSocket을 열고 OP7 Resume을 보낸다. Resume 동안 기존 UDP, transport key와 DAVE state를 유지해 미디어 session을 계속 사용할 수 있다. WebSocket 연결 자체가 실패하면 1초부터 최대 30초까지 지수 backoff하며 최대 5회 시도한다.

close code 4006 또는 4009로 session이 만료되면 UDP와 DAVE connection state를 초기화하고 OP0 Identify부터 다시 협상한다. Coordinator는 이전 미디어 엔진을 직렬로 정리하고 새 SSRC·secret key를 사용하는 엔진을 생성한다. 4014, 4021, 4022를 포함한 복구 불가 close code에서는 재접속 루프를 만들지 않고 실패 상태와 리소스 정리를 수행한다.

프로토콜 기준은 [Discord Voice 문서](https://docs.discord.com/developers/topics/voice-connections)와 [Voice opcode·close code 표](https://docs.discord.com/developers/topics/opcodes-and-status-codes)다.

## Windows 배포와 남은 범위

`libdave.dll`과 `libopus.dll`, 각각의 라이선스 bundle은 Windows runner 실행 파일 옆에 설치된다. `flutter_webrtc` plugin은 bundled `libdatachannel`·mbedTLS와 Windows Media Foundation encoder/decoder를 정적으로 링크한다. 자동 테스트는 실제 XChaCha RTP 왕복, native libdave/libopus 호출, WebRTC signaling, Go Live 별도 연결과 receive-only media를 포함한다.

남은 범위는 임의 키·마우스 버튼 PTT recording, 관리자 권한 게임과의 전역 PTT 실기기 검증, 통화 중 장치 hot swap, echo cancellation과 noise suppression이다. 관련 추적은 [[Open Questions]]에서 관리한다.

관련 문서: [[Native Client Architecture]], [[Windows Development]], [[Open Questions]]
