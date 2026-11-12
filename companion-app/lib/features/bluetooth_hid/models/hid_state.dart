enum HidConnectionStatus {
  disconnected,
  connecting,
  connected,
  disconnecting,
  error,
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
  final String? lastError;

  const HidState({
    this.status = HidConnectionStatus.disconnected,
    this.capability = const HidCapability(),
    this.connectedDeviceAddress,
    this.lastError,
  });

  HidState copyWith({
    HidConnectionStatus? status,
    HidCapability? capability,
    String? connectedDeviceAddress,
    String? lastError,
  }) {
    return HidState(
      status: status ?? this.status,
      capability: capability ?? this.capability,
      connectedDeviceAddress:
          connectedDeviceAddress ?? this.connectedDeviceAddress,
      lastError: lastError ?? this.lastError,
    );
  }
}
