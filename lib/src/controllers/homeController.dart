// controller/HomeController.dart
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart'; // For SnackBar/Colors
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart'; // For MediaType
import 'package:listen_like/src/models/route_argument.dart';

import '../screens/result.dart'; // Adjust import path if needed

class HomeController {
  // --- State Variables ---
  bool isLoading = false; // Use .obs for reactivity
  PlatformFile? selectedFile; // Reactive selected file
  String? errorMessage; // Reactive error message
  bool requestTranslation = false; // Reactive translation toggle
  String selectedTargetLanguage = 'English'; // Default target language

  static const String _apiBaseUrlEnvVar = 'API_BASE_URL';//env

  
  final String _apiBaseUrl = const String.fromEnvironment(
    _apiBaseUrlEnvVar, // Variable name
    defaultValue: 'http://localhost:10000', // Default for local testing (adjust port if needed)
  ); 
  HomeController() {
    // Log the URL being used (optional debugging)
    print("API Base URL Initialized: $_apiBaseUrl");
    if (_apiBaseUrl == 'http://localhost:10000') {
      print("WARNING: API Base URL is using default localhost. Ensure --dart-define=API_BASE_URL=... was used during build for deployment.");
    }
  }

  // Available languages for translation dropdown
  final List<String> targetLanguages = [
    'English', 'Spanish', 'French', 'German', 'Japanese', 'Chinese', 'Korean', 'Vietnamese', 'Indonesian', 'Arabic', 'Hindi', 'Russian'
    // Add more common languages as needed based on your LANGUAGE_CODE_MAP in Python
  ];

  // --- Methods ---

  // Pick a video file
  Future<void> pickVideoFile(VoidCallback onStateChange) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        // You might want to read bytes directly if files aren't too large
        // Or handle file paths if they are very large (requires more setup)
        withData: true, // Read file bytes into memory
      );

      if (result != null && result.files.single.bytes != null) {
        selectedFile = result.files.single;
        errorMessage = null; // Clear previous error on new selection
        print("File Selected: ${selectedFile?.name}");
      } else {
        // User canceled the picker or file bytes are null
        print("File selection cancelled or failed.");
        // Optionally clear selection if needed: selectedFile.value = null;
      }
      onStateChange();
    } catch (e) {
      print("Error picking file: $e");
      errorMessage = "Error picking file: $e";
      selectedFile = null; // Clear selection on error
      onStateChange();
    }
  }
  void toggleTranslation(bool value, VoidCallback onStateChange) {
      requestTranslation = value;
      onStateChange();
  }

  // Set target language
  void setTargetLanguage(String? language, VoidCallback onStateChange) {
      if (language != null) {
          selectedTargetLanguage = language;
          onStateChange();
      }
  }

  // Process the selected video (Transcribe and optionally Translate)
  Future<void> processVideo(BuildContext context, VoidCallback onStateChange) async {
    if (selectedFile == null || selectedFile!.bytes == null) {
      errorMessage = "Please select a video file first.";
      return;
    }

    isLoading = true;
    errorMessage = null;
    onStateChange();
    String? transcriptionResult;
    String? translationResult;

    try {
      // --- Step 1: Transcribe ---
      print("Starting transcription...");
      transcriptionResult = await _transcribeFile(
        selectedFile!.bytes!,
        selectedFile!.name,
      );
      print("Transcription successful.");

      // --- Step 2: Translate (if requested) ---
      if (requestTranslation) {
        print("Starting translation to ${selectedTargetLanguage}...");
        translationResult = await _translateText(
          transcriptionResult,
          selectedTargetLanguage,
        );
        print("Translation successful.");
      }

      // --- Step 3: Navigate to Results ---
      print("Navigating to results screen...");
      if (context.mounted) {
        Navigator.of(context).pushNamed('/Result', arguments: RouteArgument(id: transcriptionResult, heroTag: translationResult, param: selectedFile!.name));
      }
       // Reset state after successful processing and navigation (optional)
      // selectedFile.value = null;
      // requestTranslation.value = false;


    } catch (e) {
      print("Error during processing: $e");
      errorMessage = e.toString();
       if (context.mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(
             content: Text(e.toString()),
             backgroundColor: Colors.red,
           ),
         );
       }
    } finally {
      isLoading = false;
      onStateChange();
    }
  }

  // --- Internal Helper Methods ---

  // Call the /api/transcribe endpoint
  Future<String> _transcribeFile(Uint8List fileBytes, String filename) async {
    final url = Uri.parse("$_apiBaseUrl/api/transcribe");
    print("Calling Transcription API: $url");

    var request = http.MultipartRequest('POST', url);
    request.files.add(
      http.MultipartFile.fromBytes(
        'file', // MUST match the FastAPI parameter name ('file')
        fileBytes,
        filename: filename,
        // Try to guess content type for video
        contentType: MediaType('video', filename.split('.').last),
      ),
    );

    try {
      final response = await request.send().timeout(const Duration(minutes: 5)); // Add timeout

      final responseBody = await response.stream.bytesToString();
      print("Transcription Response Status: ${response.statusCode}");
      // print("Transcription Response Body: $responseBody"); // Debugging

      if (response.statusCode == 200) {
        final decoded = jsonDecode(responseBody);
        if (decoded.containsKey('transcription')) {
          return decoded['transcription'] as String;
        } else {
          throw Exception("Transcription successful but key 'transcription' missing in response.");
        }
      } else {
        // Try to parse error detail from backend
        String detail = "Unknown error occurred (Status ${response.statusCode})";
        try {
           final decodedError = jsonDecode(responseBody);
           if (decodedError is Map && decodedError.containsKey('detail')) {
             detail = decodedError['detail'];
           } else {
             detail = responseBody; // Use raw body if no detail key
           }
        } catch (_) {
           detail = responseBody; // Use raw body if JSON parsing fails
        }
        throw Exception("Transcription failed: $detail");
      }
    } on TimeoutException {
        throw Exception("Transcription request timed out. The video might be too long or the server is busy.");
    } catch (e) {
       print("HTTP Transcribe Error: $e");
       throw Exception("Failed to connect or transcribe: ${e.toString()}"); // Rethrow or refine
    }
  }

  // Call the /api/translate endpoint
  Future<String> _translateText(String text, String targetLanguage) async {
    final url = Uri.parse("$_apiBaseUrl/api/translate");
    print("Calling Translation API: $url");

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'text': text,
          'target_language': targetLanguage,
        }),
      ).timeout(const Duration(seconds: 90)); // Add timeout

      print("Translation Response Status: ${response.statusCode}");
      // print("Translation Response Body: ${response.body}"); // Debugging

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded.containsKey('translated_text')) {
          return decoded['translated_text'] as String;
        } else {
          throw Exception("Translation successful but key 'translated_text' missing in response.");
        }
      } else {
         // Try to parse error detail from backend
        String detail = "Unknown error occurred (Status ${response.statusCode})";
         try {
           final decodedError = jsonDecode(response.body);
           if (decodedError is Map && decodedError.containsKey('detail')) {
             detail = decodedError['detail'];
           } else {
             detail = response.body;
           }
        } catch (_) {
            detail = response.body;
        }
        throw Exception("Translation failed: $detail");
      }
     } on TimeoutException {
        throw Exception("Translation request timed out.");
    } catch (e) {
      print("HTTP Translate Error: $e");
      throw Exception("Failed to connect or translate: ${e.toString()}");
    }
  }
}