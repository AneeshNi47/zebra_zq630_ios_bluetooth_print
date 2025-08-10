import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() => runApp(const ZebraTestApp());

class ZebraTestApp extends StatelessWidget {
  const ZebraTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Zebra Printer Test',
      home: ZebraPrinterTestPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class ZebraPrinterTestPage extends StatefulWidget {
  const ZebraPrinterTestPage({super.key});
  @override
  State<ZebraPrinterTestPage> createState() => _ZebraPrinterTestPageState();
}

class _ZebraPrinterTestPageState extends State<ZebraPrinterTestPage> {
  static const _platform = MethodChannel('zebra_print');

  // iOS: list of printers from EAAccessory (name, serialNumber, etc.)
  List<Map<String, dynamic>> _printers = [];
  String? _selectedSerial;

  late final TextEditingController _zplCtrl;

  @override
  void initState() {
    super.initState();
    _zplCtrl = TextEditingController(text: '^XA^FO50,50^ADN,36,20^FDHello Zebra!^FS^XZ');
  }

  @override
  void dispose() {
    _zplCtrl.dispose();
    super.dispose();
  }

  Future<void> _pairAccessory() async {
    if (!Platform.isIOS) return;
    try {
      await _platform.invokeMethod('pairAccessory'); // opens iOS Bluetooth Accessory Picker
      // iOS will post EAAccessoryDidConnect shortly after; give it a moment then refresh:
      await Future.delayed(const Duration(seconds: 1));
      await _discoverPrinters();
    } catch (e) {
      _snack('Pair error: $e');
    }
  }

  Future<void> _discoverPrinters() async {
    if (!Platform.isIOS) return;
    try {
      final res = await _platform.invokeMethod<List<dynamic>>('discoverPrinters');
      final list = (res ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      setState(() {
        _printers = list;
        // Auto-select the first printer if none selected
        _selectedSerial ??= _printers.isNotEmpty ? _printers.first['serialNumber'] as String? : null;
      });
    } catch (e) {
      _snack('Discover error: $e');
    }
  }

  Future<void> _sendZpl() async {
    if (Platform.isIOS) {
      if (_selectedSerial == null) {
        _snack('Select a printer first');
        return;
      }
      try {
        await _platform.invokeMethod('sendZplToSerial', {
          'serialNumber': _selectedSerial,
          'zpl': _zplCtrl.text,
        });
        _snack('Sent ✅');
      } catch (e) {
        _snack('Send error: $e');
      }
    } else {
      // TODO: Android path (your existing Android logic)
      _snack('Android path not implemented in this sample');
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final isIOS = Platform.isIOS;

    return Scaffold(
      appBar: AppBar(title: const Text('Zebra Printer Test')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (isIOS)
              Row(
                children: [
                  ElevatedButton(onPressed: _pairAccessory, child: const Text('Pair')),
                  const SizedBox(width: 12),
                  ElevatedButton(onPressed: _discoverPrinters, child: const Text('Discover')),
                ],
              ),
            const SizedBox(height: 12),
            if (isIOS)
              DropdownButton<String>(
                value: _selectedSerial,
                isExpanded: true,
                hint: const Text('Select Printer'),
                items: _printers.map((p) {
                  final name = (p['name'] as String?) ?? 'Unknown';
                  final sn = (p['serialNumber'] as String?) ?? '—';
                  return DropdownMenuItem<String>(
                    value: sn,
                    child: Text('$name ($sn)'),
                  );
                }).toList(),
                onChanged: (v) => setState(() => _selectedSerial = v),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: _zplCtrl,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'ZPL Data',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _sendZpl,
                child: const Text('Send ZPL to Printer'),
              ),
            ),
            const SizedBox(height: 8),
            // Helpful debug for what iOS is returning
            if (_printers.isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Found: ${_printers.map((p) => p['name']).join(', ')}',
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ),
          ],
        ),
      ),
    );
  }
}