import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/services/timetable_service.dart';

final timetableServiceProvider = Provider<TimetableService>((ref) {
  return TimetableService();
});

enum TimetableGridViewMode {
  weekly,
  daily,
}

class TimetableFilterState {
  final String? academicYearId;
  final String? classId;
  final String? sectionId;
  final String? teacherId;
  final int? selectedDayOfWeek; // 1..6, or null for all
  final TimetableGridViewMode viewMode;
  final String searchQuery;

  const TimetableFilterState({
    this.academicYearId,
    this.classId,
    this.sectionId,
    this.teacherId,
    this.selectedDayOfWeek,
    this.viewMode = TimetableGridViewMode.weekly,
    this.searchQuery = '',
  });

  TimetableFilterState copyWith({
    String? academicYearId,
    String? classId,
    String? sectionId,
    String? teacherId,
    int? selectedDayOfWeek,
    bool clearSelectedDay = false,
    TimetableGridViewMode? viewMode,
    String? searchQuery,
  }) {
    return TimetableFilterState(
      academicYearId: academicYearId ?? this.academicYearId,
      classId: classId ?? this.classId,
      sectionId: sectionId ?? this.sectionId,
      teacherId: teacherId ?? this.teacherId,
      selectedDayOfWeek: clearSelectedDay ? null : (selectedDayOfWeek ?? this.selectedDayOfWeek),
      viewMode: viewMode ?? this.viewMode,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

class TimetableFilterNotifier extends StateNotifier<TimetableFilterState> {
  TimetableFilterNotifier() : super(const TimetableFilterState());

  void setAcademicYear(String? yearId) {
    state = state.copyWith(academicYearId: yearId);
  }

  void setClassAndSection(String? classId, String? sectionId) {
    state = state.copyWith(classId: classId, sectionId: sectionId);
  }

  void setTeacher(String? teacherId) {
    state = state.copyWith(teacherId: teacherId);
  }

  void setDayOfWeek(int? day) {
    if (day == null) {
      state = state.copyWith(clearSelectedDay: true);
    } else {
      state = state.copyWith(selectedDayOfWeek: day);
    }
  }

  void setViewMode(TimetableGridViewMode mode) {
    state = state.copyWith(viewMode: mode);
  }

  void setSearchQuery(String q) {
    state = state.copyWith(searchQuery: q);
  }
}

final timetableFilterProvider = StateNotifierProvider<TimetableFilterNotifier, TimetableFilterState>((ref) {
  return TimetableFilterNotifier();
});
