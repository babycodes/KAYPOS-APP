import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import '../../core/api.dart';
import '../../core/helpers.dart';
import '../../services/update_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  Map<String, dynamic> settings = {};
  
  PlatformFile? restoreFile;
  List<int>? restoreFileBytes;
  bool saving = false;
  String restoreMsg = '';

  String _currentVersion = '';
  final UpdateService _updateService = UpdateService();
  bool _isCheckingUpdate = false;
  double _downloadProgress = 0.0;

  final _storeNameCtrl = TextEditingController();
  final _storeAddressCtrl = TextEditingController();
  final _storePhoneCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    if (mounted) setState(() {
      _currentVersion = packageInfo.version;
    });
  }

  Future<void> _loadSettings() async {
    try {
      final res = await Api.get('/settings');
      if (mounted) setState(() {
        settings = res;
        _storeNameCtrl.text = settings['store_name'] ?? '';
        _storeAddressCtrl.text = settings['store_address'] ?? '';
        _storePhoneCtrl.text = settings['store_phone'] ?? '';
      });
    } catch (_) {}
  }

  Future<void> _saveSettings() async {
    setState(() => saving = true);
    try {
      await Api.put('/settings', body: {
        'store_name': _storeNameCtrl.text,
        'store_address': _storeAddressCtrl.text,
        'store_phone': _storePhoneCtrl.text,
      });
      if (mounted) showToast(context, 'Pengaturan tersimpan');
    } catch (e) {
      if (mounted) showToast(context, 'Gagal menyimpan: $e');
    }
    setState(() => saving = false);
  }

  void _downloadBackup() {
    final token = Api.getToken();
    final url = '${Api.getApiBase()}/backup/download?token=$token';
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }
  
  Future<void> _pickRestoreFile() async {
    FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['db'],
      withData: true,
    );

    if (result != null && result.files.isNotEmpty) {
      setState(() {
        restoreFile = result.files.first;
        restoreFileBytes = restoreFile!.bytes;
        restoreMsg = '';
      });
    }
  }

  Future<void> _restoreDB() async {
    if (restoreFile == null || restoreFileBytes == null) return;
    
    final confirm = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
      title: const Text('⚠️ Peringatan'),
      content: const Text('Ini akan mengganti semua data dengan file backup. Lanjutkan?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal')),
        FilledButton(onPressed: () => Navigator.pop(c, true), style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error), child: const Text('Lanjutkan Restore')),
      ],
    ));
    
    if (confirm != true) return;

    try {
      var request = http.MultipartRequest('POST', Uri.parse('${Api.getApiBase()}/backup/restore'));
      request.headers['Authorization'] = 'Bearer ${Api.getToken()}';
      request.files.add(http.MultipartFile.fromBytes('database', restoreFileBytes!, filename: restoreFile!.name));

      var response = await request.send();
      var respStr = await response.stream.bytesToString();
      
      if (response.statusCode == 200) {
        setState(() => restoreMsg = 'Berhasil! Harap restart server aplikasi.');
      } else {
        setState(() => restoreMsg = 'Error: $respStr');
      }
    } catch (e) {
      setState(() => restoreMsg = 'Error: $e');
    }
  }

  void _checkForUpdates() async {
    setState(() {
      _isCheckingUpdate = true;
      _downloadProgress = 0.0;
    });
    
    try {
      final updateInfo = await _updateService.checkUpdate();
      if (updateInfo != null) {
        _showUpdateDialog(updateInfo);
      } else {
        if (mounted) showToast(context, 'Aplikasi sudah versi terbaru.');
      }
    } catch (e) {
      if (mounted) showToast(context, e.toString());
    } finally {
      setState(() => _isCheckingUpdate = false);
    }
  }

  void _showUpdateDialog(UpdateInfo updateInfo) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: Text('Update Tersedia (v${updateInfo.version})'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(updateInfo.releaseNotes.isNotEmpty ? updateInfo.releaseNotes : 'Pembaruan sistem dan fitur terbaru tersedia.'),
                const SizedBox(height: 20),
                if (_downloadProgress > 0 && _downloadProgress < 100) ...[
                  LinearProgressIndicator(value: _downloadProgress / 100),
                  const SizedBox(height: 8),
                  Text('${_downloadProgress.toStringAsFixed(1)}% diunduh'),
                ] else if (_downloadProgress >= 100) ...[
                  const Text('Selesai mengunduh. Menyiapkan instalasi...', style: TextStyle(color: Colors.green)),
                ] else ...[
                  const Text('Pembaruan ini aman dan TIDAK AKAN menghapus data toko atau database Anda.', style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                ]
              ],
            ),
            actions: [
              if (_downloadProgress == 0)
                TextButton(
                  onPressed: () {
                    _updateService.cancelDownload();
                    Navigator.pop(context);
                  },
                  child: const Text('Nanti Saja'),
                ),
              ElevatedButton(
                onPressed: (_downloadProgress > 0 && _downloadProgress < 100) ? null : () async {
                  final path = await _updateService.downloadUpdate(
                    downloadUrl: updateInfo.downloadUrl,
                    version: updateInfo.version,
                    onProgress: (received, total) {
                      if (total != -1) {
                        setStateDialog(() {
                          _downloadProgress = (received / total * 100);
                        });
                      }
                    },
                  );
                  if (path != null && mounted) {
                    Navigator.pop(context); // Tutup dialog
                    await _updateService.installUpdate(path);
                  }
                },
                child: Text(_downloadProgress > 0 ? 'Mengunduh...' : 'Update Sekarang'),
              ),
            ],
          );
        }
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 800),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Store Info
          _SectionBox(cs, title: 'Info Toko', icon: Icons.storefront, children: [
            _Field('NAMA TOKO (UNTUK STRUK)', _storeNameCtrl),
            const SizedBox(height: 12),
            _Field('ALAMAT', _storeAddressCtrl),
            const SizedBox(height: 12),
            _Field('NO. TELP', _storePhoneCtrl),
          ]),
          const SizedBox(height: 24),

          FilledButton.icon(
            onPressed: saving ? null : _saveSettings,
            icon: const Icon(Icons.save),
            label: Text(saving ? 'Menyimpan...' : 'Simpan Pengaturan', style: const TextStyle(fontWeight: FontWeight.bold)),
            style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 56)),
          ),
          const SizedBox(height: 24),

          // Backup
          _SectionBox(cs, title: 'Backup & Restore', icon: Icons.backup, children: [
            FilledButton.icon(
              onPressed: _downloadBackup, icon: const Icon(Icons.download), label: const Text('Download Backup ke Perangkat Ini', style: TextStyle(fontWeight: FontWeight.bold)),
              style: FilledButton.styleFrom(backgroundColor: cs.secondaryContainer, foregroundColor: cs.onSecondaryContainer, minimumSize: const Size(double.infinity, 48)),
            ),
            const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider()),
            Text('Upload file .db untuk restore:', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: cs.surfaceContainer, borderRadius: BorderRadius.circular(12)), child: Text(restoreFile?.name ?? 'Belum ada file dipilih', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis))),
              const SizedBox(width: 8),
              FilledButton(onPressed: _pickRestoreFile, child: const Text('Pilih File')),
            ]),
            if (restoreFile != null) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _restoreDB, icon: const Icon(Icons.warning_amber), label: const Text('Restore Database', style: TextStyle(fontWeight: FontWeight.bold)),
                style: FilledButton.styleFrom(backgroundColor: cs.error, foregroundColor: cs.onError, minimumSize: const Size(double.infinity, 48)),
              ),
            ],
            if (restoreMsg.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Center(child: Text(restoreMsg, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: cs.primary)))),
          ]),
          const SizedBox(height: 24),

          // Update System
          _SectionBox(cs, title: 'Pembaruan Sistem', icon: Icons.system_update, action: _currentVersion.isEmpty ? null : Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(8)), child: Text('v$_currentVersion', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: cs.primary))), children: [
            Text('Periksa versi terbaru aplikasi KAYPOS. Data produk, pengaturan, dan riwayat transaksi tidak akan hilang setelah pembaruan.', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _isCheckingUpdate ? null : _checkForUpdates,
              icon: _isCheckingUpdate 
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) 
                : const Icon(Icons.cloud_download),
              label: Text(_isCheckingUpdate ? 'Mengecek...' : 'Cek Pembaruan', style: const TextStyle(fontWeight: FontWeight.bold)),
              style: FilledButton.styleFrom(backgroundColor: cs.primary, foregroundColor: cs.onPrimary, minimumSize: const Size(double.infinity, 48)),
            ),
          ]),
          const SizedBox(height: 24),
        ]),
      ),
    );
  }

  Widget _SectionBox(ColorScheme cs, {required String title, required IconData icon, Widget? action, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: cs.surfaceBright, borderRadius: BorderRadius.circular(20), border: Border.all(color: cs.outlineVariant)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(children: [
            Icon(icon, size: 20),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ]),
          if (action != null) action,
        ]),
        const SizedBox(height: 20),
        ...children,
      ]),
    );
  }

  Widget _Field(String label, TextEditingController ctrl, {String? hint}) {
    final cs = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: cs.onSurfaceVariant)),
      const SizedBox(height: 6),
      TextField(controller: ctrl, decoration: InputDecoration(hintText: hint)),
    ]);
  }
}
