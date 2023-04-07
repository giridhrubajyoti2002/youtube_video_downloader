// ignore_for_file: use_build_context_synchronously

import 'dart:io';
import 'package:external_path/external_path.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sn_progress_dialog/options/completed.dart';
import 'package:sn_progress_dialog/progress_dialog.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:youtube_video_downloader/utils.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final yt = YoutubeExplode();
  final textController = TextEditingController();
  bool isVideoLoaded = false;
  Video? video;
  List<MuxedStreamInfo>? muxedStreamInfoList;
  String videoQuality = '';

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
    textController.dispose();
    yt.close();
  }

  void loadVideo() async {
    String url = textController.text.trim();
    String videoId = url.split('/').last;
    if (url.contains('shorts')) {
      videoId = url.split('/').last.split('?').first;
    } else if (url.contains('watch')) {
      videoId = url.split('=')[1].split('&')[0];
    }
    showCircularProgressIndicator(context);
    try {
      video = await yt.videos.get(videoId);
      final streamManifst =
          await yt.videos.streamsClient.getManifest(video!.id);
      muxedStreamInfoList = streamManifst.muxed.sortByVideoQuality();
      final quality = muxedStreamInfoList![0].videoQuality.toString();
      final size = muxedStreamInfoList![0].size.toString();
      videoQuality =
          '${size.split(' ').join('')} ${quality.substring(quality.length - 3)}p';
    } catch (e) {
      debugPrint(e.toString());
      Fluttertoast.showToast(msg: 'Invalid Youtube Url.');
    }
    hideCircularProgressIndicator(context);
    if (muxedStreamInfoList != null) {
      setState(() {
        isVideoLoaded = true;
      });
    }
  }

  void downloadVideo() async {
    if (await Permission.storage.request() == PermissionStatus.granted) {
      MuxedStreamInfo? muxedStreamInfo;
      for (MuxedStreamInfo mStreamInfo in muxedStreamInfoList!) {
        if (mStreamInfo.videoQuality
            .toString()
            .contains(videoQuality.split(' ').last.substring(0, 3))) {
          muxedStreamInfo = mStreamInfo;
          break;
        }
      }
      var stream = yt.videos.streamsClient.get(muxedStreamInfo!);
      String downloadDirPath =
          await ExternalPath.getExternalStoragePublicDirectory(
              ExternalPath.DIRECTORY_DOWNLOADS);
      final fileName =
          '${DateFormat('dd-MM-yyyy hh-mm-ss a').format(DateTime.now())}.mp4';
      String appDownloadDirPath = '$downloadDirPath/YouTube Video Downloader';
      Directory(appDownloadDirPath).createSync();
      final filePath = '$downloadDirPath/YouTube Video Downloader/$fileName';
      File videoFile = File(filePath);
      videoFile.createSync(recursive: true);
      final fileStream = videoFile.openWrite();
      () async {
        await stream.pipe(fileStream);
        await fileStream.flush();
        await fileStream.close();
      }.call();
      ProgressDialog pd = ProgressDialog(context: context);
      pd.show(
        max: 100,
        msg: 'Preparing...',
        msgTextAlign: TextAlign.left,
        progressValueColor: Colors.blue,
        progressType: ProgressType.valuable,
        completed: Completed(),
      );
      int bytesWritten = 0;
      int progressValue = 0;
      while (bytesWritten == 0) {
        await Future.delayed(const Duration(milliseconds: 100));
        bytesWritten = videoFile.lengthSync();
      }
      while (bytesWritten < muxedStreamInfo.size.totalBytes) {
        await Future.delayed(const Duration(milliseconds: 100));
        bytesWritten = videoFile.lengthSync();
        progressValue = bytesWritten * 100 ~/ muxedStreamInfo.size.totalBytes;
        pd.update(value: progressValue, msg: 'Downloading...');
      }
      if (videoFile.lengthSync() == 0) {
        videoFile.deleteSync();
      }
      // Fluttertoast.showToast(msg: 'Vedio downloaded successfuly');
      setState(() {
        textController.clear();
        isVideoLoaded = false;
      });
    } else {
      Fluttertoast.showToast(msg: 'Please give storage permission.');
      await Future.delayed(const Duration(seconds: 2));
      openAppSettings();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: isVideoLoaded
            ? IconButton(
                onPressed: () {
                  setState(() {
                    isVideoLoaded = false;
                  });
                },
                icon: const Icon(Icons.arrow_back))
            : null,
        title: const Text('Youtube Video Downloader'),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextField(
                  controller: textController,
                  decoration: InputDecoration(
                    hintText: 'Enter Youtube video link',
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 15, horizontal: 15),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                if (isVideoLoaded)
                  SizedBox(
                    height: 250,
                    width: 320,
                    child: Image.network(
                      video!.thumbnails.standardResUrl,
                      fit: BoxFit.fill,
                    ),
                  ),
                const SizedBox(height: 40),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(width: 2, color: Colors.green),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  padding: EdgeInsets.zero,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        onPressed: () {
                          isVideoLoaded ? downloadVideo() : loadVideo();
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.all(0),
                          fixedSize: const Size.fromHeight(48),
                          backgroundColor: Colors.green,
                          shape: const RoundedRectangleBorder(),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(
                            isVideoLoaded ? 'Download' : 'Load Video',
                            style: const TextStyle(
                              fontSize: 20,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      if (isVideoLoaded) const SizedBox(width: 10),
                      if (isVideoLoaded)
                        DropdownButtonHideUnderline(
                          child: DropdownButton(
                            elevation: 0,
                            icon: const Icon(Icons.keyboard_arrow_down),
                            items: muxedStreamInfoList!.map((muxedStreamInfo) {
                              final quality =
                                  muxedStreamInfo.videoQuality.toString();
                              final fileSize = muxedStreamInfo.size.toString();
                              return DropdownMenuItem<String>(
                                value:
                                    '${fileSize.split(' ').join('')} ${quality.substring(quality.length - 3)}p',
                                child: Text(
                                  '${fileSize.split(' ').join('')} ${quality.substring(quality.length - 3)}p',
                                  style: const TextStyle(
                                      fontSize: 15, color: Colors.green),
                                ),
                              );
                            }).toList(),
                            value: videoQuality,
                            onChanged: (videoQuality) {
                              setState(() {
                                this.videoQuality = videoQuality!;
                              });
                            },
                          ),
                        ),
                      if (isVideoLoaded) const SizedBox(width: 5),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
