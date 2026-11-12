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

class HidState {
  final HidConnectionStatus status;
  final HidCapability capability;
  final String? connectedDeviceAddress;
  final List<BluetoothDeviceInfo> bondedDevices;
  final String? lastError;

  const HidState({
    this.status = HidConnectionStatus.disconnected,
    this.capability = const HidCapability(),
    this.connectedDeviceAddress,
    this.bondedDevices = const [],
    this.lastError,
  });

  HidState copyWith({
    HidConnectionStatus? status,
    HidCapability? capability,
    String? connectedDeviceAddress,
    List<BluetoothDeviceInfo>? bondedDevices,
    String? lastError,
  }) {
    return HidState(
      status: status ?? this.status,
      capability: capability ?? this.capability,
      connectedDeviceAddress:
          connectedDeviceAddress ?? this.connectedDeviceAddress,
      bondedDevices: bondedDevices ?? this.bondedDevices,
      lastError: lastError ?? this.lastError,
    );
  }
}
