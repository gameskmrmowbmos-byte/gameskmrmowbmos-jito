enum PrinterConnectionType { bluetooth, wifi }

class PrinterConfiguration {
  const PrinterConfiguration({
    required this.id,
    required this.type,
    required this.name,
    this.address,
    this.host,
    this.port = 9100,
  });

  final String id;
  final PrinterConnectionType type;
  final String name;
  final String? address;
  final String? host;
  final int port;

  bool get isBluetooth => type == PrinterConnectionType.bluetooth;

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'name': name,
        if (address != null) 'address': address,
        if (host != null) 'host': host,
        'port': port,
      };

  factory PrinterConfiguration.fromJson(Map<String, dynamic> json) {
    final type = json['type'] == PrinterConnectionType.wifi.name
        ? PrinterConnectionType.wifi
        : PrinterConnectionType.bluetooth;
    return PrinterConfiguration(
      id: json['id']?.toString() ?? '',
      type: type,
      name: json['name']?.toString() ?? '',
      address: json['address']?.toString(),
      host: json['host']?.toString(),
      port: int.tryParse(json['port']?.toString() ?? '') ?? 9100,
    );
  }
}