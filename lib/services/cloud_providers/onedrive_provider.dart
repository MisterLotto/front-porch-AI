import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:front_porch_ai/services/cloud_sync_service.dart';

/// OneDrive cloud storage provider using Microsoft Graph REST API + OAuth 2.0.
class OneDriveProvider extends CloudStorageProvider {
  // TODO: Replace with your actual Azure AD App Registration Client ID
  static const _clientId = 'YOUR_AZURE_CLIENT_ID';
  static const _redirectUri = 'http://localhost:8400/callback';
  static const _scopes = 'Files.ReadWrite.All offline_access';
  static const _authority = 'https://login.microsoftonline.com/common/oauth2/v2.0';
  static const _graphBase = 'https://graph.microsoft.com/v1.0';

  String? _accessToken;
  String? _refreshToken;
  DateTime? _tokenExpiry;
  bool _connected = false;

  @override
  bool get isConnected => _connected;

  @override
  String get displayName => 'OneDrive';

  @override
  Future<void> connect(Map<String, String> credentials) async {
    // Try to restore saved tokens
    final prefs = await SharedPreferences.getInstance();
    _refreshToken = prefs.getString('onedrive_refresh_token');

    if (_refreshToken != null) {
      try {
        await _refreshAccessToken();
        _connected = true;
        return;
      } catch (e) {
        debugPrint('Failed to restore OneDrive session: $e');
        _refreshToken = null;
      }
    }

    // Interactive sign-in via localhost redirect
    await _interactiveSignIn();
  }

  Future<void> _interactiveSignIn() async {
    final authUrl = Uri.parse('$_authority/authorize?'
        'client_id=$_clientId'
        '&response_type=code'
        '&redirect_uri=${Uri.encodeComponent(_redirectUri)}'
        '&scope=${Uri.encodeComponent(_scopes)}'
        '&response_mode=query');

    // Start local HTTP server to catch the redirect
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 8400);
    
    // Open system browser
    if (await canLaunchUrl(authUrl)) {
      await launchUrl(authUrl, mode: LaunchMode.externalApplication);
    }

