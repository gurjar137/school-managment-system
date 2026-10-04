import 'dart:async';
import '../models/student_model.dart';
import '../mock/mock_data.dart';

class AttendanceSyncQueueItem {
  final String studentId;
  final AttendanceStatus status;
  final DateTime timestamp;

  AttendanceSyncQueueItem({
    required this.studentId,
    required this.status,
    required this.timestamp,
  });
}

abstract class AttendanceRepository {
  Future<List<StudentModel>> getStudentsForClass(String className, String section);
  Future<bool> updateStudentAttendance(String studentId, AttendanceStatus status);
  Future<bool> saveClassAttendance({
    required String className,
    required String section,
    required Map<String, AttendanceStatus> attendanceMap,
  });
  Future<List<AttendanceSyncQueueItem>> getOfflineSyncQueue();
  Future<bool> syncOfflineQueue();
}

class MockAttendanceRepository implements AttendanceRepository {
  final List<StudentModel> _students = [];
  final List<AttendanceSyncQueueItem> _offlineQueue = [];
  bool isOfflineMode = false;

  @override
  Future<List<StudentModel>> getStudentsForClass(String className, String section) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _students
        .where((s) => s.className == className && s.section == section)
        .toList();
  }

  @override
  Future<bool> updateStudentAttendance(String studentId, AttendanceStatus status) async {
    final index = _students.indexWhere((s) => s.id == studentId);
    if (index != -1) {
      _students[index] = _students[index].copyWith(todayAttendance: status);
      if (isOfflineMode) {
        _offlineQueue.add(AttendanceSyncQueueItem(
          studentId: studentId,
          status: status,
          timestamp: DateTime.now(),
        ));
      }
      return true;
    }
    return false;
  }

  @override
  Future<bool> saveClassAttendance({
    required String className,
    required String section,
    required Map<String, AttendanceStatus> attendanceMap,
  }) async {
    await Future.delayed(const Duration(milliseconds: 500));
    for (var entry in attendanceMap.entries) {
      final index = _students.indexWhere((s) => s.id == entry.key);
      if (index != -1) {
        _students[index] = _students[index].copyWith(todayAttendance: entry.value);
        if (isOfflineMode) {
          _offlineQueue.add(AttendanceSyncQueueItem(
            studentId: entry.key,
            status: entry.value,
            timestamp: DateTime.now(),
          ));
        }
      }
    }
    return true;
  }

  @override
  Future<List<AttendanceSyncQueueItem>> getOfflineSyncQueue() async {
    return List.unmodifiable(_offlineQueue);
  }

  @override
  Future<bool> syncOfflineQueue() async {
    await Future.delayed(const Duration(milliseconds: 800));
    _offlineQueue.clear();
    return true;
  }
}
