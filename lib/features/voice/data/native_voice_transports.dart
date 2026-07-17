import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:discord_native/features/voice/data/discord_voice_gateway_client.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

export 'package:discord_native/features/voice/data/discord_voice_gateway_client.dart'
    show VoiceIpDiscoveryResult;

abstract interface class VoiceWebSocketConnection {
  Future<void> get ready;

  Stream<Object?> get stream;

  int? get closeCode;

  void send(Object value);

  Future<void> close();
}

typedef VoiceWebSocketConnector = VoiceWebSocketConnection Function(Uri uri);

final class WebSocketVoiceGatewayTransport implements VoiceGatewayTransport {
  WebSocketVoiceGatewayTransport({VoiceWebSocketConnector? connector})
    : _connector = connector ?? _connectWebSocket;

  final VoiceWebSocketConnector _connector;
  final StreamController<Object?> _messages = StreamController.broadcast();
  final StreamController<int?> _closes = StreamController.broadcast();

  VoiceWebSocketConnection? _connection;
  StreamSubscription<Object?>? _subscription;

  @override
  Stream<int?> get closes => _closes.stream;

  @override
  Stream<Object?> get messages => _messages.stream;

  @override
  Future<void> connect(Uri uri) async {
    if (_connection != null) {
      await close();
    }
    final connection = _connector(uri);
    await connection.ready;
    _connection = connection;
    _subscription = connection.stream.listen(
      _messages.add,
      onError: _messages.addError,
      onDone: () {
        if (!_closes.isClosed) {
          _closes.add(connection.closeCode);
        }
      },
    );
  }

  @override
  Future<void> sendJson(Map<String, Object?> payload) async {
    _requireConnection().send(jsonEncode(payload));
  }

  @override
  Future<void> sendBinary(Uint8List payload) async {
    _requireConnection().send(Uint8List.fromList(payload));
  }

  @override
  Future<void> close() async {
    final connection = _connection;
    _connection = null;
    await _subscription?.cancel();
    _subscription = null;
    await connection?.close();
  }

  VoiceWebSocketConnection _requireConnection() {
    final connection = _connection;
    if (connection == null) {
      throw StateError('Voice WebSocket이 연결되지 않았습니다.');
    }
    return connection;
  }
}

final class _WebSocketChannelConnection implements VoiceWebSocketConnection {
  const _WebSocketChannelConnection(this._channel);

  final WebSocketChannel _channel;

  @override
  int? get closeCode => _channel.closeCode;

  @override
  Future<void> get ready => _channel.ready;

  @override
  Stream<Object?> get stream => _channel.stream;

  @override
  Future<void> close() => _channel.sink.close();

  @override
  void send(Object value) => _channel.sink.add(value);
}

VoiceWebSocketConnection _connectWebSocket(Uri uri) {
  return _WebSocketChannelConnection(WebSocketChannel.connect(uri));
}

final class NativeVoiceUdpTransport implements VoiceUdpTransport {
  NativeVoiceUdpTransport({this.discoveryTimeout = const Duration(seconds: 5)});

  final Duration discoveryTimeout;
  final StreamController<Uint8List> _packets = StreamController.broadcast();

  RawDatagramSocket? _socket;
  StreamSubscription<RawSocketEvent>? _subscription;
  Timer? _keepAliveTimer;
  InternetAddress? _remoteAddress;
  int? _remotePort;
  Completer<VoiceIpDiscoveryResult>? _discovery;
  int _keepAliveCounter = 0;

  @override
  Stream<Uint8List> get packets => _packets.stream;

  @override
  Future<VoiceIpDiscoveryResult> connectAndDiscover({
    required String serverAddress,
    required int serverPort,
    required int ssrc,
  }) async {
    await close();
    final remoteAddress = await _resolveIpv4(serverAddress);
    if (serverPort <= 0 || serverPort > 65535) {
      throw const FormatException('Voice UDP port 범위가 올바르지 않습니다.');
    }
    final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    final discovery = Completer<VoiceIpDiscoveryResult>();
    _socket = socket;
    _remoteAddress = remoteAddress;
    _remotePort = serverPort;
    _discovery = discovery;
    _keepAliveCounter = 0;
    _subscription = socket.listen(
      _receiveSocketEvent,
      onError: _receiveSocketError,
      onDone: _receiveSocketDone,
    );
    _sendRaw(buildVoiceIpDiscoveryPacket(ssrc));
    _startKeepAlive();
    return discovery.future.timeout(
      discoveryTimeout,
      onTimeout: () =>
          throw TimeoutException('Voice UDP IP discovery가 만료되었습니다.'),
    );
  }

  @override
  Future<void> send(Uint8List packet) async {
    if (packet.isEmpty) {
      throw const FormatException('빈 Voice UDP packet은 보낼 수 없습니다.');
    }
    _sendRaw(packet);
  }

