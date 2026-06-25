/// WhatsApp-style reactions you can drop on a story. Choosing one also fires
/// a Beak (chat request) carrying the reaction as its preview.
enum ReactionType { like, love, laugh, wow, sad, fire }

extension ReactionTypeX on ReactionType {
  String get emoji {
    switch (this) {
      case ReactionType.like:
        return '👍';
      case ReactionType.love:
        return '❤️';
      case ReactionType.laugh:
        return '😂';
      case ReactionType.wow:
        return '😮';
      case ReactionType.sad:
        return '😢';
      case ReactionType.fire:
        return '🔥';
    }
  }

  String get label {
    switch (this) {
      case ReactionType.like:
        return 'Like';
      case ReactionType.love:
        return 'Love';
      case ReactionType.laugh:
        return 'Haha';
      case ReactionType.wow:
        return 'Wow';
      case ReactionType.sad:
        return 'Sad';
      case ReactionType.fire:
        return 'Fire';
    }
  }

  String get id => name;

  static ReactionType? fromId(String? id) {
    if (id == null) return null;
    for (final r in ReactionType.values) {
      if (r.name == id) return r;
    }
    return null;
  }
}

const List<ReactionType> kReactions = ReactionType.values;
