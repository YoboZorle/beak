import 'dart:async';
import 'package:flutter/material.dart';

import '../models/beacon_user.dart';
import '../models/chat.dart';
import '../models/reaction.dart';
import '../services/backend_service.dart';

class ChatProvider extends ChangeNotifier {
  ChatProvider(this._backend, this.myId) {
    _reqSub = _backend.requestStream().listen((r) {
      _requests = r;
      notifyListeners();
    });
    _chatSub = _backend.chatStream().listen((c) {
      _chats = List.of(c)..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      notifyListeners();
    });
  }

  final BackendService _backend;

  /// This device's identity id (== Beau PIN). Used to tell my messages from
  /// the peer's, and to compute unread counts.
  final String myId;

  late final StreamSubscription _reqSub;
  late final StreamSubscription _chatSub;

  List<ChatRequest> _requests = [];
  List<Chat> _chats = [];

  /// Last time each chat was opened/read (chatId -> timestamp).
  final Map<String, DateTime> _lastRead = {};

  List<ChatRequest> get requests => _requests;
  List<ChatRequest> get incomingPending => _requests
      .where((r) => r.incoming && r.status == ChatRequestStatus.pending)
      .toList();
  List<Chat> get chats => _chats;
  int get pendingCount => incomingPending.length;

  /// Unread peer messages in a chat (messages from the peer after last read).
  int unread(Chat c) {
    final since = _lastRead[c.id] ?? DateTime.fromMillisecondsSinceEpoch(0);
    return c.messages
        .where((m) => m.senderId != myId && m.sentAt.isAfter(since))
        .length;
  }

  int get unreadTotal => _chats.fold(0, (sum, c) => sum + unread(c));

  /// Badge shown on the Chats tab: unread messages + pending Beak requests.
  int get inboxBadge => unreadTotal + pendingCount;

  void markRead(String chatId) {
    _lastRead[chatId] = DateTime.now();
    notifyListeners();
  }

  Chat? chatById(String id) {
    for (final c in _chats) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// Fire a Beak — optionally carrying a reaction and/or an opening message,
  /// and the story it came from.
  Future<void> beak(
    BeaconUser target, {
    ReactionType? reaction,
    String? openingMessage,
    String? aboutStoryId,
    String? aboutStoryCaption,
  }) =>
      _backend.requestChat(
        target,
        reaction: reaction,
        openingMessage: openingMessage,
        aboutStoryId: aboutStoryId,
        aboutStoryCaption: aboutStoryCaption,
      );

  Future<Chat> accept(ChatRequest r) => _backend.acceptRequest(r);
  Future<void> decline(ChatRequest r) => _backend.declineRequest(r);

  /// BBM-style add by Beau PIN.
  Future<AddFriendResult> addByPin(String pin) => _backend.addFriendByPin(pin);

  Future<void> send(String chatId, String text) =>
      _backend.sendMessage(chatId: chatId, text: text);

  @override
  void dispose() {
    _reqSub.cancel();
    _chatSub.cancel();
    super.dispose();
  }
}
