import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum ActiveModalOverlay {
  none,
  tentRest,
  turntable,
  pinball,
  sortingBelt,
  artifactBooth,
  vendorStall,
  finaleMontage,
  encoreDeck,
  settingsDrawer,
}

enum PocketProgramTab {
  setlistAndStages,
  orchardMap,
  cultivarAndMix,
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
    this.pocketProgramOpen = false,
    this.pocketProgramTab = PocketProgramTab.setlistAndStages,
    this.toastBanner,
    this.toastSerial = 0,
    this.nearbyInteractPrompt,
    this.turntableTrackNumber,
    this.activeVendorStallId,
  });

  final DialogueSession? dialogue;
  final ActiveModalOverlay modal;
  final bool pocketProgramOpen;
  final PocketProgramTab pocketProgramTab;
  final String? toastBanner;
  final int toastSerial;
  final String? nearbyInteractPrompt;
  final int? turntableTrackNumber;
  final String? activeVendorStallId;

  bool get isBlockingInput =>
      dialogue != null ||
      pocketProgramOpen ||
      (modal != ActiveModalOverlay.none &&
          modal != ActiveModalOverlay.encoreDeck);

  UiOverlayState copyWith({
    DialogueSession? dialogue,
    bool clearDialogue = false,
    ActiveModalOverlay? modal,
    bool? pocketProgramOpen,
    PocketProgramTab? pocketProgramTab,
    String? toastBanner,
    int? toastSerial,
    bool clearToast = false,
    String? nearbyInteractPrompt,
    bool clearPrompt = false,
    int? turntableTrackNumber,
    bool clearTurntableTrack = false,
    String? activeVendorStallId,
    bool clearVendorStall = false,
  }) {
    return UiOverlayState(
      dialogue: clearDialogue ? null : (dialogue ?? this.dialogue),
      modal: modal ?? this.modal,
      pocketProgramOpen: pocketProgramOpen ?? this.pocketProgramOpen,
      pocketProgramTab: pocketProgramTab ?? this.pocketProgramTab,
      toastBanner: clearToast ? null : (toastBanner ?? this.toastBanner),
      toastSerial: toastSerial ?? this.toastSerial,
      nearbyInteractPrompt: clearPrompt
          ? null
          : (nearbyInteractPrompt ?? this.nearbyInteractPrompt),
      turntableTrackNumber: clearTurntableTrack
          ? null
          : (turntableTrackNumber ?? this.turntableTrackNumber),
      activeVendorStallId: clearVendorStall
          ? null
          : (activeVendorStallId ?? this.activeVendorStallId),
    );
  }

  @override
  List<Object?> get props => [
        dialogue,
        modal,
        pocketProgramOpen,
        pocketProgramTab,
        toastBanner,
        toastSerial,
        nearbyInteractPrompt,
        turntableTrackNumber,
        activeVendorStallId,
      ];
}

class UiOverlayNotifier extends StateNotifier<UiOverlayState> {
  UiOverlayNotifier() : super(const UiOverlayState());

  void startDialogue(DialogueSession session) {
    if (session.lines.isEmpty) return;
    state = state.copyWith(
      dialogue: session,
      pocketProgramOpen: false,
    );
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
    state = state.copyWith(
      modal: modal,
      pocketProgramOpen: false,
    );
  }

  void openVendorStall(String stallId) {
    state = state.copyWith(
      modal: ActiveModalOverlay.vendorStall,
      activeVendorStallId: stallId,
      pocketProgramOpen: false,
    );
  }

  void closeModal() {
    state = state.copyWith(
      modal: ActiveModalOverlay.none,
      pocketProgramOpen: false,
      clearVendorStall: true,
    );
  }

  void openPocketProgram([PocketProgramTab? tab]) {
    state = state.copyWith(
      pocketProgramOpen: true,
      pocketProgramTab: tab ?? state.pocketProgramTab,
    );
  }

  void setPocketProgramTab(PocketProgramTab tab) {
    state = state.copyWith(pocketProgramTab: tab);
  }

  void togglePocketProgram([PocketProgramTab? tab]) {
    if (state.pocketProgramOpen &&
        (tab == null || state.pocketProgramTab == tab)) {
      state = state.copyWith(pocketProgramOpen: false);
    } else {
      state = state.copyWith(
        pocketProgramOpen: true,
        pocketProgramTab: tab ?? state.pocketProgramTab,
      );
    }
  }

  void closePocketProgram() {
    if (state.pocketProgramOpen) {
      state = state.copyWith(pocketProgramOpen: false);
    }
  }

  void showToast(String message) {
    state = state.copyWith(
      toastBanner: message,
      toastSerial: state.toastSerial + 1,
    );
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
