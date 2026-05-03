import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';

/// ML Model Download and Update Manager
/// 
/// Handles:
/// 1. First-time model download after app install
/// 2. Model version checking and updates
/// 3. Fallback to bundled model if download fails
/// 4. Model integrity verification (checksum)
/// 5. Storage management
/// 
/// Model Repository Structure:
/// ```
/// https://your-cdn.com/models/
/// ├── manifest.json          # Version info and checksums
/// ├── sms_parser_llm_v1.0.0.tflite
/// ├── sms_parser_llm_v1.1.0.tflite
/// ├── sms_parser_tokenizer_v1.0.0.json
/// └── sms_parser_tokenizer_v1.1.0.json
/// ```
class MlModelManager {
  // Model CDN/Server URLs
  static const String _baseUrl = 'https://your-cdn.com/models'; // TODO: Replace with actual CDN
  static const String _manifestUrl = '$_baseUrl/manifest.json';
  
  // Local paths
  static const String _modelsDirName = 'ml_models';
  static const String _modelFileName = 'sms_parser_llm.tflite';
  static const String _tokenizerFileName = 'sms_parser_tokenizer.json';
  
  // SharedPreferences keys
  static const String _keyCurrentVersion = 'ml_model_version';
  static const String _keyLastCheckTime = 'ml_model_last_check';
  static const String _keyModelChecksum = 'ml_model_checksum';
  
  /// Download model on first app launch
  /// 
  /// Returns:
  /// - true: Model downloaded successfully
  /// - false: Download failed, will use bundled model
  static Future<bool> downloadModelIfNeeded() async {
    try {
      print('[ML Manager] Checking if model download needed...');
      
      // Check if model already exists
      final modelsDir = await _getModelsDirectory();
      final modelFile = File('${modelsDir.path}/$_modelFileName');
      final tokenizerFile = File('${modelsDir.path}/$_tokenizerFileName');
      
      if (await modelFile.exists() && await tokenizerFile.exists()) {
        print('[ML Manager] Model already exists locally');
        return true;
      }
      
      print('[ML Manager] Model not found, initiating download...');
      
      // Download model
      return await downloadLatestModel();
      
    } catch (e) {
      print('❌ [ML Manager] Download check failed: $e');
      return false;
    }
  }
  
