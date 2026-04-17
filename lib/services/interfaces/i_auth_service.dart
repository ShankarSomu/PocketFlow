/// Interface for authentication service
abstract class IAuthService {
  /// Check if user is signed in
  bool get isSignedIn;

  /// Get current user email
  String? get userEmail;

  /// Sign in with Google
  Future<dynamic> signIn();

  /// Sign out
  Future<void> signOut();

  /// Initialize the service
  Future<void> init();

  /// Create or get backup folder
  Future<dynamic> getOrCreateBackupFolder(String path);

  /// Upload backup
  Future<bool> uploadBackup(String dbPath);

  /// Download backup
  Future<String?> downloadBackup();

  /// List available backups
  Future<List<dynamic>> listBackups();

  /// Auto backup if due
  void autoBackupIfDue();
}
