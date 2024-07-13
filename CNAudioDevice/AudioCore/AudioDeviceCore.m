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

#define WEAK_REF(obj) \
__weak typeof(obj) weak_##obj = obj; \

#define STRONG_REF(obj) \
__strong typeof(weak_##obj) obj = weak_##obj; \

#define PREP_BLOCK WEAK_REF(self);

#define BEGIN_BLOCK \
STRONG_REF(self); \
if(self != nil){ \
@try { \

#define END_BLOCK \
} \
@catch (NSException *exception) { \
}} \

#define SCLog NSLog
#define SCLogI NSLog
#define SCLogW NSLog
#define SCLogE NSLog

@interface AudioDeviceCore ()
@property (strong) NSMutableArray* listenerList;

//默认输入输出设备改变
@property (copy) AudioObjectPropertyListenerBlock inputAudioChangeListenerBlock;
@property (copy) AudioObjectPropertyListenerBlock outputAudioChangeListenerBlock;

//所有设备列表改变
@property (copy) AudioObjectPropertyListenerBlock deviceListChangeListenerBlock;
@end

@implementation AudioDeviceCore

+ (id)sharedInstance {
    static AudioDeviceCore *sharedObject;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedObject = [[AudioDeviceCore alloc] init];
    });
    
    return sharedObject;
}

-(instancetype)init{
    self = [super init];
    if (self){
        _listenerList = [NSMutableArray new];
        [self startListenDeviceListChange];
        [self startListenAudioSourceChange];
        [self startListenAVCaptureDeviceChange];
    }
    
    return self;
}

- (void)registerListerner:(BDEXTDataResultCallback)block {
    [_listenerList addObject:block];
}

//监听所有设备改变
- (BOOL)startListenDeviceListChange {
    AudioObjectPropertyAddress propertyAddress = {
        .mSelector = kAudioHardwarePropertyDevices,
        .mScope = kAudioObjectPropertyScopeGlobal,
        .mElement = kAudioObjectPropertyElementMaster
    };
    
    PREP_BLOCK
    self.deviceListChangeListenerBlock = ^(UInt32 inNumberAddresses, const AudioObjectPropertyAddress*  inAddresses){
        BEGIN_BLOCK
        SCLogI(@"系统语音设备列表改变--->");
        NSArray *detail = [self allCaptureList];
        [self dispatchAllListener:detail error:nil];
        END_BLOCK
    };
    
    OSStatus status = AudioObjectAddPropertyListenerBlock(kAudioObjectSystemObject, &propertyAddress, 0, self.deviceListChangeListenerBlock);
    if (status != kAudioHardwareNoError){
        SCLogE(@"startListenDeviceListChange失败:%d",status);
        return NO;
    }
    
    return YES;
}

- (BOOL)endListenDeviceListChange {
    {
        AudioObjectPropertyAddress propertyAddress = {
            .mSelector = kAudioHardwarePropertyDevices,
            .mScope = kAudioObjectPropertyScopeGlobal,
            .mElement = kAudioObjectPropertyElementMaster
        };
        OSStatus status = AudioObjectRemovePropertyListenerBlock(kAudioObjectSystemObject, &propertyAddress, 0, self.deviceListChangeListenerBlock);
        if (status != kAudioHardwareNoError){
            return NO;
        }
    }
    
    return YES;
}

- (void)startListenAVCaptureDeviceChange {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onAVCaptureDeviceConnect:) name:AVCaptureDeviceWasConnectedNotification object:nil];
     
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onAVCaptureDeviceDisconnect:) name:AVCaptureDeviceWasDisconnectedNotification object:nil];
}

- (void)endListenAVCaptureDeviceChange {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)onAVCaptureDeviceConnect:(id)notify {
    SCLogI(@"系统设备插入事件:%@", notify);
    [self printAllAVCaptureDevices];
}

- (void)onAVCaptureDeviceDisconnect:(id)notify {
    SCLogI(@"系统设备拔出事件:%@", notify);
    [self printAllAVCaptureDevices];
}

- (void)printAllAVCaptureDevices {
    //以下代码，部分用户出现频繁卡顿
    SCLogI(@"系统所有音视频设备:%@", [AVCaptureDevice devices]);
}

