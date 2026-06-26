import '../models/beacon_user.dart';
import '../models/chat.dart';
import '../models/reaction.dart';
import '../models/story.dart';

/// The single seam between the app and any backend.
///
/// Phase 1 ships [MockBackendService]. Phase 2 ships `FirebaseBackendService`
/// implementing this exact contract, so providers, screens, and widgets never
/// change. Swap the instance in `main.dart`.
abstract class BackendService {
  // ---- Identity --------------------------------------------------------
  /// Returns the device-bound identity (BBM-style; stable per device).
  Future<BeaconUser> ensureIdentity({required double lat, required double lng});

  /// Lifetime posts by the current device (drives level/progress).
  Future<int> postCount();

  // ---- Discovery (gated) -----------------------------------------------
  /// You only appear on the map — and can see others — while you have a live
  /// post. True once you've posted within the last 24h.
  Future<bool> hasActivePost();

  /// People around you within [radiusKm]. Empty until you have a live post.
  /// Also re-emits [beaconStream].
  Future<List<BeaconUser>> nearbyBeacons({
    required double lat,
    required double lng,
    double radiusKm = 30,
  });

  /// Live (<24h) stories near you. Empty until you have a live post. Also
  /// re-emits [storyStream].
  Future<List<Story>> nearbyStories({
    required double lat,
    required double lng,
    double radiusKm = 30,
  });

  /// Live, continuously-updating nearby beacons (new arrivals, movement).
  Stream<List<BeaconUser>> beaconStream();

  /// Live, continuously-updating nearby stories (new posts, expiries).
  Stream<List<Story>> storyStream();

  /// People near you ranked by level (highest first), including you. **Gated**:
  /// empty until you have a live post — you must post to see ranks and connect.
  /// Each entry's distance is from you; your own entry has distance 0.
  Future<List<BeaconUser>> nearbyLeaderboard({double radiusKm = 30});

  // ---- Posting ---------------------------------------------------------
  /// True if the device may post (one post per 24h rule).
  Future<bool> canPostStory();

  /// Time remaining on the current device's live post (null if none).
  Future<Duration?> myStoryRemaining();

  /// The current device's own live post (with real local media), if any.
  Future<Story?> myStory();

  /// Post the single allowed post — text card, image+text, or voice note.
  Future<Story> postStory({
    required StoryType type,
    required int gradientIndex,
    required String caption,
    String? imagePath,
    String? audioPath,
    int audioDurationMs = 0,
    required double lat,
    required double lng,
  });

  // ---- Chat ("Beak") ---------------------------------------------------
  /// Fire a chat request at someone. A Beak may carry a [reaction] and/or an
  /// [openingMessage], and reference the story it came from — the recipient
  /// sees that as a preview and accepts by responding.
  Future<ChatRequest> requestChat(
    BeaconUser target, {
    ReactionType? reaction,
    String? openingMessage,
    String? aboutStoryId,
    String? aboutStoryCaption,
  });

  /// BBM-style add-by-PIN. Send a friend request to a device by its Beau PIN;
  /// the other device accepts and you become connected. Returns the outcome.
  Future<AddFriendResult> addFriendByPin(String pin);

  /// Accept an incoming request -> creates a Chat (seeded with any preview).
  Future<Chat> acceptRequest(ChatRequest request);

  /// Decline an incoming request.
  Future<void> declineRequest(ChatRequest request);

  Future<void> sendMessage({required String chatId, required String text});

  // ---- Reactive streams ------------------------------------------------
  Stream<List<ChatRequest>> requestStream();
  Stream<List<Chat>> chatStream();

  /// Push-style nearby events. Backed by FCM in Firebase; simulated here.
  Stream<NearbyEvent> nearbyEventStream();

  void dispose();
}

/// Outcome of an add-by-PIN friend request.
enum AddFriendStatus { sent, self, invalid, alreadyConnected }

class AddFriendResult {
  final AddFriendStatus status;

  /// The handle derived from the PIN (so the UI can confirm who you added).
  final String? username;

  const AddFriendResult(this.status, {this.username});
}

enum NearbyEventType { beaconNearby, storyPosted, chatRequest, messageReceived }

class NearbyEvent {
  final NearbyEventType type;
  final String title;
  final String body;
  final String? username;
  final int avatarSeed;

  const NearbyEvent({
    required this.type,
    required this.title,
    required this.body,
    this.username,
    this.avatarSeed = 0,
  });
}
