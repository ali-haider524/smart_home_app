class ChannelModel {
  final String id;
  final bool state;
  final String status;

  ChannelModel({
    required this.id,
    required this.state,
    required this.status,
  });

  factory ChannelModel.fromMap(String id, Map data) {
    return ChannelModel(
      id: id,
      state: data['state'] == true,
      status: data['status']?.toString() ?? 'OFF',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'state': state,
      'status': status,
    };
  }
}