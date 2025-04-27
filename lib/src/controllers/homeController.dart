// controller/HomeController.dart
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';

import 'package:flutter/material.dart'; // For SnackBar/Colors
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart'; // For MediaType
import 'package:listen_like/src/models/route_argument.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

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
  final TextEditingController youtubeUrlController = TextEditingController();
  HomeController() {
    // Log the URL being used (optional debugging)
    print("API Base URL Initialized: $_apiBaseUrl");
    if (_apiBaseUrl == 'http://localhost:10000') {
      print("WARNING: API Base URL is using default localhost. Ensure --dart-define=API_BASE_URL=... was used during build for deployment.");
    }
  }
  void dispose() {
    youtubeUrlController.dispose();
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
  Future<void> processVideoFile(BuildContext context, VoidCallback onStateChange) async {
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

  Future<void> processYouTubeLink(BuildContext context, VoidCallback onStateChange) async {
      final String url = youtubeUrlController.text.trim();
      if (!_isValidYouTubeUrl(url)) {
          errorMessage = "Please enter a valid YouTube video URL.";
          onStateChange();
          return;
      }

      isLoading = true;
      errorMessage = null;
      selectedFile = null; // Clear file selection if processing URL
      onStateChange();

      String? transcriptionResult;
      String? translationResult;
      String videoTitle = "YouTube Video"; // Default title

      var yt = YoutubeExplode(); // Create instance

      try {
          // --- Step 1: Download YouTube Audio ---
          print("Downloading audio for YouTube URL: $url");
          final video = await yt.videos.get(url);
          videoTitle = video.title; // Get actual title

          final manifest = await yt.videos.streamsClient.getManifest(video.id);
          final audioStreamInfo = manifest.audioOnly.withHighestBitrate();
          final stream = yt.videos.streamsClient.get(audioStreamInfo);

          // Download stream to bytes
          final bytesBuilder = BytesBuilder();
          await for (final chunk in stream) {
              bytesBuilder.add(chunk);
          }
          final audioBytes = bytesBuilder.toBytes();
          print("YouTube audio download complete (${audioBytes.length} bytes). Format: ${audioStreamInfo.container.name}");

          // Generate a filename for the API
          // Use a safe filename from title + container extension
          final safeVideoTitle = videoTitle.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_'); // Basic sanitize
          final apiFilename = "$safeVideoTitle.${audioStreamInfo.container.name}";


          // --- Step 2: Transcribe ---
          print("Starting transcription for YouTube audio...");
          transcriptionResult = await _transcribeFile(
              audioBytes,
              apiFilename, // Send downloaded audio with a filename
          );
          print("YouTube transcription successful.");

          // --- Step 3: Translate (if requested) ---
          if (requestTranslation) {
              print("Starting translation for YouTube to ${selectedTargetLanguage}...");
              translationResult = await _translateText(
                  transcriptionResult,
                  selectedTargetLanguage,
              );
              print("YouTube translation successful.");
          }

          // --- Step 4: Navigate ---
           print("Navigating to results screen (from YouTube)...");
           if (context.mounted) {
               Navigator.of(context).pushNamed(
                   '/Result',
                   arguments: RouteArgument(
                    id:transcriptionResult,
                    heroTag: translationResult,
                    param: selectedFile!.name
                   ),
               );
           }

      } catch (e) {
          print("Error during YouTube processing: $e");
          errorMessage = "Failed to process YouTube link: ${e.toString()}";
          if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(errorMessage!), backgroundColor: Colors.red),
              );
          }
      } finally {
          isLoading = false; // Use YouTube-specific loading state
          yt.close(); // Close the YouTubeExplode client
          onStateChange();
      }
  }


  // --- Helper: Validate YouTube URL ---
  bool _isValidYouTubeUrl(String url) {
    if (url.isEmpty) return false;

    try {
      final Uri uri = Uri.parse(url);

      // 1. Check Scheme
      if (!['http', 'https'].contains(uri.scheme)) {
        print("URL Check Failed: Invalid scheme (${uri.scheme})");
        return false;
      }

      // 2. Check Host Domain (allow common www and mobile prefixes)
      final String host = uri.host.toLowerCase();
      bool isKnownDomain = host == 'youtube.com' ||
                           host == 'www.youtube.com' ||
                           host == 'm.youtube.com' ||
                           host == 'youtu.be';

      if (!isKnownDomain) {
        print("URL Check Failed: Host is not a known YouTube domain ($host)");
        return false;
      }

      // 3. Check for Video ID based on domain structure
      String? videoId;

      if (host == 'youtu.be') {
        // Structure: youtu.be/VIDEO_ID
        // Path segments will be ['', 'VIDEO_ID'] or just ['VIDEO_ID'] if no leading /
        if (uri.pathSegments.isNotEmpty && uri.pathSegments.first.isNotEmpty) {
           videoId = uri.pathSegments.first;
        } else {
           print("URL Check Failed: youtu.be URL lacks a path segment for Video ID.");
           return false;
        }
      } else { // Handle youtube.com variations
        // Structure: youtube.com/watch?v=VIDEO_ID
        // Allow /embed/VIDEO_ID as well, often used for embedding
        if (uri.path == '/watch') {
          videoId = uri.queryParameters['v'];
           if (videoId == null || videoId.isEmpty) {
             print("URL Check Failed: youtube.com/watch URL lacks 'v' query parameter.");
             return false;
           }
        } else if (uri.pathSegments.isNotEmpty && uri.pathSegments.first == 'embed') {
            if (uri.pathSegments.length > 1 && uri.pathSegments[1].isNotEmpty) {
                videoId = uri.pathSegments[1];
            } else {
                print("URL Check Failed: youtube.com/embed/ URL lacks Video ID in path.");
                return false;
            }
        }
         else if (uri.pathSegments.isNotEmpty && uri.pathSegments.first == 'shorts') {
             // Structure: youtube.com/shorts/VIDEO_ID
            if (uri.pathSegments.length > 1 && uri.pathSegments[1].isNotEmpty) {
                videoId = uri.pathSegments[1];
            } else {
                print("URL Check Failed: youtube.com/shorts/ URL lacks Video ID in path.");
                return false;
            }
        }
        else {
           print("URL Check Failed: youtube.com URL doesn't match /watch, /embed/, or /shorts/ path structure.");
           return false;
        }
      }

      // 4. Validate Video ID Format (Basic Check)
      // YouTube IDs are typically 11 characters long and use specific characters.
      // Regex: Allows letters (a-z, A-Z), numbers (0-9), underscore (_), and hyphen (-)
      final RegExp videoIdRegex = RegExp(r"^[a-zA-Z0-9_-]{11}$");
      if (videoId != null && videoIdRegex.hasMatch(videoId)) {
        print("URL Check Passed: Valid structure and potential Video ID found ($videoId).");
        return true; // Looks like a valid YouTube video URL structure
      } else {
        print("URL Check Failed: Extracted Video ID '$videoId' does not match expected format/length.");
        return false;
      }

    } catch (e) {
      // Handle potential errors during URI parsing
      print("URL Check Failed: Error parsing URL '$url': $e");
      return false;
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