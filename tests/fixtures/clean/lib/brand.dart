// decoys from real apps:
// - a logo wordmark that does not follow the font size (single widget),
// - one button that is full-width through its own style (not the theme).
class BrandHeader extends StatelessWidget {
  const BrandHeader({super.key});

  @override
  Widget build(BuildContext context) => Column(
    children: [
      const Text('Acme', textScaler: TextScaler.noScaling),
      // decoy: a 48×48 badge with one letter behaves like an icon
      Container(width: 48, height: 48, child: const Text('S')),
      FilledButton(
        onPressed: () {},
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
        child: const Text('Devam'),
      ),
    ],
  );
}
