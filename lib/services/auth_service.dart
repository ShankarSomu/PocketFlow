import 'dart:convert';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../db/database.dart';
import 'app_logger.dart';

class AuthService {
  static const _backupFileName = 'pocketflow_backup.json';
  static const _driveScope = 'https://www.googleapis.com/auth/drive.file';
  static const _webClientId =
      '280001122541-auoa81jnfns02ee0r63i3730t72uuh6p.apps.googleusercontent.com';
  static const _prefFolderId = 'backup_folder_id';
  static const _prefFolderName = 'backup_folder_name';
  static const _prefFolderPath = 'backup_folder_path';
  static const _prefLastBackup = 'last_backup';
  static const _prefBackupFreq = 'backup_frequency'; // 'manual' | 'daily' | 'hourly'

  static final _googleSignIn = GoogleSignIn(
    scopes: [_driveScope],
    serverClientId: _webClientId,
  );

  static GoogleSignInAccount? _user;
  static GoogleSignInAccount? get currentUser => _user;
  static bool get isSignedIn => _user != null;

  static Future<void> init() async {
    _user = await _googleSignIn.signInSilently();
  }

  static Future<GoogleSignInAccount?> signIn() async {
    try {
      await _googleSignIn.signOut();
      _user = await _googleSignIn.signIn();
      return _user;
    } catch (e) {
      return null;
    }
  }

  static Future<void> signOut() async {
    await _googleSignIn.signOut();
    _user = null;
  }

  static Future<_AuthClient?> _getClient() async {
    final account = _user;
    if (account == null) return null;
    final auth = await account.authentication;
    return _AuthClient(auth.accessToken!);
  }

  // ── Folder management ─────────────────────────────────────────────────────

  /// Lists all folders the app has access to (drive.file scope = only app-created)
  static Future<List<DriveFolder>> listFolders() async {
    final client = await _getClient();
    if (client == null) throw Exception('Not signed in');
    final driveApi = drive.DriveApi(client);

    final result = await driveApi.files.list(
      q: "mimeType='application/vnd.google-apps.folder' and trashed=false",
      spaces: 'drive',
      $fields: 'files(id,name,parents)',
      orderBy: 'name',
      pageSize: 100,
    );

    client.close();
    final files = result.files ?? [];

    // Build folder map for path resolution
    final folderMap = {for (final f in files) f.id!: f};

    return files.map((f) {
      final path = _buildPath(f, folderMap);
      return DriveFolder(id: f.id!, name: f.name!, path: path);
    }).toList();
  }

  static String _buildPath(
      drive.File folder, Map<String, drive.File> folderMap) {
    final parts = <String>[folder.name ?? ''];
    var current = folder;
    int depth = 0;
    while (current.parents != null &&
        current.parents!.isNotEmpty &&
        depth < 5) {
      final parentId = current.parents!.first;
      final parent = folderMap[parentId];
      if (parent == null) break;
      parts.insert(0, parent.name ?? '');
      current = parent;
      depth++;
    }
    return 'My Drive / ${parts.join(' / ')}';
  }

  /// Creates a new folder in Drive root
  static Future<DriveFolder> createFolder(String name,
      {String? parentId}) async {
    final client = await _getClient();
    if (client == null) throw Exception('Not signed in');
    final driveApi = drive.DriveApi(client);

    final folder = drive.File()
      ..name = name
      ..mimeType = 'application/vnd.google-apps.folder';
    if (parentId != null) folder.parents = [parentId];

    final created = await driveApi.files.create(folder,
        $fields: 'id,name,parents');
    client.close();

    final path = parentId != null
        ? 'My Drive / ... / $name'
        : 'My Drive / $name';
    return DriveFolder(id: created.id!, name: created.name!, path: path);
  }

