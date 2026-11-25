import 'package:flutter/material.dart';

import 'backup_staging.dart'; // decoy: a file name, not a staging server

// decoy: an SVG namespace is an identifier, not a network address
const icon = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"/>';

String baseUrl({required bool isRelease}) {
  // decoy: the emulator address is only chosen when isRelease is false
  if (isRelease) return 'https://api.acme.app';
  return 'http://10.0.2.2:8000';
}

void main() {
  backup();
  runApp(const MaterialApp(home: Scaffold()));
}
