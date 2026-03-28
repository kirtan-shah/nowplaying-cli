// Copyright (c) 2025 Jonas van den Berg
// This file is licensed under the BSD 3-Clause License.

#ifndef MEDIAREMOTEADAPTER_ADAPTER_H
#define MEDIAREMOTEADAPTER_ADAPTER_H

#import <Foundation/Foundation.h>

extern NSString *kMRAProcessIdentifier;
extern NSString *kMRABundleIdentifier;
extern NSString *kMRAParentApplicationBundleIdentifier;
extern NSString *kMRAPlaying;

extern NSString *kMRADurationMicros;
extern NSString *kMRAElapsedTimeMicros;
extern NSString *kMRATimestampEpochMicros;

extern NSString *kMRAElapsedTimeNow;
extern NSString *kMRAElapsedTimeNowMicros;

extern NSString *kMRATitle;
extern NSString *kMRAArtist;
extern NSString *kMRAAlbum;
extern NSString *kMRADuration;
extern NSString *kMRAElapsedTime;
extern NSString *kMRATimestamp;
extern NSString *kMRAArtworkMimeType;
extern NSString *kMRAArtworkData;

extern NSString *kMRAChapterNumber;
extern NSString *kMRAComposer;
extern NSString *kMRAGenre;
extern NSString *kMRAIsAdvertisement;
extern NSString *kMRAIsBanned;
extern NSString *kMRAIsInWishList;
extern NSString *kMRAIsLiked;
extern NSString *kMRAIsMusicApp;
extern NSString *kMRAPlaybackRate;
extern NSString *kMRAProhibitsSkip;
extern NSString *kMRAQueueIndex;
extern NSString *kMRARadioStationIdentifier;
extern NSString *kMRARepeatMode;
extern NSString *kMRAShuffleMode;
extern NSString *kMRAStartTime;
extern NSString *kMRASupportsFastForward15Seconds;
extern NSString *kMRASupportsIsBanned;
extern NSString *kMRASupportsIsLiked;
extern NSString *kMRASupportsRewind15Seconds;
extern NSString *kMRATotalChapterCount;
extern NSString *kMRATotalDiscCount;
extern NSString *kMRATotalQueueCount;
extern NSString *kMRATotalTrackCount;
extern NSString *kMRATrackNumber;
extern NSString *kMRAUniqueIdentifier;
extern NSString *kMRAContentItemIdentifier;
extern NSString *kMRARadioStationHash;
extern NSString *kMRAMediaType;

// Prints the current MediaRemote now playing information to stdout.
// Data is encoded as a JSON dictionary or "null" when there is no information.
extern void adapter_get();
extern void adapter_get_env();

#endif // MEDIAREMOTEADAPTER_ADAPTER_H
