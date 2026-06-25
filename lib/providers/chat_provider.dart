import 'dart:async';
import 'package:flutter/material.dart';

import '../models/beacon_user.dart';
import '../models/chat.dart';
import '../models/reaction.dart';
import '../services/backend_service.dart';

class ChatProvider extends ChangeNotifier {
  ChatProvider(this._backend) {
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
  late final StreamSubscription _reqSub;
  late final StreamSubscription _chatSub;

  List<ChatRequest> _requests = [];
  List<Chat> _chats = [];

  List<ChatRequest> get requests => _requests;
  List<ChatRequest> get incomingPending => _requests
      .where((r) => r.incoming && r.status == ChatRequestStatus.pending)
      .toList();
  List<Chat> get chats => _chats;
  int get pendingCount => incomingPending.length;

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
  Future<void> send(String chatId, String text) =>
      _backend.sendMessage(chatId: chatId, text: text);

  @override
  void dispose() {
    _reqSub.cancel();
    _chatSub.cancel();
    super.dispose();
  }
}
