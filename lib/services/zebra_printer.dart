import 'package:flutter/services.dart';

class ZebraPrinter {
  static const _ch = MethodChannel('zebra_print');

  /// Opens iOS Bluetooth accessory picker for MFi Zebra printers
  static Future<void> pairAccessory() async {
    await _ch.invokeMethod('pairAccessory');
  }

  /// Discovers paired & connected MFi printers
  static Future<List<Map<String, dynamic>>> discoverPrinters() async {
    final res = await _ch.invokeMethod<List<dynamic>>('discoverPrinters');
    return (res ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  /// Sends a ZPL string to the printer with the given serial number
  static Future<void> sendZplToSerial(String serialNumber, String zpl) async {
    await _ch.invokeMethod('sendZplToSerial', {
      'serialNumber': serialNumber,
      'zpl': zpl,
    });
  }
}