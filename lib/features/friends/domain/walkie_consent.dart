class WalkieConsent {
  const WalkieConsent({
    required this.allowFromMe,
    required this.allowFromPeer,
  });

  final bool allowFromMe;
  final bool allowFromPeer;

  bool get isMutual => allowFromMe && allowFromPeer;

  WalkieConsent copyWith({
    bool? allowFromMe,
    bool? allowFromPeer,
  }) {
    return WalkieConsent(
      allowFromMe: allowFromMe ?? this.allowFromMe,
      allowFromPeer: allowFromPeer ?? this.allowFromPeer,
    );
  }
}

