enum HidConnectionStatus {
  disconnected,
  connecting,
  connected,
  disconnecting,
  error,
}

class BluetoothDeviceInfo {
  final String name;
  final String address;

  const BluetoothDeviceInfo({required this.name, required this.address});

  factory BluetoothDeviceInfo.fromMap(Map<dynamic, dynamic> map) {
    return BluetoothDeviceInfo(
      name: (map['name'] as String?)?.isNotEmpty == true
          ? map['name'] as String
          : 'Unknown Device',
      address: map['address'] as String? ?? '',
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BluetoothDeviceInfo &&
          runtimeType == other.runtimeType &&
          address == other.address;

  @override
  int get hashCode => address.hashCode;
}

class HidCapability {
  final bool isSupported;
  final bool isEnabled;
  final bool hasProfileProxy;
  final String errorMessage;

  const HidCapability({
    this.isSupported = false,
    this.isEnabled = false,
    this.hasProfileProxy = false,
    this.errorMessage = '',
  });

  factory HidCapability.fromMap(Map<dynamic, dynamic>? map) {
    if (map == null) return const HidCapability();
    return HidCapability(
      isSupported: map['isSupported'] as bool? ?? false,
      isEnabled: map['isEnabled'] as bool? ?? false,
      hasProfileProxy: map['hasProfileProxy'] as bool? ?? false,
      errorMessage: map['errorMessage'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'isSupported': isSupported,
        'isEnabled': isEnabled,
        'hasProfileProxy': hasProfileProxy,
        'errorMessage': errorMessage,
      };
}

class KeyboardSpoofPreset {
  final String id;
  final String displayName;
  final String deviceName;
  final String provider;
  final String description;

  const KeyboardSpoofPreset({
    required this.id,
    required this.displayName,
    required this.deviceName,
    required this.provider,
    required this.description,
  });

  static const logitechMxKeys = KeyboardSpoofPreset(
    id: 'logitech_mx_keys',
    displayName: 'Logitech MX Keys (Universal)',
    deviceName: 'Logitech MX Keys',
    provider: 'Logitech',
    description: 'Logitech MX Keys Advanced Wireless Keyboard',
  );

  static const List<KeyboardSpoofPreset> presets = [
    logitechMxKeys,
    KeyboardSpoofPreset(
      id: 'apple_magic',
      displayName: 'Apple Magic Keyboard',
      deviceName: 'Magic Keyboard',
      provider: 'Apple Inc.',
      description: 'Magic Keyboard with Numeric Keypad',
    ),
    KeyboardSpoofPreset(
      id: 'keychron_k2',
      displayName: 'Keychron K2 Mechanical',
      deviceName: 'Keychron K2',
      provider: 'Keychron',
      description: 'Keychron K2 Wireless Mechanical Keyboard',
    ),
    KeyboardSpoofPreset(
      id: 'dell_kb216',
      displayName: 'Dell KB216 Multimedia',
      deviceName: 'Dell Multimedia Keyboard',
      provider: 'Dell Inc.',
      description: 'Dell KB216 USB/Bluetooth Keyboard',
    ),
    KeyboardSpoofPreset(
      id: 'corsair_k70',
      displayName: 'Corsair K70 RGB Gaming',
      deviceName: 'Corsair K70',
      provider: 'Corsair',
      description: 'Corsair K70 RGB Gaming Keyboard',
    ),
  ];

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KeyboardSpoofPreset &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class HidState {
  final HidConnectionStatus status;
  final HidCapability capability;
  final String? connectedDeviceAddress;
  final List<BluetoothDeviceInfo> bondedDevices;
  final KeyboardSpoofPreset activeSpoof;
  final bool isDiscoverable;
  final String? lastError;

  const HidState({
    this.status = HidConnectionStatus.disconnected,
    this.capability = const HidCapability(),
    this.connectedDeviceAddress,
    this.bondedDevices = const [],
    this.activeSpoof = KeyboardSpoofPreset.logitechMxKeys,
    this.isDiscoverable = false,
    this.lastError,
  });

  HidState copyWith({
    HidConnectionStatus? status,
    HidCapability? capability,
    String? connectedDeviceAddress,
    List<BluetoothDeviceInfo>? bondedDevices,
    KeyboardSpoofPreset? activeSpoof,
    bool? isDiscoverable,
    String? lastError,
  }) {
    return HidState(
      status: status ?? this.status,
      capability: capability ?? this.capability,
      connectedDeviceAddress:
          connectedDeviceAddress ?? this.connectedDeviceAddress,
      bondedDevices: bondedDevices ?? this.bondedDevices,
      activeSpoof: activeSpoof ?? this.activeSpoof,
      isDiscoverable: isDiscoverable ?? this.isDiscoverable,
      lastError: lastError ?? this.lastError,
    );
  }
}