  /// Download the latest model from server
  static Future<bool> downloadLatestModel({
    Function(double)? onProgress,
  }) async {
    try {
      print('[ML Manager] Fetching manifest...');
      
      // 1. Fetch manifest to get latest version
      final manifest = await _fetchManifest();
      if (manifest == null) {
        print('❌ [ML Manager] Failed to fetch manifest');
        return false;
      }
      
      final latestVersion = manifest['latest_version'] as String;
      final modelInfo = manifest['models'][latestVersion] as Map<String, dynamic>;
      final modelUrl = modelInfo['model_url'] as String;
      final tokenizerUrl = modelInfo['tokenizer_url'] as String;
      final modelChecksum = modelInfo['model_checksum'] as String;
      final tokenizerChecksum = modelInfo['tokenizer_checksum'] as String;
      
      print('[ML Manager] Latest version: $latestVersion');
      
      // 2. Get download directory
      final modelsDir = await _getModelsDirectory();
      await modelsDir.create(recursive: true);
      
      final modelFile = File('${modelsDir.path}/$_modelFileName');
      final tokenizerFile = File('${modelsDir.path}/$_tokenizerFileName');
      
      // 3. Download model file
      print('[ML Manager] Downloading model from $modelUrl...');
      final modelDownloaded = await _downloadFile(
        modelUrl,
        modelFile,
        expectedChecksum: modelChecksum,
        onProgress: (progress) => onProgress?.call(progress * 0.7), // 70% of total
      );
      
      if (!modelDownloaded) {
        print('❌ [ML Manager] Model download failed');
        return false;
      }
      
      // 4. Download tokenizer file
      print('[ML Manager] Downloading tokenizer from $tokenizerUrl...');
      final tokenizerDownloaded = await _downloadFile(
        tokenizerUrl,
        tokenizerFile,
        expectedChecksum: tokenizerChecksum,
        onProgress: (progress) => onProgress?.call(0.7 + progress * 0.3), // Last 30%
      );
      
      if (!tokenizerDownloaded) {
        print('❌ [ML Manager] Tokenizer download failed');
        await modelFile.delete(); // Clean up
        return false;
      }
      
      // 5. Save version info
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyCurrentVersion, latestVersion);
      await prefs.setString(_keyModelChecksum, modelChecksum);
      await prefs.setInt(_keyLastCheckTime, DateTime.now().millisecondsSinceEpoch);
      
      print('✅ [ML Manager] Model downloaded successfully: $latestVersion');
      onProgress?.call(1.0);
      
      return true;
      
    } catch (e) {
      print('❌ [ML Manager] Download failed: $e');
      return false;
    }
  }
  
  /// Check for model updates (run periodically)
  static Future<bool> checkForUpdates() async {
    try {
      // Check if we've checked recently (avoid excessive checks)
      final prefs = await SharedPreferences.getInstance();
      final lastCheck = prefs.getInt(_keyLastCheckTime) ?? 0;
      final hoursSinceLastCheck = 
          (DateTime.now().millisecondsSinceEpoch - lastCheck) / 1000 / 60 / 60;
      
      if (hoursSinceLastCheck < 24) {
        print('[ML Manager] Update check skipped (checked $hoursSinceLastCheck hours ago)');
        return false;
      }
      
      print('[ML Manager] Checking for updates...');
      
      // Fetch manifest
      final manifest = await _fetchManifest();
      if (manifest == null) return false;
      
      final latestVersion = manifest['latest_version'] as String;
      final currentVersion = prefs.getString(_keyCurrentVersion);
      
      if (currentVersion == null) {
        print('[ML Manager] No local version, update needed');
        return true;
      }
      
      // Compare versions
      if (_isNewerVersion(latestVersion, currentVersion)) {
        print('[ML Manager] Update available: $currentVersion → $latestVersion');
        return true;
      }
      
      print('[ML Manager] Model is up to date: $currentVersion');
      await prefs.setInt(_keyLastCheckTime, DateTime.now().millisecondsSinceEpoch);
      
      return false;
      
    } catch (e) {
      print('❌ [ML Manager] Update check failed: $e');
      return false;
    }
  }
  
  /// Fetch model manifest from server
  static Future<Map<String, dynamic>?> _fetchManifest() async {
    try {
      final response = await http.get(
        Uri.parse(_manifestUrl),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode != 200) {
        print('❌ [ML Manager] Manifest fetch failed: ${response.statusCode}');
        return null;
      }
      
      return jsonDecode(response.body) as Map<String, dynamic>;
      
    } catch (e) {
      print('❌ [ML Manager] Manifest fetch error: $e');
      return null;
    }
  }
  
  /// Download file with progress and checksum verification
  static Future<bool> _downloadFile(
    String url,
    File destinationFile,
    {
      String? expectedChecksum,
      Function(double)? onProgress,
    }
  ) async {
    try {
      final request = await HttpClient().getUrl(Uri.parse(url));
      final response = await request.close();
      
      if (response.statusCode != 200) {
        print('❌ [ML Manager] Download failed: ${response.statusCode}');
        return false;
      }
      
      // Get total size
      final totalBytes = response.contentLength;
      int downloadedBytes = 0;
      
      // Download with progress
      final sink = destinationFile.openWrite();
      final digestSink = md5.startChunkedConversion(AccumulatorSink<Digest>());
      
      await for (final chunk in response) {
        sink.add(chunk);
        digestSink.add(chunk);
        
        downloadedBytes += chunk.length;
        if (totalBytes > 0) {
          final progress = downloadedBytes / totalBytes;
          onProgress?.call(progress);
        }
      }
      
      await sink.close();
      digestSink.close();
      
      // Verify checksum if provided
      if (expectedChecksum != null) {
        final actualChecksum = (digestSink as dynamic).inner.digest.toString();
        if (actualChecksum != expectedChecksum) {
          print('❌ [ML Manager] Checksum mismatch!');
          print('   Expected: $expectedChecksum');
          print('   Actual:   $actualChecksum');
          await destinationFile.delete();
          return false;
        }
        print('✅ [ML Manager] Checksum verified');
      }
      
      return true;
      
    } catch (e) {
      print('❌ [ML Manager] File download error: $e');
      return false;
    }
  }
  
  /// Get models directory
  static Future<Directory> _getModelsDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    return Directory('${appDir.path}/$_modelsDirName');
  }
  
  /// Compare version strings (semantic versioning)
  static bool _isNewerVersion(String newVer, String currentVer) {
    final newParts = newVer.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final currentParts = currentVer.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    
    for (int i = 0; i < 3; i++) {
      final newPart = i < newParts.length ? newParts[i] : 0;
      final currentPart = i < currentParts.length ? currentParts[i] : 0;
      
      if (newPart > currentPart) return true;
      if (newPart < currentPart) return false;
    }
    
    return false; // Versions are equal
  }
  
  /// Get current model version info
  static Future<Map<String, dynamic>> getVersionInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final modelsDir = await _getModelsDirectory();
    final modelFile = File('${modelsDir.path}/$_modelFileName');
    
    int? modelSize;
    if (await modelFile.exists()) {
      modelSize = await modelFile.length();
    }
    
    return {
      'version': prefs.getString(_keyCurrentVersion) ?? 'bundled',
      'last_check': prefs.getInt(_keyLastCheckTime),
      'model_size_mb': modelSize != null ? (modelSize / 1024 / 1024).toStringAsFixed(2) : null,
      'has_local_model': await modelFile.exists(),
    };
  }
  
  /// Delete downloaded model (free up space)
  static Future<void> deleteDownloadedModel() async {
    try {
      final modelsDir = await _getModelsDirectory();
      if (await modelsDir.exists()) {
        await modelsDir.delete(recursive: true);
        print('✅ [ML Manager] Downloaded model deleted');
      }
      
      // Clear preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyCurrentVersion);
      await prefs.remove(_keyLastCheckTime);
      await prefs.remove(_keyModelChecksum);
      
    } catch (e) {
      print('❌ [ML Manager] Delete failed: $e');
    }
  }
}

/// Accumulator sink for hash digest
class AccumulatorSink<T> implements Sink<T> {
  final List<T> _values = [];
  
  @override
  void add(T data) {
    _values.add(data);
  }
  
  @override
  void close() {}
  
  T get digest => _values.last;
}
