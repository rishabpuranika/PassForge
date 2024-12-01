import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'dart:convert';

class SecureCredentialManager {
  // Create a singleton instance
  static final SecureCredentialManager _instance = SecureCredentialManager._internal();
  factory SecureCredentialManager() => _instance;
  SecureCredentialManager._internal();

  // Secure storage and encryption constants
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  static const String _credentialsStorageKey = 'stored_credentials';
  static const String _keyStorageKey = 'encryption_key';

  // Generate or retrieve an encryption key
  Future<encrypt.Key> _getOrCreateEncryptionKey() async {
    String? existingKey = await _secureStorage.read(key: _keyStorageKey);
    
    if (existingKey != null) {
      return encrypt.Key.fromBase64(existingKey);
    }
    
    final key = encrypt.Key.fromSecureRandom(32);
    await _secureStorage.write(
      key: _keyStorageKey, 
      value: base64Url.encode(key.bytes)
    );
    
    return key;
  }

  // Encrypt a string
  Future<String> _encrypt(String plainText) async {
    final key = await _getOrCreateEncryptionKey();
    final iv = encrypt.IV.fromSecureRandom(16);
    final encrypter = encrypt.Encrypter(encrypt.AES(key));
    
    final encrypted = encrypter.encrypt(plainText, iv: iv);
    
    return json.encode({
      'iv': base64Url.encode(iv.bytes),
      'encryptedData': encrypted.base64
    });
  }

  // Decrypt a string
  Future<String> _decrypt(String encryptedText) async {
    final key = await _getOrCreateEncryptionKey();
    final jsonData = json.decode(encryptedText);
    
    final iv = encrypt.IV.fromBase64(jsonData['iv']);
    final encrypter = encrypt.Encrypter(encrypt.AES(key));
    
    return encrypter.decrypt64(
      jsonData['encryptedData'], 
      iv: iv
    );
  }

  // Store a new credential
  Future<void> storeCredential({
    required String serviceName, 
    required String username, 
    required String password
  }) async {
    try {
      // Prepare credentials data
      final credentialsData = json.encode({
        'serviceName': serviceName,
        'username': username,
        'password': password,
        'timestamp': DateTime.now().toIso8601String()
      });
      
      // Encrypt credentials
      final encryptedCredentials = await _encrypt(credentialsData);
      
      // Retrieve existing credentials
      String? existingCredentialsStr = 
        await _secureStorage.read(key: _credentialsStorageKey);
      
      List<dynamic> credentials = [];
      if (existingCredentialsStr != null) {
        credentials = json.decode(existingCredentialsStr);
      }
      
      // Add new credential
      credentials.add(encryptedCredentials);
      
      // Store updated credentials
      await _secureStorage.write(
        key: _credentialsStorageKey, 
        value: json.encode(credentials)
      );
    } catch (e) {
      print('Error storing credentials: $e');
      rethrow;
    }
  }

  // Retrieve all stored credentials
  Future<List<Map<String, String>>> retrieveCredentials() async {
    try {
      // Get stored encrypted credentials
      final storedCredentialsStr = 
        await _secureStorage.read(key: _credentialsStorageKey);
      
      if (storedCredentialsStr == null) return [];
      
      // Parse stored credentials
      final storedCredentials = json.decode(storedCredentialsStr);
      
      // Decrypt and parse each credential
      final decryptedCredentials = <Map<String, String>>[];
      
      for (var encryptedCred in storedCredentials) {
        final decryptedCredStr = await _decrypt(encryptedCred);
        final decryptedCred = 
          json.decode(decryptedCredStr) as Map<String, dynamic>;
        
        decryptedCredentials.add({
          'serviceName': decryptedCred['serviceName'] ?? '',
          'username': decryptedCred['username'] ?? '',
          'password': decryptedCred['password'] ?? '',
          'timestamp': decryptedCred['timestamp'] ?? ''
        });
      }
      
      // Sort credentials by timestamp (most recent first)
      decryptedCredentials.sort((a, b) => 
        (b['timestamp'] ?? '').compareTo(a['timestamp'] ?? ''));
      
      return decryptedCredentials;
    } catch (e) {
      print('Error retrieving credentials: $e');
      return [];
    }
  }

  // Delete a specific credential
  Future<void> deleteCredential({
    required String serviceName, 
    required String username, 
    required String timestamp
  }) async {
    try {
      // Retrieve existing credentials
      String? existingCredentialsStr = 
        await _secureStorage.read(key: _credentialsStorageKey);
      
      if (existingCredentialsStr == null) return;
      
      // Parse credentials
      List<dynamic> credentials = json.decode(existingCredentialsStr);
      
      // Temporary list to store credentials to keep
      final updatedCredentials = <dynamic>[];
      
      // Iterate and decrypt to check service name, username, and timestamp
      for (var encryptedCred in credentials) {
        final decryptedStr = await _decrypt(encryptedCred);
        final decrypted = json.decode(decryptedStr);
        
        // Keep credentials that don't match all three parameters
        if (!(decrypted['serviceName'] == serviceName && 
              decrypted['username'] == username && 
              decrypted['timestamp'] == timestamp)) {
          updatedCredentials.add(encryptedCred);
        }
      }
      
      // Update stored credentials
      if (updatedCredentials.isEmpty) {
        await _secureStorage.delete(key: _credentialsStorageKey);
      } else {
        await _secureStorage.write(
          key: _credentialsStorageKey, 
          value: json.encode(updatedCredentials)
        );
      }
    } catch (e) {
      print('Error deleting credential: $e');
    }
  }
  // Clear all stored credentials
  Future<void> clearAllCredentials() async {
    await _secureStorage.delete(key: _credentialsStorageKey);
  }
}

