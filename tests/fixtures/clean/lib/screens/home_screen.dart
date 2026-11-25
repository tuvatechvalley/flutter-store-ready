class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, Object?>> items = [];
  bool loading = true;
  AppFailure? failure;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => loading = true);
    try {
      final r = await dio.get('/items');
      items = (r.data as List).cast();
      failure = null;
    } on DioException catch (e, st) {
      logger.error('items failed: ${e.response?.statusCode} $e', e, st);
      failure = mapToFailure(e, st);
    }
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (loading) return const Center(child: CircularProgressIndicator());
    if (failure != null) {
      return ErrorView(message: l10n.failureMessage(failure!), onRetry: _fetch);
    }
    return ListView(
      children: [
        // decoy: `e` is a list item here, not an exception
        for (final e in items) Text('${e['count']}'),
      ],
    );
  }
}
