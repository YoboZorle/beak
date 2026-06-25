import 'dart:async';
import 'dart:math';

import 'package:uuid/uuid.dart';

import '../models/beacon_user.dart';
import '../models/chat.dart';
import '../models/level.dart';
import '../models/reaction.dart';
import '../models/story.dart';
import 'backend_service.dart';
import 'location_service.dart';
import 'storage_service.dart';
import 'username_generator.dart';

/// In-memory backend for the frontend phase — the single source of truth.
///
/// Everything is driven through streams so all screens stay consistent:
/// discovery (beacons + stories), chat requests, chats, and push events all
/// flow from the same mutable state and are re-emitted on every change.
class MockBackendService implements BackendService {
  MockBackendService(this._storage);

  final StorageService _storage;
  final _uuid = const Uuid();
  final _rng = Random();

  late BeaconUser _me;
  double _myLat = LocationService.fallbackLat;
  double _myLng = LocationService.fallbackLng;

  final List<BeaconUser> _world = [];
  final List<Story> _stories = [];
  final List<ChatRequest> _requests = [];
  final List<Chat> _chats = [];
  Story? _myStory;

  final _beaconCtrl = StreamController<List<BeaconUser>>.broadcast();
  final _storyCtrl = StreamController<List<Story>>.broadcast();
  final _requestCtrl = StreamController<List<ChatRequest>>.broadcast();
  final _chatCtrl = StreamController<List<Chat>>.broadcast();
  final _eventCtrl = StreamController<NearbyEvent>.broadcast();

  Timer? _ambient;
  Timer? _expiry;

  static const double _maxMeters = 30000;

  // ------------------------------------------------------------- identity
  @override
  Future<BeaconUser> ensureIdentity(
      {required double lat, required double lng}) async {
    _myLat = lat;
    _myLng = lng;

    // Device-bound, deterministic identity (BBM-style): derived from the PIN.
    final seed = _storage.identitySeed;
    _me = BeaconUser(
      id: _storage.pin,
      username: UsernameGenerator.generateFrom(seed),
      avatarSeed: UsernameGenerator.avatarSeedFrom(seed),
      level: Level.fromPostCount(_storage.postCount),
      distanceMeters: 0,
      hasStory: _live,
      bearing: 0,
    );

    _myStory = await myStory();
    _seedWorld();
    _startTimers();
    _emitDiscovery();
    return _me;
  }

  @override
  Future<int> postCount() async => _storage.postCount;

  // -------------------------------------------------------------- gating
  bool get _live {
    final last = _storage.lastPostAt;
    return last != null && DateTime.now().difference(last) < Story.lifetime;
  }

  @override
  Future<bool> hasActivePost() async => _live;

  // ------------------------------------------------------------ discovery
  void _seedWorld() {
    if (_world.isNotEmpty) return;
    final count = 9 + _rng.nextInt(4); // 9-12 people
    for (var i = 0; i < count; i++) {
      _world.add(_spawn(maxMeters: _maxMeters));
    }
    // Give roughly half of them a live story.
    final withStories =
        _world.where((_) => _rng.nextBool()).toList(growable: false);
    for (final u in withStories) {
      _stories.add(_storyFor(u));
    }
  }

  BeaconUser _spawn({required double maxMeters}) {
    final dist = 80 + _rng.nextDouble() * maxMeters;
    return BeaconUser(
      id: _uuid.v4(),
      username: UsernameGenerator.generate(),
      avatarSeed: UsernameGenerator.avatarSeed(),
      level: Level.fromPostCount(_rng.nextInt(60)),
      distanceMeters: dist,
      hasStory: false,
      bearing: _rng.nextDouble() * 2 * pi,
    );
  }

  static const _captions = [
    'anyone around for late night anime talk?',
    'rewatching FMA Brotherhood, fight me',
    'new in town. say hi 👋',
    'coffee + manga kind of evening',
    "who else can't sleep",
    'cosplay wip, opinions?',
    'looking for a co-op partner tonight',
    'drop your top 5 anime rn',
    'sketching at the park, anyone close?',
  ];

