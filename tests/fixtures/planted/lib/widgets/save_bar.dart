// planted: a fixed-height button; its label is cut off at large text sizes
class SaveBar extends StatelessWidget {
  const SaveBar({super.key});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: 56,
    child: FilledButton(onPressed: () {}, child: const Text('Kaydet')),
  );
}
