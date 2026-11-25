class StockScreen extends StatefulWidget {
  const StockScreen({super.key});

  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> {
  List<Map<String, Object?>> items = [];

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  // planted: no progress indicator while this runs, nothing shown when it fails
  Future<void> _fetch() async {
    final r = await dio.get('/stock');
    setState(() => items = (r.data as List).cast());
  }

  @override
  Widget build(BuildContext context) => ListView(
    children: [
      // decoy: `e` is a list item here, not an exception
      for (final e in items) Text('${e['count']}'),
    ],
  );
}
