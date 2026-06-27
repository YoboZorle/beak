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
/// Discovery is **location-real**: each nearby person is anchored at an actual
/// coordinate near the device, and distances are true haversine metres that
/// change as the user moves (the app feeds live GPS in via [nearbyBeacons]).
/// If the user jumps far (e.g. the first real GPS fix replaces the fallback),
/// people are re-anchored around the new position so the radar stays useful.
///
/// Because Beau's rule is "no post, no presence", **every** visible person has
/// a live post — so the radar always shows posts and updates in realtime as
/// new posts arrive and old ones expire. (Real *other* users arrive in Phase 2
/// via Firebase; here peers are simulated but behave consistently.)
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

  // Per-person geo: relative (distance, bearing) from the anchor, and the
  // resolved absolute coordinate. Distances are recomputed from these.
  final Map<String, List<double>> _rel = {}; // id -> [dist(m), bearing(rad)]
  final Map<String, List<double>> _coords = {}; // id -> [lat, lng]
  double? _anchorLat;
  double? _anchorLng;

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

  // ------------------------------------------------------------ geo helpers
  void _place(String id, double dist, double bearing) {
    _rel[id] = [dist, bearing];
    _coords[id] =
        LocationService.destination(_myLat, _myLng, dist, bearing);
  }

  void _reanchorIfNeeded() {
    final moved = (_anchorLat == null)
        ? double.infinity
        : LocationService.distanceMeters(
            _anchorLat!, _anchorLng!, _myLat, _myLng);
    if (moved > 2000) {
      // Re-place everyone around the new position, preserving their relative
      // distance + bearing, so a big GPS jump doesn't fling them away.
      for (final entry in _rel.entries) {
        _coords[entry.key] = LocationService.destination(
            _myLat, _myLng, entry.value[0], entry.value[1]);
      }
      _anchorLat = _myLat;
      _anchorLng = _myLng;
    }
  }

  void _recomputeDistances() {
    for (var i = 0; i < _world.length; i++) {
      final u = _world[i];
      final c = _coords[u.id];
      if (c == null) continue;
      final d = LocationService.distanceMeters(_myLat, _myLng, c[0], c[1]);
      _world[i] = u.copyWith(distanceMeters: d);
      final si = _stories.indexWhere((s) => s.authorId == u.id);
      if (si != -1) {
        _stories[si] =
            _stories[si].copyWith(distanceMeters: d, lat: c[0], lng: c[1]);
      }
    }
  }

  // ------------------------------------------------------------ discovery
  void _seedWorld() {
    if (_world.isNotEmpty) return;
    _anchorLat = _myLat;
    _anchorLng = _myLng;
    // A cluster right around the beacon (visible at the 1 km view)…
    for (var i = 0; i < 6; i++) {
      final u = _spawn(maxMeters: 900);
      _world.add(u);
      _stories.add(_storyFor(u)); // everyone visible has a post
    }
    // …plus more spread out for the wider ranges.
    final extra = 6 + _rng.nextInt(4);
    for (var i = 0; i < extra; i++) {
      final u = _spawn(maxMeters: 9000);
      _world.add(u);
      _stories.add(_storyFor(u));
    }
  }

  BeaconUser _spawn({required double maxMeters}) {
    final id = _uuid.v4();
    final bearing = _rng.nextDouble() * 2 * pi;
    final dist = 80 + _rng.nextDouble() * maxMeters;
    _place(id, dist, bearing);
    final c = _coords[id]!;
    return BeaconUser(
      id: id,
      username: UsernameGenerator.generate(),
      avatarSeed: UsernameGenerator.avatarSeed(),
      level: Level.fromPostCount(_rng.nextInt(60)),
      distanceMeters: LocationService.distanceMeters(_myLat, _myLng, c[0], c[1]),
      hasStory: true,
      bearing: bearing,
    );
  }

  static const _imageAssets = [
    'assets/samples/img1.png',
    'assets/samples/img2.png',
    'assets/samples/img3.png',
    'assets/samples/img4.png',
    'assets/samples/img5.png',
    'assets/samples/img6.png',
  ];
  static const _voiceAssets = [
    'assets/samples/voice1.wav',
    'assets/samples/voice2.wav',
    'assets/samples/voice3.wav',
  ];
  static const _voiceDurations = [4000, 6000, 3500];
  static const _voiceCaptions = [
    'my current mood 🎧',
    'say something back?',
    'guess this opening 🎶',
  ];

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

  /// A peer post. Peers use real bundled media — text cards, images, AND voice
  /// notes — so other people's posts look like yours. [fresh] posts are created
  /// "now" (just posted); otherwise they get a random age within the lifetime.
  Story _storyFor(BeaconUser u, {bool fresh = false}) {
    final pin = _coords[u.id] ?? [_myLat, _myLng];
    final roll = _rng.nextDouble();
    StoryType type;
    String? imagePath;
    String? audioPath;
    int audioMs = 0;
    String caption;
    if (roll < 0.45) {
      type = StoryType.textCard;
      caption = _captions[_rng.nextInt(_captions.length)];
    } else if (roll < 0.78) {
      type = StoryType.imageText;
      imagePath = _imageAssets[_rng.nextInt(_imageAssets.length)];
      caption = _captions[_rng.nextInt(_captions.length)];
    } else {
      type = StoryType.voiceNote;
      final vi = _rng.nextInt(_voiceAssets.length);
      audioPath = _voiceAssets[vi];
      audioMs = _voiceDurations[vi];
      caption = _voiceCaptions[_rng.nextInt(_voiceCaptions.length)];
    }
    return Story(
      id: _uuid.v4(),
      authorId: u.id,
      authorUsername: u.username,
      authorAvatarSeed: u.avatarSeed,
      authorLevel: u.level,
      type: type,
      gradientIndex: _rng.nextInt(8),
      caption: caption,
      createdAt: fresh
          ? DateTime.now()
          : DateTime.now()
              .subtract(Duration(seconds: _rng.nextInt(Story.lifetime.inSeconds))),
      distanceMeters: u.distanceMeters,
      lat: pin[0],
      lng: pin[1],
      imagePath: imagePath,
      audioPath: audioPath,
      audioDurationMs: audioMs,
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
  Future<List<BeaconUser>> nearbyLeaderboard({double radiusKm = 30}) async {
    if (!_live) return const []; // post first to see ranks
    final maxM = radiusKm * 1000;
    final people =
        _world.where((u) => u.distanceMeters <= maxM).toList();
    final me = BeaconUser(
      id: _me.id,
      username: _me.username,
      avatarSeed: _me.avatarSeed,
      level: Level.fromPostCount(_storage.postCount),
      distanceMeters: 0,
      hasStory: _live,
      bearing: 0,
    );
    final all = [me, ...people];
    all.sort((a, b) {
      final byStage = b.level.stage.compareTo(a.level.stage);
      if (byStage != 0) return byStage;
      return b.level.progress.compareTo(a.level.progress);
    });
    return all;
  }

  @override
  Future<List<BeaconUser>> nearbyBeacons({
    required double lat,
    required double lng,
    double radiusKm = 30,
  }) async {
    _myLat = lat;
    _myLng = lng;
    _reanchorIfNeeded();
    _recomputeDistances();
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
    _myLat = lat;
    _myLng = lng;
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
      lat: lat,
      lng: lng,
      imagePath: imagePath,
      audioPath: audioPath,
      audioDurationMs: audioDurationMs,
    );
    await _storage.recordPost(story.toJson());
    _myStory = story;
    _me = _me.copyWith(hasStory: true);

    _seedWorld(); // ensure a world to reveal
    _reanchorIfNeeded();
    _recomputeDistances();
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
  Future<AddFriendResult> addFriendByPin(String pinInput) async {
    final pin = StorageService.normalizePin(pinInput);
    if (!RegExp(r'^[0-9A-Z]{8}$').hasMatch(pin)) {
      return const AddFriendResult(AddFriendStatus.invalid);
    }
    if (pin == _me.id) return const AddFriendResult(AddFriendStatus.self);

    // Derive the friend's identity from their PIN — identical to how their own
    // device derives it, so the handle + avatar match exactly.
    final seed = UsernameGenerator.seedFromPin(pin);
    final username = UsernameGenerator.generateFrom(seed);
    final avatarSeed = UsernameGenerator.avatarSeedFrom(seed);

    final existingIdx = _chats.indexWhere((c) => c.peerId == pin);
    if (existingIdx != -1) {
      return AddFriendResult(AddFriendStatus.alreadyConnected,
          username: username, chatId: _chats[existingIdx].id);
    }

    final req = ChatRequest(
      id: _uuid.v4(),
      fromUserId: _me.id,
      fromUsername: _me.username,
      fromAvatarSeed: _me.avatarSeed,
      toUserId: pin,
      status: ChatRequestStatus.pending,
      createdAt: DateTime.now(),
      incoming: false,
      viaPin: true,
      openingMessage: 'added you by Beau PIN',
    );
    _requests.add(req);
    _requestCtrl.add(List.unmodifiable(_requests));

    final target = BeaconUser(
      id: pin,
      username: username,
      avatarSeed: avatarSeed,
      level: Level.fromPostCount(seed % 30),
      distanceMeters: 0,
      hasStory: false,
      bearing: 0,
    );

    // Simulate the other device receiving + accepting the request. In Phase 2
    // this is a real request routed to that PIN's device via Firebase.
    Timer(Duration(seconds: 2 + _rng.nextInt(3)), () {
      final i = _requests.indexWhere((r) => r.id == req.id);
      if (i != -1) {
        _requests[i] =
            _requests[i].copyWith(status: ChatRequestStatus.accepted);
        _requestCtrl.add(List.unmodifiable(_requests));
      }
      _ensureChat(
        peerId: target.id,
        peerUsername: target.username,
        peerAvatarSeed: target.avatarSeed,
        seed: Message(
          id: _uuid.v4(),
          senderId: target.id,
          text: 'hey! added you back 🤝',
          sentAt: DateTime.now(),
        ),
      );
      _eventCtrl.add(NearbyEvent(
        type: NearbyEventType.chatRequest,
        title: '$username accepted',
        body: 'You\u2019re now beacon friends — say hi!',
        username: username,
        avatarSeed: avatarSeed,
      ));
    });

    return AddFriendResult(AddFriendStatus.sent, username: username);
  }

  @override
  Future<Chat> acceptRequest(ChatRequest request) async {
    final i = _requests.indexWhere((r) => r.id == request.id);
    if (i != -1) {
      _requests[i] = _requests[i].copyWith(status: ChatRequestStatus.accepted);
      _requestCtrl.add(List.unmodifiable(_requests));
    }
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

    // Live activity every 7s. Gated until you post. Because presence requires
    // a post, a "new person" always comes WITH a post that lands close enough
    // to show on the scanner immediately.
    _ambient = Timer.periodic(const Duration(seconds: 7), (_) {
      if (!_live) return;
      if (_rng.nextDouble() < 0.7) {
        // New nearby post — placed within ~5km so it appears on the radar.
        final u = _spawn(maxMeters: 900);
        _world.add(u);
        final s = _storyFor(u, fresh: true);
        _stories.add(s);
        _emitDiscovery();
        _eventCtrl.add(NearbyEvent(
          type: NearbyEventType.storyPosted,
          title: '${u.username} posted nearby',
          body: '${s.caption}  ·  ${u.distanceLabel}',
          username: u.username,
          avatarSeed: u.avatarSeed,
        ));
      } else {
        // Incoming Beak — often a reaction/message about MY live story.
        final u = _spawn(maxMeters: 1600);
        _world.add(u);
        _stories.add(_storyFor(u, fresh: true));
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
        _emitDiscovery();
        _eventCtrl.add(NearbyEvent(
          type: NearbyEventType.chatRequest,
          title: 'Beak from ${u.username}',
          body: req.preview,
          username: u.username,
          avatarSeed: u.avatarSeed,
        ));
      }
    });

    // Expiry sweep every 8s: drop expired posts, re-gate when mine lapses,
    // and prune their geo so memory stays tidy.
    _expiry = Timer.periodic(const Duration(seconds: 8), (_) {
      final expired = _stories.where((s) => s.isExpired).toList();
      if (expired.isNotEmpty) {
        for (final s in expired) {
          _stories.removeWhere((x) => x.id == s.id);
          _world.removeWhere((w) => w.id == s.authorId);
          _rel.remove(s.authorId);
          _coords.remove(s.authorId);
        }
      }
      final myExpired = !_live && _myStory != null;
      if (myExpired) _myStory = null;
      if (expired.isNotEmpty || myExpired) _emitDiscovery();
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
