#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#import <mach-o/dyld.h>
#import "Enums.h"
#import "MRContent.h"

// ---------------------------------------------------------------------------
// Old C-function-pointer API (works on macOS < 15.4)
// ---------------------------------------------------------------------------
typedef void (*MRMediaRemoteGetNowPlayingInfoFunction)(dispatch_queue_t queue, void (^handler)(NSDictionary* information));
typedef void (*MRMediaRemoteSetElapsedTimeFunction)(double time);
typedef Boolean (*MRMediaRemoteSendCommandFunction)(MRMediaRemoteCommand cmd, NSDictionary* userInfo);
typedef void (*MRMediaRemoteRegisterForNowPlayingNotificationsFunction)(dispatch_queue_t queue);
typedef void (*MRMediaRemoteSetCanBeNowPlayingApplicationFunction)(Boolean canBeNowPlayingApplication);

// ---------------------------------------------------------------------------
// Timing constants
// ---------------------------------------------------------------------------
// How long (ms) to wait after registering notifications before the first query.
static const int kInitialDelayMs = 150;
// Poll interval for the new MRNowPlayingController API (ms).
static const int kControllerPollIntervalMs = 100;
// Max polls before giving up on the controller API (2500 ms total).
static const int kControllerMaxPolls = 25;
// Hard wall-clock timeout (ms) before printing empty results and exiting.
static const int kHardTimeoutMs = 3500;

// ---------------------------------------------------------------------------
void printHelp() {
    printf("Example Usage: \n");
    printf("\tnowplaying-cli get-raw\n");
    printf("\tnowplaying-cli get title album artist\n");
    printf("\tnowplaying-cli pause\n");
    printf("\tnowplaying-cli seek 60\n");
    printf("\n");
    printf("Available commands: \n");
    printf("\tget, get-raw, play, pause, togglePlayPause, next, previous, seek <secs>\n");
}

typedef enum {
    GET,
    GET_RAW,
    MEDIA_COMMAND,
    SEEK,
} Command;

NSDictionary<NSString*, NSNumber*> *cmdTranslate = @{
    @"play":             @(MRMediaRemoteCommandPlay),
    @"pause":            @(MRMediaRemoteCommandPause),
    @"togglePlayPause":  @(MRMediaRemoteCommandTogglePlayPause),
    @"next":             @(MRMediaRemoteCommandNextTrack),
    @"previous":         @(MRMediaRemoteCommandPreviousTrack),
};

// ---------------------------------------------------------------------------
// Build a kMRMediaRemoteNowPlayingInfo-keyed NSDictionary from a
// MRNowPlayingPlayerResponse object (macOS 15.4+ new API).
// Uses only id + KVC (valueForKey:) to avoid linker-time symbol resolution
// issues with private ObjC class symbols.
// ---------------------------------------------------------------------------
static NSDictionary *buildInfoDictFromResponse(id response) {
    if (!response) return nil;

    NSMutableDictionary *info = [NSMutableDictionary dictionary];

    // playbackRate
    NSNumber *rateNum = [response valueForKey:@"playbackRate"];
    if (rateNum) {
        info[@"kMRMediaRemoteNowPlayingInfoPlaybackRate"] = rateNum;
        if ([rateNum floatValue] == 0.0f) {
            // Derive from playbackState: 1 = playing
            NSNumber *stateNum = [response valueForKey:@"playbackState"];
            if (stateNum) {
                info[@"kMRMediaRemoteNowPlayingInfoPlaybackRate"] =
                    ([stateNum unsignedIntValue] == 1) ? @(1.0) : @(0.0);
            }
        }
    }

    // Content items live inside the playbackQueue.
    id queue = [response valueForKey:@"playbackQueue"];
    if (!queue) return ([info count] > 0) ? info : nil;

    NSArray *items = [queue valueForKey:@"contentItems"];
    if (![items isKindOfClass:[NSArray class]] || [items count] == 0) {
        return ([info count] > 0) ? info : nil;
    }

    // Pick the item at the queue's current location (falls back to index 0).
    NSNumber *locNum = [queue valueForKey:@"location"];
    NSInteger location = [locNum integerValue];
    id item = (location >= 0 && location < (NSInteger)[items count])
        ? items[(NSUInteger)location]
        : items[0];

    id meta = [item valueForKey:@"metadata"];
    if (!meta) return ([info count] > 0) ? info : nil;

    void (^add)(NSString*, NSString*) = ^(NSString *mk, NSString *ik) {
        id v = [meta valueForKey:mk];
        if (v) info[ik] = v;
    };
    add(@"title",            @"kMRMediaRemoteNowPlayingInfoTitle");
    add(@"trackArtistName",  @"kMRMediaRemoteNowPlayingInfoArtist");
    add(@"albumName",        @"kMRMediaRemoteNowPlayingInfoAlbum");
    add(@"albumArtistName",  @"kMRMediaRemoteNowPlayingInfoAlbumArtist");
    add(@"composer",         @"kMRMediaRemoteNowPlayingInfoComposer");
    add(@"genre",            @"kMRMediaRemoteNowPlayingInfoGenre");
    add(@"duration",         @"kMRMediaRemoteNowPlayingInfoDuration");
    add(@"elapsedTime",      @"kMRMediaRemoteNowPlayingInfoElapsedTime");
    add(@"trackNumber",      @"kMRMediaRemoteNowPlayingInfoTrackNumber");
    add(@"discNumber",       @"kMRMediaRemoteNowPlayingInfoDiscNumber");
    add(@"totalTrackCount",  @"kMRMediaRemoteNowPlayingInfoTotalTrackCount");

    // Merge any app-specific extras from the metadata's own nowPlayingInfo dict.
    NSDictionary *extra = [meta valueForKey:@"nowPlayingInfo"];
    if ([extra isKindOfClass:[NSDictionary class]]) {
        for (NSString *k in extra) { if (!info[k]) info[k] = extra[k]; }
    }

    return ([info count] > 0) ? info : nil;
}

