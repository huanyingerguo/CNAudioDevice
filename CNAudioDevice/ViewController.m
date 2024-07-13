//
//  ViewController.m
//  CNAudioDevice
//
//  Created by jinglin sun on 2022/1/19.
//

#import "ViewController.h"
#import "AudioCore/AudioDeviceCore.h"

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    // Do any additional setup after loading the view.
}


- (void)setRepresentedObject:(id)representedObject {
    [super setRepresentedObject:representedObject];

    // Update the view, if already loaded.
}

- (IBAction)onBUttonClicked:(id)sender {
    NSArray *list = [[AudioDeviceCore sharedInstance] allCaptureList];
    self.textView.string = list[0];
}

@end