  Story _storyFor(BeaconUser u) {
    // Mark the author as having a live story so the radar ring shows.
    final idx = _world.indexWhere((w) => w.id == u.id);
    if (idx != -1) _world[idx] = _world[idx].copyWith(hasStory: true);
    return Story(
      id: _uuid.v4(),
      authorId: u.id,
      authorUsername: u.username,
      authorAvatarSeed: u.avatarSeed,
      authorLevel: u.level,
      type: StoryType.textCard, // peers use text cards in Phase 1
      gradientIndex: _rng.nextInt(8),
      caption: _captions[_rng.nextInt(_captions.length)],
      createdAt:
          DateTime.now().subtract(Duration(minutes: _rng.nextInt(22 * 60))),
      distanceMeters: u.distanceMeters,
    );
  }

  List<BeaconUser> _gatedBeacons() {
    if (!_live) return const [];
    return (_world.where((u) => u.distanceMeters <= _maxMeters).toList())
      ..sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
  }

  List<Story> _gatedStories() {
    if (!_live) return const [];
    _stories.removeWhere((s) => s.isExpired);
    return (_stories.where((s) => s.distanceMeters <= _maxMeters).toList())
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  void _emitDiscovery() {
    _beaconCtrl.add(_gatedBeacons());
    _storyCtrl.add(_gatedStories());
  }

  @override
  Stream<List<BeaconUser>> beaconStream() => _beaconCtrl.stream;

  @override
  Stream<List<Story>> storyStream() => _storyCtrl.stream;

  @override
  Future<List<BeaconUser>> nearbyBeacons({
    required double lat,
    required double lng,
    double radiusKm = 30,
  }) async {
    _myLat = lat;
    _myLng = lng;
    // Simulate movement / new arrivals on each manual scan (shake).
    for (var i = 0; i < _world.length; i++) {
      final u = _world[i];
      final jitter = (_rng.nextDouble() - 0.5) * 800;
      final d = (u.distanceMeters + jitter).clamp(60.0, _maxMeters);
      _world[i] = u.copyWith(distanceMeters: d);
      // keep that user's story distance in sync
      final si = _stories.indexWhere((s) => s.authorId == u.id);
      if (si != -1) _stories[si] = _stories[si].copyWith(distanceMeters: d);
    }
    if (_live && _rng.nextDouble() < 0.4) _world.add(_spawn(maxMeters: _maxMeters));
    _emitDiscovery();
    return _gatedBeacons();
  }

  @override
  Future<List<Story>> nearbyStories({
    required double lat,
    required double lng,
    double radiusKm = 30,
  }) async {
    _emitDiscovery();
    return _gatedStories();
  }

  // -------------------------------------------------------------- posting
  @override
  Future<bool> canPostStory() async => !_live;

  @override
  Future<Duration?> myStoryRemaining() async {
    final last = _storage.lastPostAt;
    if (last == null) return null;
    final r = Story.lifetime - DateTime.now().difference(last);
    return r.isNegative ? null : r;
  }

  @override
  Future<Story?> myStory() async {
    final json = _storage.myStory;
    if (json == null) return null;
    final s = Story.fromJson(json);
    return s.isExpired ? null : s;
  }

  @override
  Future<Story> postStory({
    required StoryType type,
    required int gradientIndex,
    required String caption,
    String? imagePath,
    String? audioPath,
    int audioDurationMs = 0,
    required double lat,
    required double lng,
  }) async {
    final story = Story(
      id: _uuid.v4(),
      authorId: _me.id,
      authorUsername: _me.username,
      authorAvatarSeed: _me.avatarSeed,
      authorLevel: Level.fromPostCount(_storage.postCount + 1),
      type: type,
      gradientIndex: gradientIndex,
      caption: caption,
      createdAt: DateTime.now(),
      distanceMeters: 0,
      imagePath: imagePath,
      audioPath: audioPath,
      audioDurationMs: audioDurationMs,
    );
    await _storage.recordPost(story.toJson());
    _myStory = story;

    _me = _me.copyWith(hasStory: true);

    // Posting unlocks discovery — make sure there's a world to reveal, then
    // emit everything. (Consistency: one place updates, streams fan out.)
    _seedWorld();
    _emitDiscovery();
    return story;
  }

  // ----------------------------------------------------------------- chat
  String _previewText(ChatRequest r) {
    if ((r.openingMessage ?? '').isNotEmpty) return r.openingMessage!;
    if (r.reaction != null) return r.reaction!.emoji;
    return 'hey! saw you on the beacon 👋';
  }

  @override
  Future<ChatRequest> requestChat(
    BeaconUser target, {
    ReactionType? reaction,
    String? openingMessage,
    String? aboutStoryId,
    String? aboutStoryCaption,
  }) async {
    final req = ChatRequest(
      id: _uuid.v4(),
      fromUserId: _me.id,
      fromUsername: _me.username,
      fromAvatarSeed: _me.avatarSeed,
      toUserId: target.id,
      status: ChatRequestStatus.pending,
      createdAt: DateTime.now(),
      incoming: false,
      reaction: reaction,
      openingMessage: openingMessage,
      aboutStoryId: aboutStoryId,
      aboutStoryCaption: aboutStoryCaption,
    );
    _requests.add(req);
    _requestCtrl.add(List.unmodifiable(_requests));

    // Simulate the peer accepting; seed the chat with my opening line, then
    // a reply lands shortly after.
    Timer(Duration(seconds: 2 + _rng.nextInt(3)), () {
      final i = _requests.indexWhere((r) => r.id == req.id);
      if (i != -1) {
        _requests[i] = _requests[i].copyWith(status: ChatRequestStatus.accepted);
        _requestCtrl.add(List.unmodifiable(_requests));
      }
      final chat = _ensureChat(
        peerId: target.id,
        peerUsername: target.username,
        peerAvatarSeed: target.avatarSeed,
        seed: Message(
          id: _uuid.v4(),
          senderId: _me.id,
          text: _previewText(req),
          sentAt: DateTime.now(),
        ),
      );
      _scheduleReply(chat.id, target);
    });
    return req;
  }

  @override
  Future<Chat> acceptRequest(ChatRequest request) async {
    final i = _requests.indexWhere((r) => r.id == request.id);
    if (i != -1) {
      _requests[i] = _requests[i].copyWith(status: ChatRequestStatus.accepted);
      _requestCtrl.add(List.unmodifiable(_requests));
    }
    // Accepting by responding: their preview becomes the opening message.
    return _ensureChat(
      peerId: request.fromUserId,
      peerUsername: request.fromUsername,
      peerAvatarSeed: request.fromAvatarSeed,
      seed: Message(
        id: _uuid.v4(),
        senderId: request.fromUserId,
        text: _previewText(request),
        sentAt: DateTime.now(),
      ),
    );
  }

  Chat _ensureChat({
    required String peerId,
    required String peerUsername,
    required int peerAvatarSeed,
    Message? seed,
  }) {
    final existing = _chats.indexWhere((c) => c.peerId == peerId);
    if (existing != -1) return _chats[existing];
    final chat = Chat(
      id: _uuid.v4(),
      peerId: peerId,
      peerUsername: peerUsername,
      peerAvatarSeed: peerAvatarSeed,
      messages: seed != null ? [seed] : const [],
      updatedAt: DateTime.now(),
    );
    _chats.add(chat);
    _chatCtrl.add(List.unmodifiable(_chats));
    return chat;
  }

  void _scheduleReply(String chatId, BeaconUser peer) {
    Timer(Duration(milliseconds: 1400 + _rng.nextInt(1800)), () {
      final j = _chats.indexWhere((c) => c.id == chatId);
      if (j == -1) return;
      const replies = [
        'haha for real',
        'nice, what are you into?',
        'same! where you at rn?',
        "lol that's wild",
        'wanna trade anime recs?',
        'oh nice, glad you reached out 🙌',
      ];
      final c = _chats[j];
      _chats[j] = c.copyWith(
        messages: [
          ...c.messages,
          Message(
            id: _uuid.v4(),
            senderId: peer.id,
            text: replies[_rng.nextInt(replies.length)],
            sentAt: DateTime.now(),
          ),
        ],
        updatedAt: DateTime.now(),
      );
      _chatCtrl.add(List.unmodifiable(_chats));
      _eventCtrl.add(NearbyEvent(
        type: NearbyEventType.messageReceived,
        title: peer.username,
        body: 'sent you a message',
        username: peer.username,
        avatarSeed: peer.avatarSeed,
      ));
    });
  }

  @override
  Future<void> declineRequest(ChatRequest request) async {
    final i = _requests.indexWhere((r) => r.id == request.id);
    if (i != -1) {
      _requests[i] = _requests[i].copyWith(status: ChatRequestStatus.declined);
      _requestCtrl.add(List.unmodifiable(_requests));
    }
  }

  @override
  Future<void> sendMessage({required String chatId, required String text}) async {
    final i = _chats.indexWhere((c) => c.id == chatId);
    if (i == -1) return;
    final chat = _chats[i];
    _chats[i] = chat.copyWith(
      messages: [
        ...chat.messages,
        Message(
            id: _uuid.v4(),
            senderId: _me.id,
            text: text,
            sentAt: DateTime.now()),
      ],
      updatedAt: DateTime.now(),
    );
    _chatCtrl.add(List.unmodifiable(_chats));
    _scheduleReply(
      chatId,
      BeaconUser(
        id: chat.peerId,
        username: chat.peerUsername,
        avatarSeed: chat.peerAvatarSeed,
        level: const Level(stage: 0, progress: 0),
        distanceMeters: 0,
        hasStory: false,
        bearing: 0,
      ),
    );
  }

  // -------------------------------------------------------------- streams
  @override
  Stream<List<ChatRequest>> requestStream() => _requestCtrl.stream;

  @override
  Stream<List<Chat>> chatStream() => _chatCtrl.stream;

  @override
  Stream<NearbyEvent> nearbyEventStream() => _eventCtrl.stream;

  // -------------------------------------------------------------- timers
  void _startTimers() {
    _ambient?.cancel();
    _expiry?.cancel();

    // Live activity: new arrivals, new stories, incoming Beaks.
    _ambient = Timer.periodic(const Duration(seconds: 12), (_) {
      if (!_live) return; // gated — nothing to surface until you post
      final roll = _rng.nextDouble();
      if (roll < 0.4) {
        final u = _spawn(maxMeters: 14000);
        _world.add(u);
        _emitDiscovery();
        _eventCtrl.add(NearbyEvent(
          type: NearbyEventType.beaconNearby,
          title: 'New beacon near you',
          body: '${u.username} is ${u.distanceLabel}',
          username: u.username,
          avatarSeed: u.avatarSeed,
        ));
      } else if (roll < 0.72) {
        final u = _world.isEmpty
            ? _spawn(maxMeters: 14000)
            : _world[_rng.nextInt(_world.length)];
        if (!_world.any((w) => w.id == u.id)) _world.add(u);
        final s = _storyFor(u);
        _stories.add(s);
        _emitDiscovery();
        _eventCtrl.add(NearbyEvent(
          type: NearbyEventType.storyPosted,
          title: '${u.username} posted nearby',
          body: s.caption,
          username: u.username,
          avatarSeed: u.avatarSeed,
        ));
      } else {
        // Incoming Beak — often a reaction/message about MY live story.
        final u = _spawn(maxMeters: 9000);
        final react = _rng.nextBool()
            ? kReactions[_rng.nextInt(kReactions.length)]
            : null;
        final msg = react == null
            ? ['hey 👋', 'you seem cool', 'wanna talk anime?'][_rng.nextInt(3)]
            : null;
        final req = ChatRequest(
          id: _uuid.v4(),
          fromUserId: u.id,
          fromUsername: u.username,
          fromAvatarSeed: u.avatarSeed,
          toUserId: _me.id,
          status: ChatRequestStatus.pending,
          createdAt: DateTime.now(),
          incoming: true,
          reaction: react,
          openingMessage: msg,
          aboutStoryId: _myStory?.id,
          aboutStoryCaption: _myStory?.caption,
        );
        _requests.add(req);
        _requestCtrl.add(List.unmodifiable(_requests));
        _eventCtrl.add(NearbyEvent(
          type: NearbyEventType.chatRequest,
          title: 'Beak from ${u.username}',
          body: req.preview,
          username: u.username,
          avatarSeed: u.avatarSeed,
        ));
      }
    });

    // Expiry sweep: drop expired stories; re-gate when my post lapses.
    _expiry = Timer.periodic(const Duration(seconds: 20), (_) {
      final before = _stories.length;
      _stories.removeWhere((s) => s.isExpired);
      final myExpired = !_live && _myStory != null;
      if (myExpired) _myStory = null;
      if (before != _stories.length || myExpired) _emitDiscovery();
    });
  }

  @override
  void dispose() {
    _ambient?.cancel();
    _expiry?.cancel();
    _beaconCtrl.close();
    _storyCtrl.close();
    _requestCtrl.close();
    _chatCtrl.close();
    _eventCtrl.close();
  }
}
