import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import '/src/models/route_argument.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:listen_like/src/constants/resize.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../controllers/homeController.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}
class _HomeScreenState extends State<HomeScreen> {
  //final TextEditingController _linkController = TextEditingController();
  late bool isLoading;
  @override
  void initState() {
    super.initState();
    setState(() {
      isLoading = false;
    });
  }
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  void _updateState() {
    // If the widget is still mounted, rebuild the UI
    if (mounted) {
      setState(() {});
    }
  }
  final HomeController _controller = HomeController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Media Processor'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const SizedBox(height: 20),

                // --- File Upload Section ---
                const Text(
                  'Upload Video File',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 15),
                ElevatedButton.icon(
                  icon: const Icon(Icons.video_file),
                  label: const Text('Pick Video'),
                  // Pass the callback to update state after picking
                  onPressed: _controller.isLoading ? null : () => _controller.pickVideoFile(_updateState),
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15)),
                ),
                const SizedBox(height: 10),
                // Display selected file name directly from controller variable
                Text(
                  _controller.selectedFile?.name ?? 'No file selected',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontStyle: FontStyle.italic),
                ),

                //YT link here
                const SizedBox(height: 30),
                const Divider(),
                const SizedBox(height: 30),

                // --- YouTube Link Section ---
                 const Text(
                  'Or Process YouTube Link',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                 const SizedBox(height: 15),
                 TextField(
                   controller: _controller.youtubeUrlController,
                   enabled: !_controller.isLoading, // Disable if loading
                   decoration: const InputDecoration(
                     labelText: 'YouTube Video URL',
                     hintText: 'https://www.youtube.com/watch?v=...',
                     border: OutlineInputBorder(),
                     prefixIcon: Icon(Icons.link),
                   ),
                   keyboardType: TextInputType.url,
                   onChanged: (_) => _updateState(), // Update UI maybe to enable button
                   onTap: () { // Clear file selection when user interacts with URL field
                     if (_controller.selectedFile != null) {
                        setState(() {
                           _controller.selectedFile = null;
                        });
                     }
                   },
                 ),
                 const SizedBox(height: 15),
                 // YouTube Processing Button & Loading Indicator
                 if (_controller.isLoading)
                   const Center(child: Padding(
                     padding: EdgeInsets.symmetric(vertical: 15.0),
                     child: CircularProgressIndicator(),
                   ))
                 else
                   ElevatedButton.icon(
                     icon: const Icon(Icons.play_circle_outline), // YouTube icon
                     label: const Text('Process YouTube Link'),
                     // Disable if URL is empty or loading is happening
                     onPressed: _controller.youtubeUrlController.text.trim().isEmpty || _controller.isLoading
                       ? null
                       : () => _controller.processYouTubeLink(context, _updateState),
                     style: ElevatedButton.styleFrom(
                       padding: const EdgeInsets.symmetric(vertical: 15),
                       backgroundColor: Colors.redAccent, // YouTube-ish color
                       foregroundColor: Colors.white,
                     ),
                   ),


                const SizedBox(height: 30),
                const Divider(),
                const SizedBox(height: 30),

                // --- Translation Options ---
                 Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Advanced options'),
                    const Text('Request Translation?'),
                    const SizedBox(width: 10),
                    // Use standard Switch bound to controller variable
                    Switch(
                      value: _controller.requestTranslation,
                      onChanged: (value) {
                        // Call controller method to update state and trigger rebuild
                        _controller.toggleTranslation(value, _updateState);
                      },
                    ),
                  ],
                ),
                 const SizedBox(height: 15),
                // Dropdown - only show if translation is requested
                // Use standard Visibility or if check
                if (_controller.requestTranslation)
                  DropdownButtonFormField<String>(
                    value: _controller.selectedTargetLanguage,
                    decoration: const InputDecoration(
                      labelText: 'Translate To',
                      border: OutlineInputBorder(),
                    ),
                    items: _controller.targetLanguages.map((String language) {
                      return DropdownMenuItem<String>(
                        value: language,
                        child: Text(language),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                       // Call controller method to update state and trigger rebuild
                      _controller.setTargetLanguage(newValue, _updateState);
                    },
                  ),

                const SizedBox(height: 40),

                // --- Process Button & Loading Indicator ---
                // Use standard if check for loading state
                if (_controller.isLoading)
                  const Center(child: CircularProgressIndicator())
                else
                  ElevatedButton.icon(
                    icon: const Icon(Icons.precision_manufacturing),
                    label: const Text('Process Video'),
                    // Disable button if no file is selected
                    onPressed: _controller.selectedFile == null
                      ? null
                      // Pass context and callback to processVideo
                      : () => _controller.processVideoFile(context, _updateState),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white
                    ),
                  ),
                 const SizedBox(height: 20),

                // --- Error Display ---
                // Use standard if check for error message
                if (_controller.errorMessage != null)
                  Text(
                    _controller.errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                  )
                else
                   const SizedBox.shrink(), // Return empty space if no error

              ],
            ),
          ),
        ),
      ),
    );
  }
}