// ---------------------------------------------------------------------------
// Print now-playing info.
// ---------------------------------------------------------------------------
static void printNowPlayingInfo(NSDictionary *information, Command command,
                                NSArray<NSString *> *keys, int numKeys) {
    NSDictionary *safeInfo = information ?: @{};

    if (command == GET_RAW) {
        printf("%s\n", [[safeInfo description] UTF8String]);
        return;
    }

    for (int i = 0; i < numKeys; i++) {
        NSString *propKey = [keys[i] stringByReplacingCharactersInRange:NSMakeRange(0,1)
                             withString:[[keys[i] substringToIndex:1] capitalizedString]];
        NSString *key = [NSString stringWithFormat:@"kMRMediaRemoteNowPlayingInfo%@", propKey];
        NSObject *rawValue = [safeInfo objectForKey:key];
        if (rawValue == nil) {
            printf("null\n");
        } else if ([key isEqualToString:@"kMRMediaRemoteNowPlayingInfoArtworkData"] ||
                   [key isEqualToString:@"kMRMediaRemoteNowPlayingInfoClientPropertiesData"]) {
            NSData *data = (NSData *)rawValue;
            printf("%s\n", [[data base64EncodedStringWithOptions:0] UTF8String]);
        } else if ([key isEqualToString:@"kMRMediaRemoteNowPlayingInfoElapsedTime"]) {
            MRContentItem *contentItem = [[objc_getClass("MRContentItem") alloc]
                                          initWithNowPlayingInfo:(__bridge NSDictionary *)safeInfo];
            printf("%s\n", [[NSString stringWithFormat:@"%f",
                             contentItem.metadata.calculatedPlaybackPosition] UTF8String]);
        } else {
            printf("%s\n", [[NSString stringWithFormat:@"%@", rawValue] UTF8String]);
        }
    }
}

static NSString *GetExecutableDir(void) {
    uint32_t size = 0;
    _NSGetExecutablePath(NULL, &size);
    if (size == 0) return nil;

    char *buffer = (char *)malloc(size);
    if (!buffer) return nil;

    if (_NSGetExecutablePath(buffer, &size) != 0) {
        free(buffer);
        return nil;
    }

    NSString *path = [[NSFileManager defaultManager]
        stringWithFileSystemRepresentation:buffer
                                    length:strlen(buffer)];
    free(buffer);
    return [path stringByDeletingLastPathComponent];
}