-(BOOL)startListenAudioSourceChange{
    
    {
        PREP_BLOCK
        self.outputAudioChangeListenerBlock = ^(UInt32 inNumberAddresses, const AudioObjectPropertyAddress*  inAddresses){
            BEGIN_BLOCK
            SCLogI(@"默认音频输出设备改变...");
            END_BLOCK
        };
        
        AudioObjectPropertyAddress defaultAddr = [self defaultSpeakerAddress];
        OSStatus status = AudioObjectAddPropertyListenerBlock(kAudioObjectSystemObject, &defaultAddr, 0,self.outputAudioChangeListenerBlock);
        if (status != kAudioHardwareNoError){
            SCLogE(@"startListenSourceChange 输出失败:%d",status);
            return NO;
        }
    }
    
    {
        PREP_BLOCK
        self.inputAudioChangeListenerBlock = ^(UInt32 inNumberAddresses, const AudioObjectPropertyAddress*  inAddresses){
            BEGIN_BLOCK
            SCLogI(@"默认音频输入设备改变...");
            END_BLOCK
        };
        
        AudioObjectPropertyAddress defaultAddr = [self defaultMicroAddress];
        OSStatus status = AudioObjectAddPropertyListenerBlock(kAudioObjectSystemObject, &defaultAddr, 0,self.inputAudioChangeListenerBlock);
        if (status != kAudioHardwareNoError){
            SCLogE(@"startListenSourceChange 输入失败:%d",status);
            return NO;
        }
    }
    
    return YES;
}

-(BOOL)endListenAudioSourceChange{
    {
        AudioObjectPropertyAddress outputAddr = [self defaultSpeakerAddress];
        OSStatus status = AudioObjectRemovePropertyListenerBlock(kAudioObjectSystemObject, &outputAddr, 0, self.outputAudioChangeListenerBlock);
        if (status != kAudioHardwareNoError){
            return NO;
        }
    }
    
    {
        AudioObjectPropertyAddress inputAddr = [self defaultMicroAddress];
        OSStatus status = AudioObjectRemovePropertyListenerBlock(kAudioObjectSystemObject, &inputAddr, 0, self.inputAudioChangeListenerBlock);
        if (status != kAudioHardwareNoError){
            return NO;
        }
    }
    
    return YES;
}


#pragma mark- Public Method
- (NSArray *)allMicrophoneList {
    return nil;
}

- (NSArray *)allSpeakerList {
    
    
    return nil;
}

- (NSDictionary *)defaultMicrophone {
    AudioObjectPropertyAddress micro = [self defaultMicroAddress];

    AudioDeviceID masterInputDeviceID;
    UInt32 masterInputDeviceIDSize = sizeof(masterInputDeviceID);
    OSStatus result = AudioObjectGetPropertyData(kAudioObjectSystemObject,
                                                 &micro,
                                                 0, NULL,
                                                 &masterInputDeviceIDSize, &masterInputDeviceID);
    
    if(kAudioHardwareNoError != result){
        NSLog(@"masterInputAudioDeviceID失败:%d",result);
        return nil;
    }
    
    NSDictionary *detail = [self getDeviceInfoById:masterInputDeviceID isInput:YES];
    NSLog(@"默认输入设备detail:%@", detail);
    return detail;
}

- (NSDictionary *)defaultSpeaker {
    AudioObjectPropertyAddress micro = [self defaultSpeakerAddress];

    AudioDeviceID masterOutputDeviceID;
    UInt32 masterDeviceIDSize = sizeof(masterOutputDeviceID);
    OSStatus result = AudioObjectGetPropertyData(kAudioObjectSystemObject,
                                                 &micro,
                                                 0, NULL,
                                                 &masterDeviceIDSize, &masterOutputDeviceID);
    
    if(kAudioHardwareNoError != result){
        NSLog(@"masterInputAudioDeviceID失败:%d",result);
        return nil;
    }
    
    NSDictionary *detail = [self getDeviceInfoById:masterOutputDeviceID isInput:YES];
    NSLog(@"默认输出设备detail:%@", detail);
    return detail;
}


- (NSArray *)allCaptureList {
    AVCaptureDeviceDiscoverySession *audioSession = [AVCaptureDeviceDiscoverySession discoverySessionWithDeviceTypes:@[AVCaptureDeviceTypeBuiltInMicrophone, AVCaptureDeviceTypeExternalUnknown] mediaType:AVMediaTypeAudio position:AVCaptureDevicePositionUnspecified];
    NSArray *devices = [audioSession devices] ?: @[];
    NSArray *devices2 = [AVCaptureDevice devices] ?: @[];
    NSArray *inputList = [self getAllAudioDeviceList:YES] ?: @[];
    NSArray *outputList = [self getAllAudioDeviceList:NO] ?: @[];
    
    NSMutableArray *tansedList = [NSMutableArray array];
    [devices2 enumerateObjectsUsingBlock:^(AVCaptureDevice *  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([obj hasMediaType: AVMediaTypeAudio]) {
            NSString *deviceId = obj.uniqueID;
            AudioDeviceID objId = [self transDeviceStringIDToDeviceID:deviceId];
            if (objId) {
                NSMutableDictionary *newDetail = [NSMutableDictionary dictionary];
                [newDetail setObject:obj forKey:@"obj"];
                [newDetail setObject:@(objId) forKey:@"id"];
                [tansedList addObject:newDetail];
            }
        }
    }];

    NSLog(@"deviceList:%@, \r\n devices2:%@, \r\n input:%@, \r\n output:%@, \r\n tansedList:%@",
          devices,
          devices2,
          inputList,
          outputList,
          tansedList);
    
    id speaker =  [self defaultSpeaker];
    id mic = [self defaultMicrophone];
    
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    NSString *str = [NSString stringWithFormat:@"speaker:%@, \r\n mic:%@, \r\n input:%@, \r\n output:%@, \r\n tansedList:%@",
                     speaker,
                     mic,
                     inputList,
                     outputList,
                     tansedList];

    return @[str];
}

