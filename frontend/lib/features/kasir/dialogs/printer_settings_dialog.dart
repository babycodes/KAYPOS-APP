import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_pos_printer_platform_image_3/flutter_pos_printer_platform_image_3.dart';
import '../../../services/printer_service.dart';
import '../../../core/api.dart';
import '../../../core/helpers.dart';

class PrinterSettingsDialog extends StatefulWidget {
  const PrinterSettingsDialog({super.key});

  @override
  State<PrinterSettingsDialog> createState() => _PrinterSettingsDialogState();
}

class _PrinterSettingsDialogState extends State<PrinterSettingsDialog> {
  PrinterType defaultPrinterType = PrinterType.bluetooth;
  final PrinterService _printerService = PrinterService();
  
  List<PrinterDevice> devices = [];
  bool isScanning = false;
  StreamSubscription<PrinterDevice>? _subscription;

  @override
  void initState() {
    super.initState();
    _startScan();
  }

  void _startScan() {
    setState(() {
      devices.clear();
      isScanning = true;
    });

    _subscription?.cancel();
    _subscription = _printerService.scan(defaultPrinterType).listen((device) {
      bool exists = devices.any((d) {
        if (defaultPrinterType == PrinterType.bluetooth) {
          return d.address == device.address && d.address != null && d.address!.isNotEmpty;
        } else {
          return d.name == device.name;
        }
      });
      if (!exists && device.name != null && device.name!.isNotEmpty) {
        setState(() {
          devices.add(device);
        });
      }
    }, onDone: () {
      if (mounted) setState(() => isScanning = false);
    }, onError: (e) {
      if (mounted) setState(() => isScanning = false);
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _connect(PrinterDevice device) async {
    try {
      showDialog(
        context: context, 
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator())
      );
      await _printerService.connect(device, defaultPrinterType);
      if (mounted) {
        Navigator.pop(context); // close loading
        showToast(context, '✅ Printer ${device.name} terhubung');
        setState(() {}); // refresh UI to show connected status
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        showToast(context, '❌ Gagal: $e');
      }
    }
  }

  Future<void> _testPrint() async {
    try {
      if (!_printerService.isConnected) {
        showToast(context, '⚠️ Printer belum terhubung');
        return;
      }
      final res = await Api.post('/print/test');
      if (res['success'] == true && res['receipt_base64'] != null) {
        final bytes = base64Decode(res['receipt_base64']);
        await _printerService.printReceipt(bytes.toList());
        if (mounted) showToast(context, '✅ Test print berhasil');
      }
    } catch (e) {
      if (mounted) showToast(context, '❌ Gagal: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final selected = _printerService.selectedPrinter;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('🖨️ Pengaturan Printer', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
              const SizedBox(height: 16),
              
              // Type Selector
              Row(
                children: [
                  Expanded(
                    child: SegmentedButton<PrinterType>(
                      segments: const [
                        ButtonSegment(value: PrinterType.bluetooth, label: Text('Bluetooth'), icon: Icon(Icons.bluetooth)),
                        ButtonSegment(value: PrinterType.usb, label: Text('USB'), icon: Icon(Icons.usb)),
                      ],
                      selected: {defaultPrinterType},
                      onSelectionChanged: (Set<PrinterType> newSelection) {
                        setState(() {
                          defaultPrinterType = newSelection.first;
                        });
                        _startScan();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: isScanning ? null : _startScan,
                    icon: isScanning ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.refresh),
                    tooltip: 'Scan ulang',
                  )
                ],
              ),
              const SizedBox(height: 16),
              
              // Device List
              Expanded(
                child: devices.isEmpty 
                  ? Center(child: Text(isScanning ? 'Mencari printer...' : 'Tidak ada printer ditemukan'))
                  : ListView.builder(
                      itemCount: devices.length,
                      itemBuilder: (context, index) {
                        final device = devices[index];
                        final isSelected = selected != null && selected.address == device.address;
                        
                        return ListTile(
                          title: Text(device.name ?? 'Unknown'),
                          subtitle: Text(device.address ?? ''),
                          leading: Icon(
                            defaultPrinterType == PrinterType.bluetooth ? Icons.bluetooth : Icons.usb,
                            color: isSelected ? cs.primary : null,
                          ),
                          trailing: isSelected 
                            ? Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(12)),
                                child: Text('TERHUBUNG', style: TextStyle(color: cs.onPrimaryContainer, fontSize: 10, fontWeight: FontWeight.bold)),
                              )
                            : OutlinedButton(
                                onPressed: () => _connect(device),
                                child: const Text('Hubungkan'),
                              ),
                          onTap: isSelected ? null : () => _connect(device),
                        );
                      },
                    ),
              ),
              
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: selected == null ? null : _testPrint,
                  icon: const Icon(Icons.print),
                  label: const Text('Test Print'),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
