import 'dart:io';
import 'package:flutter/material.dart';
import '../models/route_argument.dart';

class ResultScreen extends StatefulWidget {
  final RouteArgument? routeArgument;

  const ResultScreen({super.key, this.routeArgument});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  @override
  void initState() {
    super.initState();
    
  }

  @override
  void dispose() {
    // _textController.removeListener(_updateWordCount);
    // _textController.dispose();
    super.dispose();
  }

   @override
  Widget build(BuildContext context) {
    String? transcribedText = widget.routeArgument!.id; 
    String? translatedText = widget.routeArgument?.heroTag; 
    String? fileName = widget.routeArgument!.param;

    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: Text('Results for ${fileName}'),
        ),
        body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView( // Use ListView for potentially long text
          children: [
            const Text(
              'Transcription:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(transcribedText!), // Make text selectable
            ),
            const SizedBox(height: 24),

            // Conditionally display translation
            if (translatedText != null) ...[
              const Text(
                'Translation:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(translatedText),
              ),
              const SizedBox(height: 24),
            ],

            // Placeholder for Interactive Test UI
            const Divider(),
            const SizedBox(height: 16),
            const Text(
              'IELTS Questions (Placeholder)',
               style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
             // TODO: Implement the UI to display questions from /api/generate_questions
            const Center(child: Text('Interactive test UI will go here.')),
             const SizedBox(height: 10),
             ElevatedButton(
               onPressed: () {
                 // TODO: Add logic to fetch questions based on args.transcription
                 print("Fetch/Display Questions button pressed");
                 ScaffoldMessenger.of(context).showSnackBar(
                   const SnackBar(content: Text("Question generation/fetching not implemented yet."))
                  );
               },
               child: const Text("Load Questions")
             )

          ],
        ),
      )
      )
    );
  }
}