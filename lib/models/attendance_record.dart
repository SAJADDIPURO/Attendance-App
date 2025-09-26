import 'package:cloud_firestore/cloud_firestore.dart';

enum AttendanceType { checkIn, checkOut }

class AttendanceRecord {
  final String id;
  final String userId;
  final String userName;
  final AttendanceType type;
  final DateTime timestamp;
  final String? photoPath;
  final Map<String, dynamic>? faceData;
  final double? confidence;

  AttendanceRecord({
    required this.id,
    required this.userId,
    required this.userName,
    required this.type,
    required this.timestamp,
    this.photoPath,
    this.faceData,
    this.confidence,
  });

  // Convert AttendanceRecord to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'userName': userName,
      'type': type.toString().split('.').last,
      'timestamp': Timestamp.fromDate(timestamp),
      'photoPath': photoPath,
      'faceData': faceData,
      'confidence': confidence,
    };
  }

  // Create AttendanceRecord from Map (Firestore)
  factory AttendanceRecord.fromMap(Map<String, dynamic> map) {
    return AttendanceRecord(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? '',
      type: AttendanceType.values.firstWhere(
        (e) => e.toString().split('.').last == map['type'],
        orElse: () => AttendanceType.checkIn,
      ),
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      photoPath: map['photoPath'],
      faceData: map['faceData'],
      confidence: map['confidence']?.toDouble(),
    );
  }

  // Create a copy with modified fields
  AttendanceRecord copyWith({
    String? id,
    String? userId,
    String? userName,
    AttendanceType? type,
    DateTime? timestamp,
    String? photoPath,
    Map<String, dynamic>? faceData,
    double? confidence,
  }) {
    return AttendanceRecord(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      type: type ?? this.type,
      timestamp: timestamp ?? this.timestamp,
      photoPath: photoPath ?? this.photoPath,
      faceData: faceData ?? this.faceData,
      confidence: confidence ?? this.confidence,
    );
  }

  @override
  String toString() {
    return 'AttendanceRecord(id: $id, userId: $userId, userName: $userName, type: $type, timestamp: $timestamp)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is AttendanceRecord &&
        other.id == id &&
        other.userId == userId &&
        other.userName == userName &&
        other.type == type &&
        other.timestamp == timestamp;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        userId.hashCode ^
        userName.hashCode ^
        type.hashCode ^
        timestamp.hashCode;
  }
}
