//
//  AudioRecorderManager.m
//  AudioRecorderManager
//
//  Created by Joshua Sierles on 15/04/15.
//  Copyright (c) 2015 Joshua Sierles. All rights reserved.
//

#import "AudioRecorderManager.h"
#import "RCTConvert.h"
#import "RCTBridge.h"
#import "RCTEventDispatcher.h"
#import <AVFoundation/AVFoundation.h>

NSString *const AudioRecorderEventProgress = @"recordingProgress";
NSString *const AudioRecorderEventFinished = @"recordingFinished";

@implementation AudioRecorderManager {

  AVAudioRecorder *_audioRecorder;
  AVAudioPlayer *_audioPlayer;

  NSTimeInterval _currentTime;
  NSTimeInterval _preCurrentTime;
  id _progressUpdateTimer;
  int _progressUpdateInterval;
  NSDate *_prevProgressUpdateTime;
  NSURL *_audioFileURL;
  AVAudioSession *_recordSession;
  CGFloat _decibel;
}

@synthesize bridge = _bridge;

RCT_EXPORT_MODULE();

- (void)sendProgressUpdate {
  if (_audioRecorder && _audioRecorder.recording) {
      [_audioRecorder updateMeters];

    _decibel = pow (10, [_audioRecorder averagePowerForChannel:0] / 20) * 250;
    _currentTime = _audioRecorder.currentTime;
    if (_currentTime) {
      _preCurrentTime = _audioRecorder.currentTime;
    }
    _currentTime = _preCurrentTime;
  } else if (_audioPlayer && _audioPlayer.playing) {
    _currentTime = _audioPlayer.currentTime;
  } else {
    return;
  }

  if (_prevProgressUpdateTime == nil || (([_prevProgressUpdateTime timeIntervalSinceNow] * -1000.0) >= _progressUpdateInterval)) {
      [self.bridge.eventDispatcher sendAppEventWithName:AudioRecorderEventProgress body:@{
      @"currentTime": [NSNumber numberWithFloat:_currentTime],
      @"decibel": [NSNumber numberWithFloat:_decibel]
    }];
    _prevProgressUpdateTime = [NSDate date];
  }
}

- (void)stopProgressTimer {
  [_progressUpdateTimer invalidate];
}

- (void)startProgressTimer {
  _progressUpdateInterval = 250;
  _prevProgressUpdateTime = nil;
  _audioRecorder.meteringEnabled = YES;

  [self stopProgressTimer];

  _recordSession = [AVAudioSession sharedInstance];
  [_recordSession setCategory:AVAudioSessionCategoryPlayAndRecord
                    withOptions:(AVAudioSessionCategoryOptionDefaultToSpeaker |
                                 AVAudioSessionCategoryOptionAllowBluetooth)
                          error:nil];
  _progressUpdateTimer = [CADisplayLink displayLinkWithTarget:self selector:@selector(sendProgressUpdate)];
  [_progressUpdateTimer addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
}

- (void)audioRecorderDidFinishRecording:(AVAudioRecorder *)recorder successfully:(BOOL)flag {
  [self.bridge.eventDispatcher sendAppEventWithName:AudioRecorderEventFinished body:@{
      @"status": flag ? @"OK" : @"ERROR"
    }];
}

- (NSString *) applicationDocumentsDirectory
{
  NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
  NSString *basePath = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
  return basePath;
}

RCT_EXPORT_METHOD(prepareRecordingAtPath:(NSString *)path)
{

  _prevProgressUpdateTime = nil;
  [self stopProgressTimer];

  NSString *audioFilePath = [[self applicationDocumentsDirectory] stringByAppendingPathComponent:path];


    NSDictionary *recordSettings = [NSDictionary dictionaryWithObjectsAndKeys:
                                   [NSNumber numberWithInt:kAudioFormatLinearPCM], AVFormatIDKey,
                                   //[NSNumber numberWithFloat:44100.0], AVSampleRateKey,
                                   [NSNumber numberWithFloat:16000.00], AVSampleRateKey,
                                   [NSNumber numberWithInt:1], AVNumberOfChannelsKey,
                                   //  [NSData dataWithBytes:&channelLayout length:sizeof(AudioChannelLayout)], AVChannelLayoutKey,
                                   [NSNumber numberWithInt:16], AVLinearPCMBitDepthKey,
                                   [NSNumber numberWithBool:NO], AVLinearPCMIsNonInterleaved,
                                   [NSNumber numberWithBool:NO],AVLinearPCMIsFloatKey,
                                   [NSNumber numberWithBool:NO], AVLinearPCMIsBigEndianKey,
                                   nil];


    _audioFileURL = [NSURL fileURLWithPath:audioFilePath];


  NSError *error = nil;

  _recordSession = [AVAudioSession sharedInstance];
  // [_recordSession setCategory:AVAudioSessionCategoryPlayAndRecord
  //                withOptions:(AVAudioSessionCategoryOptionDefaultToSpeaker |
  //                           AVAudioSessionCategoryOptionAllowBluetooth)
  //                error:nil];
  // [_recordSession overrideOutputAudioPort:AVAudioSessionPortOverrideSpeaker error:nil];

  _audioRecorder = [[ AVAudioRecorder alloc] initWithURL:_audioFileURL settings:recordSettings error:&error];
  _audioRecorder.delegate = self;

  if (error) {
      NSLog(@"error: %@", [error localizedDescription]);
      // TODO: dispatch error over the bridge
    } else {
      [_audioRecorder prepareToRecord];
  }
}



RCT_EXPORT_METHOD(startRecording)
{
  if (!_audioRecorder.recording) {
    [self startProgressTimer];
    [_recordSession setActive:YES error:nil];
    [_audioRecorder record];

  }
}

RCT_EXPORT_METHOD(stopRecording)
{
  if (_audioRecorder.recording) {
    [_audioRecorder stop];
    // [_recordSession setActive:NO error:nil];
    _prevProgressUpdateTime = nil;
  }
}

RCT_EXPORT_METHOD(pauseRecording)
{
  if (_audioRecorder.recording) {
    [self stopProgressTimer];
    [_audioRecorder pause];
  }
}

RCT_EXPORT_METHOD(playRecording)
{
  if (_audioRecorder.recording) {
    NSLog(@"stop the recording before playing");
    return;

  } else {

    NSError *error;

    if (!_audioPlayer.playing) {
      _audioPlayer = [[AVAudioPlayer alloc]
        initWithContentsOfURL:_audioRecorder.url
        error:&error];

      if (error) {
        [self stopProgressTimer];
        NSLog(@"audio playback loading error: %@", [error localizedDescription]);
        // TODO: dispatch error over the bridge
      } else {
        [self startProgressTimer];
        [_audioPlayer play];
      }
    }
  }
}

RCT_EXPORT_METHOD(pausePlaying)
{
  if (_audioPlayer.playing) {
    [_audioPlayer pause];
  }
}

RCT_EXPORT_METHOD(stopPlaying)
{
  if (_audioPlayer.playing) {
    [_audioPlayer stop];
  }
}

@end
