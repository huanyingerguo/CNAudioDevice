//
//  AudioDeviceCore.h
//  CNAudioDevice
//
//  Created by jinglin sun on 2022/1/19.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface AudioDeviceCore : NSObject
+ (id)sharedInstance;
- (NSArray *)allMicrophoneList;
- (NSArray *)allSpeakerList;
- (NSArray *)allCaptureList;
@end

NS_ASSUME_NONNULL_END
