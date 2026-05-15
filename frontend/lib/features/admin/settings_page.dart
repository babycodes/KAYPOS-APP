import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import '../../core/api.dart';
import '../../core/helpers.dart';

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
  
  List<dynamic> detectedPrinters = [];
  bool detecting = false;
  String testMsg = '';

  final _storeNameCtrl = TextEditingController();
  final _storeAddressCtrl = TextEditingController();
  final _storePhoneCtrl = TextEditingController();
  final _printerPortCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _detectPrinters();
  }

  Future<void> _loadSettings() async {
    try {
      final res = await Api.get('/settings');
      if (mounted) setState(() {
        settings = res;
        _storeNameCtrl.text = settings['store_name'] ?? '';
        _storeAddressCtrl.text = settings['store_address'] ?? '';
        _storePhoneCtrl.text = settings['store_phone'] ?? '';
        _printerPortCtrl.text = settings['printer_port'] ?? '';
      });
    } catch (_) {}
  }

  Future<void> _detectPrinters() async {
    setState(() => detecting = true);
    try {
      final res = await Api.get('/print/detect');
      setState(() {
        detectedPrinters = res['printers'] ?? [];
        if (res['current'] != null) {
          _printerPortCtrl.text = res['current'];
        }
      });
    } catch (_) {
      setState(() => detectedPrinters = []);
    }
    setState(() => detecting = false);
  }

  void _selectPrinter(String path) {
    setState(() => _printerPortCtrl.text = path);
  }

  Future<void> _testPrint() async {
    setState(() => testMsg = '');
    try {
      final res = await Api.post('/print/test');
      setState(() => testMsg = '✅ ${res['message'] ?? 'Test print berhasil!'}');
    } catch (e) {
      setState(() => testMsg = '❌ ${e.toString().replaceFirst('Exception: ', '')}');
    }
  }

  Future<void> _saveSettings() async {
    setState(() => saving = true);
    try {
      await Api.put('/settings', body: {
        'store_name': _storeNameCtrl.text,
        'store_address': _storeAddressCtrl.text,
        'store_phone': _storePhoneCtrl.text,
        'printer_port': _printerPortCtrl.text,
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

          // Printer
          _SectionBox(cs, title: 'Printer Thermal', icon: Icons.print, action: TextButton.icon(
            onPressed: detecting ? null : _detectPrinters,
            icon: detecting ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.refresh, size: 16),
            label: Text(detecting ? 'Mendeteksi...' : 'Deteksi Ulang', style: const TextStyle(fontSize: 12)),
          ), children: [
            if (detectedPrinters.isNotEmpty) ...[
              Text('Printer terdeteksi:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: cs.onSurfaceVariant)),
              const SizedBox(height: 8),
              ...detectedPrinters.map((p) {
                final isActive = _printerPortCtrl.text == p['path'];
                return Padding(padding: const EdgeInsets.only(bottom: 8), child: InkWell(onTap: () => _selectPrinter(p['path']), borderRadius: BorderRadius.circular(12), child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: isActive ? cs.primaryContainer : cs.surfaceContainer, border: Border.all(color: isActive ? cs.primary : cs.outlineVariant.withValues(alpha: 0.3)), borderRadius: BorderRadius.circular(12)),
                  child: Row(children: [
                    Icon(Icons.print, color: isActive ? cs.primary : cs.onSurfaceVariant),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(p['name'] ?? '', style: TextStyle(fontWeight: FontWeight.bold, color: cs.onSurface)),
                      Text(p['path'] ?? '', style: TextStyle(fontSize: 10, fontFamily: 'monospace', color: cs.onSurfaceVariant)),
                    ])),
                    if (p['writable'] == true)
                      Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)), child: const Text('OK', style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)))
                    else
                      Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: cs.errorContainer, borderRadius: BorderRadius.circular(4)), child: Text('No Access', style: TextStyle(color: cs.error, fontSize: 10, fontWeight: FontWeight.bold))),
                    if (isActive) ...[const SizedBox(width: 8), Icon(Icons.check, color: cs.primary, size: 20)]
                  ]),
                )));
              }).toList(),
            ] else if (!detecting) ...[
              Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: cs.surfaceContainer, borderRadius: BorderRadius.circular(12)), child: Center(child: Column(children: [
                Text('Tidak ada printer terdeteksi', style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('Hubungkan printer USB lalu tekan "Deteksi Ulang"', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant.withValues(alpha: 0.8))),
              ]))),
            ],
            const SizedBox(height: 16),
            _Field('PORT PRINTER (MANUAL)', _printerPortCtrl, hint: '/dev/usb/lp0'),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _testPrint, icon: const Icon(Icons.print, size: 16), label: const Text('Test Print', style: TextStyle(fontWeight: FontWeight.bold)),
              style: FilledButton.styleFrom(backgroundColor: cs.tertiaryContainer, foregroundColor: cs.onTertiaryContainer, minimumSize: const Size(double.infinity, 48)),
            ),
            if (testMsg.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Center(child: Text(testMsg, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: testMsg.contains('✅') ? Colors.green : cs.error)))),
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
