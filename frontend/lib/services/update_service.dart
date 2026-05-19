import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:open_filex/open_filex.dart';
import 'package:permission_handler/permission_handler.dart';

class UpdateInfo {
  final String version;
  final String releaseNotes;
  final String downloadUrl;

  UpdateInfo({
    required this.version,
    required this.releaseNotes,
    required this.downloadUrl,
  });
}

class UpdateService {
  // Pastikan Dio mengikuti redirect karena Worker membalas dengan 302 ke S3
  final Dio _dio = Dio(BaseOptions(followRedirects: true));
  
  // Ganti dengan URL Worker Anda
  final String _workerUrl = 'https://kaypos-worker-updater.wahyutkj-18.workers.dev/api/latest-release';
  CancelToken? _cancelToken;

  /// 1. Memeriksa pembaruan ke Cloudflare Worker
  Future<UpdateInfo?> checkUpdate() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      final response = await _dio.get(_workerUrl);

      if (response.statusCode == 200) {
        final data = response.data;
        final String latestVersion = data['version'];
        String releaseNotes = (data['releaseNotes'] ?? '').toString();
        // Bersihkan link GitHub Changelog agar UI lebih rapi
        releaseNotes = releaseNotes.replaceAll(RegExp(r'\*\*Full Changelog\*\*.*', dotAll: true), '').trim();
        final Map<String, dynamic> assetsUrls = data['assets'] ?? {};

        if (_isNewerVersion(currentVersion, latestVersion)) {
          final downloadUrl = _getDownloadUrlForCurrentPlatform(assetsUrls);
          if (downloadUrl != null) {
            return UpdateInfo(
              version: latestVersion,
              releaseNotes: releaseNotes,
              downloadUrl: downloadUrl,
            );
          }
        }
      }
    } catch (e) {
      print('UpdateService Error (checkUpdate): $e');
      throw Exception('Gagal memeriksa pembaruan. Periksa koneksi internet Anda.');
    }
    return null;
  }

  /// 2. Mengunduh file installer dan menyimpannya di temporary directory
  Future<String?> downloadUpdate({
    required String downloadUrl,
    required String version,
    required Function(int received, int total) onProgress,
  }) async {
    _cancelToken = CancelToken();
    try {
      final tempDir = await getTemporaryDirectory();
      final extension = _getExtensionForCurrentPlatform();
      final savePath = '${tempDir.path}/app_update_$version$extension';

      await _dio.download(
        downloadUrl,
        savePath,
        cancelToken: _cancelToken,
        onReceiveProgress: onProgress,
      );

      return savePath;
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        print('Unduhan dibatalkan oleh pengguna.');
        return null;
      } else {
        print('UpdateService Error (download): $e');
        throw Exception('Gagal mengunduh file update. Sinyal mungkin tidak stabil.');
      }
    } catch (e) {
      print('UpdateService Error (download system): $e');
      throw Exception('Terjadi kesalahan sistem saat menyimpan file unduhan.');
    }
  }

  /// 3. Membatalkan proses unduhan
  void cancelDownload() {
    _cancelToken?.cancel('Dibatalkan oleh pengguna.');
  }

  /// 4. Menjalankan file installer setelah selesai diunduh 100%
  Future<void> installUpdate(String filePath) async {
    try {
      if (Platform.isAndroid) {
        // Meminta izin instalasi paket untuk Android
        final status = await Permission.requestInstallPackages.request();
        if (status.isGranted) {
          final result = await OpenFilex.open(filePath);
          if (result.type != ResultType.done) {
            throw Exception('Gagal membuka file APK: ${result.message}');
          }
        } else {
          throw Exception('Izin untuk menginstal aplikasi tidak diberikan.');
        }
      } else if (Platform.isLinux) {
        // Eksekusi instalasi otomatis di Linux menggunakan pkexec
        ProcessResult result;
        if (filePath.endsWith('.rpm')) {
          result = await Process.run('pkexec', ['dnf', 'reinstall', '-y', filePath]);
        } else {
          result = await Process.run('pkexec', ['apt-get', 'install', '--reinstall', '-y', filePath]);
        }
        
        if (result.exitCode == 0) {
          // Restart aplikasi secara otomatis setelah selesai
          Process.start('/opt/kaypos/kaypos', []);
          exit(0);
        } else {
          throw Exception('Instalasi dibatalkan atau gagal: ${result.stderr}');
        }
      } else {
        // Untuk Windows (.exe), macOS (.dmg)
        final result = await OpenFilex.open(filePath);
        if (result.type != ResultType.done) {
          throw Exception('Gagal mengeksekusi installer: ${result.message}');
        }
      }
    } catch (e) {
      print('UpdateService Error (install): $e');
      rethrow;
    }
  }

  /// Helper: Membandingkan Semantic Versioning (Lokal vs Server)
  bool _isNewerVersion(String current, String latest) {
    try {
      final v1 = current.split('.').map(int.parse).toList();
      final v2 = latest.split('.').map(int.parse).toList();

      for (int i = 0; i < 3; i++) {
        final num1 = i < v1.length ? v1[i] : 0;
        final num2 = i < v2.length ? v2[i] : 0;
        if (num2 > num1) return true;
        if (num2 < num1) return false;
      }
    } catch (e) {
      print('UpdateService Error (Version Parse): $e');
    }
    return false; // Sama atau format salah
  }

  /// Helper: Cek apakah OS Linux adalah keluarga Fedora/RedHat
  bool _isFedora() {
    if (!Platform.isLinux) return false;
    return File('/etc/fedora-release').existsSync() || File('/etc/redhat-release').existsSync() || File('/usr/bin/rpm').existsSync();
  }

  /// Helper: Mendapatkan URL unduhan sesuai platform OS
  String? _getDownloadUrlForCurrentPlatform(Map<String, dynamic> assetsUrls) {
    if (Platform.isAndroid) return assetsUrls['apk'];
    if (Platform.isWindows) return assetsUrls['exe'];
    if (Platform.isMacOS) return assetsUrls['dmg'];
    if (Platform.isLinux) {
      if (_isFedora()) return assetsUrls['rpm'] ?? assetsUrls['deb'];
      return assetsUrls['deb'];
    }
    return null;
  }

  /// Helper: Mendapatkan ekstensi file sesuai platform OS
  String _getExtensionForCurrentPlatform() {
    if (Platform.isAndroid) return '.apk';
    if (Platform.isWindows) return '.exe';
    if (Platform.isMacOS) return '.dmg';
    if (Platform.isLinux) {
      if (_isFedora()) return '.rpm';
      return '.deb';
    }
    return '';
  }
}
