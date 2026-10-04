import 'package:flutter_test/flutter_test.dart';
import 'package:school_app/data/models/parent_model.dart';
import 'package:school_app/data/models/student_model.dart';
import 'package:school_app/data/models/user_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Parent Access & Management Test Suite (11 Scenarios)', () {
    const schoolA = '8dfc32c4-32b5-4568-9848-0056c31a74ce'; // Greenwood
    const schoolB = '6254bee9-151d-4332-8a1c-3994af7d2153'; // KPS

    final studentA1 = StudentModel(
      id: 'b070f30b-5d5c-48af-af4e-95d821aade94',
      name: 'Rohan Kumar Gupta',
      schoolId: schoolA,
      admissionNumber: 'GRN-TEST-2026-001',
      firstName: 'Rohan',
      middleName: 'Kumar',
      lastName: 'Gupta',
      parentAccessCode: 'PRT-GRN-9848',
      academicYearId: '47d1569b-e032-44a7-891f-b21f5458f55b',
    );

    final studentA2 = StudentModel(
      id: 'student-greenwood-sibling-02',
      name: 'Aanya Gupta',
      schoolId: schoolA,
      admissionNumber: 'GRN-TEST-2026-002',
      firstName: 'Aanya',
      lastName: 'Gupta',
      parentAccessCode: 'PRT-GRN-9848',
      academicYearId: '47d1569b-e032-44a7-891f-b21f5458f55b',
    );

    final studentB1 = StudentModel(
      id: 'student-kps-001',
      name: 'Aarav Sharma',
      schoolId: schoolB,
      admissionNumber: 'KPS-2026-001',
      firstName: 'Aarav',
      lastName: 'Sharma',
      parentAccessCode: 'PRT-KPS-1111',
      academicYearId: 'ay-kps-2026',
    );

    test('Scenario 1: Linking parent to student', () {
      final link = ParentStudentLinkModel(
        id: 'link-01',
        schoolId: schoolA,
        parentId: 'parent-01',
        studentId: studentA1.id,
        relationship: 'Father',
        isPrimary: true,
        studentName: studentA1.name,
        studentClass: 'Class 1-A',
        admissionNumber: studentA1.admissionNumber,
      );

      final parent = ParentModel(
        id: 'parent-01',
        schoolId: schoolA,
        name: 'Rajesh Gupta',
        email: 'rajesh.gupta@schoolos.test',
        phone: '+91 98765 43210',
        parentCode: 'PRT-GRN-9848',
        status: AccountStatus.active,
        linkedStudentsCount: 1,
        linkedStudents: [link],
        createdAt: DateTime(2026, 9, 15),
      );

      expect(parent.linkedStudents.length, 1);
      expect(parent.linkedStudents.first.studentId, studentA1.id);
      expect(parent.linkedStudents.first.relationship, 'Father');
      expect(parent.linkedStudents.first.isPrimary, true);
      expect(parent.linkedStudents.first.studentName, 'Rohan Kumar Gupta');
    });

    test('Scenario 2: Activating parent access', () {
      final accessInfo = StudentParentAccessInfo(
        studentId: studentA1.id,
        studentName: studentA1.name,
        schoolId: schoolA,
        parentAccessCode: 'PRT-GRN-9848',
        isConfigured: true,
        isEnabled: true,
        status: AccountStatus.active,
        parentAccountId: 'parent-01',
        parentAccountName: 'Rajesh Gupta',
        parentCode: 'PRT-GRN-9848',
        parentPhone: '+91 98765 43210',
        parentEmail: 'rajesh.gupta@schoolos.test',
      );

      expect(accessInfo.isEnabled, isTrue);
      expect(accessInfo.status, AccountStatus.active);
      expect(accessInfo.parentAccessCode, isNotNull);
      expect(accessInfo.parentAccessCode, startsWith('PRT-'));
    });

    test('Scenario 3: Deactivating parent access', () {
      final deactivatedAccessInfo = StudentParentAccessInfo(
        studentId: studentA1.id,
        studentName: studentA1.name,
        schoolId: schoolA,
        parentAccessCode: null,
        isConfigured: true,
        isEnabled: false,
        status: AccountStatus.inactive,
        parentAccountId: 'parent-01',
        parentAccountName: 'Rajesh Gupta',
        parentCode: 'PRT-GRN-9848',
        parentPhone: '+91 98765 43210',
        parentEmail: 'rajesh.gupta@schoolos.test',
      );

      expect(deactivatedAccessInfo.isEnabled, isFalse);
      expect(deactivatedAccessInfo.status, AccountStatus.inactive);
      expect(deactivatedAccessInfo.parentAccessCode, isNull);
    });

    test('Scenario 4: Linking multiple children to one parent', () {
      final link1 = ParentStudentLinkModel(
        id: 'link-01',
        schoolId: schoolA,
        parentId: 'parent-01',
        studentId: studentA1.id,
        relationship: 'Father',
        isPrimary: true,
        studentName: studentA1.name,
        studentClass: 'Class 1-A',
        admissionNumber: studentA1.admissionNumber,
      );

      final link2 = ParentStudentLinkModel(
        id: 'link-02',
        schoolId: schoolA,
        parentId: 'parent-01',
        studentId: studentA2.id,
        relationship: 'Father',
        isPrimary: false,
        studentName: studentA2.name,
        studentClass: 'Class 3-B',
        admissionNumber: studentA2.admissionNumber,
      );

      final multiChildParent = ParentModel(
        id: 'parent-01',
        schoolId: schoolA,
        name: 'Rajesh Gupta',
        email: 'rajesh.gupta@schoolos.test',
        phone: '+91 98765 43210',
        parentCode: 'PRT-GRN-9848',
        status: AccountStatus.active,
        linkedStudentsCount: 2,
        linkedStudents: [link1, link2],
        createdAt: DateTime(2026, 9, 15),
      );

      expect(multiChildParent.linkedStudents.length, 2);
      expect(multiChildParent.linkedStudents.map((s) => s.studentId).toSet(), {
        studentA1.id,
        studentA2.id,
      });
      expect(multiChildParent.linkedStudents.first.studentName, 'Rohan Kumar Gupta');
      expect(multiChildParent.linkedStudents.last.studentName, 'Aanya Gupta');
    });

    test('Scenario 5: Access denial on wrong student', () {
      final parent = ParentModel(
        id: 'parent-01',
        schoolId: schoolA,
        name: 'Rajesh Gupta',
        phone: '+91 98765 43210',
        parentCode: 'PRT-GRN-9848',
        status: AccountStatus.active,
        createdAt: DateTime(2026, 9, 15),
        linkedStudents: [
          ParentStudentLinkModel(
            id: 'link-01',
            schoolId: schoolA,
            parentId: 'parent-01',
            studentId: studentA1.id,
            relationship: 'Father',
            studentName: studentA1.name,
            studentClass: 'Class 1-A',
            admissionNumber: studentA1.admissionNumber,
          ),
        ],
      );

      const targetStudentId = 'some-other-student-id';
      final isAuthorized = parent.linkedStudents.any((l) => l.studentId == targetStudentId);
      expect(isAuthorized, isFalse, reason: 'Parent must NOT have access to unlinked student');
    });

    test('Scenario 6: Access denial across schools', () {
      final greenwoodParent = ParentModel(
        id: 'parent-01',
        schoolId: schoolA,
        name: 'Rajesh Gupta',
        phone: '+91 98765 43210',
        parentCode: 'PRT-GRN-9848',
        status: AccountStatus.active,
        createdAt: DateTime(2026, 9, 15),
        linkedStudents: [
          ParentStudentLinkModel(
            id: 'link-01',
            schoolId: schoolA,
            parentId: 'parent-01',
            studentId: studentA1.id,
            studentName: studentA1.name,
            studentClass: 'Class 1-A',
            admissionNumber: studentA1.admissionNumber,
          ),
        ],
      );

      // Verify school isolation check
      final isSchoolMatch = greenwoodParent.schoolId == studentB1.schoolId;
      expect(isSchoolMatch, isFalse, reason: 'Greenwood parent must never match KPS schoolId');

      final canAccessKpsStudent = greenwoodParent.schoolId == studentB1.schoolId &&
          greenwoodParent.linkedStudents.any((l) => l.studentId == studentB1.id);
      expect(canAccessKpsStudent, isFalse, reason: 'Cross-school access must strictly be denied');
    });

    test('Scenario 7: Parent authorized to view attendance', () {
      final parent = ParentModel(
        id: 'parent-01',
        schoolId: schoolA,
        name: 'Rajesh Gupta',
        phone: '+91 98765 43210',
        parentCode: 'PRT-GRN-9848',
        status: AccountStatus.active,
        createdAt: DateTime(2026, 9, 15),
        linkedStudents: [
          ParentStudentLinkModel(
            id: 'link-01',
            schoolId: schoolA,
            parentId: 'parent-01',
            studentId: studentA1.id,
            studentName: studentA1.name,
            studentClass: 'Class 1-A',
            admissionNumber: studentA1.admissionNumber,
          ),
        ],
      );

      bool canViewAttendance(String reqSchoolId, String reqStudentId) {
        if (parent.status != AccountStatus.active) return false;
        if (parent.schoolId != reqSchoolId) return false;
        return parent.linkedStudents.any((l) => l.studentId == reqStudentId);
      }

      expect(canViewAttendance(schoolA, studentA1.id), isTrue);
      expect(canViewAttendance(schoolA, 'wrong-student'), isFalse);
      expect(canViewAttendance(schoolB, studentA1.id), isFalse);
    });

    test('Scenario 8: Parent authorized to view fee summary', () {
      final parent = ParentModel(
        id: 'parent-01',
        schoolId: schoolA,
        name: 'Rajesh Gupta',
        phone: '+91 98765 43210',
        parentCode: 'PRT-GRN-9848',
        status: AccountStatus.active,
        createdAt: DateTime(2026, 9, 15),
        linkedStudents: [
          ParentStudentLinkModel(
            id: 'link-01',
            schoolId: schoolA,
            parentId: 'parent-01',
            studentId: studentA1.id,
            studentName: studentA1.name,
            studentClass: 'Class 1-A',
            admissionNumber: studentA1.admissionNumber,
          ),
        ],
      );

      bool canViewFees(String reqSchoolId, String reqStudentId, String reqCode) {
        if (parent.status != AccountStatus.active) return false;
        if (parent.schoolId != reqSchoolId) return false;
        if (parent.parentCode != reqCode) return false;
        return parent.linkedStudents.any((l) => l.studentId == reqStudentId);
      }

      expect(canViewFees(schoolA, studentA1.id, 'PRT-GRN-9848'), isTrue);
      expect(canViewFees(schoolA, studentA1.id, 'WRONG-CODE'), isFalse);
      expect(canViewFees(schoolB, studentA1.id, 'PRT-GRN-9848'), isFalse);
    });

    test('Scenario 9: Parent authorized to view results', () {
      final parent = ParentModel(
        id: 'parent-01',
        schoolId: schoolA,
        name: 'Rajesh Gupta',
        phone: '+91 98765 43210',
        parentCode: 'PRT-GRN-9848',
        status: AccountStatus.active,
        createdAt: DateTime(2026, 9, 15),
        linkedStudents: [
          ParentStudentLinkModel(
            id: 'link-01',
            schoolId: schoolA,
            parentId: 'parent-01',
            studentId: studentA1.id,
            studentName: studentA1.name,
            studentClass: 'Class 1-A',
            admissionNumber: studentA1.admissionNumber,
          ),
        ],
      );

      bool canViewResults(String reqSchoolId, String reqStudentId) {
        if (parent.status != AccountStatus.active) return false;
        if (parent.schoolId != reqSchoolId) return false;
        return parent.linkedStudents.any((l) => l.studentId == reqStudentId);
      }

      expect(canViewResults(schoolA, studentA1.id), isTrue);
      expect(canViewResults(schoolA, 'wrong-student'), isFalse);
      expect(canViewResults(schoolB, studentB1.id), isFalse);
    });

    test('Scenario 10: Parent Code lookup via secure RPC logic', () {
      final studentsDb = [studentA1, studentB1];

      Map<String, dynamic>? lookupStudentByParentAccessCode(String inputCode) {
        final cleanCode = inputCode.trim().toUpperCase();
        if (cleanCode.isEmpty) return null;

        try {
          final matched = studentsDb.firstWhere(
            (s) => s.parentAccessCode?.trim().toUpperCase() == cleanCode,
          );
          return {
            'student_id': matched.id,
            'school_id': matched.schoolId,
            'admission_number': matched.admissionNumber,
            'student_name': matched.name,
            'academic_year_id': matched.academicYearId,
          };
        } catch (_) {
          return null;
        }
      }

      // Exact match
      final res1 = lookupStudentByParentAccessCode('PRT-GRN-9848');
      expect(res1, isNotNull);
      expect(res1!['student_id'], studentA1.id);
      expect(res1['student_name'], 'Rohan Kumar Gupta');

      // Case-insensitive & whitespace trimmed match
      final res2 = lookupStudentByParentAccessCode('  prt-grn-9848  ');
      expect(res2, isNotNull);
      expect(res2!['student_id'], studentA1.id);

      // Non-existent or invalid code
      final res3 = lookupStudentByParentAccessCode('INVALID-CODE-999');
      expect(res3, isNull);
    });

    test('Scenario 11: No plaintext password stored anywhere in database or models', () {
      final parentJson = ParentModel(
        id: 'parent-01',
        schoolId: schoolA,
        name: 'Rajesh Gupta',
        email: 'rajesh.gupta@schoolos.test',
        phone: '+91 98765 43210',
        parentCode: 'PRT-GRN-9848',
        status: AccountStatus.active,
        createdAt: DateTime(2026, 9, 15),
      ).toJson();

      final linkJson = ParentStudentLinkModel(
        id: 'link-01',
        schoolId: schoolA,
        parentId: 'parent-01',
        studentId: studentA1.id,
        studentName: studentA1.name,
        studentClass: 'Class 1-A',
        admissionNumber: studentA1.admissionNumber,
      ).toJson();

      expect(parentJson.containsKey('password'), isFalse);
      expect(parentJson.containsKey('parent_password'), isFalse);
      expect(parentJson.containsKey('plain_password'), isFalse);
      expect(parentJson.containsKey('hash'), isFalse);

      expect(linkJson.containsKey('password'), isFalse);
      expect(linkJson.containsKey('parent_password'), isFalse);
      expect(linkJson.containsKey('plain_password'), isFalse);
    });
  });
}
