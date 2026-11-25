class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  Future<void> _save() async {
    try {
      await dio.post('/orders');
    } on DioException catch (e) {
      // planted: exception text, status code, server text, developer wording
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata: ${e.response?.statusCode}')),
      );
      showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Internal Server Error'),
          content: Text(e.response?.data['message'] as String),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) =>
      FilledButton(onPressed: _save, child: const Text('Kaydet'));
}
