#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <objc/runtime.h>
#import "Enums.h"
#import "MRContent.h"

typedef void (*MRMediaRemoteGetNowPlayingInfoFunction)(dispatch_queue_t queue, void (^handler)(NSDictionary* information));
typedef Boolean (*MRMediaRemoteSendCommandFunction)(MRMediaRemoteCommand cmd, NSDictionary* userInfo);

void printHelp() {
    printf("Example Usage: \n");
    printf("\tnowplaying-cli get-raw\n");
    printf("\tnowplaying-cli get title album artist\n");
    printf("\tnowplaying-cli pause\n");
    printf("\n");
    printf("Available commands: \n");
    printf("\tget, get-raw, play, pause, togglePlayPause, next, previous\n");
}

typedef enum {
    GET,
    GET_RAW,
    MEDIA_COMMAND

} Command;

NSDictionary<NSString*, NSNumber*> *cmdTranslate = @{
    @"play": @(MRMediaRemoteCommandPlay),
    @"pause": @(MRMediaRemoteCommandPause),
    @"togglePlayPause": @(MRMediaRemoteCommandTogglePlayPause),
    @"next": @(MRMediaRemoteCommandNextTrack),
    @"previous": @(MRMediaRemoteCommandPreviousTrack),
};

int main(int argc, char** argv) {

    if(argc == 1) {
        printHelp();
        return 0;
    }

    Command command = GET;
    NSString *cmdStr = [NSString stringWithUTF8String:argv[1]];

    int numKeys = argc - 2;
    NSMutableArray<NSString *> *keys = [NSMutableArray array];
    if(strcmp(argv[1], "get") == 0) {
        for(int i = 2; i < argc; i++) {
            NSString *key = [NSString stringWithUTF8String:argv[i]];
            [keys addObject:key];
        }
        command = GET;
    }
    else if(strcmp(argv[1], "get-raw") == 0) {
        command = GET_RAW;
    }
    else if(cmdTranslate[cmdStr] != nil) {
        command = MEDIA_COMMAND;
    }
    else {
        printHelp();
        return 0;
    }

    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
    NSPanel* panel = [[NSPanel alloc] 
        initWithContentRect: NSMakeRect(0, 0, 0, 0)
        styleMask: NSWindowStyleMaskTitled
        backing: NSBackingStoreBuffered
        defer: NO];


    CFURLRef ref = (__bridge CFURLRef) [NSURL fileURLWithPath:@"/System/Library/PrivateFrameworks/MediaRemote.framework"];
    CFBundleRef bundle = CFBundleCreate(kCFAllocatorDefault, ref);

    MRMediaRemoteSendCommandFunction MRMediaRemoteSendCommand = (MRMediaRemoteSendCommandFunction) CFBundleGetFunctionPointerForName(bundle, CFSTR("MRMediaRemoteSendCommand"));
    if(command == MEDIA_COMMAND) {
        MRMediaRemoteSendCommand((MRMediaRemoteCommand) [cmdTranslate[cmdStr] intValue], nil);
    }

    MRMediaRemoteGetNowPlayingInfoFunction MRMediaRemoteGetNowPlayingInfo = (MRMediaRemoteGetNowPlayingInfoFunction) CFBundleGetFunctionPointerForName(bundle, CFSTR("MRMediaRemoteGetNowPlayingInfo"));
    MRMediaRemoteGetNowPlayingInfo(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(NSDictionary* information) {
        if(command == MEDIA_COMMAND) {
            [NSApp terminate:nil];
            return;
        }

        NSString *data = [information description];
        const char *dataStr = [data UTF8String];
        if(command == GET_RAW) {
            printf("%s\n", dataStr);
            [NSApp terminate:nil];
            return;
        }

        for(int i = 0; i < numKeys; i++) {
            NSString *propKey = [keys[i] stringByReplacingCharactersInRange:NSMakeRange(0,1) withString:[[keys[i] substringToIndex:1] capitalizedString]];
            NSString *key = [NSString stringWithFormat:@"kMRMediaRemoteNowPlayingInfo%@", propKey];
            NSObject *rawValue = [information objectForKey:key];
            if(rawValue == nil) {
                printf("null\n");
            }
            else if([key isEqualToString:@"kMRMediaRemoteNowPlayingInfoArtworkData"] || [key isEqualToString:@"kMRMediaRemoteNowPlayingInfoClientPropertiesData"]) {
                NSData *data = (NSData *) rawValue;
                NSString *base64 = [data base64EncodedStringWithOptions:0];
                printf("%s\n", [base64 UTF8String]);
            }
            else if([key isEqualToString:@"kMRMediaRemoteNowPlayingInfoElapsedTime"]) {
                MRContentItem *item = [[objc_getClass("MRContentItem") alloc] initWithNowPlayingInfo:(__bridge NSDictionary *)information];
                NSString *value = [NSString stringWithFormat:@"%f", item.metadata.calculatedPlaybackPosition];
                const char *valueStr = [value UTF8String];
                printf("%s\n", valueStr);
            }
            else {
                NSString *value = [NSString stringWithFormat:@"%@", rawValue];
                const char *valueStr = [value UTF8String];
                printf("%s\n", valueStr);
            }
        }
        [NSApp terminate:nil];
    });

    [NSApp run];
    [pool release];
    return 0;
}
