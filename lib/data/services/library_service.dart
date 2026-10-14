import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/academic_models.dart';
import '../../core/config/supabase_config.dart';
import 'tenant_resolver.dart';

class LibraryService {
  final SupabaseClient? _clientOverride;

  LibraryService({SupabaseClient? client}) : _clientOverride = client;

  SupabaseClient? get _client {
    if (_clientOverride != null) return _clientOverride;
    try {
      if (SupabaseConfig.isConfigured) {
        return Supabase.instance.client;
      }
    } catch (_) {}
    return null;
  }

  String _cacheKey(String schoolId) => 'cached_library_books_${schoolId.trim()}';
  final Map<String, List<LibraryBookModel>> _cachedBooksBySchool = {};

  Future<void> _loadCache(String schoolId) async {
    if (schoolId.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString(_cacheKey(schoolId));
      if (str != null && str.isNotEmpty) {
        final decoded = jsonDecode(str);
        if (decoded is List) {
          final list = <LibraryBookModel>[];
          for (final item in decoded) {
            if (item is Map<String, dynamic>) {
              list.add(LibraryBookModel.fromJson(item));
            }
          }
          _cachedBooksBySchool[schoolId] = list;
        }
      }
    } catch (e) {
      debugPrint('[LibraryService Cache Load Warning]: $e');
    }
  }

  Future<void> _saveCache(String schoolId) async {
    if (schoolId.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final books = _cachedBooksBySchool[schoolId] ?? [];
      await prefs.setString(_cacheKey(schoolId), jsonEncode(books.map((b) => b.toJson()).toList()));
    } catch (e) {
      debugPrint('[LibraryService Cache Save Warning]: $e');
    }
  }

  Future<String> resolveActiveSchoolId([String? schoolId]) async {
    return TenantResolver.resolveActiveSchoolId(
      client: _client,
      requestedSchoolId: schoolId,
    );
  }

  Future<List<LibraryBookModel>> fetchBooks({String? schoolId}) async {
    final activeSchoolId = await resolveActiveSchoolId(schoolId);
    await _loadCache(activeSchoolId);

    if (_client != null && SupabaseConfig.isConfigured) {
      try {
        final data = await _client!
            .from('library_books')
            .select()
            .eq('school_id', activeSchoolId)
            .order('title', ascending: true);

        if (data.isNotEmpty) {
          final liveList = data.map((d) => LibraryBookModel.fromJson(d)).toList();
          _cachedBooksBySchool[activeSchoolId] = liveList;
          await _saveCache(activeSchoolId);
          return liveList;
        }

        // Real Supabase mode: return real rows (empty if none exist)
        _cachedBooksBySchool[activeSchoolId] = [];
        await _saveCache(activeSchoolId);
        return [];
      } catch (e) {
        debugPrint('[LibraryService Supabase Fetch Warning]: $e');
        // If genuine offline failure, return tenant cache
        return List.unmodifiable(_cachedBooksBySchool[activeSchoolId] ?? []);
      }
    }

    // Pure offline / unconfigured mock mode ONLY
    final currentCached = _cachedBooksBySchool[activeSchoolId] ?? [];
    if (currentCached.isEmpty) {
      final seeded = _generateSeedBooks();
      _cachedBooksBySchool[activeSchoolId] = seeded;
      await _saveCache(activeSchoolId);
      return seeded;
    }

    return List.unmodifiable(currentCached);
  }

  Future<LibraryBookModel> addBook({
    String? schoolId,
    required String title,
    required String author,
    required String isbn,
    BookStatus status = BookStatus.available,
    String? issuedToStudent,
    DateTime? issueDate,
    DateTime? dueDate,
  }) async {
    final activeSchoolId = await resolveActiveSchoolId(schoolId);
    await _loadCache(activeSchoolId);
    final bookId = 'book_${DateTime.now().millisecondsSinceEpoch}';

    final newBook = LibraryBookModel(
      id: bookId,
      title: title.trim(),
      author: author.trim(),
      isbn: isbn.trim(),
      status: status,
      issuedToStudent: issuedToStudent?.trim(),
      issueDate: issueDate,
      dueDate: dueDate,
    );

    if (_client != null && SupabaseConfig.isConfigured) {
      try {
        final resp = await _client!.from('library_books').insert({
          'school_id': activeSchoolId,
          'title': newBook.title,
          'author': newBook.author,
          'isbn': newBook.isbn,
          'status': newBook.status.name,
          'issued_to_student': newBook.issuedToStudent,
          'issue_date': newBook.issueDate?.toIso8601String().split('T').first,
          'due_date': newBook.dueDate?.toIso8601String().split('T').first,
        }).select().maybeSingle();

        if (resp != null && resp['id'] != null) {
          final persisted = LibraryBookModel.fromJson(resp);
          _cachedBooksBySchool.putIfAbsent(activeSchoolId, () => []).add(persisted);
          await _saveCache(activeSchoolId);
          return persisted;
        }
      } catch (e) {
        debugPrint('[LibraryService Supabase Insert Warning]: $e');
      }
    }

    _cachedBooksBySchool.putIfAbsent(activeSchoolId, () => []).add(newBook);
    await _saveCache(activeSchoolId);
    return newBook;
  }

