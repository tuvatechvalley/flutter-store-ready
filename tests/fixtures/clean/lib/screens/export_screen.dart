// decoy: awaits a local export service, not a server
class ExportScreen extends StatelessWidget {
  const ExportScreen({super.key});

  Future<void> _export() => const ExportService().exportCsv();

  @override
  Widget build(BuildContext context) =>
      FilledButton(onPressed: _export, child: const Text('Dışa aktar'));
}