    try {
      // Wait for the callback with a timeout
      final request = await server.first.timeout(const Duration(minutes: 2));
      final code = request.uri.queryParameters['code'];
      
      // Send a response to the browser
      request.response
        ..statusCode = 200
        ..headers.contentType = ContentType.html
        ..write('<html><body><h2>Sign-in successful!</h2><p>You can close this tab and return to Front Porch AI.</p></body></html>');
      await request.response.close();
      await server.close();

      if (code == null) throw Exception('No authorization code received');

      // Exchange code for tokens
      final tokenResponse = await http.post(
        Uri.parse('$_authority/token'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'client_id': _clientId,
          'code': code,
          'redirect_uri': _redirectUri,
          'grant_type': 'authorization_code',
          'scope': _scopes,
        },
      );

      if (tokenResponse.statusCode != 200) {
        throw Exception('Token exchange failed: ${tokenResponse.body}');
      }

      final tokenData = jsonDecode(tokenResponse.body);
      _accessToken = tokenData['access_token'];
      _refreshToken = tokenData['refresh_token'];
      _tokenExpiry = DateTime.now().add(Duration(seconds: tokenData['expires_in'] ?? 3600));
      _connected = true;

      // Save refresh token
      final prefs = await SharedPreferences.getInstance();
      if (_refreshToken != null) {
        await prefs.setString('onedrive_refresh_token', _refreshToken!);
      }
    } catch (e) {
      await server.close();
      _connected = false;
      rethrow;
    }
  }

  Future<void> _refreshAccessToken() async {
    if (_refreshToken == null) throw Exception('No refresh token');

    final response = await http.post(
      Uri.parse('$_authority/token'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'client_id': _clientId,
        'refresh_token': _refreshToken!,
        'grant_type': 'refresh_token',
        'scope': _scopes,
      },
    );

    if (response.statusCode != 200) throw Exception('Token refresh failed: ${response.body}');

    final data = jsonDecode(response.body);
    _accessToken = data['access_token'];
    _refreshToken = data['refresh_token'] ?? _refreshToken;
    _tokenExpiry = DateTime.now().add(Duration(seconds: data['expires_in'] ?? 3600));

    final prefs = await SharedPreferences.getInstance();
    if (_refreshToken != null) {
      await prefs.setString('onedrive_refresh_token', _refreshToken!);
    }
  }

  Future<Map<String, String>> _authHeaders() async {
    // Auto-refresh if token is expired or about to expire
    if (_tokenExpiry != null && DateTime.now().isAfter(_tokenExpiry!.subtract(const Duration(minutes: 5)))) {
      await _refreshAccessToken();
    }
    return {'Authorization': 'Bearer $_accessToken'};
  }

  @override
  Future<void> disconnect() async {
    _accessToken = null;
    _refreshToken = null;
    _tokenExpiry = null;
    _connected = false;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('onedrive_refresh_token');
  }

  @override
  Future<List<RemoteFileInfo>> listFiles(String remotePath) async {
    final result = <RemoteFileInfo>[];
    final encodedPath = _encodePath(remotePath);
    final headers = await _authHeaders();

    // List children of the folder
    final url = '$_graphBase/me/drive/root:$encodedPath:/children?\$select=name,lastModifiedDateTime,size,folder';
    final response = await http.get(Uri.parse(url), headers: headers);

    if (response.statusCode == 404) return result; // folder doesn't exist
    if (response.statusCode != 200) throw Exception('OneDrive list error: ${response.body}');

    final data = jsonDecode(response.body);
    final items = data['value'] as List? ?? [];

    for (final item in items) {
      final name = item['name'] as String;
      final isFolder = item['folder'] != null;
      final itemPath = '$remotePath/$name';

      if (isFolder) {
        try {
          final subFiles = await listFiles(itemPath);
          result.addAll(subFiles);
        } catch (_) {}
      } else {
        result.add(RemoteFileInfo(
          remotePath: itemPath,
          lastModified: item['lastModifiedDateTime'] != null
              ? DateTime.parse(item['lastModifiedDateTime'])
              : null,
          size: item['size'] as int?,
        ));
      }
    }

    return result;
  }

  @override
  Future<void> uploadFile(String localPath, String remotePath) async {
    final headers = await _authHeaders();
    final file = File(localPath);
    final bytes = await file.readAsBytes();
    final encodedPath = _encodePath(remotePath);

    // For files < 4MB, use simple upload
    final url = '$_graphBase/me/drive/root:$encodedPath:/content';
    final response = await http.put(
      Uri.parse(url),
      headers: {
        ...headers,
        'Content-Type': 'application/octet-stream',
      },
      body: bytes,
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('OneDrive upload error: ${response.body}');
    }
  }

  @override
  Future<void> downloadFile(String remotePath, String localPath) async {
    final headers = await _authHeaders();
    final encodedPath = _encodePath(remotePath);

    final url = '$_graphBase/me/drive/root:$encodedPath:/content';
    final response = await http.get(Uri.parse(url), headers: headers);

    if (response.statusCode == 302 || response.statusCode == 200) {
      final localFile = File(localPath);
      await localFile.parent.create(recursive: true);

      if (response.statusCode == 302) {
        // Follow redirect
        final redirectUrl = response.headers['location']!;
        final downloadResponse = await http.get(Uri.parse(redirectUrl));
        await localFile.writeAsBytes(downloadResponse.bodyBytes);
      } else {
        await localFile.writeAsBytes(response.bodyBytes);
      }
    } else {
      throw Exception('OneDrive download error: ${response.body}');
    }
  }

  @override
  Future<void> ensureDir(String remotePath) async {
    final headers = await _authHeaders();
    final parts = remotePath.split('/').where((p) => p.isNotEmpty).toList();

    String currentPath = '';
    for (final part in parts) {
      final parentPath = currentPath.isEmpty ? '' : currentPath;
      currentPath = '$currentPath/$part';
      final encodedPath = _encodePath(currentPath);

      // Check if folder exists
      final checkUrl = '$_graphBase/me/drive/root:$encodedPath';
      final checkResp = await http.get(Uri.parse(checkUrl), headers: headers);

      if (checkResp.statusCode == 404) {
        // Create the folder
        final parentUrl = parentPath.isEmpty
            ? '$_graphBase/me/drive/root/children'
            : '$_graphBase/me/drive/root:${_encodePath(parentPath)}:/children';
        
        final createResp = await http.post(
          Uri.parse(parentUrl),
          headers: {...headers, 'Content-Type': 'application/json'},
          body: jsonEncode({
            'name': part,
            'folder': {},
            '@microsoft.graph.conflictBehavior': 'fail',
          }),
        );

        if (createResp.statusCode != 201 && createResp.statusCode != 409) {
          // 409 = already exists, which is fine
          debugPrint('OneDrive mkdir warning: ${createResp.body}');
        }
      }
    }
  }

  /// Encode a path for use in Microsoft Graph API URLs.
  String _encodePath(String remotePath) {
    return remotePath.split('/').map((p) => Uri.encodeComponent(p)).join('/');
  }

  @override
  Future<void> deleteFile(String remotePath) async {
    final headers = await _authHeaders();
    final encodedPath = _encodePath(remotePath);
    final url = '$_graphBase/me/drive/root:$encodedPath';
    await http.delete(Uri.parse(url), headers: headers);
  }

  @override
  Future<void> deleteDirectory(String remotePath) async {
    final headers = await _authHeaders();
    final encodedPath = _encodePath(remotePath);
    final url = '$_graphBase/me/drive/root:$encodedPath';
    await http.delete(Uri.parse(url), headers: headers);
  }
}
