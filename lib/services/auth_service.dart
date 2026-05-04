import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../db/database.dart';
import 'app_logger.dart';

class AuthService {
  static const _backupFileName = 'pocketflow_backup.json';
  static const _defaultBackupFolderName = 'PocketFlow Backups';
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

  /// Ensures the app's backup folder is selected in prefs.
  /// If [createIfMissing] is false, returns null when folder does not exist.
  static Future<DriveFolder?> ensureSelectedBackupFolder({
    bool createIfMissing = false,
  }) async {
    final selected = await getSelectedFolder();
    if (selected != null) return selected;

    final folders = await listFolders();
    final existing = folders
        .where((f) => f.name == _defaultBackupFolderName)
        .firstOrNull;

    if (existing != null) {
      await saveSelectedFolder(existing);
      return existing;
    }

    if (!createIfMissing) return null;

    final created = await createFolder(_defaultBackupFolderName);
    await saveSelectedFolder(created);
    return created;
  }

  /// Checks whether the selected folder contains a PocketFlow backup file.
  static Future<bool> hasBackupInSelectedFolder() async {
    final folder = await getSelectedFolder();
    if (folder == null) return false;

    final client = await _getClient();
    if (client == null) return false;

    try {
      final driveApi = drive.DriveApi(client);
      final existing = await driveApi.files.list(
        q: "name='$_backupFileName' and '${folder.id}' in parents and trashed=false",
        spaces: 'drive',
        $fields: 'files(id)',
        pageSize: 1,
      );
      return existing.files != null && existing.files!.isNotEmpty;
    } finally {
      client.close();
    }
  }

  // ── Backup ────────────────────────────────────────────────────────────────

  static Future<String> backup() async {
    AppLogger.backup('backup started', detail: 'folder: ${(await getSelectedFolder())?.name}');
    final client = await _getClient();
    if (client == null) throw Exception('Not signed in');

    // Check WiFi-only preference with connectivity_plus
    final prefs = await SharedPreferences.getInstance();
    final wifiOnly = prefs.getBool('backup_wifi_only') ?? true;
    
    if (wifiOnly) {
      try {
        final connectivityResult = await Connectivity().checkConnectivity();
        
        // Log the connection type
        AppLogger.backup('Connection type', detail: connectivityResult.toString());
        
        // Block if on mobile/cellular data
        if (connectivityResult.contains(ConnectivityResult.mobile)) {
          client.close();
          AppLogger.backup('backup blocked', detail: 'On mobile data, WiFi-only enabled');
          throw Exception('WiFi-only backup is enabled. You are on mobile data. Please connect to WiFi.');
        }
        
        // Also block if no WiFi connection is detected
        if (!connectivityResult.contains(ConnectivityResult.wifi)) {
          client.close();
          AppLogger.backup('backup blocked', detail: 'Not on WiFi, WiFi-only enabled');
          throw Exception('WiFi-only backup is enabled. Please connect to WiFi to create a backup.');
        }
        
        // WiFi confirmed
        AppLogger.backup('WiFi confirmed', detail: 'Proceeding with backup');
        
      } catch (e) {
        client.close();
        if (e.toString().contains('WiFi-only')) {
          rethrow;
        }
        // If we can't determine connection type, block for safety
        AppLogger.backup('backup blocked', detail: 'Connection check failed: ${e.toString()}');
        throw Exception('WiFi-only backup is enabled. Cannot verify WiFi connection. Please connect to WiFi.');
      }
    }

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

    // ── Export feedback and learning data ───────────────────────────────────
    final db = await AppDatabase.db();
    
    // Get parsing feedback (quick thumbs up/down on fields)
    final parsingFeedback = await db.query('parsing_feedback');
    
    // Get detailed user corrections
    final userCorrections = await db.query('user_corrections');
    
    // Get feedback events
    final feedbackEvents = await db.query('feedback_events');
    
    // Get learned merchant normalizations
    final merchantNormRules = await db.query('merchant_normalization_rules');
    
    // Get learned merchant-category mappings
    final merchantCategoryMaps = await db.query('merchant_category_map');

    // Get structural negative feedback samples (used by SmsCorrectionService)
    final smsNegativeSamples = await db.query('sms_negative_samples');

    // Get SMS event ledger for dedupe after restore/rescan
    final smsEvents = await db.query('sms_events');

    // Get learned rule tables (if any user/system updates exist)
    final smsClassificationRules = await db.query('sms_classification_rules');
    final smsRuleIndex = await db.query('sms_rule_index');

    return jsonEncode({
      'exported_at': DateTime.now().toIso8601String(),
      'accounts': accounts.map((a) => a.toMap()).toList(),
      'transactions': transactions.map((t) => t.toMap()).toList(),
      'savings_goals': goals.map((g) => g.toMap()).toList(),
      'recurring_transactions': recurring.map((r) => r.toMap()).toList(),
      // ── FEEDBACK & LEARNING DATA ───────────────────────────────────────
      'parsing_feedback': parsingFeedback,
      'user_corrections': userCorrections,
      'feedback_events': feedbackEvents,
      'merchant_normalization_rules': merchantNormRules,
      'merchant_category_map': merchantCategoryMaps,
      'sms_negative_samples': smsNegativeSamples,
      'sms_events': smsEvents,
      'sms_classification_rules': smsClassificationRules,
      'sms_rule_index': smsRuleIndex,
    });
  }

