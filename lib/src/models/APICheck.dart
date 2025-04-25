import 'dart:convert';
import 'package:http/http.dart' as http;

class APIKeyManager {
  final String hostUrl;
  final String jsonFileUrl;
  final String updateUrl;

  APIKeyManager({
    required this.hostUrl,
    required this.jsonFileUrl,
    required this.updateUrl,
  });
  Future<Map<String, dynamic>?> fetchAvailableApiKey() async {
    try {
      // Get the JSON file from the host
      final response = await http.get(Uri.parse('$hostUrl/$jsonFileUrl'));
      
      if (response.statusCode != 200) {
        throw Exception('Failed to load API keys. Status code: ${response.statusCode}');
      }
      
      // Parse the JSON data
      List<dynamic> apiKeys = jsonDecode(response.body);
      
      // Current timestamp in seconds
      final currentTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      
      // Calculate timestamp for 24 hours ago
      final oneDayAgo = currentTime - (24 * 60 * 60);
      
      // Find the first key that meets our conditions
      Map<String, dynamic>? selectedKey;
      
      for (var key in apiKeys) {
        // Check if key is not in use
        if (key['isUsed'] == false) {
          // Check if count < 50 OR lastUsed > 24 hours ago
          if (key['count'] < 50 || 
              (key['lastUsed'] != null && int.parse(key['lastUsed'].toString()) < oneDayAgo)) {
            selectedKey = Map<String, dynamic>.from(key);
            break;
          }
        }
      }
      
      if (selectedKey != null) {
        // Update the key status on the server
        bool updateSuccess = await updateKeyStatus(
          selectedKey['id'], 
          true, 
          selectedKey['count'] >= 50 ? 0 : selectedKey['count'] + 1,
          currentTime
        );
        
        if (updateSuccess) {
          return selectedKey;
        } else {
          throw Exception('Failed to update key status');
        }
      } else {
        return null; // No available keys found
      }
    } catch (e) {
      print('Error fetching API key: $e');
      return null;
    }
  }

  /// Updates the status of an API key
  Future<bool> updateKeyStatus(String id, bool isUsed, int count, int timestamp) async {
    try {
      final response = await http.post(
        Uri.parse('$hostUrl/$updateUrl'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'id': id,
          'isUsed': isUsed.toString(),
          'count': count.toString(),
          'lastUsed': timestamp.toString(),
        },
      );
      
      return response.statusCode == 200;
    } catch (e) {
      print('Error updating key status: $e');
      return false;
    }
  }
  
  /// Release an API key (mark as not used) when done with it
  Future<bool> releaseApiKey(String id) async {
    try {
      final response = await http.post(
        Uri.parse('$hostUrl/$updateUrl'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'id': id,
          'isUsed': 'false',
        },
      );
      
      return response.statusCode == 200;
    } catch (e) {
      print('Error releasing key: $e');
      return false;
    }
  }
}

final keyManager = APIKeyManager(
  hostUrl: 'https://listenlike.mooo.com',
  jsonFileUrl: 'key.json',
  updateUrl: 'be.php'
);