  Future<void> issueBook({
    String? schoolId,
    required String bookId,
    required String studentName,
    required DateTime dueDate,
  }) async {
    final activeSchoolId = await resolveActiveSchoolId(schoolId);
    await _loadCache(activeSchoolId);
    final books = _cachedBooksBySchool[activeSchoolId] ?? [];
    final idx = books.indexWhere((b) => b.id == bookId);
    if (idx != -1) {
      final old = books[idx];
      books[idx] = LibraryBookModel(
        id: old.id,
        title: old.title,
        author: old.author,
        isbn: old.isbn,
        status: BookStatus.issued,
        issuedToStudent: studentName,
        issueDate: DateTime.now(),
        dueDate: dueDate,
      );
      await _saveCache(activeSchoolId);
    }

    if (_client != null && SupabaseConfig.isConfigured) {
      try {
        await _client!.from('library_books').update({
          'status': 'issued',
          'issued_to_student': studentName,
          'issue_date': DateTime.now().toIso8601String().split('T').first,
          'due_date': dueDate.toIso8601String().split('T').first,
        }).eq('id', bookId).eq('school_id', activeSchoolId);
      } catch (e) {
        debugPrint('[LibraryService issueBook Supabase Warning]: $e');
      }
    }
  }

  Future<void> returnBook(String bookId, {String? schoolId}) async {
    final activeSchoolId = await resolveActiveSchoolId(schoolId);
    await _loadCache(activeSchoolId);
    final books = _cachedBooksBySchool[activeSchoolId] ?? [];
    final idx = books.indexWhere((b) => b.id == bookId);
    if (idx != -1) {
      final old = books[idx];
      books[idx] = LibraryBookModel(
        id: old.id,
        title: old.title,
        author: old.author,
        isbn: old.isbn,
        status: BookStatus.available,
        issuedToStudent: null,
        issueDate: null,
        dueDate: null,
      );
      await _saveCache(activeSchoolId);
    }

    if (_client != null && SupabaseConfig.isConfigured) {
      try {
        await _client!.from('library_books').update({
          'status': 'available',
          'issued_to_student': null,
          'issue_date': null,
          'due_date': null,
        }).eq('id', bookId).eq('school_id', activeSchoolId);
      } catch (e) {
        debugPrint('[LibraryService returnBook Supabase Warning]: $e');
      }
    }
  }

  List<LibraryBookModel> _generateSeedBooks() {
    return [
      LibraryBookModel(
        id: 'bk_001',
        title: 'A Brief History of Time',
        author: 'Stephen Hawking',
        isbn: '978-0553380163',
        status: BookStatus.available,
      ),
      LibraryBookModel(
        id: 'bk_002',
        title: 'To Kill a Mockingbird',
        author: 'Harper Lee',
        isbn: '978-0060935467',
        status: BookStatus.issued,
        issuedToStudent: 'Ajay Sharma',
        issueDate: DateTime.now().subtract(const Duration(days: 10)),
        dueDate: DateTime.now().add(const Duration(days: 4)),
      ),
      LibraryBookModel(
        id: 'bk_003',
        title: 'Concepts of Physics (Vol 1)',
        author: 'H.C. Verma',
        isbn: '978-8177091878',
        status: BookStatus.available,
      ),
      LibraryBookModel(
        id: 'bk_004',
        title: 'The Discovery of India',
        author: 'Jawaharlal Nehru',
        isbn: '978-0143031031',
        status: BookStatus.overdue,
        issuedToStudent: 'Pooja Verma',
        issueDate: DateTime.now().subtract(const Duration(days: 25)),
        dueDate: DateTime.now().subtract(const Duration(days: 5)),
      ),
    ];
  }
}
