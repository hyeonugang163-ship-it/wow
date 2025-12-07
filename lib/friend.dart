class Friend {
  const Friend({
    required this.id,
    required this.name,
    this.status,
  });

  final String id;
  final String name;
  final String? status;
}