- (BOOL)hasCamera {
    
    if ([AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo].count != 0) {
        return YES;
    }
    NSLog(@"系统摄像头个数为0，检测是否有默认摄像头");
    if ([AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo]) {
        return YES;
    }
    NSLog(@"系统没有默认摄像头--->");
    return NO;
}

- (NSDictionary *)getDeviceInfoById:(AudioDeviceID)deviceId isInput:(BOOL)isInput {
    NSString *name = [self getAudioDeviceStringProperty:deviceId property:kAudioDevicePropertyDeviceName isInput:isInput];
    NSString *type = [self getAudioDeviceStringProperty:deviceId property:kAudioDevicePropertyTransportType isInput:isInput];
    type = [self reversalString:type];
    NSString *manufacure = [self getAudioDeviceStringProperty:deviceId property:kAudioDevicePropertyDeviceManufacturer isInput:isInput];
    NSString *deviceUID = [self getAudioDeviceStringPropertyV2:deviceId selector:kAudioDevicePropertyDeviceUID isInput:isInput];

    return @{@"id": @(deviceId),
             @"deviceName": name ?: @"",
             @"type": type ?: @"",
             @"deviceUID": deviceUID ?: @"",
             @"manufacure": manufacure ?: @"",
    };
}

- (AudioDeviceID)transDeviceStringIDToDeviceID:(NSString *)inStringID {
    AudioObjectID theAnswer = kAudioObjectUnknown;
    AudioValueTranslation theValue = { &inStringID, sizeof(CFStringRef), &theAnswer, sizeof(AudioObjectID) };
    UInt32 theSize = sizeof(AudioValueTranslation);
    
    AudioObjectPropertyAddress address = {
        kAudioHardwarePropertyDeviceForUID,
        kAudioObjectPropertyScopeGlobal,
        kAudioObjectPropertyElementMaster
    };
    
    OSStatus result = AudioObjectGetPropertyData(kAudioObjectSystemObject,
                                                 &address,
                                                 0, NULL,
                                                 &theSize,
                                                 &theValue);
    
    if (kAudioHardwareNoError != result) {
        NSLog(@"getAudioPluginDeviceID失败:%d", result);
        theAnswer = kAudioObjectUnknown;
    }
    
    return theAnswer;
}

#pragma mark- Util
- (NSString *)reversalString:(NSString *)string {
    NSString *resultStr = @"";
    for (NSInteger i = string.length -1; i >= 0; i--) {
        NSString *indexStr = [string substringWithRange:NSMakeRange(i, 1)];
        resultStr = [resultStr stringByAppendingString:indexStr];
    }
    return resultStr;
}

- (NSString *)getAudioDeviceStringPropertyV2:(AudioDeviceID)audioDeviceID selector:(AudioObjectPropertySelector)mSelector isInput:(BOOL)isInput {
    AudioObjectPropertyAddress propertyAddress = {
        kAudioHardwarePropertyDevices,
        kAudioObjectPropertyScopeGlobal,
        kAudioObjectPropertyElementMaster
    };

    propertyAddress.mSelector = mSelector;
    if (isInput) {
        propertyAddress.mScope = kAudioDevicePropertyScopeInput;
    } else {
        propertyAddress.mScope = kAudioDevicePropertyScopeOutput;
    }

    CFStringRef deviceUID = NULL;
    UInt32 dataSize = sizeof(deviceUID);
    
    OSStatus status = AudioHardwareServiceGetPropertyData(audioDeviceID, &propertyAddress, 0, NULL, &dataSize, &deviceUID);
    if(kAudioHardwareNoError != status) {
        return @"";
    }

    NSString *result = (__bridge_transfer NSString*)deviceUID;
    return result;
}

- (NSString *)getAudioDeviceStringProperty:(AudioDeviceID)audioDeviceID property:(AudioDevicePropertyID)audioDevicePropertyID isInput:(BOOL)isInput {
    UInt32 propertySize = 256;
    char propertyName[256]= {0};
    AudioDeviceGetProperty(audioDeviceID, 0, isInput ? true : false, audioDevicePropertyID, &propertySize, propertyName);
    return propertyName[0] ? [NSString stringWithUTF8String:propertyName] : nil;
}

