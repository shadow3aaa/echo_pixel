import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;

class MediaScanSettingsPage extends StatefulWidget {
  const MediaScanSettingsPage({super.key});

  @override
  State<MediaScanSettingsPage> createState() => _MediaScanSettingsPageState();

  /// 获取默认的媒体扫描文件夹
  /// 返回平台特定的默认媒体文件夹路径列表
  static Future<List<String>> getDefaultMediaFolders() async {
    List<String> defaultFolders = [];

    try {
      if (Platform.isAndroid) {
        // Android平台的默认媒体目录
        final externalDir = await getExternalStorageDirectory();
        if (externalDir != null) {
          final dcimDir = Directory('${externalDir.path}/../DCIM');
          final picturesDir = Directory('${externalDir.path}/../Pictures');

          if (await dcimDir.exists()) {
            defaultFolders.add(dcimDir.path);
          }
          if (await picturesDir.exists()) {
            defaultFolders.add(picturesDir.path);
          }
        }
      } else if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
        // 桌面平台的默认媒体目录
        final homeDir = Platform.isWindows
            ? Platform.environment['USERPROFILE'] ?? ''
            : Platform.environment['HOME'] ?? '';

        defaultFolders.add(path.join(homeDir, 'Pictures'));
        defaultFolders.add(path.join(homeDir, 'Videos'));
      }
    } catch (e) {
      debugPrint('获取默认媒体文件夹错误: $e');
    }

    return defaultFolders;
  }

  /// 判断是否为桌面平台
  static bool isDesktopPlatform() {
    return !kIsWeb &&
        (Platform.isWindows || Platform.isMacOS || Platform.isLinux);
  }
}

class _MediaScanSettingsPageState extends State<MediaScanSettingsPage> {
  final List<String> _scanFolders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();

      // 加载扫描目录列表
      final scanFolders = prefs.getStringList('scan_folders');

      setState(() {
        if (scanFolders != null) {
          _scanFolders.clear();
          _scanFolders.addAll(scanFolders);
        } else {
          _addDefaultFolders();
        }

        _isLoading = false;
      });
    } catch (e) {
      debugPrint('加载媒体扫描设置错误: $e');
      setState(() {
        _addDefaultFolders();
        _isLoading = false;
      });
    }
  }

  Future<void> _addDefaultFolders() async {
    _scanFolders.clear();

    try {
      // 使用公开方法获取默认文件夹
      final defaultFolders =
          await MediaScanSettingsPage.getDefaultMediaFolders();
      _scanFolders.addAll(defaultFolders);

      await _saveScanFolders();
    } catch (e) {
      debugPrint('添加默认文件夹错误: $e');
    }
  }

  Future<void> _addScanFolder() async {
    try {
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath(
        dialogTitle: '选择要扫描的文件夹',
      );

      if (selectedDirectory != null && selectedDirectory.isNotEmpty) {
        // 检查目录是否已经在列表中
        if (!_scanFolders.contains(selectedDirectory)) {
          setState(() {
            _scanFolders.add(selectedDirectory);
          });
          await _saveScanFolders();
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('该文件夹已在扫描列表中')),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('选择文件夹错误: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('选择文件夹失败: $e')),
        );
      }
    }
  }

  Future<void> _removeScanFolder(int index) async {
    setState(() {
      _scanFolders.removeAt(index);
    });
    await _saveScanFolders();
  }

  Future<void> _saveScanFolders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('scan_folders', _scanFolders);
    } catch (e) {
      debugPrint('保存扫描文件夹列表错误: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存扫描文件夹失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('媒体扫描设置'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                // 扫描文件夹列表 - 只在桌面平台显示
                if (MediaScanSettingsPage.isDesktopPlatform())
                  Card.filled(
                    margin: const EdgeInsets.only(bottom: 16.0),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '扫描文件夹',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            '选择要扫描媒体文件的文件夹',
                            style: TextStyle(fontSize: 14),
                          ),
                          const SizedBox(height: 16),
                          if (_scanFolders.isEmpty)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Text('没有扫描文件夹，点击下方按钮添加'),
                              ),
                            )
                          else
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _scanFolders.length,
                              itemBuilder: (context, index) {
                                final folder = _scanFolders[index];
                                return ListTile(
                                  leading: const Icon(Icons.folder),
                                  title: Text(
                                    folder,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete),
                                    onPressed: () => _removeScanFolder(index),
                                  ),
                                );
                              },
                            ),
                          const SizedBox(height: 16),
                          Center(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.add),
                              label: const Text('添加文件夹'),
                              onPressed: _addScanFolder,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // 移动端设备说明
                if (!MediaScanSettingsPage.isDesktopPlatform())
                  Card.filled(
                    margin: const EdgeInsets.only(bottom: 16.0),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            '移动设备媒体访问',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 12),
                          Text(
                            '在移动设备上，应用会自动使用系统媒体库中的照片和视频，无需手动选择扫描文件夹。',
                            style: TextStyle(fontSize: 14),
                          ),
                          SizedBox(height: 8),
                          Text(
                            '请确保已授予应用访问照片和媒体的权限。',
                            style:
                                TextStyle(fontSize: 14, color: Colors.orange),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
