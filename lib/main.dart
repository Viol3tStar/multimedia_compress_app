import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_compress/video_compress.dart';
import 'package:video_player/video_player.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late Subscription _subscription;
  double? fileSize = 0;
  double originalFileSize = 0;
  double compressionProgress = 0.0;
  File? selectedVideo;
  File? compressedVideo;

  VideoPlayerController? _videoPlayerController;


  @override
  void initState() {
    super.initState();
    _subscription =
        VideoCompress.compressProgress$.subscribe((progress) {
          setState(() {
            compressionProgress = progress;
          });
        });
  }

  @override
  void dispose() {
    super.dispose();
    _subscription.unsubscribe();
  }

  Future<void> compressVideo (String filePath) async {
    final appDir = await getApplicationDocumentsDirectory();
    final tempFilePath = '${appDir.path}/temp_video.mp4';

    // Copy the selected video to the temporary location
    await File(filePath).copy(tempFilePath);

    // Compress the video using FFmpeg
    final outputFilePath = '${appDir.path}/compressed_video.mp4';

    MediaInfo? mediaInfo = await VideoCompress.compressVideo(
      filePath,
      quality: VideoQuality.LowQuality,
      deleteOrigin: false, // It's false by default
    );

    if (mediaInfo != null) {

      final thumbnailFile = await VideoCompress.getFileThumbnail(
          filePath,
          quality: 50, // default(100)
          position: 3 // default(-1)
      );
      print('thumbnail: $thumbnailFile');
      compressedVideo = mediaInfo.file;

      setState(() {
        print("Compressed video : $compressedVideo");
        _videoPlayerController = VideoPlayerController.file(compressedVideo!)
          ..initialize().then((_) {
            setState(() {});
            _videoPlayerController!.play();
          });
        selectedVideo = thumbnailFile;
        fileSize = bytesToMegabytes(mediaInfo.filesize);
        print('fileSize: $fileSize');
      });
    }
  }

  Future<void> selectAndCompress() async {
    try {
      final pickedFile = await ImagePicker().pickVideo(source: ImageSource.gallery);

      print('pickedFile $pickedFile}');
      if (pickedFile != null) {
        File videoFile = File(pickedFile.path);
        _videoPlayerController = VideoPlayerController.file(videoFile)
          ..initialize().then((_) {
            setState(() {});
            _videoPlayerController!.play();
          });
        int fileSize = await videoFile.length();
        originalFileSize = bytesToMegabytes(fileSize);

        await compressVideo(pickedFile.path);
      }
    }catch (e) {
      print('eeee: $e');
    }
  }

  double bytesToMegabytes(int? bytes) {
    if (bytes == null) return 0;

    return (bytes / (1024 * 1024));
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Column(
        children: [
          Row(
            children: [
              const Text("Original file size:"),
              Text("${originalFileSize?.toStringAsFixed(2)} MB")
            ],
          ),
          selectedVideo != null
              ? Image.file(selectedVideo!)
              : Container(),
          Row(
            children: [
              const Text("File size:"),
              Text("${fileSize?.toStringAsFixed(2)} MB")
            ],
          ),

          const SizedBox(height: 20),
          if (compressionProgress > 0 && compressionProgress <= 89)
            Column(
              children: [
                LinearProgressIndicator(
                  value: compressionProgress/100,
                ),
                SizedBox(height: 10),
                Text('Progress: ${(compressionProgress).toStringAsFixed(2)}%'),
              ],
            ),
          if (compressedVideo != null)
            _videoPlayerController != null
                ? AspectRatio(
              aspectRatio: _videoPlayerController!.value.aspectRatio,
              child: VideoPlayer(_videoPlayerController!),
            )
                : Container(),
          Center(
            child: ElevatedButton(
              onPressed: () async {
                await selectAndCompress();
              },
              child: Text('Select and Compress Video'),
            ),
          ),
        ],
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
