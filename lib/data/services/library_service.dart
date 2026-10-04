import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/academic_models.dart';
import '../../core/config/supabase_config.dart';
import '../../core/errors/exceptions.dart';

class LibraryService {
  SupabaseClient? get _client {
    try {
      if (SupabaseConfig.isConfigured) {
        return Supabase.instance.client;
      }
    } catch (_) {}
    return null;
  }

  static const String _cacheKey = 'cached_library_books_data';
  final List<LibraryBookModel> _cachedBooks = [];
  bool _isCacheLoaded = false;

  Future<void> _loadCache() async {
    if (_isCacheLoaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString(_cacheKey);
      if (str != null && str.isNotEmpty) {
        final decoded = jsonDecode(str);
        if (decoded is List) {
          _cachedBooks.clear();
          for (final item in decoded) {
            if (item is Map<String, dynamic>) {
              _cachedBooks.add(LibraryBookModel.fromJson(item));
            }
          }
        }
      }
      _isCacheLoaded = true;
    } catch (e) {
      debugPrint('[LibraryService Cache Load Warning]: $e');
    }
  }

  Future<void> _saveCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode(_cachedBooks.map((b) => b.toJson()).toList()));
    } catch (e) {
      debugPrint('[LibraryService Cache Save Warning]: $e');
    }
  }

  Future<String> resolveActiveSchoolId([String? schoolId]) async {
    if (schoolId != null && schoolId.isNotEmpty) return schoolId;
    final client = _client;
    if (client != null && client.auth.currentUser != null) {
      try {
        final profile = await client
            .from('profiles')
            .select('school_id')
            .eq('auth_user_id', client.auth.currentUser!.id)
            .maybeSingle();
        if (profile != null && profile['school_id'] != null && profile['school_id'].toString().isNotEmpty) {
          return profile['school_id'].toString();
        }
      } catch (_) {}
    }
    if (SupabaseConfig.isConfigured) {
      throw const TenantResolutionException('Active school could not be resolved for current user. Please log in again.');
    }
    return 'offline_mock_school';
  }

  Future<List<LibraryBookModel>> fetchBooks({String? schoolId}) async {
    await _loadCache();
    final activeSchoolId = await resolveActiveSchoolId(schoolId);

    if (_client != null && SupabaseConfig.isConfigured) {
      try {
        final data = await _client!
            .from('library_books')
            .select()
            .eq('school_id', activeSchoolId)
            .order('title', ascending: true);

        if (data is List) {
          final liveList = data.map((d) => LibraryBookModel.fromJson(d)).toList();
          _cachedBooks.clear();
          _cachedBooks.addAll(liveList);
          await _saveCache();
          return liveList;
        }
      } catch (e) {
        debugPrint('[LibraryService Supabase Fetch Warning]: $e');
      }
    }

    // If cache is still empty after DB check, initialize seed books so the catalog is ready
    if (_cachedBooks.isEmpty) {
      _seedInitialBooks();
      await _saveCache();
    }

    return List.unmodifiable(_cachedBooks);
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
    await _loadCache();
    final activeSchoolId = await resolveActiveSchoolId(schoolId);
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
          _cachedBooks.add(persisted);
          await _saveCache();
          return persisted;
        }
      } catch (e) {
        debugPrint('[LibraryService Supabase Insert Warning]: $e');
      }
    }

    _cachedBooks.add(newBook);
    await _saveCache();
    return newBook;
  }

  Future<void> issueBook({
    required String bookId,
    required String studentName,
    required DateTime dueDate,
  }) async {
    await _loadCache();
    final idx = _cachedBooks.indexWhere((b) => b.id == bookId);
    if (idx != -1) {
      final old = _cachedBooks[idx];
      _cachedBooks[idx] = LibraryBookModel(
        id: old.id,
        title: old.title,
        author: old.author,
        isbn: old.isbn,
        status: BookStatus.issued,
        issuedToStudent: studentName,
        issueDate: DateTime.now(),
        dueDate: dueDate,
      );
      await _saveCache();
    }

    if (_client != null && SupabaseConfig.isConfigured) {
      try {
        await _client!.from('library_books').update({
          'status': 'issued',
          'issued_to_student': studentName,
          'issue_date': DateTime.now().toIso8601String().split('T').first,
          'due_date': dueDate.toIso8601String().split('T').first,
        }).eq('id', bookId);
      } catch (e) {
        debugPrint('[LibraryService issueBook Supabase Warning]: $e');
      }
    }
  }

  Future<void> returnBook(String bookId) async {
    await _loadCache();
    final idx = _cachedBooks.indexWhere((b) => b.id == bookId);
    if (idx != -1) {
      final old = _cachedBooks[idx];
      _cachedBooks[idx] = LibraryBookModel(
        id: old.id,
        title: old.title,
        author: old.author,
        isbn: old.isbn,
        status: BookStatus.available,
        issuedToStudent: null,
        issueDate: null,
        dueDate: null,
      );
      await _saveCache();
    }

    if (_client != null && SupabaseConfig.isConfigured) {
      try {
        await _client!.from('library_books').update({
          'status': 'available',
          'issued_to_student': null,
          'issue_date': null,
          'due_date': null,
        }).eq('id', bookId);
      } catch (e) {
        debugPrint('[LibraryService returnBook Supabase Warning]: $e');
      }
    }
  }

  void _seedInitialBooks() {
    _cachedBooks.addAll([
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
    ]);
  }
}
