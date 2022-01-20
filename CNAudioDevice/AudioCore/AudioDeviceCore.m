//
//  AudioDeviceCore.m
//  CNAudioDevice
//
//  Created by jinglin sun on 2022/1/19.
//

#import "AudioDeviceCore.h"
#import <AVFoundation/AVFoundation.h>
#import <AVFoundation/AVCaptureDevice.h>
#import <CoreAudio/AudioHardware.h>
#import <CoreAudio/AudioHardwareBase.h>
#import <CoreAudio/AudioHardwareDeprecated.h>
#import <AudioToolBox/AudioHardwareService.h>

@implementation AudioDeviceCore

- (id)sharedInstance {
    static AudioDeviceCore *sharedObject;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedObject = [[AudioDeviceCore alloc] init];
    });
    
    return sharedObject;
}

- (NSArray *)allMicrophoneList {
    return nil;
}

- (NSArray *)allSpeakerList {
    
    
    return nil;
}

- (NSArray *)allCaptureList {
    AVCaptureDeviceDiscoverySession *audioSession = [AVCaptureDeviceDiscoverySession discoverySessionWithDeviceTypes:@[AVCaptureDeviceTypeBuiltInMicrophone, AVCaptureDeviceTypeExternalUnknown] mediaType:AVMediaTypeAudio position:AVCaptureDevicePositionUnspecified];
    NSArray *devices = [audioSession devices];
    NSArray *devices2 = [AVCaptureDevice devices];

    NSLog(@"deviceList:%@, \r\n devices2:%@", devices, devices2);
    return nil;
}
@end
