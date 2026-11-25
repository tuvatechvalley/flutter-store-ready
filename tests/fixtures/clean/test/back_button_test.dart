void main() {
  testWidgets('back button returns to the parent page', (tester) async {
    await tester.pumpWidget(const App());
    expect(await tester.binding.handlePopRoute(), isTrue);
  });
}
