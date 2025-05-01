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
  final String _youtubeApiBaseUrl = "https://youtube-download-api-4bjr.onrender.com";
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
      String urlInput = youtubeUrlController.text.trim();
      if (urlInput.isEmpty) {
          errorMessage = "Please enter a valid URL.";
          onStateChange();
          return;
      }

      // --- Improved Pre-Validation ---
      // 1. Attempt to prepend https:// if no scheme exists
      if (!urlInput.startsWith('http://') && !urlInput.startsWith('https://')) {
          // Check if it LOOKS like a plausible domain start
          if (urlInput.startsWith('www.youtube.com') ||
              urlInput.startsWith('youtube.com') ||
              urlInput.startsWith('m.youtube.com') ||
              urlInput.startsWith('youtu.be')) {
             print("Prepending https:// to URL: $urlInput");
             urlInput = 'https://$urlInput'; // Default to https
          } else {
              // Doesn't start with http and doesn't look like a known domain start
              errorMessage = "Invalid URL format. Please include http/https or use a standard YouTube link.";
              onStateChange();
              return;
          }
      }

      // 2. Basic structural check using Uri (catches totally malformed URLs)
      Uri? parsedUri;
      try {
          parsedUri = Uri.parse(urlInput);
      } catch (e) {
          print("URL parsing failed: $e");
          errorMessage = "Invalid URL format.";
          onStateChange();
          return;
      }

      // 3. Check host and basic path/query for known patterns (similar to previous robust check)
       final String host = parsedUri.host.toLowerCase();
       bool looksLikeVideoLink = false;
       if (host == 'youtu.be' && parsedUri.pathSegments.isNotEmpty) {
           looksLikeVideoLink = true; // youtu.be/ID
       } else if ((host == 'youtube.com' || host == 'www.youtube.com' || host == 'm.youtube.com')) {
           if (parsedUri.path == '/watch' && parsedUri.queryParameters.containsKey('v')) {
               looksLikeVideoLink = true; // youtube.com/watch?v=ID
           } else if (parsedUri.pathSegments.isNotEmpty && parsedUri.pathSegments.first == 'embed' && parsedUri.pathSegments.length > 1) {
               looksLikeVideoLink = true; // youtube.com/embed/ID
           } else if (parsedUri.pathSegments.isNotEmpty && parsedUri.pathSegments.first == 'shorts' && parsedUri.pathSegments.length > 1) {
               looksLikeVideoLink = true; // youtube.com/shorts/ID
           }
       }

       if (!looksLikeVideoLink) {
           errorMessage = "URL doesn't look like a valid YouTube Video, Short, or Embed link.";
           onStateChange();
           return;
       }

      // --- Validation Passed - Proceed with API call ---
      final String finalUrlToProcess = urlInput; // Use the potentially modified URL

      isLoading = true;
      errorMessage = null;
      selectedFile = null;
      onStateChange();

      String? transcriptionResult;
      String? translationResult;
      String videoTitle = "YouTube Video"; // Default title

      try {
          // --- Step 1: Get Video Info (Optional, for title) ---
          String apiFilename = "youtube_audio.mp3"; // Default filename
          try {
              final infoUrl = Uri.parse('$_youtubeApiBaseUrl/info').replace(queryParameters: {'url': finalUrlToProcess});
              print("Calling YouTube Info API: $infoUrl");
              final infoResponse = await http.get(infoUrl).timeout(const Duration(seconds: 30));
              if (infoResponse.statusCode == 200) {
                  final infoData = jsonDecode(infoResponse.body);
                  videoTitle = infoData['title'] ?? videoTitle;
                  // Sanitize title slightly for filename
                   final safeVideoTitle = videoTitle.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
                  apiFilename = "$safeVideoTitle.mp3";
                  print("Retrieved video title: $videoTitle");
              } else {
                  print("Warning: Failed to get video info (Status ${infoResponse.statusCode}). Using default title.");
                  // Proceed without title, use default filename
              }
          } catch (e) {
               print("Warning: Error getting video info: $e. Using default title.");
               // Proceed without title
          }


          // --- Step 2: Download MP3 Audio Bytes from Node API ---
          final downloadUrl = Uri.parse('$_youtubeApiBaseUrl/mp3').replace(queryParameters: {'url': finalUrlToProcess});
          print("Calling YouTube MP3 Download API: $downloadUrl");

          final audioResponse = await http.get(downloadUrl).timeout(const Duration(minutes: 5)); // Allow time for download

          print("YouTube MP3 API Response Status: ${audioResponse.statusCode}");

          if (audioResponse.statusCode != 200) {
              // Try to get error message from Node API response body
              String errorDetail = audioResponse.body.isNotEmpty ? audioResponse.body : "Failed to download audio";
              throw Exception("YouTube Download API failed (Status ${audioResponse.statusCode}): $errorDetail");
          }

          final Uint8List audioBytes = audioResponse.bodyBytes;
          if (audioBytes.isEmpty) {
              throw Exception("YouTube Download API returned empty audio data.");
          }
          print("YouTube audio download complete (${audioBytes.length} bytes).");


          // --- Step 3: Transcribe using MAIN Backend ---
          print("Starting transcription for YouTube audio via Main API...");
          // Use the _transcribeFile helper, passing the downloaded bytes and generated filename
          transcriptionResult = await _transcribeFile(
              audioBytes,
              apiFilename, // Send downloaded audio with .mp3 filename
          );
          print("YouTube transcription successful.");

          // --- Step 4: Translate (if requested) using MAIN Backend ---
          if (requestTranslation) {
              print("Starting translation for YouTube to ${selectedTargetLanguage} via Main API...");
              translationResult = await _translateText( // Uses main backend
                  transcriptionResult,
                  selectedTargetLanguage,
              );
              print("YouTube translation successful.");
          }

          // --- Step 5: Navigate ---
           print("Navigating to results screen (from YouTube)...");
           if (context.mounted) {
               Navigator.of(context).pushNamed(
                   '/ProcessResult',
                   arguments: RouteArgument(
                       id: transcriptionResult!,
                       heroTag: translationResult,
                       param: videoTitle, // Use title from /info or default
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
          isLoading = false;
          onStateChange();
      }
  }

  // --- Helper: Validate YouTube URL ---
  //not using it for now
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
     // IMPORTANT: Ensure this uses _mainApiBaseUrl
     final url = Uri.parse("$_apiBaseUrl/api/transcribe");
     print("Calling MAIN Transcription API: $url for file: $filename");

     var request = http.MultipartRequest('POST', url);
     String? mimeType = _getMimeType(filename) ?? 'application/octet-stream'; // Guess MIME or use default
     MediaType? contentType;
     final typeParts = mimeType.split('/');
     if (typeParts.length == 2) contentType = MediaType(typeParts[0], typeParts[1]);

     print("Uploading with Content-Type: ${contentType?.mimeType ?? 'unknown'}");

     request.files.add(
       http.MultipartFile.fromBytes(
         'file', fileBytes, filename: filename, contentType: contentType,
       ),
     );
     // ... rest of the existing _transcribeFile logic (error handling, parsing) ...
     try {
       final response = await request.send().timeout(const Duration(minutes: 5));
       final responseBody = await response.stream.bytesToString();
       print("Main Transcription API Response Status: ${response.statusCode}");
       if (response.statusCode == 200) {
         final decoded = jsonDecode(responseBody);
         if (decoded.containsKey('transcription')) return decoded['transcription'] as String;
         throw Exception("Key 'transcription' missing in response.");
       } else {
         String detail = _parseErrorDetail(responseBody, response.statusCode);
         throw Exception("Transcription failed: $detail");
       }
     } on TimeoutException { throw Exception("Transcription request timed out."); }
     catch (e) { throw Exception("Failed to connect or transcribe: ${e.toString()}"); }
  }

  // _translateText: Calls YOUR MAIN BACKEND (/api/translate)
  Future<String> _translateText(String text, String targetLanguage) async {
     // IMPORTANT: Ensure this uses _mainApiBaseUrl
     final url = Uri.parse("$_apiBaseUrl/api/translate");
     print("Calling MAIN Translation API: $url");
     // ... rest of the existing _translateText logic ...
      try {
       final response = await http.post( url, headers: {'Content-Type': 'application/json'},
         body: jsonEncode({'text': text, 'target_language': targetLanguage,}),
       ).timeout(const Duration(seconds: 90));
       print("Main Translation API Response Status: ${response.statusCode}");
       if (response.statusCode == 200) {
         final decoded = jsonDecode(response.body);
         if (decoded.containsKey('translated_text')) return decoded['translated_text'] as String;
         throw Exception("Key 'translated_text' missing in response.");
       } else {
         String detail = _parseErrorDetail(response.body, response.statusCode);
         throw Exception("Translation failed: $detail");
       }
      } on TimeoutException { throw Exception("Translation request timed out."); }
      catch (e) { throw Exception("Failed to connect or translate: ${e.toString()}"); }
  }

  // _parseErrorDetail: Helper for parsing errors from EITHER backend
  String _parseErrorDetail(String responseBody, int statusCode) {
       try {
          final decodedError = jsonDecode(responseBody);
          if (decodedError is Map && decodedError.containsKey('detail')) {
            return decodedError['detail']; // FastAPI/Python style
          } else if (decodedError is String) {
             return decodedError; // Node API might just send string error
          }
          // Fallback if JSON parsing works but structure is wrong
          return responseBody.isNotEmpty ? responseBody : "Status code: $statusCode";
       } catch (_) {
          // Fallback if response body isn't JSON
          return responseBody.isNotEmpty ? responseBody : "Status code: $statusCode";
       }
  }

   // _getMimeType: Helper to guess MIME type (add mp3)
   String? _getMimeType(String filename) {
     final extension = filename.split('.').last.toLowerCase();
     switch (extension) {
       case 'mp4': return 'video/mp4';
       case 'mov': return 'video/quicktime';
       case 'avi': return 'video/x-msvideo';
       case 'webm': return 'video/webm';
       case 'm4a': return 'audio/mp4';
       case 'mp3': return 'audio/mpeg'; // Added MP3
       case 'wav': return 'audio/wav';
       case 'ogg': return 'audio/ogg';
       default: return null;
     }
   }
}