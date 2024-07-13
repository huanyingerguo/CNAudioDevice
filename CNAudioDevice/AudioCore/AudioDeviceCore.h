//
//  AudioDeviceCore.h
//  CNAudioDevice
//
//  Created by jinglin sun on 2022/1/19.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

//异步调用单一对象返回结果
typedef void (^BDEXTDataResultCallback) (id _Nullable data, NSError* _Nullable err);

@interface AudioDeviceCore : NSObject
+ (id)sharedInstance;
- (NSArray *)allMicrophoneList;
- (NSArray *)allSpeakerList;
- (NSArray *)allCaptureList;

- (void)registerListerner:(BDEXTDataResultCallback)block;
@end

NS_ASSUME_NONNULL_END
