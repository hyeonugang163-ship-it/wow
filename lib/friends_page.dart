import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class FriendsPage extends StatelessWidget {
  const FriendsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final friends = List.generate(
      10,
      (index) {
        final no = index + 1;
        return (
          id: 'u$no',
          name: '친구 $no',
        );
      },
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Friends'),
      ),
      body: ListView.builder(
        itemCount: friends.length,
        itemBuilder: (context, index) {
          final friend = friends[index];
          return ListTile(
            title: Text(friend.name),
            subtitle: Text(friend.id),
            onTap: () {
              context.push('/chat/${friend.id}');
            },
          );
        },
      ),
    );
  }
}
