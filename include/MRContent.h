@interface MRContentItemMetadata : NSObject
@property CGFloat calculatedPlaybackPosition;
@end

@interface MRContentItem : NSObject
@property (retain) MRContentItemMetadata *metadata;
- (instancetype)initWithNowPlayingInfo:(NSDictionary *)nowPlayingInfo;
@end