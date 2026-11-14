import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum ActiveModalOverlay {
  none,
  tentRest,
  turntable,
  pinball,
  sortingBelt,
  artifactBooth,
  finaleMontage,
  encoreDeck,
  settingsDrawer,
}

class DialogueSession extends Equatable {
  const DialogueSession({
    required this.speakerName,
    required this.speakerTitle,
    required this.portraitAsset,
    required this.voicePitch,
    required this.lines,
    this.pageIndex = 0,
  });

  final String speakerName;
  final String speakerTitle;
  final String portraitAsset;
  final String voicePitch;
  final List<String> lines;
  final int pageIndex;

  String get currentLine =>
      lines.isEmpty ? '' : lines[pageIndex.clamp(0, lines.length - 1)];

  bool get hasNextPage => pageIndex + 1 < lines.length;

  DialogueSession nextPage() => DialogueSession(
        speakerName: speakerName,
        speakerTitle: speakerTitle,
        portraitAsset: portraitAsset,
        voicePitch: voicePitch,
        lines: lines,
        pageIndex: pageIndex + 1,
      );

  @override
  List<Object?> get props => [
        speakerName,
        speakerTitle,
        portraitAsset,
        voicePitch,
        lines,
        pageIndex,
      ];
}

class UiOverlayState extends Equatable {
  const UiOverlayState({
    this.dialogue,
    this.modal = ActiveModalOverlay.none,
    this.toastBanner,
    this.nearbyInteractPrompt,
    this.turntableTrackNumber,
  });

  final DialogueSession? dialogue;
  final ActiveModalOverlay modal;
  final String? toastBanner;
  final String? nearbyInteractPrompt;
  final int? turntableTrackNumber;

  bool get isBlockingInput =>
      dialogue != null ||
      (modal != ActiveModalOverlay.none &&
          modal != ActiveModalOverlay.encoreDeck);

  UiOverlayState copyWith({
    DialogueSession? dialogue,
    bool clearDialogue = false,
    ActiveModalOverlay? modal,
    String? toastBanner,
    bool clearToast = false,
    String? nearbyInteractPrompt,
    bool clearPrompt = false,
    int? turntableTrackNumber,
    bool clearTurntableTrack = false,
  }) {
    return UiOverlayState(
      dialogue: clearDialogue ? null : (dialogue ?? this.dialogue),
      modal: modal ?? this.modal,
      toastBanner: clearToast ? null : (toastBanner ?? this.toastBanner),
      nearbyInteractPrompt: clearPrompt
          ? null
          : (nearbyInteractPrompt ?? this.nearbyInteractPrompt),
      turntableTrackNumber: clearTurntableTrack
          ? null
          : (turntableTrackNumber ?? this.turntableTrackNumber),
    );
  }

  @override
  List<Object?> get props => [
        dialogue,
        modal,
        toastBanner,
        nearbyInteractPrompt,
        turntableTrackNumber,
      ];
}

class UiOverlayNotifier extends StateNotifier<UiOverlayState> {
  UiOverlayNotifier() : super(const UiOverlayState());

  void startDialogue(DialogueSession session) {
    if (session.lines.isEmpty) return;
    state = state.copyWith(dialogue: session);
  }

  /// Advances to the next page or closes the dialogue box. Returns true if closed.
  bool advanceOrCloseDialogue() {
    final current = state.dialogue;
    if (current == null) return true;
    if (current.hasNextPage) {
      state = state.copyWith(dialogue: current.nextPage());
      return false;
    }
    state = state.copyWith(clearDialogue: true);
    return true;
  }

  void openModal(ActiveModalOverlay modal) {
    state = state.copyWith(modal: modal);
  }

  void closeModal() {
    state = state.copyWith(modal: ActiveModalOverlay.none);
  }

  void showToast(String message) {
    state = state.copyWith(toastBanner: message);
  }

  void clearToast() {
    if (state.toastBanner != null) {
      state = state.copyWith(clearToast: true);
    }
  }

  void setNearbyPrompt(String? prompt) {
    if (prompt == state.nearbyInteractPrompt) return;
    if (prompt == null) {
      state = state.copyWith(clearPrompt: true);
    } else {
      state = state.copyWith(nearbyInteractPrompt: prompt);
    }
  }

  void setTurntableTrack(int? trackNumber) {
    if (trackNumber == null) {
      state = state.copyWith(clearTurntableTrack: true);
    } else {
      state = state.copyWith(turntableTrackNumber: trackNumber);
    }
  }
}
