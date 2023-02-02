#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

typedef void (*MRMediaRemoteGetNowPlayingInfoFunction)(dispatch_queue_t queue, void (^handler)(NSDictionary* information));

void printHelp() {
    printf("Example Usage: \n");
    printf("\tnowplaying-cli get-raw\n");
    printf("\tnowplaying-cli get title album artist\n");
}

int main(int argc, char** argv) {

    if(argc == 1) {
        printHelp();
        return 0;
    }
    bool getRaw = false;
    int numKeys = argc - 2;
    NSMutableArray<NSString *> *keys = [NSMutableArray array];
    if(strcmp(argv[1], "get") == 0) {
        for(int i = 2; i < argc; i++) {
            NSString *key = [NSString stringWithUTF8String:argv[i]];
            [keys addObject:key];
        }
    }
    else if(strcmp(argv[1], "get-raw") == 0) {
        getRaw = true;
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
    
    MRMediaRemoteGetNowPlayingInfoFunction MRMediaRemoteGetNowPlayingInfo = (MRMediaRemoteGetNowPlayingInfoFunction) CFBundleGetFunctionPointerForName(bundle, CFSTR("MRMediaRemoteGetNowPlayingInfo"));
    MRMediaRemoteGetNowPlayingInfo(dispatch_get_main_queue(), ^(NSDictionary* information) {
        NSString *data = [information description];

        const char *dataStr = [data UTF8String];
        if(getRaw) {
            printf("%s\n", dataStr);
            [NSApp terminate:nil];
            return;
        }

        for(int i = 0; i < numKeys; i++) {
            NSString *propKey = [keys[i] stringByReplacingCharactersInRange:NSMakeRange(0,1) withString:[[keys[i] substringToIndex:1] capitalizedString]];
            NSString *key = [NSString stringWithFormat:@"kMRMediaRemoteNowPlayingInfo%@", propKey];
            NSObject *rawValue = [information objectForKey:key];
            if(rawValue == nil) {
                continue;
            }
            NSString *value = [NSString stringWithFormat:@"%@", rawValue];
            const char *valueStr = [value UTF8String];
            printf("%s\n", valueStr);
        }

        [NSApp terminate:nil];
    });

    [NSApp run];
    [pool release];
    return 0;
}