  @override
  Future<void> close() async {
    _keepAliveTimer?.cancel();
    _keepAliveTimer = null;
    final discovery = _discovery;
    _discovery = null;
    if (discovery != null && !discovery.isCompleted) {
      discovery.completeError(StateError('Voice UDP 연결이 종료되었습니다.'));
    }
    await _subscription?.cancel();
    _subscription = null;
    _socket?.close();
    _socket = null;
    _remoteAddress = null;
    _remotePort = null;
  }

  Future<void> dispose() async {
    await close();
    await _packets.close();
  }

  void _receiveSocketEvent(RawSocketEvent event) {
    if (event != RawSocketEvent.read) {
      return;
    }
    Datagram? datagram;
    while ((datagram = _socket?.receive()) != null) {
      _receiveDatagram(datagram!.data);
    }
  }

  void _receiveDatagram(Uint8List packet) {
    final discovery = _discovery;
    if (discovery != null && !discovery.isCompleted) {
      try {
        discovery.complete(parseVoiceIpDiscoveryPacket(packet));
        return;
      } on FormatException {
        return;
      }
    }
    if (!_packets.isClosed) {
      _packets.add(Uint8List.fromList(packet));
    }
  }

  void _receiveSocketError(Object error, StackTrace stackTrace) {
    final discovery = _discovery;
    if (discovery != null && !discovery.isCompleted) {
      discovery.completeError(error, stackTrace);
    }
    if (!_packets.isClosed) {
      _packets.addError(error, stackTrace);
    }
  }

  void _receiveSocketDone() {
    final discovery = _discovery;
    if (discovery != null && !discovery.isCompleted) {
      discovery.completeError(StateError('Voice UDP socket이 종료되었습니다.'));
    }
  }

  void _startKeepAlive() {
    void sendNext() {
      _sendRaw(buildVoiceKeepAlivePacket(_keepAliveCounter));
      _keepAliveCounter = (_keepAliveCounter + 1) & 0xFFFFFFFF;
    }

    sendNext();
    _keepAliveTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => sendNext(),
    );
  }

  void _sendRaw(Uint8List packet) {
    final socket = _socket;
    final address = _remoteAddress;
    final port = _remotePort;
    if (socket == null || address == null || port == null) {
      throw StateError('Voice UDP socket이 연결되지 않았습니다.');
    }
    socket.send(packet, address, port);
  }
}

Uint8List buildVoiceIpDiscoveryPacket(int ssrc) {
  if (ssrc < 0 || ssrc > 0xFFFFFFFF) {
    throw const FormatException('Voice SSRC 범위가 올바르지 않습니다.');
  }
  final packet = Uint8List(74);
  final data = ByteData.sublistView(packet);
  data.setUint16(0, 1, Endian.big);
  data.setUint16(2, 70, Endian.big);
  data.setUint32(4, ssrc, Endian.big);
  return packet;
}

VoiceIpDiscoveryResult parseVoiceIpDiscoveryPacket(Uint8List packet) {
  if (packet.length != 74) {
    throw const FormatException('Voice IP discovery 응답 길이가 올바르지 않습니다.');
  }
  final data = ByteData.sublistView(packet);
  if (data.getUint16(0, Endian.big) != 2 ||
      data.getUint16(2, Endian.big) != 70) {
    throw const FormatException('Voice IP discovery 응답 header가 올바르지 않습니다.');
  }
  final terminator = packet.indexOf(0, 8);
  if (terminator <= 8 || terminator >= 72) {
    throw const FormatException('Voice IP discovery 주소가 올바르지 않습니다.');
  }
  final address = utf8.decode(packet.sublist(8, terminator));
  final parsedAddress = InternetAddress.tryParse(address);
  if (parsedAddress == null || parsedAddress.type != InternetAddressType.IPv4) {
    throw const FormatException('Voice IP discovery IPv4 주소가 올바르지 않습니다.');
  }
  final port = data.getUint16(72, Endian.big);
  if (port == 0) {
    throw const FormatException('Voice IP discovery port가 올바르지 않습니다.');
  }
  return VoiceIpDiscoveryResult(address: address, port: port);
}

Uint8List buildVoiceKeepAlivePacket(int counter) {
  if (counter < 0 || counter > 0xFFFFFFFF) {
    throw const FormatException('Voice UDP keepalive counter 범위가 올바르지 않습니다.');
  }
  final packet = Uint8List(8);
  ByteData.sublistView(packet).setUint32(0, counter, Endian.little);
  return packet;
}

Future<InternetAddress> _resolveIpv4(String host) async {
  final normalized = host.trim();
  if (normalized.isEmpty) {
    throw const FormatException('Voice UDP 주소가 필요합니다.');
  }
  final parsed = InternetAddress.tryParse(normalized);
  if (parsed != null) {
    if (parsed.type != InternetAddressType.IPv4) {
      throw const FormatException('Voice UDP는 IPv4 주소가 필요합니다.');
    }
    return parsed;
  }
  final addresses = await InternetAddress.lookup(
    normalized,
    type: InternetAddressType.IPv4,
  );
  if (addresses.isEmpty) {
    throw const SocketException('Voice UDP IPv4 주소를 찾을 수 없습니다.');
  }
  return addresses.first;
}
