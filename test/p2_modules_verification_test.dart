import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:school_app/data/models/academic_models.dart';
import 'package:school_app/data/models/parent_model.dart';
import 'package:school_app/data/models/user_model.dart';
import 'package:school_app/data/services/parent_service.dart';
import 'package:school_app/data/services/library_service.dart';
import 'package:school_app/data/services/transport_service.dart';
import 'package:school_app/data/repositories/school_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('P2-1: Parent Management Persistence & Verification Tests', () {
    test('createParent creates, serializes, and persists to cache', () async {
      final service = ParentService();
      final parent = await service.createParent(
        schoolId: 'test-school-123',
        name: 'Rajesh Kumar',
        phone: '+91 98765 43210',
        email: 'rajesh@example.com',
        address: 'Flat 402, Sunshine Heights',
      );

      expect(parent.id, isNotEmpty);
      expect(parent.schoolId, equals('test-school-123'));
      expect(parent.name, equals('Rajesh Kumar'));
      expect(parent.phone, equals('+91 98765 43210'));
      expect(parent.parentCode, startsWith('SCH001-PAR-'));
      expect(parent.status, equals(AccountStatus.active));
      expect(parent.linkedStudentsCount, equals(0));

      // Test retrieval
      final fetched = await service.fetchParents(schoolId: 'test-school-123');
      expect(fetched.length, equals(1));
      expect(fetched.first.name, equals('Rajesh Kumar'));

      // Test fresh service instance reading from persistent SharedPreferences cache
      final freshService = ParentService();
      final cachedParents = await freshService.fetchParents(schoolId: 'test-school-123');
      expect(cachedParents.length, equals(1));
      expect(cachedParents.first.parentCode, equals(parent.parentCode));
    });

    test('linkStudentToParent links real student, updates count, and survives restart', () async {
      final service = ParentService();
      final parent = await service.createParent(
        schoolId: 'test-school-123',
        name: 'Sunita Sharma',
        phone: '+91 91234 56789',
      );

      final link = await service.linkStudentToParent(
        schoolId: 'test-school-123',
        parentId: parent.id,
        studentId: 'student-uuid-999',
        studentName: 'Aarav Sharma',
        studentClass: 'Class 9-B',
        admissionNumber: 'ADM-2026-999',
        relationship: 'MOTHER',
      );

      expect(link.id, isNotEmpty);
      expect(link.studentName, equals('Aarav Sharma'));
      expect(link.relationship, equals('MOTHER'));

      final links = await service.getLinkedStudentsForParent(parent.id);
      expect(links.length, equals(1));
      expect(links.first.admissionNumber, equals('ADM-2026-999'));

      // Test duplicate prevention
      expect(
        () => service.linkStudentToParent(
          schoolId: 'test-school-123',
          parentId: parent.id,
          studentId: 'student-uuid-999',
          studentName: 'Aarav Sharma',
          studentClass: 'Class 9-B',
          admissionNumber: 'ADM-2026-999',
        ),
        throwsA(isA<Exception>()),
      );

      // Verify persistence in a fresh service instance
      final freshService = ParentService();
      final freshLinks = await freshService.getLinkedStudentsForParent(parent.id);
      expect(freshLinks.length, equals(1));
      expect(freshLinks.first.studentName, equals('Aarav Sharma'));
    });

    test('verifyParentCode verifies successfully by parentCode and phone', () async {
      final service = ParentService();
      final parent = await service.createParent(
        schoolId: 'test-school-123',
        name: 'Vikram Singh',
        phone: '+91 99887 76655',
      );

      await service.linkStudentToParent(
        schoolId: 'test-school-123',
        parentId: parent.id,
        studentId: 'student-uuid-101',
        studentName: 'Rohan Singh',
        studentClass: 'Class 7-A',
        admissionNumber: 'ADM-2026-101',
      );

      // Verify by parent code
      final resultByCode = await service.verifyParentCode(parent.parentCode);
      expect(resultByCode['success'], isTrue);
      expect((resultByCode['parent'] as ParentModel).name, equals('Vikram Singh'));
      expect((resultByCode['children'] as List).length, equals(1));

      // Verify by phone number
      final resultByPhone = await service.verifyParentCode('+91 99887 76655');
      expect(resultByPhone['success'], isTrue);
      expect((resultByPhone['parent'] as ParentModel).parentCode, equals(parent.parentCode));

      // Invalid code throws Exception
      expect(
        () => service.verifyParentCode('INVALID-CODE-XYZ'),
        throwsA(isA<Exception>()),
      );
    });

    test('unlinkStudentFromParent unlinks child and decrements count', () async {
      final service = ParentService();
      final parent = await service.createParent(
        schoolId: 'test-school-123',
        name: 'Deepak Patel',
        phone: '+91 94444 33333',
      );

      final link = await service.linkStudentToParent(
        schoolId: 'test-school-123',
        parentId: parent.id,
        studentId: 'student-uuid-555',
        studentName: 'Kavya Patel',
        studentClass: 'Class 5-C',
        admissionNumber: 'ADM-2026-555',
      );

      var links = await service.getLinkedStudentsForParent(parent.id);
      expect(links.length, equals(1));

      await service.unlinkStudentFromParent(link.id);
      links = await service.getLinkedStudentsForParent(parent.id);
      expect(links.isEmpty, isTrue);
    });
  });

  group('P2-2: Library Persistence Tests', () {
    test('fetchBooks returns catalog and persists new books across service instances', () async {
      final service = LibraryService();
      final initialBooks = await service.fetchBooks(schoolId: 'test-school-123');
      expect(initialBooks.isNotEmpty, isTrue);

      final added = await service.addBook(
        schoolId: 'test-school-123',
        title: 'Introduction to Algorithms',
        author: 'CLRS',
        isbn: '978-0262033848',
      );

      expect(added.id, isNotEmpty);
      expect(added.title, equals('Introduction to Algorithms'));
      expect(added.status, equals(BookStatus.available));

      // Issue book
      await service.issueBook(
        bookId: added.id,
        studentName: 'Ajay Sharma',
        dueDate: DateTime.now().add(const Duration(days: 14)),
      );

      // Verify in fresh instance
      final freshService = LibraryService();
      final freshBooks = await freshService.fetchBooks(schoolId: 'test-school-123');
      final issuedBook = freshBooks.firstWhere((b) => b.id == added.id);
      expect(issuedBook.status, equals(BookStatus.issued));
      expect(issuedBook.issuedToStudent, equals('Ajay Sharma'));

      // Return book
      await freshService.returnBook(added.id);
      final reloadedBooks = await freshService.fetchBooks(schoolId: 'test-school-123');
      final returnedBook = reloadedBooks.firstWhere((b) => b.id == added.id);
      expect(returnedBook.status, equals(BookStatus.available));
      expect(returnedBook.issuedToStudent, isNull);
    });
  });

  group('P2-3: Transport Persistence Tests', () {
    test('fetchRoutes returns routes and persists new routes across service instances', () async {
      final service = TransportService();
      final initialRoutes = await service.fetchRoutes(schoolId: 'test-school-123');
      expect(initialRoutes.isNotEmpty, isTrue);

      final added = await service.addRoute(
        schoolId: 'test-school-123',
        routeName: 'Route 4 - Western Express',
        busNumber: 'MH-12-GH-9999',
        driverName: 'Harish Rao',
        driverPhone: '+91 98231 99999',
        studentCount: 30,
        stops: ['Station Road', 'Airport Colony', 'School Main Gate'],
      );

      expect(added.id, isNotEmpty);
      expect(added.routeName, equals('Route 4 - Western Express'));
      expect(added.stops.length, equals(3));

      // Verify fresh instance
      final freshService = TransportService();
      final freshRoutes = await freshService.fetchRoutes(schoolId: 'test-school-123');
      final found = freshRoutes.firstWhere((r) => r.id == added.id);
      expect(found.driverName, equals('Harish Rao'));
      expect(found.studentCount, equals(30));

      // Delete route
      await freshService.deleteRoute(added.id);
      final finalRoutes = await freshService.fetchRoutes(schoolId: 'test-school-123');
      expect(finalRoutes.any((r) => r.id == added.id), isFalse);
    });
  });

  group('P2 Integration: SchoolRepository wiring', () {
    test('SchoolRepository getLibraryBooks and getTransportRoutes delegate to services', () async {
      final libraryService = LibraryService();
      final transportService = TransportService();
      final repo = SchoolRepository(
        libraryService: libraryService,
        transportService: transportService,
      );

      final books = await repo.getLibraryBooks();
      expect(books.isNotEmpty, isTrue);

      final routes = await repo.getTransportRoutes();
      expect(routes.isNotEmpty, isTrue);
    });
  });
}