static NSDictionary *ReadViaHelperBinary(void) {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *exeDir = GetExecutableDir();
    if (!exeDir) return nil;

    NSString *scriptPath = [exeDir stringByAppendingPathComponent:@"scripts/mediaremote-mini.pl"];
    NSString *dylibPath = [exeDir stringByAppendingPathComponent:@"build/mediaremote-mini/MediaRemoteMini.dylib"];

    if (![fm isExecutableFileAtPath:scriptPath]) return nil;
    if (![fm isReadableFileAtPath:dylibPath]) return nil;

    NSTask *task = [[NSTask alloc] init];
    [task setLaunchPath:@"/usr/bin/perl"];
    [task setArguments:@[scriptPath, dylibPath, @"adapter_get_env"]];

    NSPipe *pipe = [NSPipe pipe];
    [task setStandardOutput:pipe];
    [task setStandardError:[NSFileHandle fileHandleWithNullDevice]];

    @try {
        [task launch];
    } @catch (NSException *) {
        return nil;
    }

    NSData *output = [[pipe fileHandleForReading] readDataToEndOfFile];
    [task waitUntilExit];

    if ([task terminationStatus] != 0 || [output length] == 0) return nil;

    NSError *jsonError = nil;
    id obj = [NSJSONSerialization JSONObjectWithData:output options:0 error:&jsonError];
    if (![obj isKindOfClass:[NSDictionary class]]) return nil;

    NSDictionary *json = (NSDictionary *)obj;
    id title = json[@"title"];
    if (!title || title == [NSNull null] || ![title isKindOfClass:[NSString class]] || [title length] == 0) {
        return nil;
    }

    return json;
}

static NSDictionary *LegacyInfoDictFromHelperJSON(NSDictionary *json) {
    if (!json || ![json isKindOfClass:[NSDictionary class]]) return nil;

    NSDictionary *map = @{
        @"title": @"kMRMediaRemoteNowPlayingInfoTitle",
        @"artist": @"kMRMediaRemoteNowPlayingInfoArtist",
        @"album": @"kMRMediaRemoteNowPlayingInfoAlbum",
        @"composer": @"kMRMediaRemoteNowPlayingInfoComposer",
        @"genre": @"kMRMediaRemoteNowPlayingInfoGenre",
        @"duration": @"kMRMediaRemoteNowPlayingInfoDuration",
        @"elapsedTime": @"kMRMediaRemoteNowPlayingInfoElapsedTime",
        @"playbackRate": @"kMRMediaRemoteNowPlayingInfoPlaybackRate",
        @"trackNumber": @"kMRMediaRemoteNowPlayingInfoTrackNumber",
        @"totalTrackCount": @"kMRMediaRemoteNowPlayingInfoTotalTrackCount",
        @"artworkData": @"kMRMediaRemoteNowPlayingInfoArtworkData",
        @"bundleIdentifier": @"kMRMediaRemoteNowPlayingInfoClientBundleIdentifier",
        @"uniqueIdentifier": @"kMRMediaRemoteNowPlayingInfoUniqueIdentifier",
    };

    NSMutableDictionary *info = [NSMutableDictionary dictionary];
    for (NSString *jsonKey in map) {
        id value = json[jsonKey];
        if (!value || value == [NSNull null]) continue;

        NSString *legacyKey = map[jsonKey];
        if ([jsonKey isEqualToString:@"artworkData"] && [value isKindOfClass:[NSString class]]) {
            NSData *decoded = [[NSData alloc] initWithBase64EncodedString:value options:0];
            if (decoded) info[legacyKey] = decoded;
        } else {
            info[legacyKey] = value;
        }
    }

    return ([info count] > 0) ? info : nil;
}

// ---------------------------------------------------------------------------
// Fall-back: query via the new MRNowPlayingController ObjC class API.
// Required on macOS 15.4+ where MRMediaRemoteGetNowPlayingInfo returns empty.
//
// Uses a dispatch_source repeating timer (NOT recursive blocks) to poll for
// the response, avoiding crashes from the recursive-block pattern under ObjC
// memory management on some macOS versions.
// ---------------------------------------------------------------------------
static void queryViaNewControllerAPI(void (^completion)(NSDictionary *info)) {
    Class destClass     = NSClassFromString(@"MRDestination");
    Class configClass   = NSClassFromString(@"MRNowPlayingControllerConfiguration");
    Class controllerCls = NSClassFromString(@"MRNowPlayingController");

    if (!destClass || !configClass || !controllerCls) {
        completion(nil);
        return;
    }

    id dest = [destClass performSelector:NSSelectorFromString(@"userSelectedDestination")];

    id config = [[configClass alloc]
                  performSelector:NSSelectorFromString(@"initWithDestination:")
                  withObject:dest];
    [config setValue:@NO  forKey:@"singleShot"];
    [config setValue:@YES forKey:@"requestPlaybackState"];
    [config setValue:@YES forKey:@"requestPlaybackQueue"];

    __block id controller = [[controllerCls alloc]
                               performSelector:NSSelectorFromString(@"initWithConfiguration:")
                               withObject:config];
    [controller performSelector:NSSelectorFromString(@"beginLoadingUpdates")];

    __block NSInteger pollCount = 0;
    __block BOOL done = NO;

    // Use a retained dispatch_source timer so we can poll without recursive blocks.
    dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER,
                                                     0, 0, dispatch_get_main_queue());
    dispatch_source_set_timer(timer,
                              DISPATCH_TIME_NOW,
                              (uint64_t)kControllerPollIntervalMs * NSEC_PER_MSEC,
                              (uint64_t)(kControllerPollIntervalMs / 10) * NSEC_PER_MSEC);
    dispatch_source_set_event_handler(timer, ^{
        if (done) { dispatch_source_cancel(timer); return; }

        pollCount++;
        id response = [controller valueForKey:@"response"];
        NSDictionary *info = buildInfoDictFromResponse(response);
        BOOL hasData = (info != nil && [info count] > 0);

        if (hasData || pollCount >= kControllerMaxPolls) {
            done = YES;
            dispatch_source_cancel(timer);
            [controller performSelector:NSSelectorFromString(@"endLoadingUpdates")];
            controller = nil;
            completion(info);
        }
    });
    dispatch_resume(timer);
}

