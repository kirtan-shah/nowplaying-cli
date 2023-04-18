#ifndef PrivateMediaRemote_Enums_h
#define PrivateMediaRemote_Enums_h

typedef enum {
	/*
	 * Use nil for userInfo.
	 */
	MRMediaRemoteCommandPlay,
	MRMediaRemoteCommandPause,
	MRMediaRemoteCommandTogglePlayPause,
	MRMediaRemoteCommandStop,
	MRMediaRemoteCommandNextTrack,
	MRMediaRemoteCommandPreviousTrack,
	MRMediaRemoteCommandAdvanceShuffleMode,
	MRMediaRemoteCommandAdvanceRepeatMode,
	MRMediaRemoteCommandBeginFastForward,
	MRMediaRemoteCommandEndFastForward,
	MRMediaRemoteCommandBeginRewind,
	MRMediaRemoteCommandEndRewind,
	MRMediaRemoteCommandRewind15Seconds,
	MRMediaRemoteCommandFastForward15Seconds,
	MRMediaRemoteCommandRewind30Seconds,
	MRMediaRemoteCommandFastForward30Seconds,
	MRMediaRemoteCommandToggleRecord,
	MRMediaRemoteCommandSkipForward,
	MRMediaRemoteCommandSkipBackward,
	MRMediaRemoteCommandChangePlaybackRate,

	/*
	 * Use a NSDictionary for userInfo, which contains three keys:
	 * kMRMediaRemoteOptionTrackID
	 * kMRMediaRemoteOptionStationID
	 * kMRMediaRemoteOptionStationHash
	 */
	MRMediaRemoteCommandRateTrack,
	MRMediaRemoteCommandLikeTrack,
	MRMediaRemoteCommandDislikeTrack,
	MRMediaRemoteCommandBookmarkTrack,

	/*
	 * Use nil for userInfo.
	 */
	MRMediaRemoteCommandSeekToPlaybackPosition,
	MRMediaRemoteCommandChangeRepeatMode,
	MRMediaRemoteCommandChangeShuffleMode,
	MRMediaRemoteCommandEnableLanguageOption,
	MRMediaRemoteCommandDisableLanguageOption
} MRMediaRemoteCommand;

#endif /* PrivateMediaRemote_Enums_h */