  static Future<void> _importJson(String json) async {
    final data = jsonDecode(json) as Map<String, dynamic>;
    final d = await AppDatabase.db();

    await d.transaction((txn) async {
      // Delete core data
      await txn.delete('recurring_transactions');
      await txn.delete('transactions');
      await txn.delete('budgets');
      await txn.delete('savings_goals');
      await txn.delete('accounts');
      
      // ── DELETE FEEDBACK & LEARNING DATA ──────────────────────────────────
      await txn.delete('parsing_feedback');
      await txn.delete('user_corrections');
      await txn.delete('feedback_events');
      await txn.delete('merchant_normalization_rules');
      await txn.delete('merchant_category_map');
      await txn.delete('sms_negative_samples');
      await txn.delete('sms_events');
      await txn.delete('sms_rule_index');
      await txn.delete('sms_classification_rules');

      // Restore core data
      for (final a in (data['accounts'] as List? ?? [])) {
        await txn.insert('accounts', Map<String, dynamic>.from(a));
      }
      for (final t in (data['transactions'] as List? ?? [])) {
        await txn.insert('transactions', Map<String, dynamic>.from(t));
      }
      for (final g in (data['savings_goals'] as List? ?? [])) {
        await txn.insert('savings_goals', Map<String, dynamic>.from(g));
      }
      for (final r in (data['recurring_transactions'] as List? ?? [])) {
        await txn.insert(
            'recurring_transactions', Map<String, dynamic>.from(r));
      }
      
      // ── RESTORE FEEDBACK & LEARNING DATA ─────────────────────────────────
      for (final pf in (data['parsing_feedback'] as List? ?? [])) {
        await txn.insert('parsing_feedback', Map<String, dynamic>.from(pf));
      }
      for (final uc in (data['user_corrections'] as List? ?? [])) {
        await txn.insert('user_corrections', Map<String, dynamic>.from(uc));
      }
      for (final fe in (data['feedback_events'] as List? ?? [])) {
        await txn.insert('feedback_events', Map<String, dynamic>.from(fe));
      }
      for (final mnr in (data['merchant_normalization_rules'] as List? ?? [])) {
        await txn.insert('merchant_normalization_rules', Map<String, dynamic>.from(mnr));
      }
      for (final mcm in (data['merchant_category_map'] as List? ?? [])) {
        await txn.insert('merchant_category_map', Map<String, dynamic>.from(mcm));
      }
      for (final sns in (data['sms_negative_samples'] as List? ?? [])) {
        await txn.insert('sms_negative_samples', Map<String, dynamic>.from(sns));
      }
      for (final ev in (data['sms_events'] as List? ?? [])) {
        await txn.insert('sms_events', Map<String, dynamic>.from(ev));
      }
      for (final r in (data['sms_classification_rules'] as List? ?? [])) {
        await txn.insert('sms_classification_rules', Map<String, dynamic>.from(r));
      }
      for (final idx in (data['sms_rule_index'] as List? ?? [])) {
        await txn.insert('sms_rule_index', Map<String, dynamic>.from(idx));
      }

      // Re-apply learned merchant category mappings to historical SMS
      // transactions that were stored as uncategorized.
      await txn.rawUpdate('''
        UPDATE transactions
        SET category = (
          SELECT mcm.category
          FROM merchant_category_map mcm
          WHERE LOWER(TRIM(mcm.merchant)) = LOWER(TRIM(transactions.merchant))
            AND mcm.confidence >= 0.6
          ORDER BY mcm.confidence DESC, mcm.usage_count DESC
          LIMIT 1
        )
        WHERE source_type = 'sms'
          AND deleted_at IS NULL
          AND merchant IS NOT NULL
          AND (
            category IS NULL OR
            category = '' OR
            LOWER(category) = 'uncategorized'
          )
          AND EXISTS (
            SELECT 1
            FROM merchant_category_map mcm2
            WHERE LOWER(TRIM(mcm2.merchant)) = LOWER(TRIM(transactions.merchant))
              AND mcm2.confidence >= 0.6
          )
      ''');
    });
  }
}

// ── Models ────────────────────────────────────────────────────────────────────

class DriveFolder {
  const DriveFolder({required this.id, required this.name, required this.path});
  final String id;
  final String name;
  final String path;
}

class _AuthClient extends http.BaseClient {
  _AuthClient(this._token);
  final String _token;
  final _inner = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers['Authorization'] = 'Bearer $_token';
    return _inner.send(request);
  }

  @override
  void close() => _inner.close();
}
