> **@Apple**&ensp;*Before breaking this,
> please consider giving Mac users the option
> to share actively playing media with the apps they use
> and to control media playback.
> Perhaps by introducing a new entitlement
> that can be granted to apps by users in the system settings.
> There are
> [many](https://musicpresence.app)
> [use](https://folivora.ai)
> [cases](https://lyricfever.com)
> [for](https://theboring.name)
> [this](https://github.com/kirtan-shah/nowplaying-cli).*

> **@Developers**&ensp;*Please **star**
> this repository to show Apple that we care.*

---

<!-- BADGES BEGIN -->
![](https://img.shields.io/github/stars/ungive/mediaremote-adapter?style=flat&label=stars&logo=github&labelColor=444&color=DAAA3F&cacheSeconds=3600)
![](https://img.shields.io/static/v1?label=macOS&message=macOS%2026.0%20%2825A5316i%29&labelColor=444&color=blue)
![](https://img.shields.io/static/v1?label=last%20tested&message=Thu%20Jul%2024%2002%3A24%3A11%20CEST%202025&labelColor=444&color)
<!-- BADGES END -->

# MediaRemote Adapter

Get now playing information using the MediaRemote framework
on all macOS versions, including 15.4 and above.

This works by using a system binary &ndash; `/usr/bin/perl` in this case &ndash;
which is entitled to use the MediaRemote framework
and by dynamically loading a custom helper framework
that prints real-time updates to stdout.

## Example

Install the [media-control](https://github.com/ungive/media-control)
CLI tool to see this project in action. Works on all macOS versions:

```
$ brew tap ungive/media-control
$ brew install media-control
$ media-control stream
```

## Usage

This project provides a Perl script
with a well-defined CLI interface that you can invoke from your app
in order to read now playing information and control media players.
The [mediaremote-adapter.pl](./bin/mediaremote-adapter.pl) script
needs to be bundled with your app,
alongside the `MediaRemoteAdapter.framework`
and optionally the `MediaRemoteAdapterTestClient`
which are exposed as CMake targets in [CMakeLists.txt](./CMakeLists.txt).
You can find instructions to build the framework in the next section.

The script must then be invoked like this:

```
/usr/bin/perl /path/to/mediaremote-adapter.pl /path/to/MediaRemoteAdapter.framework COMMAND
```

`COMMAND` is a placeholder for one of the commands documented below.

For the `test` command the `NowPlayingTestCMediaRemoteAdapterTestClientlient` must be passed
as an additional argument:

```
/usr/bin/perl /path/to/mediaremote-adapter.pl /path/to/MediaRemoteAdapter.framework /path/to/MediaRemoteAdapterTestClient test
```

For ease of use you can also always pass the path to the test client:

```
/usr/bin/perl /path/to/mediaremote-adapter.pl /path/to/MediaRemoteAdapter.framework /path/to/MediaRemoteAdapterTestClient COMMAND
```

For more help on available commands read below or omit the `COMMAND` argument.

> [!WARNING]
> This project is still in development
> and the API may experience breaking changes across minor revisions.

> [!NOTE]
> A Swift package and an Objective-C library
> that you can directly include in your project is underway.

## Build from source

```
$ git clone https://github.com/ungive/mediaremote-adapter.git
$ cd mediaremote-adapter
$ mkdir build && cd build
$ cmake ..
$ cmake --build .
$ cd ..
$ FRAMEWORK_PATH=$(realpath ./build/MediaRemoteAdapter.framework)
$ /usr/bin/perl ./bin/mediaremote-adapter.pl "$FRAMEWORK_PATH" stream
```

This creates the `MediaRemoteAdapter.framework` in the build directory,
which must be *bundled* with your app, but *not linked against*.
The framework is only used by the script
and must merely be passed as a script argument.

If you want to be able to test whether the adapter still works,
which can be useful to e.g. automatically fall back to AppleScript,
you need to also bundle the `MediaRemoteAdapterTestClient` executable with your app
and pass it as an additional argument:

```
$ HELPER_PATH=$(realpath ./build/MediaRemoteAdapterTestClient)
$ /usr/bin/perl ./bin/mediaremote-adapter.pl "$FRAMEWORK_PATH" "$HELPER_PATH" test
```

An exit code of `0` then means the adapter is functional and safe to use.

The framework and test executable are built for the following architectures:
`x86_64` `arm64`

## Commands

- [get](#get)
- [stream](#stream)
- [send COMMAND](#send-command)
- [seek POSITION](#seek-position)
- [shuffle MODE](#shuffle-mode)
- [repeat MODE](#repeat-mode)
- [speed SPEED](#speed-speed)
- [test](#test)

### get

Prints now playing information once with all available metadata.

Output is encoded as JSON and characterized by either `null`
or a dictionary with any of the following keys:

> `bundleIdentifier`
`parentApplicationBundleIdentifier`
`playing`
`title`
`artist`
`album`
`duration`
`elapsedTime`
`timestamp`
`artworkMimeType`
`artworkData`
`chapterNumber`
`composer`
`genre`
`isAdvertisement`
`isBanned`
`isInWishList`
`isLiked`
`isMusicApp`
`playbackRate`
`prohibitsSkip`
`queueIndex`
`radioStationIdentifier`
`repeatMode`
`shuffleMode`
`startTime`
`supportsFastForward15Seconds`
`supportsIsBanned`
`supportsIsLiked`
`supportsRewind15Seconds`
`totalChapterCount`
`totalDiscCount`
`totalQueueCount`
`totalTrackCount`
`trackNumber`
`uniqueIdentifier`
`contentItemIdentifier`
`radioStationHash`
`mediaType`

The following mandatory keys never have a null value:
`bundleIdentifier`
`playing`
`title`.
If any of the mandatory keys cannot be determined,
the command prints `null`.
Media without a title is considered invalid.

The `mediaType` may contain one of the following values:
- `MRMediaRemoteMediaTypeMusic`
- `kMRMediaRemoteNowPlayingInfoTypeAudio`
- Possibly others, this key is not very well documented

**Caveats**

Metadata such as `artworkData` and `artworkMimeType`
often takes a bit of time to load
and may not appear in the output in all cases.
Do not rely on this key to be present reliably.
Either use the `stream` command or poll `get` regularly,
to ensure you get the artwork data *eventually*.

**Options**

`--now`&ensp;Adds an `elapsedTimeNow` key with an estimation of the current
elapsed playback time. This estimation may be off by up to a second.
To determine a more accurate time without polling `get` continuously,
calculate it using the `elapsedTime` and `timestamp` keys. `elapsedTime`
contains the elapsed time at the time that is stored in `timestamp`.

`--micros`&ensp;Replaces the following keys with microsecond equivalents:

| Original key     | Converted key name     | Comment                   |
|------------------|------------------------|---------------------------|
| `duration`       | `durationMicros`       | -                         |
| `elapsedTime`    | `elapsedTimeMicros`    | -                         |
| `elapsedTimeNow` | `elapsedTimeNowMicros` | Only present with `--now` |
| `timestamp`      | `timestampEpochMicros` | Converted to epoch time   |

---

### stream

Streams now playing information updates in real-time
until the script receives a SIGTERM signal.

Output is encoded as JSON and characterized by
a dictionary with the following keys:

> `type`
`diff`
`payload`

`type` is always a string with the value `"data"`.

`payload` contains the now playing information and is a dictionary
that is structurally identical to the output of the `get` command,
with the same keys. The dictionary itself is never `null`.
No keys are set at all,
when no media player is reporting now playing information.
Some keys may have a `null` value,
when the media player reports `null` for them (this happens rarely, if ever).
Any key may be `null`, when `diff` is set to true and the key vanishes.

`diff` is a boolean that indicates whether the `payload`
contains only fields whose values have been updated.
When set to `false`,
the payload is to be considered the current now playing state
with all available keys and their values,
regardless of any payloads that have been sent in the past.
When set to `true` on the other hand,
the last sent non-diff payload must be updated with these new values,
in order to have a representation of the the current now playing state.
When a key is not present anymore, it's set to `null` in the payload
and its previous value should be removed.
**Diffing is enabled by default, but can be disabled with a command line flag.**

**Options**

`--no-diff`&ensp;Disables diffing. `diff` is always `false`
and `payload` always contains all current information.

`--debounce=N`&ensp;Adds a debounce delay in milliseconds
between the point where changes are detected
and when they are printed.
If a new update comes in during delaying,
the delay is restarted and all updates are merged.
This is useful to prevent bursts of smaller updates.
The default is 0.

`--micros`&ensp;Identical to the `--micros` option of the `get` command.

**Experimental options**

`--experimental-peculiar-debounce:BUNDLE_ID=N`&ensp;
Adds a debounce delay in milliseconds for the case when the media player
with the given bundle identifier (`BUNDLE_ID`) reports metadata that
contains parts of the previous track and parts of the next track,
but doesn't contain the full metadata of the next track.
Whenever the track title changes,
the update for it is either delayed for the given debounce delay
or the update is printed when all other metadata updated as well,
whichever happens earlier.
Currently only `com.tidal.desktop` can be passed for `BUNDLE_ID`,
since it is the only media player that is known to have this issue.
A value of `1000` for `N` is recommended for TIDAL specifically.

---

### send COMMAND

Sends a MediaRemote command to the now playing application.

The value for `COMMAND` must be a valid ID from the table below.

| ID | MediaRemote key         | Description                   |
|:--:|-------------------------|-------------------------------|
| 0  | kMRPlay                 | Start playback                |
| 1  | kMRPause                | Pause playback                |
| 2  | kMRTogglePlayPause      | Toggle between play and pause |
| 3  | kMRStop                 | Stop playback                 |
| 4  | kMRNextTrack            | Skip to the next track        |
| 5  | kMRPreviousTrack        | Return to the previous track  |
| 6  | kMRToggleShuffle        | Toggle shuffle mode           |
| 7  | kMRToggleRepeat         | Toggle repeat mode            |
| 8  | kMRStartForwardSeek     | Start seeking forward         |
| 9  | kMREndForwardSeek       | Stop seeking forward          |
| 10 | kMRStartBackwardSeek    | Start seeking backward        |
| 11 | kMREndBackwardSeek      | Stop seeking backward         |
| 12 | kMRGoBackFifteenSeconds | Go back 15 seconds            |
| 13 | kMRSkipFifteenSeconds   | Skip ahead 15 seconds         |

---

### seek POSITION

Seeks to a specific timeline position with the now playing application.

The value for `POSITION` must a valid positive integer.
The unit is microseconds.

---

### shuffle MODE

Sets the shuffle mode.

The value for `MODE` must be a valid ID from the table below.

| ID | Description    |
|:--:|----------------|
| 1  | Disable        |
| 2  | Shuffle albums |
| 3  | Shuffle tracks |

---

### repeat MODE

Sets the repeat mode.

The value for `MODE` must be a valid ID from the table below.

| ID | Description     |
|:--:|-----------------|
| 1  | Disable         |
| 2  | Repeat track    |
| 3  | Repeat playlist |

---

### speed SPEED

Sets the playback speed.

The value for `SPEED` must be a valid positive integer.

---

### test

Tests if the adapter is entitled to use the MediaRemote framework
and if it is able to execute any of the supported commands without failure.
An exit code of 0 means the adapter is functional and safe to use.

This can be integrated into your app
to help confirm that the adapter is still functional and if not,
fall back to other methods for media detection (e.g. AppleScript),
since future macOS updates may break MediaRemote access again.

#### Usage

```
/usr/bin/perl /path/to/mediaremote-adapter.pl /path/to/MediaRemoteAdapter.framework /path/to/MediaRemoteAdapterTestClient test
```

Note that the `test` command requires the absolute path
to the `MediaRemoteAdapterTestClient` executable after the framework path.
For ease of use you can always pass the path to the test client executable,
even when using other commands, like `get` or `stream`.

#### Output

An exit code of `0` indicates that the adapter is still functional
and can safely be used to detect media.
Any other exit indicates that the adapter is likely broken.

If you ever get an exit code other than `0`,
please [report this](https://github.com/ungive/mediaremote-adapter/issues). Thank you!

#### How this works

1. Now playing information is attempted to be read normally using `get`
2. If no media is detected, the `MediaRemoteAdapterTestClient` helper process is launched to simulate media playback
3. While the helper process is running, now playing information is attempted to be read again using `get`
4. Afterwards the helper process is terminated
5. If any of the `get` attempts yielded media information, the command exits with an exit code of `0`
6. Otherwise the command exits with an exit code of `1`

> [!WARNING]
> **May interfere with other apps using MediaRemote**  
> The test can create a fake media entry that will briefly appear
as the now playing application.
This only happens when no other media is playing.
Since the helper process has no bundle identifier,
it is mostly ignored by the `stream` and `get` commands —
`stream` won't update, and `get` will print `null`.

---

## Built-in fixes

This library has some fixes built-in
to accomodate for inconsistencies within the MediaRemote framework:

- Artwork data sometimes unloads for a brief moment,
  e.g. when changing the current timeline position of a track.
  To combat this, artwork data is reused when the track has not changed,
  the track had artwork data before and the artwork data has disappeared.
  This fix is applied when using the `stream` command

If you need a way to disable any or all of these fixes,
please open an issue or create a pull request.

---

## Implementation notes

- Consider `NSJSONSerialization` for JSON deserialization.
  This is what is used for encoding
- You can use `NSData`'s `initWithBase64EncodedString`
  for decoding of base64 data
- Every line printed to stderr is an error message.
  If the script did not exit with a non-zero exit code,
  then any of these errors are non-fatal and can be safely ignored
- Other apps using MediaRemote Adapter may run `test` which should not interfere with the `stream` and `get` commands, but will generate a missing bundle identifier error message, which can be ignored. See the `test` command section for more information.
- You should not reinvoke the script when a fatal error occurs
  (non-zero exit code)
- Make sure to pass the absolute path of the bundled framework and helper executable
  as arguments and not a relative path

## Why this works

According to the findings by [@My-Iris](https://github.com/Mx-Iris) in
[this comment](https://github.com/aviwad/LyricFever/issues/94#issuecomment-2746155419)
processes with a bundle identifier starting with `com.apple.`
are granted permission to access the MediaRemote framework.
The Perl platform binary `/usr/bin/perl`
is reported as having the bundle identifier `com.apple.perl` (or a variation).

You can confirm this by streaming log messages using the Console.app
whilst running the script:

`default	14:44:55.871495+0200	mediaremoted	Adding client <MRDMediaRemoteClient 0x15820b1a0, bundleIdentifier = com.apple.perl5, pid = 86889>`

## Motivation

This project was created due to the MediaRemote framework
being completely non-functional when being loaded directly from within an app,
starting with macOS 15.4 (see the numerous issues linked below).

The aim of this project is to provide a tool (and perhaps soon a full library)
that serves as a fully functional alternative to using MediaRemote directly
and perhaps to inspire Apple to give us a public API
to read now playing information and control media playback on the device
(see the note at the top of this file).

## Projects that use this library

- [Music Presence](https://musicpresence.app) is a cross-platform desktop application
  for showing what you are listening to in your Discord status.
  It uses this library since version [2.3.1](https://github.com/ungive/discord-music-presence/releases/tag/v2.3.1)
  to detect media from all media players again.
- [media-control](https://github.com/ungive/media-control)
  is a CLI tool to control and observe media playback on any macOS version.
  You can install it directly via brew: `$ brew tap ungive/media-control && brew install media-control`

*If you use this library in your project, please
[let me know](https://github.com/ungive/mediaremote-adapter/issues)!*

## Useful links

- Issues regarding MediaRemote breaking since macOS 15.4
  - https://github.com/vincentneo/LosslessSwitcher/issues/161
  - https://github.com/aviwad/LyricFever/issues/94
  - https://github.com/TheBoredTeam/boring.notch/issues/417
  - https://community.folivora.ai/t/now-playing-is-no-longer-working-on-macos-15-4/42802/11
  - https://github.com/ungive/discord-music-presence/issues/165
  - https://github.com/ungive/discord-music-presence/issues/245
  - https://github.com/kirtan-shah/nowplaying-cli/issues/28
  - https://github.com/FelixKratz/SketchyBar/issues/708
- Getting now playing information using `osascript` and `MRNowPlayingRequest`.
  Note that this is unable to load the song artwork
  and it is impossible to get real-time updates with this solution.
  It is much simpler to implement though
  - https://github.com/EinTim23/PlayerLink/commit/9821b6a294873f975852f06419a0baf2fe404800
  - https://github.com/fastfetch-cli/fastfetch/commit/1557f0c5564a8288604824e55db47508f65e82c9
  - https://gist.github.com/SKaplanOfficial/f9f5bdd6455436203d0d318c078358de

## Acknowledgements

Thank you [@Alexander5015](https://github.com/Alexander5015) for implementing the `test` command,
so we're able to detect when the adapter stops working!

Thank you [@EinTim23](https://github.com/EinTim23) for bringing
a [similar workaround](https://github.com/EinTim23/PlayerLink/commit/9821b6a294873f975852f06419a0baf2fe404800) to my attention!
Without your hint I most likely would not have dug into this anytime soon
and my app [Music Presence](https://musicpresence.app)
would still only work with AppleScript automation.

Thank you [@My-Iris](https://github.com/Mx-Iris)
for providing insight into the changes made since macOS 15.4:
[aviwad/LyricFever#94](https://github.com/aviwad/LyricFever/issues/94#issuecomment-2746155419)

## License

This project is licensed under the BSD 3-Clause License.
See [LICENSE](./LICENSE) for details.

Copyright (c) 2025 Jonas van den Berg and contributors