- (NSArray *)getAllAudioDeviceList:(BOOL)isInput {
    UInt32 propertySize = 0;
    AudioDeviceID dev_array[512];
    int numberOfDevices = 0;
    
    AudioHardwareGetPropertyInfo(kAudioHardwarePropertyDevices, &propertySize, NULL);
    AudioHardwareGetProperty(kAudioHardwarePropertyDevices, &propertySize, dev_array);
    
    numberOfDevices = (propertySize / sizeof(AudioDeviceID));
    
    NSMutableArray *list = [NSMutableArray array];
    
    for(int i = 0; i < numberOfDevices; ++i) {
        UInt32 propertySize = 256;
        // if there are any input streams, then it is an input
        AudioDeviceGetPropertyInfo(dev_array[i], 0, isInput ? true : false, kAudioDevicePropertyStreams, &propertySize, NULL);
        if (propertySize <= 0) {
            continue;
        }
        
        UInt32 outData = 0;
        
        AudioDeviceGetProperty(dev_array[i], 0, isInput ? true : false, kAudioDevicePropertyDeviceCanBeDefaultDevice, &propertySize, &outData);

        if (!outData) {
           // continue;
        }
        
#if 0
        AudioDeviceGetProperty(dev_array[i], 0, isInput ? true : false, kAudioDevicePropertyTransportType, &propertySize, &outData);

        if (outData == kAudioDeviceTransportTypeVirtual) {
            //虚拟设备不添加，同腾讯会议
            continue;
        }
#endif
        
        NSString *name = [self getAudioDeviceStringProperty:dev_array[i] property:kAudioDevicePropertyDeviceName isInput:isInput];
        
        if (!name || [name hasPrefix:@"VPAUAggregateAudioDevice"]) {
            continue;
        }
        
        if (isInput) {
            UInt32 kAudioDevicePropertyTapEnabled = 'tapd';
            
            AudioObjectPropertyAddress address = { kAudioDevicePropertyTapEnabled, kAudioDevicePropertyScopeOutput, kAudioObjectPropertyElementMaster };
            
            if (AudioObjectHasProperty(dev_array[i], &address)){
                NSLog(@"Ignore output devices that have input only for echo cancellation");
                continue;
            }
        }

        
        NSString *manufacturer = [self getAudioDeviceStringProperty:dev_array[i] property:kAudioDevicePropertyDeviceManufacturer isInput:isInput];
        
        NSString *deviceUID = [self getAudioDeviceStringPropertyV2:dev_array[i] selector:kAudioDevicePropertyDeviceUID isInput:isInput];

        NSString *type = [self getAudioDeviceStringProperty:dev_array[i] property:kAudioDevicePropertyTransportType isInput:isInput];
        id item = [self getDeviceInfoById:dev_array[i] isInput:isInput];

//        id item = @{@"name": name ?: @"",
//                    @"manufacturer": manufacturer ?: @"",
//                    @"id": @(dev_array[i]),
//                    @"deviceUID": deviceUID ?: @"",
//                    @"type": type ?: @""
//                    };
                
        [list addObject:item];
        
    }
    
    NSLog(@"getAllAudioDeviceList input=%d list:%@", isInput, list);
    return [list copy];
}

#pragma mark- Device Address
- (AudioObjectPropertyAddress)defaultMicroAddress {
    AudioObjectPropertyAddress address = {
        kAudioHardwarePropertyDefaultInputDevice,
        kAudioObjectPropertyScopeInput,
        kAudioObjectPropertyElementMaster,
    };
    
    return address;
}

- (AudioObjectPropertyAddress)defaultSpeakerAddress {
    AudioObjectPropertyAddress address = {
        kAudioHardwarePropertyDefaultOutputDevice,
        kAudioObjectPropertyScopeOutput,
        kAudioObjectPropertyElementMaster,
    };
    
    return address;
}

- (AudioObjectPropertyAddress)masterVolumePropertyAddress {
    AudioObjectPropertyAddress leftVolumePropertyAddress = {
        kAudioHardwareServiceDeviceProperty_VirtualMasterVolume,
        kAudioDevicePropertyScopeOutput,
        kAudioObjectPropertyElementMaster
    };
    
    return leftVolumePropertyAddress;
}

- (AudioObjectPropertyAddress)microPhoneVolumePropertyAddress{
    AudioObjectPropertyAddress microPhoneVolumePropertyAddress = {
        kAudioDevicePropertyVolumeScalar,
        kAudioObjectPropertyScopeInput,
        kAudioObjectPropertyElementMaster
    };
    
    return microPhoneVolumePropertyAddress;
}

- (void)dispatchAllListener:(id)data error:(NSError *)error {
    for (BDEXTDataResultCallback callback in _listenerList) {
        callback(data, error);
    }
}
@end
