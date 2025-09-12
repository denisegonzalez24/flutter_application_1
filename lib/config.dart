// lib/config.dart

/// Base del servidor. Para emulador AVD podés usar: ws://10.0.2.2:13001
/// Para dispositivo físico en tu LAN: ws://<IP_DE_TU_PC>:13001
/// Para servidor público TLS: wss://tu-dominio
const String kWsBase = 'wss://node2.liit.com.ar';

/// Path del endpoint WS (si aplica)
const String kWsPath = '/ws';

/// Token (si tu backend lo requiere en Authorization: Bearer)
const String kToken = '123456';
