import 'reaction.dart';

/// Chat domain models.

enum ChatRequestStatus { pending, accepted, declined }

/// A request to start chatting, fired from the beacon or a story ("Beak").
///
/// A Beak can carry a preview the recipient sees before accepting:
///  * [reaction]      — they reacted to your story (👍 ❤️ 😂 …), and/or
///  * [openingMessage] — a first line they sent, and/or
///  * [aboutStoryCaption] — which story it was about.
/// On accept the preview becomes the first message in the chat, so you
/// literally "accept by responding".
class ChatRequest {
  final String id;
  final String fromUserId;
  final String fromUsername;
  final int fromAvatarSeed;
  final String toUserId;
  final ChatRequestStatus status;
  final DateTime createdAt;

  /// True when the request came TO the current device (incoming).
  final bool incoming;

  final ReactionType? reaction;
  final String? openingMessage;
  final String? aboutStoryId;
  final String? aboutStoryCaption;

  /// True when this request came from an explicit add-by-PIN (BBM-style),
  /// rather than a proximity Beak.
  final bool viaPin;

  const ChatRequest({
    required this.id,
    required this.fromUserId,
    required this.fromUsername,
    required this.fromAvatarSeed,
    required this.toUserId,
    required this.status,
    required this.createdAt,
    required this.incoming,
    this.reaction,
    this.openingMessage,
    this.aboutStoryId,
    this.aboutStoryCaption,
    this.viaPin = false,
  });

  /// One-line preview for the request tile / notification.
  String get preview {
    if (viaPin) return 'wants to be beacon friends';
    if (reaction != null && (openingMessage?.isNotEmpty ?? false)) {
      return '${reaction!.emoji} “$openingMessage”';
    }
    if (reaction != null) {
      return aboutStoryCaption != null
          ? 'reacted ${reaction!.emoji} to your story'
          : 'reacted ${reaction!.emoji}';
    }
    if (openingMessage?.isNotEmpty ?? false) return '“$openingMessage”';
    return 'wants to chat';
  }

  ChatRequest copyWith({ChatRequestStatus? status}) => ChatRequest(
        id: id,
        fromUserId: fromUserId,
        fromUsername: fromUsername,
        fromAvatarSeed: fromAvatarSeed,
        toUserId: toUserId,
        status: status ?? this.status,
        createdAt: createdAt,
        incoming: incoming,
        reaction: reaction,
        openingMessage: openingMessage,
        aboutStoryId: aboutStoryId,
        aboutStoryCaption: aboutStoryCaption,
        viaPin: viaPin,
      );
}

class Message {
  final String id;
  final String senderId;
  final String text;
  final DateTime sentAt;

  const Message({
    required this.id,
    required this.senderId,
    required this.text,
    required this.sentAt,
  });
}

/// An active conversation with another anonymous beacon.
class Chat {
  final String id;
  final String peerId;
  final String peerUsername;
  final int peerAvatarSeed;
  final List<Message> messages;
  final DateTime updatedAt;

  const Chat({
    required this.id,
    required this.peerId,
    required this.peerUsername,
    required this.peerAvatarSeed,
    required this.messages,
    required this.updatedAt,
  });

  Message? get lastMessage => messages.isEmpty ? null : messages.last;

  Chat copyWith({List<Message>? messages, DateTime? updatedAt}) => Chat(
        id: id,
        peerId: peerId,
        peerUsername: peerUsername,
        peerAvatarSeed: peerAvatarSeed,
        messages: messages ?? this.messages,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}
