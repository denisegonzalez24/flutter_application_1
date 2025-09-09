class WsMsg {
  static Map<String, dynamic> ackTorch({
    required String id,
    required bool ok,
    String? err,
  }) => {
    'id': id,
    'op': 'torch',
    'ok': ok ? 'true' : 'false',
    if (err != null) 'err': err,
  };

  static Map<String, dynamic> pong({required String id, dynamic ts}) => {
    'id': id,
    'op': 'ping',
    'ok': 'true',
    if (ts != null) 'ts': ts,
  };
}
