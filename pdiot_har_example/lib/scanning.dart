import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class ScanningPage extends StatefulWidget {
  const ScanningPage({super.key});
  @override
  State<ScanningPage> createState() => _ScanningPageState();
}

class _ScanningPageState extends State<ScanningPage> {
  bool _returned = false;
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Scan RESpeck QR code')),
        body: MobileScanner(onDetect: (capture) {
          if (_returned || !mounted) return;
          for (final barcode in capture.barcodes) {
            final value = barcode.rawValue;
            if (value != null && value.isNotEmpty) {
              _returned = true;
              Navigator.pop(context, value);
              return;
            }
          }
        }),
      );
}
