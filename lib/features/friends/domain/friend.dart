class Friend {
  const Friend({
    required this.id,
    required this.name,
    this.status,
    this.isWalkieAllowed = false,
  });

  final String id;
  final String name;
  final String? status;
  // 이 친구와 상호 무전 허용 여부.
  // true이면 Walkie 모드에서 즉시 재생 허용 대상이다
  // (현재는 로컬/Fake 상태에 기반하며, 추후 서버 상호동의 정보와 연동될 수 있다).
  final bool isWalkieAllowed;
}