  static Future<void> saveSelectedFolder(DriveFolder folder) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefFolderId, folder.id);
    await prefs.setString(_prefFolderName, folder.name);
    await prefs.setString(_prefFolderPath, folder.path);
  }

  static Future<DriveFolder?> getSelectedFolder() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_prefFolderId);
    final name = prefs.getString(_prefFolderName);
    final path = prefs.getString(_prefFolderPath);
    if (id == null || name == null) return null;
    return DriveFolder(id: id, name: name, path: path ?? 'My Drive / $name');
  }

  static Future<void> clearSelectedFolder() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefFolderId);
    await prefs.remove(_prefFolderName);
    await prefs.remove(_prefFolderPath);
  }

  // ── Backup ────────────────────────────────────────────────────────────────

  static Future<String> backup() async {
    AppLogger.backup('backup started', detail: 'folder: ${(await getSelectedFolder())?.name}');
    final client = await _getClient();
    if (client == null) throw Exception('Not signed in');

    final folder = await getSelectedFolder();
    if (folder == null) throw Exception('No backup folder selected');

    final driveApi = drive.DriveApi(client);
    final data = await _exportJson();
    final bytes = utf8.encode(data);

    final existing = await driveApi.files.list(
      q: "name='$_backupFileName' and '${folder.id}' in parents and trashed=false",
      spaces: 'drive',
      $fields: 'files(id)',
    );

    final media = drive.Media(
      Stream.fromIterable([bytes]),
      bytes.length,
      contentType: 'application/json',
    );

    if (existing.files != null && existing.files!.isNotEmpty) {
      await driveApi.files.update(
        drive.File(),
        existing.files!.first.id!,
        uploadMedia: media,
      );
    } else {
      final file = drive.File()
        ..name = _backupFileName
        ..parents = [folder.id];
      await driveApi.files.create(file, uploadMedia: media);
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefLastBackup, DateTime.now().toIso8601String());
    AppLogger.backup('backup completed', detail: 'folder: ${folder.name}');
    client.close();
    return DateTime.now().toIso8601String();
  }

  // ── Restore ───────────────────────────────────────────────────────────────

  static Future<void> restore() async {
    AppLogger.backup('restore started');
    final client = await _getClient();
    if (client == null) throw Exception('Not signed in');

    final folder = await getSelectedFolder();
    if (folder == null) throw Exception('No backup folder selected');

    final driveApi = drive.DriveApi(client);

    final existing = await driveApi.files.list(
      q: "name='$_backupFileName' and '${folder.id}' in parents and trashed=false",
      spaces: 'drive',
      $fields: 'files(id)',
    );

    if (existing.files == null || existing.files!.isEmpty) {
      throw Exception('No backup found in "${folder.name}"');
    }

    final media = await driveApi.files.get(
      existing.files!.first.id!,
      downloadOptions: drive.DownloadOptions.fullMedia,
    ) as drive.Media;

    final chunks = <int>[];
    await for (final chunk in media.stream) {
      chunks.addAll(chunk);
    }

    await _importJson(utf8.decode(chunks));
    AppLogger.backup('restore completed');
    client.close();
  }

  static Future<void> exportDiagnostics() async {
    final client = await _getClient();
    if (client == null) throw Exception('Not signed in');
    final folder = await getSelectedFolder();
    if (folder == null) throw Exception('No backup folder selected');

    final driveApi = drive.DriveApi(client);
    final text = AppLogger.exportText();
    final bytes = utf8.encode(text);
    final fileName = 'pocketflow_diagnostics_${DateTime.now().toIso8601String().substring(0,10)}.txt';

    final existing = await driveApi.files.list(
      q: "name='$fileName' and '${folder.id}' in parents and trashed=false",
      spaces: 'drive',
      $fields: 'files(id)',
    );

    final media = drive.Media(
      Stream.fromIterable([bytes]),
      bytes.length,
      contentType: 'text/plain',
    );

    if (existing.files != null && existing.files!.isNotEmpty) {
      await driveApi.files.update(
          drive.File(), existing.files!.first.id!, uploadMedia: media);
    } else {
      final file = drive.File()
        ..name = fileName
        ..parents = [folder.id];
      await driveApi.files.create(file, uploadMedia: media);
    }
    AppLogger.backup('diagnostics exported', detail: fileName);
    client.close();
  }

  static Future<String?> lastBackupTime() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefLastBackup);
  }

  static Future<String> getBackupFrequency() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefBackupFreq) ?? 'daily';
  }

  static Future<void> setBackupFrequency(String freq) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefBackupFreq, freq);
  }

  /// Call on app start — auto-backup if due based on frequency
  static Future<void> autoBackupIfDue() async {
    if (!isSignedIn) return;
    final folder = await getSelectedFolder();
    if (folder == null) return;
    final freq = await getBackupFrequency();
    if (freq == 'manual') return;

    final lastStr = await lastBackupTime();
    if (lastStr == null) {
      await backup();
      return;
    }
    final last = DateTime.parse(lastStr);
    final now = DateTime.now();
    final diff = now.difference(last);
    final isDue = freq == 'hourly'
        ? diff.inHours >= 1
        : freq == 'weekly'
            ? diff.inDays >= 7
            : freq == 'monthly'
                ? diff.inDays >= 30
                : diff.inHours >= 24; // daily (default)
    if (isDue) await backup();
  }

  // ── JSON export/import ────────────────────────────────────────────────────

  static Future<String> _exportJson() async {
    final accounts = await AppDatabase.getAccounts();
    final transactions = await AppDatabase.getTransactions();
    final goals = await AppDatabase.getGoals();
    final recurring = await AppDatabase.getRecurring();

    return jsonEncode({
      'exported_at': DateTime.now().toIso8601String(),
      'accounts': accounts.map((a) => a.toMap()).toList(),
      'transactions': transactions.map((t) => t.toMap()).toList(),
      'savings_goals': goals.map((g) => g.toMap()).toList(),
      'recurring_transactions': recurring.map((r) => r.toMap()).toList(),
    });
  }

  static Future<void> _importJson(String json) async {
    final data = jsonDecode(json) as Map<String, dynamic>;
    final d = await AppDatabase.db;

    await d.transaction((txn) async {
      await txn.delete('recurring_transactions');
      await txn.delete('transactions');
      await txn.delete('budgets');
      await txn.delete('savings_goals');
      await txn.delete('accounts');

      for (final a in (data['accounts'] as List)) {
        await txn.insert('accounts', Map<String, dynamic>.from(a));
      }
      for (final t in (data['transactions'] as List)) {
        await txn.insert('transactions', Map<String, dynamic>.from(t));
      }
      for (final g in (data['savings_goals'] as List)) {
        await txn.insert('savings_goals', Map<String, dynamic>.from(g));
      }
      for (final r in (data['recurring_transactions'] as List)) {
        await txn.insert(
            'recurring_transactions', Map<String, dynamic>.from(r));
      }
    });
  }
}

// ── Models ────────────────────────────────────────────────────────────────────

class DriveFolder {
  final String id;
  final String name;
  final String path;
  const DriveFolder({required this.id, required this.name, required this.path});
}

class _AuthClient extends http.BaseClient {
  final String _token;
  final _inner = http.Client();
  _AuthClient(this._token);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers['Authorization'] = 'Bearer $_token';
    return _inner.send(request);
  }

  @override
  void close() => _inner.close();
}