// ---------------------------------------------------------------------------
// main
// ---------------------------------------------------------------------------
int main(int argc, char** argv) {

    if (argc == 1) {
        printHelp();
        return 0;
    }

    Command command = GET;
    NSString *cmdStr = [NSString stringWithUTF8String:argv[1]];
    double seekTime = 0;

    int numKeys = argc - 2;
    NSMutableArray<NSString *> *keys = [NSMutableArray array];
    if (strcmp(argv[1], "get") == 0) {
        for (int i = 2; i < argc; i++) {
            [keys addObject:[NSString stringWithUTF8String:argv[i]]];
        }
        command = GET;
    } else if (strcmp(argv[1], "get-raw") == 0) {
        command = GET_RAW;
    } else if (strcmp(argv[1], "seek") == 0 && argc == 3) {
        command = SEEK;
        char *end;
        seekTime = strtod(argv[2], &end);
        if (*end != '\0') {
            fprintf(stderr, "Invalid seek time: %s\n", argv[2]);
            fprintf(stderr, "Usage: nowplaying-cli seek <secs>\n");
            return 1;
        }
    } else if (cmdTranslate[cmdStr] != nil) {
        command = MEDIA_COMMAND;
    } else {
        printHelp();
        return 0;
    }

    @autoreleasepool {

    if (command == GET || command == GET_RAW) {
        NSDictionary *helperJSON = ReadViaHelperBinary();
        if (helperJSON != nil) {
            if (command == GET_RAW) {
                NSData *jsonData = [NSJSONSerialization dataWithJSONObject:helperJSON options:NSJSONWritingPrettyPrinted error:nil];
                if (jsonData) {
                    printf("%s\n", [[[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding] UTF8String]);
                } else {
                    printf("{}\n");
                }
            } else {
                NSDictionary *legacyInfo = LegacyInfoDictFromHelperJSON(helperJSON);
                printNowPlayingInfo(legacyInfo, command, keys, numKeys);
            }
            return 0;
        }
    }

    NSPanel *panel = [[NSPanel alloc]
        initWithContentRect: NSMakeRect(0, 0, 0, 0)
        styleMask: NSWindowStyleMaskTitled
        backing: NSBackingStoreBuffered
        defer: NO];

    // Use dlopen so that ObjC classes inside the MediaRemote framework (which
    // live only in the dyld shared cache on macOS 15.4+) are registered with
    // the ObjC runtime and visible via NSClassFromString().
    if (!dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote",
                RTLD_NOW | RTLD_GLOBAL)) {
        fprintf(stderr, "Failed to load MediaRemote framework\n");
        return 1;
    }

    CFURLRef ref = (__bridge CFURLRef)[NSURL fileURLWithPath:
        @"/System/Library/PrivateFrameworks/MediaRemote.framework"];
    CFBundleRef bundle = CFBundleCreate(kCFAllocatorDefault, ref);
    if (!bundle) {
        fprintf(stderr, "Failed to create MediaRemote bundle\n");
        return 1;
    }

    // ---- Media-control commands ----
    MRMediaRemoteSendCommandFunction MRMediaRemoteSendCommand =
        (MRMediaRemoteSendCommandFunction)CFBundleGetFunctionPointerForName(
            bundle, CFSTR("MRMediaRemoteSendCommand"));
    if (command == MEDIA_COMMAND && MRMediaRemoteSendCommand != nil) {
        MRMediaRemoteSendCommand((MRMediaRemoteCommand)[cmdTranslate[cmdStr] intValue], nil);
    }

    // ---- Seek ----
    MRMediaRemoteSetElapsedTimeFunction MRMediaRemoteSetElapsedTime =
        (MRMediaRemoteSetElapsedTimeFunction)CFBundleGetFunctionPointerForName(
            bundle, CFSTR("MRMediaRemoteSetElapsedTime"));
    if (command == SEEK && MRMediaRemoteSetElapsedTime != nil) {
        MRMediaRemoteSetElapsedTime(seekTime);
    }

    if (command == MEDIA_COMMAND || command == SEEK) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(500 * NSEC_PER_MSEC)),
                       dispatch_get_main_queue(), ^{ [NSApp terminate:nil]; });
        [NSApp run];
        CFRelease(bundle);
        return 0;
    }

    // ---- Register for now-playing notifications ----
    // Required on macOS 13+ for the daemon to establish a connection.
    MRMediaRemoteRegisterForNowPlayingNotificationsFunction MRMediaRemoteRegisterForNowPlayingNotifications =
        (MRMediaRemoteRegisterForNowPlayingNotificationsFunction)CFBundleGetFunctionPointerForName(
            bundle, CFSTR("MRMediaRemoteRegisterForNowPlayingNotifications"));
    if (MRMediaRemoteRegisterForNowPlayingNotifications != nil) {
        MRMediaRemoteRegisterForNowPlayingNotifications(dispatch_get_main_queue());
    }

    // Do not declare ourselves as a now-playing application.
    MRMediaRemoteSetCanBeNowPlayingApplicationFunction MRMediaRemoteSetCanBeNowPlayingApplication =
        (MRMediaRemoteSetCanBeNowPlayingApplicationFunction)CFBundleGetFunctionPointerForName(
            bundle, CFSTR("MRMediaRemoteSetCanBeNowPlayingApplication"));
    if (MRMediaRemoteSetCanBeNowPlayingApplication != nil) {
        MRMediaRemoteSetCanBeNowPlayingApplication(false);
    }

    // ---- Old API ----
    MRMediaRemoteGetNowPlayingInfoFunction MRMediaRemoteGetNowPlayingInfo =
        (MRMediaRemoteGetNowPlayingInfoFunction)CFBundleGetFunctionPointerForName(
            bundle, CFSTR("MRMediaRemoteGetNowPlayingInfo"));

    __block BOOL queryDone = NO;

    // Hard timeout: always print something and exit after kHardTimeoutMs ms.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kHardTimeoutMs * NSEC_PER_MSEC)),
                   dispatch_get_main_queue(), ^{
        if (queryDone) return;
        queryDone = YES;
        printNowPlayingInfo(nil, command, keys, numKeys);
        [NSApp terminate:nil];
    });

    // Schedule the primary query after kInitialDelayMs.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kInitialDelayMs * NSEC_PER_MSEC)),
                   dispatch_get_main_queue(), ^{
        if (queryDone) return;

        if (MRMediaRemoteGetNowPlayingInfo == nil) {
            // Old API not available: go straight to the new controller API.
            queryViaNewControllerAPI(^(NSDictionary *info) {
                if (queryDone) return;
                queryDone = YES;
                printNowPlayingInfo(info, command, keys, numKeys);
                [NSApp terminate:nil];
            });
            return;
        }

        // Try the old API first (fast path, works on macOS < 15.4).
        MRMediaRemoteGetNowPlayingInfo(dispatch_get_main_queue(), ^(NSDictionary *information) {
            if (queryDone) return;

            if (information != nil && [information count] > 0) {
                // Old API returned data: use it.
                queryDone = YES;
                printNowPlayingInfo(information, command, keys, numKeys);
                [NSApp terminate:nil];
                return;
            }

            // Old API returned empty.  On macOS 15.4+ the MediaRemote daemon
            // no longer populates the legacy callback.  Fall back to the new
            // ObjC MRNowPlayingController API.
            queryViaNewControllerAPI(^(NSDictionary *info) {
                if (queryDone) return;
                queryDone = YES;
                printNowPlayingInfo(info, command, keys, numKeys);
                [NSApp terminate:nil];
            });
        });
    });

    [NSApp run];
    CFRelease(bundle);
    return 0;

    } // @autoreleasepool
}
