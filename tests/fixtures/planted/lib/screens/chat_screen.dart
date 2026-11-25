// planted: users read each other's messages; nothing lets them complain
// about a message or hide another user
class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key, required this.messages});

  final List<String> messages;

  @override
  Widget build(BuildContext context) =>
      ListView(children: [for (final m in messages) Text(m)]);
}
