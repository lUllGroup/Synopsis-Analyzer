//
//  PreferencesPresetViewController.m
//  Synopsis
//
//  Created by vade on 12/26/15.
//  Copyright (c) 2015 metavisual. All rights reserved.
//

#import "PreferencesPresetViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <VideoToolbox/VideoToolbox.h>
#import <VideoToolbox/VTVideoEncoderList.h>
#import <VideoToolbox/VTCompressionProperties.h>
#import <VideoToolbox/VTProfessionalVideoWorkflow.h>
#import "PresetGroup.h"
#import "AVAssetWriterHapInput.h"

// Preferences Keys
const NSString* title = @"Title";
const NSString* value = @"Value";


@interface PreferencesPresetViewController ()  <NSOutlineViewDataSource, NSOutlineViewDelegate, NSSplitViewDelegate>

@property (weak) IBOutlet NSSplitView* stupidFuckingSplitview;
@property (weak) IBOutlet NSBox* presetInfoContainerBox;

@property (weak) IBOutlet NSOutlineView* presetOutlineView;

@property (weak) IBOutlet NSView* overviewContainerView;
@property (weak) IBOutlet NSTextField* overviewTitleTextField;
@property (weak) IBOutlet NSTextField* overviewDescriptionTextField;

// Preferences Video
@property (weak) IBOutlet NSView* videoContainerView;
@property (weak) IBOutlet NSButton* useVideoCheckButton;
@property (weak) IBOutlet NSPopUpButton* prefsVideoCompressor;
@property (weak) IBOutlet NSPopUpButton* prefsVideoDimensions;
@property (weak) IBOutlet NSPopUpButton* prefsVideoQuality;
@property (weak) IBOutlet NSTextField* prefsVideoDimensionsCustomWidth;
@property (weak) IBOutlet NSTextField* prefsVideoDimensionsCustomHeight;
@property (weak) IBOutlet NSPopUpButton* prefsVideoAspectRatio;

// Video Prefs Logic Backing /
@property (readwrite, atomic, strong) NSArray* videoResolutions;


//@property (atomic, readwrite, strong) NSDictionary* prefsVideoSettings; // sent to kSynopsisTranscodeVideoSettingsKey

// Preferences Audio
@property (weak) IBOutlet NSView* audioContainerView;
@property (weak) IBOutlet NSButton* useAudioCheckButton;
@property (weak) IBOutlet NSPopUpButton* prefsAudioFormat;
@property (weak) IBOutlet NSPopUpButton* prefsAudioRate;
@property (weak) IBOutlet NSPopUpButton* prefsAudioQuality;
@property (weak) IBOutlet NSPopUpButton* prefsAudioBitrate;

//@property (atomic, readwrite, strong) NSDictionary* prefsAudioSettings; // sent to kSynopsisTranscodeAudioSettingsKey

// Preferences Analysis
@property (weak) IBOutlet NSView* analysisContainerView;
@property (weak) IBOutlet NSButton* useAnalysisCheckButton;


// Outline View Data source
@property (atomic, readwrite, strong) PresetGroup* standardPresets;
@property (atomic, readwrite, strong) PresetGroup* customPresets;

@property (atomic, readwrite, strong) PresetObject* selectedPreset;
@property (atomic, readwrite, strong) PresetGroup* selectedPresetGroup;

@end

@implementation PreferencesPresetViewController

- (id) initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if(self)
    {
        self.selectedPreset = nil;
        self.standardPresets = [[PresetGroup alloc] initWithTitle:@"Standard Presets" editable:NO];
        self.customPresets = [[PresetGroup alloc] initWithTitle:@"Custom Presets" editable:NO];
        
#pragma mark - Passthrough 
        
        PresetObject* passthrough = [[PresetObject alloc] initWithTitle:@"Passthrough" audioSettings:[PresetAudioSettings none] videoSettings:[PresetVideoSettings none] analyzerSettings:[PresetAnalysisSettings none] useAudio:YES useVideo:YES useAnalysis:YES editable:NO];
        
        PresetObject* passthroughNoAudio = [[PresetObject alloc] initWithTitle:@"Passthrough - No Audio" audioSettings:[PresetAudioSettings none] videoSettings:[PresetVideoSettings none] analyzerSettings:[PresetAnalysisSettings none] useAudio:NO useVideo:YES useAnalysis:YES editable:NO];
        
        PresetGroup* passthroughGroup = [[PresetGroup alloc] initWithTitle:@"Passthrough" editable:NO];
        passthroughGroup.children = @[passthrough, passthroughNoAudio];

#pragma mark - Uncompressed
        
        // Uncompressed YUV 422 -
        // TODO: when to use yuvs vs 2vuy ?
        PresetVideoSettings* yuv422YpCbCr8VideoSetting = [[PresetVideoSettings alloc] init];
        yuv422YpCbCr8VideoSetting.settingsDictionary = @{AVVideoCodecKey:@"2vuy"};
        
        PresetObject* yuv422YpCbCr8Preset = [[PresetObject alloc] initWithTitle:@"Uncompressed 8 Bit 422"
                                                                         audioSettings:[PresetAudioSettings none]
                                                                         videoSettings:yuv422YpCbCr8VideoSetting
                                                                      analyzerSettings:[PresetAnalysisSettings none]
                                                                              useAudio:YES
                                                                              useVideo:YES
                                                                           useAnalysis:YES
                                                                              editable:NO];

        // TODO: RGB 24 bit ?
        PresetGroup* uncompressedGroup = [[PresetGroup alloc] initWithTitle:@"Uncompressed" editable:NO];
        uncompressedGroup.children = @[yuv422YpCbCr8Preset];
     
#pragma mark - HAP
        
        // Hap1
        PresetVideoSettings* hap1VideoSetting = [[PresetVideoSettings alloc] init];
        hap1VideoSetting.settingsDictionary = @{AVVideoCodecKey: AVVideoCodecHap};
        
        PresetObject* hap1Preset = [[PresetObject alloc] initWithTitle:@"HAP"
                                                                  audioSettings:[PresetAudioSettings none]
                                                                  videoSettings:hap1VideoSetting
                                                               analyzerSettings:[PresetAnalysisSettings none]
                                                                       useAudio:YES
                                                                       useVideo:YES
                                                                    useAnalysis:YES
                                                                       editable:NO];
        // Hap5
        PresetVideoSettings* hap5VideoSetting = [[PresetVideoSettings alloc] init];
        hap5VideoSetting.settingsDictionary = @{AVVideoCodecKey : AVVideoCodecHapAlpha};
        
        PresetObject* hap5Preset = [[PresetObject alloc] initWithTitle:@"HAP Alpha"
                                                         audioSettings:[PresetAudioSettings none]
                                                         videoSettings:hap5VideoSetting
                                                      analyzerSettings:[PresetAnalysisSettings none]
                                                              useAudio:YES
                                                              useVideo:YES
                                                           useAnalysis:YES
                                                              editable:NO];

        // HapY
        PresetVideoSettings* hapYVideoSetting = [[PresetVideoSettings alloc] init];
        hapYVideoSetting.settingsDictionary = @{AVVideoCodecKey : AVVideoCodecHapQ};
        
        PresetObject* hapYPreset = [[PresetObject alloc] initWithTitle:@"HAP Q"
                                                         audioSettings:[PresetAudioSettings none]
                                                         videoSettings:hapYVideoSetting
                                                      analyzerSettings:[PresetAnalysisSettings none]
                                                              useAudio:YES
                                                              useVideo:YES
                                                           useAnalysis:YES
                                                              editable:NO];
        
        // HapM
        PresetVideoSettings* hapMVideoSetting = [[PresetVideoSettings alloc] init];
        hapMVideoSetting.settingsDictionary = @{AVVideoCodecKey : AVVideoCodecHapQAlpha};
        
        PresetObject* hapMPreset = [[PresetObject alloc] initWithTitle:@"HAP Q Alpha"
                                                         audioSettings:[PresetAudioSettings none]
                                                         videoSettings:hapMVideoSetting
                                                      analyzerSettings:[PresetAnalysisSettings none]
                                                              useAudio:YES
                                                              useVideo:YES
                                                           useAnalysis:YES
                                                              editable:NO];

//        // HapA
//        PresetVideoSettings* hapAVideoSetting = [[PresetVideoSettings alloc] init];
//        hapAVideoSetting.settingsDictionary = @{AVVideoCodecKey:@"HapA"};
//        
//        PresetObject* hapAPreset = [[PresetObject alloc] initWithTitle:@"HAP Alpha"
//                                                         audioSettings:[PresetAudioSettings none]
//                                                         videoSettings:hapAVideoSetting
//                                                      analyzerSettings:[PresetAnalysisSettings none]
//                                                              useAudio:YES
//                                                              useVideo:YES
//                                                           useAnalysis:YES
//                                                              editable:NO];
        
        PresetGroup* hapGroup = [[PresetGroup alloc] initWithTitle:@"HAP" editable:NO];
        hapGroup.children = @[hap1Preset,
                              hap5Preset,
                              hapYPreset,
                              hapMPreset,
//                              hapAPreset,
                              ];
        
#pragma mark - Animation

        // No RLE Encoder in AVFoundation on 10.12?
//        PresetVideoSettings* animationVideoSetting = [[PresetVideoSettings alloc] init];
//        animationVideoSetting.settingsDictionary = @{AVVideoCodecKey:@"rle "};
//        
//        PresetObject* animationPreset = [[PresetObject alloc] initWithTitle:@"Apple Animation"
//                                                                  audioSettings:[PresetAudioSettings none]
//                                                                  videoSettings:animationVideoSetting
//                                                               analyzerSettings:[PresetAnalysisSettings none]
//                                                                       useAudio:YES
//                                                                       useVideo:YES
//                                                                    useAnalysis:YES
//                                                                       editable:NO];
//        
//        PresetGroup* animationGroup = [[PresetGroup alloc] initWithTitle:@"Animation" editable:NO];
//        animationGroup.children = @[animationPreset];

#pragma mark - Pro Res Variants
        
        // 4444
        PresetVideoSettings* appleProRes4444VideoSetting = [[PresetVideoSettings alloc] init];
        appleProRes4444VideoSetting.settingsDictionary = @{AVVideoCodecKey:@"ap4h"};
        
        PresetObject* appleProRes4444Preset = [[PresetObject alloc] initWithTitle:@"Apple Pro Res 4444"
                                                                   audioSettings:[PresetAudioSettings none]
                                                                   videoSettings:appleProRes4444VideoSetting
                                                                analyzerSettings:[PresetAnalysisSettings none]
                                                                        useAudio:YES
                                                                        useVideo:YES
                                                                     useAnalysis:YES
                                                                        editable:NO];
       
        // 422 HQ
        PresetVideoSettings* appleProRes422HQVideoSetting = [[PresetVideoSettings alloc] init];
        appleProRes422HQVideoSetting.settingsDictionary = @{AVVideoCodecKey:@"apch"};
        
        PresetObject* appleProRes422HQPreset = [[PresetObject alloc] initWithTitle:@"Apple Pro Res 422 HQ"
                                                                                audioSettings:[PresetAudioSettings none]
                                                                                videoSettings:appleProRes422HQVideoSetting
                                                                             analyzerSettings:[PresetAnalysisSettings none]
                                                                                     useAudio:YES
                                                                                     useVideo:YES
                                                                                  useAnalysis:YES
                                                                                     editable:NO];

        
        // 422
        PresetVideoSettings* appleProRes422VideoSetting = [[PresetVideoSettings alloc] init];
        appleProRes422VideoSetting.settingsDictionary = @{AVVideoCodecKey:AVVideoCodecAppleProRes422};
        
        PresetObject* appleProRes422Preset = [[PresetObject alloc] initWithTitle:@"Apple Pro Res 422"
                                                                      audioSettings:[PresetAudioSettings none]
                                                                      videoSettings:appleProRes422VideoSetting
                                                                   analyzerSettings:[PresetAnalysisSettings none]
                                                                           useAudio:YES
                                                                           useVideo:YES
                                                                        useAnalysis:YES
                                                                           editable:NO];
        
        // 422 LT
        PresetVideoSettings* appleProRes422LTVideoSetting = [[PresetVideoSettings alloc] init];
        appleProRes422LTVideoSetting.settingsDictionary = @{AVVideoCodecKey:@"apcs"};
        
        PresetObject* appleProRes422LTPreset = [[PresetObject alloc] initWithTitle:@"Apple Pro Res 422 LT"
                                                                   audioSettings:[PresetAudioSettings none]
                                                                   videoSettings:appleProRes422LTVideoSetting
                                                                analyzerSettings:[PresetAnalysisSettings none]
                                                                        useAudio:YES
                                                                        useVideo:YES
                                                                     useAnalysis:YES
                                                                        editable:NO];

        // 422 Proxy
        PresetVideoSettings* appleProRes422ProxyVideoSetting = [[PresetVideoSettings alloc] init];
        appleProRes422ProxyVideoSetting.settingsDictionary = @{AVVideoCodecKey:@"apco"};
        
        PresetObject* appleProRes422ProxyPreset = [[PresetObject alloc] initWithTitle:@"Apple Pro Res 422 Proxy"
                                                                     audioSettings:[PresetAudioSettings none]
                                                                     videoSettings:appleProRes422ProxyVideoSetting
                                                                  analyzerSettings:[PresetAnalysisSettings none]
                                                                          useAudio:YES
                                                                          useVideo:YES
                                                                       useAnalysis:YES
                                                                          editable:NO];

        PresetGroup* proResGroup = [[PresetGroup alloc] initWithTitle:@"Pro Res" editable:NO];
        proResGroup.children = @[appleProRes4444Preset,
                                 appleProRes422HQPreset,
                                 appleProRes422Preset,
                                 appleProRes422LTPreset,
                                 appleProRes422ProxyPreset,
                                 ];
        
#pragma mark - Apple Intermediate
        
        PresetVideoSettings* appleIntermediateVideoSetting = [[PresetVideoSettings alloc] init];
        appleIntermediateVideoSetting.settingsDictionary = @{AVVideoCodecKey:@"icod"};
        
        PresetObject* appleIntermediatePreset = [[PresetObject alloc] initWithTitle:@"Apple Intermediate"
                                                                         audioSettings:[PresetAudioSettings none]
                                                                         videoSettings:appleIntermediateVideoSetting
                                                                      analyzerSettings:[PresetAnalysisSettings none]
                                                                              useAudio:YES
                                                                              useVideo:YES
                                                                           useAnalysis:YES
                                                                              editable:NO];

        PresetObject* appleIntermediatePresetNoAudio = [[PresetObject alloc] initWithTitle:@"Apple Intermediate - No Audio"
                                                                     audioSettings:[PresetAudioSettings none]
                                                                     videoSettings:appleIntermediateVideoSetting
                                                                  analyzerSettings:[PresetAnalysisSettings none]
                                                                          useAudio:NO
                                                                          useVideo:YES
                                                                       useAnalysis:YES
                                                                          editable:NO];
        
        PresetGroup* aicGroup = [[PresetGroup alloc] initWithTitle:@"Apple Intermediate Codec" editable:NO];
        aicGroup.children = @[appleIntermediatePreset,
                              appleIntermediatePresetNoAudio];
        
#pragma mark - Motion Jpeg
        
        PresetVideoSettings* photoJPEGVideoSetting = [[PresetVideoSettings alloc] init];
        photoJPEGVideoSetting.settingsDictionary = @{AVVideoCodecKey:AVVideoCodecJPEG};
        
        PresetObject* photoJPEGPreset = [[PresetObject alloc] initWithTitle:@"Photo JPEG"
                                                                      audioSettings:[PresetAudioSettings none]
                                                                      videoSettings:photoJPEGVideoSetting
                                                                   analyzerSettings:[PresetAnalysisSettings none]
                                                                           useAudio:YES
                                                                           useVideo:YES
                                                                        useAnalysis:YES
                                                                           editable:NO];
        
        PresetObject* photoJPEGPresetNoAudio = [[PresetObject alloc] initWithTitle:@"Photo JPEG - No Audio"
                                                               audioSettings:[PresetAudioSettings none]
                                                               videoSettings:photoJPEGVideoSetting
                                                            analyzerSettings:[PresetAnalysisSettings none]
                                                                    useAudio:NO
                                                                    useVideo:YES
                                                                 useAnalysis:YES
                                                                    editable:NO];

        PresetGroup* motionJPEGGroup = [[PresetGroup alloc] initWithTitle:@"Photo JPEG" editable:NO];
        motionJPEGGroup.children = @[photoJPEGPreset,
                                     photoJPEGPresetNoAudio];

#pragma mark - DV Family
        
        // DV NTSC
        PresetVideoSettings* dvNTSCVideoSetting = [[PresetVideoSettings alloc] init];
        dvNTSCVideoSetting.settingsDictionary = @{AVVideoCodecKey:@"dvc ",
                                                  AVVideoScalingModeKey : AVVideoScalingModeResizeAspect};
        
        PresetObject* dvNTSCPreset = [[PresetObject alloc] initWithTitle:@"DV NTSC (720x480)"
                                                              audioSettings:[PresetAudioSettings none]
                                                              videoSettings:dvNTSCVideoSetting
                                                           analyzerSettings:[PresetAnalysisSettings none]
                                                                   useAudio:YES
                                                                   useVideo:YES
                                                                useAnalysis:YES
                                                                   editable:NO];
       
        // DV NTSC
        PresetVideoSettings* dvPalVideoSetting = [[PresetVideoSettings alloc] init];
        dvPalVideoSetting.settingsDictionary = @{AVVideoCodecKey:@"dvcp",
                                                  AVVideoScalingModeKey : AVVideoScalingModeResizeAspect};
        
        PresetObject* dvPalPreset = [[PresetObject alloc] initWithTitle:@"DV PAL (720x576)"
                                                           audioSettings:[PresetAudioSettings none]
                                                           videoSettings:dvPalVideoSetting
                                                        analyzerSettings:[PresetAnalysisSettings none]
                                                                useAudio:YES
                                                                useVideo:YES
                                                             useAnalysis:YES
                                                                editable:NO];
        
        // DVCPro 50 NTSC
        PresetVideoSettings* dvcProNTSCVideoSetting = [[PresetVideoSettings alloc] init];
        dvcProNTSCVideoSetting.settingsDictionary = @{AVVideoCodecKey:@"dv5n",
                                                 AVVideoScalingModeKey : AVVideoScalingModeResizeAspect};
        
        PresetObject* dvcProNTSCPreset = [[PresetObject alloc] initWithTitle:@"DVCPro 50 NTSC (720x480)"
                                                          audioSettings:[PresetAudioSettings none]
                                                          videoSettings:dvcProNTSCVideoSetting
                                                       analyzerSettings:[PresetAnalysisSettings none]
                                                               useAudio:YES
                                                               useVideo:YES
                                                            useAnalysis:YES
                                                               editable:NO];
        
        // DVCPro 50 PAL
        PresetVideoSettings* dvcProPALVideoSetting = [[PresetVideoSettings alloc] init];
        dvcProPALVideoSetting.settingsDictionary = @{AVVideoCodecKey:@"dv5p",
                                                     AVVideoScalingModeKey : AVVideoScalingModeResizeAspect
                                                     };
        
        PresetObject* dvcProPALPreset = [[PresetObject alloc] initWithTitle:@"DVCPro 50 PAL (720x576)"
                                                              audioSettings:[PresetAudioSettings none]
                                                              videoSettings:dvcProPALVideoSetting
                                                           analyzerSettings:[PresetAnalysisSettings none]
                                                                   useAudio:YES
                                                                   useVideo:YES
                                                                useAnalysis:YES
                                                                   editable:NO];
       
        // For whatever reason, DVCPro codecs need size
        // Adjust for pixel aspect ratio
        // so output size is right.

        // DVC Pro HD 720p60
        PresetVideoSettings* dvcPro720p60VideoSetting = [[PresetVideoSettings alloc] init];
        dvcPro720p60VideoSetting.settingsDictionary = @{AVVideoCodecKey:@"dvhp",
                                                        AVVideoScalingModeKey : AVVideoScalingModeResizeAspect,
                                                        AVVideoWidthKey : @(960),
                                                        AVVideoHeightKey : @(720),
                                                        };
        
        PresetObject* dvcPro720p60Preset = [[PresetObject alloc] initWithTitle:@"DVCPro 720p60 (1280x720)"
                                                             audioSettings:[PresetAudioSettings none]
                                                             videoSettings:dvcPro720p60VideoSetting
                                                          analyzerSettings:[PresetAnalysisSettings none]
                                                                  useAudio:YES
                                                                  useVideo:YES
                                                               useAnalysis:YES
                                                                  editable:NO];

        // DVC Pro HD 720p50
        PresetVideoSettings* dvcPro720p50VideoSetting = [[PresetVideoSettings alloc] init];
        dvcPro720p50VideoSetting.settingsDictionary = @{AVVideoCodecKey:@"dvhq",
                                                        AVVideoScalingModeKey : AVVideoScalingModeResizeAspect,
                                                        AVVideoWidthKey : @(960),
                                                        AVVideoHeightKey : @(720),
                                                        };
        
        PresetObject* dvcPro720p50Preset = [[PresetObject alloc] initWithTitle:@"DVCPro 720p50 (1280x720)"
                                                                 audioSettings:[PresetAudioSettings none]
                                                                 videoSettings:dvcPro720p50VideoSetting
                                                              analyzerSettings:[PresetAnalysisSettings none]
                                                                      useAudio:YES
                                                                      useVideo:YES
                                                                   useAnalysis:YES
                                                                      editable:NO];

        // DVC Pro HD 1080i60
        PresetVideoSettings* dvcPro1080i60VideoSetting = [[PresetVideoSettings alloc] init];
        dvcPro1080i60VideoSetting.settingsDictionary = @{AVVideoCodecKey:@"dvh6",
                                                        AVVideoScalingModeKey : AVVideoScalingModeResizeAspect,
                                                        AVVideoWidthKey : @(1280),
                                                        AVVideoHeightKey : @(1080),
                                                        };
        
        PresetObject* dvcPro1080i60Preset = [[PresetObject alloc] initWithTitle:@"DVCPro 1080i60 (1920x1080)"
                                                                 audioSettings:[PresetAudioSettings none]
                                                                 videoSettings:dvcPro1080i60VideoSetting
                                                              analyzerSettings:[PresetAnalysisSettings none]
                                                                      useAudio:YES
                                                                      useVideo:YES
                                                                   useAnalysis:YES
                                                                      editable:NO];

        // DVC Pro HD 1080i50
        PresetVideoSettings* dvcPro1080i50VideoSetting = [[PresetVideoSettings alloc] init];
        dvcPro1080i50VideoSetting.settingsDictionary = @{AVVideoCodecKey:@"dvh5",
                                                         AVVideoScalingModeKey : AVVideoScalingModeResizeAspect,
                                                         AVVideoWidthKey : @(1280),
                                                         AVVideoHeightKey : @(1080),
                                                         };
        
        PresetObject* dvcPro1080i50Preset = [[PresetObject alloc] initWithTitle:@"DVCPro 1080i50 (1920x1080)"
                                                                  audioSettings:[PresetAudioSettings none]
                                                                  videoSettings:dvcPro1080i50VideoSetting
                                                               analyzerSettings:[PresetAnalysisSettings none]
                                                                       useAudio:YES
                                                                       useVideo:YES
                                                                    useAnalysis:YES
                                                                       editable:NO];

        // DVC Pro HD 1080p30
        PresetVideoSettings* dvcPro1080p30VideoSetting = [[PresetVideoSettings alloc] init];
        dvcPro1080p30VideoSetting.settingsDictionary = @{AVVideoCodecKey:@"dvh3",
                                                         AVVideoScalingModeKey : AVVideoScalingModeResizeAspect,
                                                         AVVideoWidthKey : @(1280),
                                                         AVVideoHeightKey : @(1080),
                                                         };
        
        PresetObject* dvcPro1080p30Preset = [[PresetObject alloc] initWithTitle:@"DVCPro 1080p30 (1920x1080)"
                                                                  audioSettings:[PresetAudioSettings none]
                                                                  videoSettings:dvcPro1080p30VideoSetting
                                                               analyzerSettings:[PresetAnalysisSettings none]
                                                                       useAudio:YES
                                                                       useVideo:YES
                                                                    useAnalysis:YES
                                                                       editable:NO];
 
        // DVC Pro HD 1080p25
        PresetVideoSettings* dvcPro1080p25VideoSetting = [[PresetVideoSettings alloc] init];
        dvcPro1080p25VideoSetting.settingsDictionary = @{AVVideoCodecKey:@"dvh3",
                                                         AVVideoScalingModeKey : AVVideoScalingModeResizeAspect,
                                                         AVVideoWidthKey : @(1280),
                                                         AVVideoHeightKey : @(1080),
                                                         };
        
        PresetObject* dvcPro1080p25Preset = [[PresetObject alloc] initWithTitle:@"DVCPro 1080p25 (1920x1080)"
                                                                  audioSettings:[PresetAudioSettings none]
                                                                  videoSettings:dvcPro1080p25VideoSetting
                                                               analyzerSettings:[PresetAnalysisSettings none]
                                                                       useAudio:YES
                                                                       useVideo:YES
                                                                    useAnalysis:YES
                                                                       editable:NO];

        PresetGroup* dvGroup = [[PresetGroup alloc] initWithTitle:@"DV" editable:NO];
        dvGroup.children = @[dvNTSCPreset,
                             dvPalPreset,
                             dvcProNTSCPreset,
                             dvcProPALPreset,
                             dvcPro720p60Preset,
                             dvcPro720p50Preset,
//                             dvcPro1080i60Preset,
//                             dvcPro1080i50Preset,
                             dvcPro1080p30Preset,
                             dvcPro1080p25Preset,
                             ];

#pragma mark - h.264
        

        PresetAudioSettings* aac48Khz = [[PresetAudioSettings alloc] init];
        aac48Khz.settingsDictionary = @{ AVFormatIDKey : @(kAudioFormatMPEG4AAC),
                                         AVSampleRateKey : @(48000.0),
                                         AVNumberOfChannelsKey : @(2),
                                         AVEncoderBitRateKey : @(256),
//                                         AVEncoderAudioQualityKey : @(AVAudioQualityHigh),
                                        };
        
        // h.264 Baseline Auto / AAC 48khz Stereo 256
        PresetVideoSettings* baseLineAutoLevelVideoSetting = [[PresetVideoSettings alloc] init];
        baseLineAutoLevelVideoSetting.settingsDictionary = @{AVVideoCodecKey : AVVideoCodecH264,

                                                             AVVideoCompressionPropertiesKey : @{
                                                                     AVVideoProfileLevelKey : AVVideoProfileLevelH264BaselineAutoLevel,
                                                             },
                                                             
                                                             AVVideoEncoderSpecificationKey : @{
                                                                     (NSString*)kVTVideoEncoderSpecification_EnableHardwareAcceleratedVideoEncoder : @YES,
                                                                     }
                                                             };

        PresetObject* baseLineAutoLevelPreset = [[PresetObject alloc] initWithTitle:@"h.264 Baseline Auto Level / Stereo AAC, 48Khz 240kbps"
                                                                  audioSettings:aac48Khz
                                                                  videoSettings:baseLineAutoLevelVideoSetting
                                                               analyzerSettings:[PresetAnalysisSettings none]
                                                                       useAudio:YES
                                                                       useVideo:YES
                                                                    useAnalysis:YES
                                                                       editable:NO];
       
        // h.264 Main Auto / AAC 48khz Stereo 256
        PresetVideoSettings* mainAutoLevelVideoSetting = [[PresetVideoSettings alloc] init];
        mainAutoLevelVideoSetting.settingsDictionary = @{AVVideoCodecKey : AVVideoCodecH264,
                                                         AVVideoCompressionPropertiesKey : @{
                                                                 AVVideoProfileLevelKey : AVVideoProfileLevelH264BaselineAutoLevel,
                                                                 },
                                                         AVVideoEncoderSpecificationKey : @{
                                                                 (NSString*)kVTVideoEncoderSpecification_EnableHardwareAcceleratedVideoEncoder : @YES,
                                                                 }
                                                         };
        
        PresetObject* mainAutoLevelPreset = [[PresetObject alloc] initWithTitle:@"h.264 Main Auto Level / Stereo AAC, 48Khz 240kbps"
                                                                      audioSettings:aac48Khz
                                                                      videoSettings:mainAutoLevelVideoSetting
                                                                   analyzerSettings:[PresetAnalysisSettings none]
                                                                           useAudio:YES
                                                                           useVideo:YES
                                                                        useAnalysis:YES
                                                                           editable:NO];

        // h.264 Main Auto / AAC 48khz Stereo 256
        PresetVideoSettings* highAutoLevelVideoSetting = [[PresetVideoSettings alloc] init];
        highAutoLevelVideoSetting.settingsDictionary = @{AVVideoCodecKey : AVVideoCodecH264,
                                                         AVVideoCompressionPropertiesKey : @{
                                                                 AVVideoProfileLevelKey : AVVideoProfileLevelH264BaselineAutoLevel,
                                                                 },
                                                         AVVideoEncoderSpecificationKey : @{
                                                                 (NSString*)kVTVideoEncoderSpecification_EnableHardwareAcceleratedVideoEncoder : @YES,
                                                                 }
                                                         };
        
        PresetObject* highAutoLevelPreset = [[PresetObject alloc] initWithTitle:@"h.264 High Auto Level / Stereo AAC, 48Khz 240kbps"
                                                                  audioSettings:aac48Khz
                                                                  videoSettings:highAutoLevelVideoSetting
                                                               analyzerSettings:[PresetAnalysisSettings none]
                                                                       useAudio:YES
                                                                       useVideo:YES
                                                                    useAnalysis:YES
                                                                       editable:NO];

        
        PresetGroup* h264Group = [[PresetGroup alloc] initWithTitle:@"h.264" editable:NO];
        h264Group.children = @[
                             baseLineAutoLevelPreset,
                             mainAutoLevelPreset,
                             highAutoLevelPreset
                             ];

        
#pragma mark - HEVC
        
        self.standardPresets.children = @[passthroughGroup,
                                          uncompressedGroup,
                                          hapGroup,
//                                          animationGroup,
                                          proResGroup,
                                          aicGroup,
                                          motionJPEGGroup,
                                          dvGroup,
                                          h264Group,
                                          ];

        self.selectedPresetGroup = self.customPresets;
        
        return self;
    }
    
    return nil;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.stupidFuckingSplitview.delegate = self;
    
    self.presetOutlineView.dataSource = self;
    self.presetOutlineView.delegate = self;

    [self initPrefs];
}

#pragma mark -

- (void) initPrefs
{
    [self initVideoPrefs];
    [self initAudioPrefs];
}

- (void) initVideoPrefs
{
    [self.prefsVideoCompressor removeAllItems];
    [self.prefsVideoDimensions removeAllItems];
    [self.prefsVideoQuality removeAllItems];
    [self.prefsVideoAspectRatio removeAllItems];
    
    // Video Prefs Encoders
    
    VTRegisterProfessionalVideoWorkflowVideoDecoders();
    VTRegisterProfessionalVideoWorkflowVideoEncoders();
        
    CFArrayRef videoEncoders;
    VTCopyVideoEncoderList(NULL, &videoEncoders);
    NSArray* videoEncodersArray = (__bridge NSArray*)videoEncoders;
    
    NSMutableArray* encoderArrayWithTitles = [NSMutableArray arrayWithCapacity:videoEncodersArray.count + 2];

    [encoderArrayWithTitles addObject: @{title : @"Passthrough", value :[NSNull null] }];
    [encoderArrayWithTitles addObject: @{title : @"Seperator", value : @"Seperator" }];
    
    for(NSDictionary* encoder in videoEncodersArray)
    {
        NSNumber* codecType = encoder[@"CodecType"];
        FourCharCode fourcc = (FourCharCode)[codecType intValue];
        NSString* fourCCString = NSFileTypeForHFSTypeCode(fourcc);
        
        // remove ' so "'jpeg'" becomes "jpeg" for example
        fourCCString = [fourCCString stringByReplacingOccurrencesOfString:@"'" withString:@""];

        [encoderArrayWithTitles addObject:@{title:encoder[@"DisplayName"], value:fourCCString}];
    }

    // Add HAP Codecs manually
    [encoderArrayWithTitles addObject:@{ title : @"HAP", value : AVVideoCodecHap}];
    [encoderArrayWithTitles addObject:@{ title : @"HAP Alpha", value :AVVideoCodecHapAlpha}];
    [encoderArrayWithTitles addObject:@{ title : @"HAP Q", value : AVVideoCodecHapQ}];
    [encoderArrayWithTitles addObject:@{ title : @"HAP Q Alpha", value : AVVideoCodecHapQAlpha}];
//    [encoderArrayWithTitles addObject:@{ title : @"HAP Alpha", value : @"HapA"}];
    
    //    NSDictionary* animationDictionary = @{ title : @"MPEG4 Video" , value: @{ @"CodecType" : [NSNumber numberWithInt:kCMVideoCodecType_MPEG4Video]}};
    //    [encoderArrayWithTitles addObject: animationDictionary];
    
    [self addMenuItemsToMenu:self.prefsVideoCompressor.menu withArray:encoderArrayWithTitles withSelector:@selector(selectVideoEncoder:)];
    
    // Video Prefs Resolution    
    self.videoResolutions = @[
                              @{title : @"Native", value : [NSValue valueWithSize:NSZeroSize] },
                              @{title : @"Seperator", value : @"Seperator" },
                              @{title : @"640 x 480 (NTSC)", value : [NSValue valueWithSize:(NSSize){640.0, 480.0}] },
                              @{title : @"768 x 576 (PAL)", value : [NSValue valueWithSize:(NSSize){786.0, 576.0}] },
                              @{title : @"720 x 480 (480p)", value : [NSValue valueWithSize:(NSSize){720.0, 480.0}] },
                              @{title : @"720 x 576 (576p)", value : [NSValue valueWithSize:(NSSize){720.0, 576.0}] },
                              @{title : @"1280 x 720 (720p)", value : [NSValue valueWithSize:(NSSize){1280.0, 720.0}] },
                              @{title : @"1920 x 1080 (1080p)", value : [NSValue valueWithSize:(NSSize){1920.0, 1080.0}] },
                              @{title : @"2048 × 1080 (2k)", value : [NSValue valueWithSize:(NSSize){2048.0, 1080.0}] },
                              @{title : @"2048 × 858 (2k Cinemascope)", value : [NSValue valueWithSize:(NSSize){2048.0, 858.0}] },
                              @{title : @"3840 × 2160 (UHD)", value : [NSValue valueWithSize:(NSSize){3840.0, 2160.0}] },
                              @{title : @"4096 × 2160 (4k)", value : [NSValue valueWithSize:(NSSize){4096.0, 2160.0}] },
                              @{title : @"4096 × 1716 (4k Cinemascope)", value : [NSValue valueWithSize:(NSSize){4096.0, 1716.0}] },
                              @{title : @"Seperator", value : @"Seperator" },
                              @{title : @"Custom", value : [NSNull null] },
                              ];
    
    [self addMenuItemsToMenu:self.prefsVideoDimensions.menu withArray:self.videoResolutions withSelector:@selector(selectVideoResolution:)];

    // Video Prefs Quality
    NSArray* qualityArray = @[
                              @{title : @"Not Applicable", value : [NSNull null] },
                              @{title : @"Seperator", value : @"Seperator" },
                              @{title : @"Minimum", value : @0.0} ,
                              @{title : @"Low", value : @0.25},
                              @{title : @"Normal", value : @0.5},
                              @{title : @"High", value : @0.75},
                              @{title : @"Maximum", value : @1.0}
                              ];
    
    [self addMenuItemsToMenu:self.prefsVideoQuality.menu withArray:qualityArray withSelector:@selector(selectVideoQuality:)];
    
    // Video Prefs Aspect Ratio
    // AVVideoScalingModeKey
    NSArray* aspectArray = @[
                             @{title : @"Native", value : [NSNull null] },
                             @{title : @"Seperator", value : @"Seperator" },
                             @{title : @"Aspect Fill", value : AVVideoScalingModeResizeAspectFill},
                             @{title : @"Aspect Fit", value : AVVideoScalingModeResizeAspect},
                             @{title : @"Resize", value : AVVideoScalingModeResize},
                             ];
    
    [self addMenuItemsToMenu:self.prefsVideoAspectRatio.menu withArray:aspectArray withSelector:@selector(selectVideoAspectRatio:)];
    
    [self validateVideoPrefsUI];
    [self buildVideoPreferences];
}

- (void) initAudioPrefs
{
    [self.prefsAudioFormat removeAllItems];
    [self.prefsAudioRate removeAllItems];
    [self.prefsAudioQuality removeAllItems];
    [self.prefsAudioBitrate removeAllItems];
    
    // Audio Prefs Format
    NSArray* formatArray = @[
                             @{title : @"Passthrough", value :[NSNull null] },
                             @{title : @"Seperator", value : @"Seperator" },
                             @{title : @"LinearPCM", value : @(kAudioFormatLinearPCM)} ,
                             @{title : @"Apple Lossless", value : @(kAudioFormatAppleLossless)},
                             @{title : @"AAC", value : @(kAudioFormatMPEG4AAC)},
                             //                             @{title : @"MP3", value : @(kAudioFormatMPEGLayer3)},
                             ];
    
    [self addMenuItemsToMenu:self.prefsAudioFormat.menu withArray:formatArray withSelector:@selector(selectAudioFormat:)];
    
    // Audio Prefs Rate
    NSArray* rateArray = @[
                           @{title : @"Recommended", value : [NSNull null]},
                           @{title : @"Seperator", value : @"Seperator" },
                           @{title : @"16.000 Khz", value : @(16000.0)},
                           @{title : @"22.050 Khz", value : @(22050.0)},
                           @{title : @"24.000 Khz", value : @(24000.0)},
                           @{title : @"32.000 Khz", value : @(32000.0)},
                           @{title : @"44.100 Khz", value : @(44100.0)},
                           @{title : @"48.000 Khz", value : @(48000.0)},
                           @{title : @"88.200 Khz", value : @(88200.0)},
                           @{title : @"96.000 Khz", value : @(960000.0)},
                           ];
    
    [self addMenuItemsToMenu:self.prefsAudioRate.menu withArray:rateArray withSelector:@selector(selectAudioSamplerate:)];
    
    // Audio Prefs Quality
    
    NSArray* qualityArray = @[
                              @{title : @"Minimum", value : @(AVAudioQualityMin)} ,
                              @{title : @"Low", value : @(AVAudioQualityLow)},
                              @{title : @"Normal", value : @(AVAudioQualityMedium)},
                              @{title : @"High", value : @(AVAudioQualityHigh)},
                              @{title : @"Maximum", value : @(AVAudioQualityMax)}
                              ];
    
    [self addMenuItemsToMenu:self.prefsAudioQuality.menu withArray:qualityArray withSelector:@selector(selectAudioQuality:)];
    
    // Audio Prefs Bitrate
    NSArray* bitRateArray = @[
                              @{title : @"Recommended", value : [NSNull null]},
                              @{title : @"Seperator", value : @"Seperator" },
                              @{title : @"16 Kbps", value : @(16000)},
                              @{title : @"24 Kbps", value : @(24000)},
                              @{title : @"32 Kbps", value : @(32000)},
                              @{title : @"48 Kbps", value : @(38000)},
                              @{title : @"64 Kbps", value : @(64000)},
                              @{title : @"80 Kbps", value : @(80000)},
                              @{title : @"96 Kbps", value : @(96000)},
                              @{title : @"112 Kbps", value : @(112000)},
                              @{title : @"128 Kbps", value : @(128000)},
                              @{title : @"160 Kbps", value : @(160000)},
                              @{title : @"192 Kbps", value : @(192000)},
                              @{title : @"224 Kbps", value : @(224000)},
                              @{title : @"256 Kbps", value : @(256000)},
                              @{title : @"320 Kbps", value : @(320000)},
                              ];
    
    [self addMenuItemsToMenu:self.prefsAudioBitrate.menu withArray:bitRateArray withSelector:@selector(selectAudioBitrate:)];
}

#pragma mark - Prefs Helpers

- (void) addMenuItemsToMenu:(NSMenu*)aMenu withArray:(NSArray*)array withSelector:(SEL)selector
{
    for(NSDictionary* item in array)
    {
        if([item[title] isEqualToString:@"Seperator"])
        {
            [aMenu addItem:[NSMenuItem separatorItem]];
        }
        else
        {
            NSMenuItem* menuItem = [[NSMenuItem alloc] initWithTitle:item[title] action:selector keyEquivalent:@""];
            [menuItem setRepresentedObject:item[value]];
            [aMenu addItem:menuItem];
        }
    }
}

#pragma mark - Video Prefs Actions

- (IBAction)selectVideoEncoder:(id)sender
{
    NSLog(@"selected Video Encoder: %@", [sender representedObject]);
    
    // If we are on passthrough encoder, then we disable all our options
    if(self.prefsVideoCompressor.selectedItem.representedObject == [NSNull null])
    {
        // disable other ui
        self.prefsVideoAspectRatio.enabled = NO;
        [self.prefsVideoAspectRatio selectItemAtIndex:0];
        
        self.prefsVideoDimensions.enabled = NO;
        [self.prefsVideoDimensions selectItemAtIndex:0];
        
        self.prefsVideoQuality.enabled = NO;
        [self.prefsVideoQuality selectItemAtIndex:0];
        
        self.prefsVideoDimensionsCustomHeight.enabled = NO;
        self.prefsVideoDimensionsCustomHeight.stringValue = @"";
        
        self.prefsVideoDimensionsCustomWidth.enabled = NO;
        self.prefsVideoDimensionsCustomWidth.stringValue = @"";
    }
    else
    {
        if(self.selectedPreset.editable)
            self.prefsVideoDimensions.enabled = YES;
        
        // If we are on JPEG, enable quality
        NSString* codecFourCC = self.prefsVideoCompressor.selectedItem.representedObject;
        if( [codecFourCC isEqualToString:@"JPEG"])
        {
            if(self.selectedPreset.editable)
                self.prefsVideoQuality.enabled = YES;
            [self.prefsVideoQuality selectItemAtIndex:4];
        }
        else
        {
            self.prefsVideoQuality.enabled = NO;
            [self.prefsVideoQuality selectItemAtIndex:0];
        }
    }
    
    
//    [self validateVideoPrefsUI];
    [self buildVideoPreferences];
}

- (IBAction)selectVideoResolution:(id)sender
{
    NSLog(@"selected Video Resolution: %@", [sender representedObject]);
    
    // If we are on the first (Native) resolution
    if (self.prefsVideoDimensions.indexOfSelectedItem == 0)
    {
        [self.prefsVideoAspectRatio selectItemAtIndex:0];
        // Enable 'Native'
        [[self.prefsVideoAspectRatio itemAtIndex:0] setEnabled:YES];
        self.prefsVideoAspectRatio.enabled = NO;
    }
    else
    {
        // Disable the native aspect ratio choice, and select aspect fill by default
        self.prefsVideoAspectRatio.enabled = YES;
        // Disable 'Native'
        [[self.prefsVideoAspectRatio itemAtIndex:0] setEnabled:NO];
        [self.prefsVideoAspectRatio selectItemAtIndex:2];
    }
    
    // if our video resolution is custom
    if(self.prefsVideoDimensions.selectedItem.representedObject == [NSNull null])
    {
        self.prefsVideoDimensionsCustomWidth.enabled = YES;
        self.prefsVideoDimensionsCustomHeight.enabled = YES;
    }
    else
    {
        // Update the custom size UI with the appropriate values
        NSSize selectedSize = [self.prefsVideoDimensions.selectedItem.representedObject sizeValue];
        self.prefsVideoDimensionsCustomWidth.floatValue = selectedSize.width;
        self.prefsVideoDimensionsCustomHeight.floatValue = selectedSize.height;
        
        self.prefsVideoDimensionsCustomWidth.enabled = NO;
        self.prefsVideoDimensionsCustomHeight.enabled = NO;
    }
    
//    [self validateVideoPrefsUI];
    [self buildVideoPreferences];
}

- (IBAction)selectVideoQuality:(id)sender
{
    NSLog(@"selected Video Quality: %@", [sender representedObject]);
    
//    [self validateVideoPrefsUI];
    [self buildVideoPreferences];
}

- (IBAction)selectVideoAspectRatio:(id)sender
{
    NSLog(@"selected Video Quality: %@", [sender representedObject]);
    
//    [self validateVideoPrefsUI];
    [self buildVideoPreferences];
}

#pragma mark - Video Prefs Validation

- (void) validateVideoPrefsUI
{
    // update UI / hack since we dont have validator code yet
    [self selectVideoEncoder:self.prefsVideoCompressor.selectedItem];
}

- (void) buildVideoPreferences
{
    NSMutableDictionary* videoSettingsDictonary = [NSMutableDictionary new];
    
    // get our fourcc from our compressor UI represented object and convert it to a string
    id compressorFourCC = self.prefsVideoCompressor.selectedItem.representedObject;
    
    // If we are passthrough, we set out video prefs to nil and bail early
    if(compressorFourCC == [NSNull null] || compressorFourCC == nil)
    {
        self.selectedPreset.videoSettings = nil;
        return;
    }
    
    // Otherwise introspect our codec dictionary
    if([compressorFourCC isKindOfClass:[NSString class]])
    {
        
        videoSettingsDictonary[AVVideoCodecKey] = compressorFourCC;
    }
    // if we have a dimension, custom or other wise, get it
    id sizeValue = self.prefsVideoDimensions.selectedItem.representedObject;
    
    // Custom Size for NULL entry
    if(sizeValue == [NSNull null])
    {
        videoSettingsDictonary[AVVideoWidthKey] =  @(self.prefsVideoDimensionsCustomWidth.floatValue);
        videoSettingsDictonary[AVVideoHeightKey] =  @(self.prefsVideoDimensionsCustomHeight.floatValue);
        
        // If we have a non native size, we need the aspect key
        videoSettingsDictonary[AVVideoScalingModeKey] = self.prefsVideoAspectRatio.selectedItem.representedObject;
    }
    else if([sizeValue isKindOfClass:[NSValue class]])
    {
        NSSize videoSize = [self.prefsVideoDimensions.selectedItem.representedObject sizeValue];
        
        // Native size for NSZeroSize
        if(!NSEqualSizes(videoSize, NSZeroSize))
        {
            videoSettingsDictonary[AVVideoWidthKey] =  @(videoSize.width);
            videoSettingsDictonary[AVVideoHeightKey] =  @(videoSize.height);
            
            // If we have a non native size, we need the aspect key
            videoSettingsDictonary[AVVideoScalingModeKey] = self.prefsVideoAspectRatio.selectedItem.representedObject;
        }
    }
    
    // if we have a quality, get it,
    id qualityValue = self.prefsVideoQuality.selectedItem.representedObject;
    
    if(qualityValue != [NSNull null])
    {
        if([qualityValue isKindOfClass:[NSNumber class]])
        {
            NSDictionary* videoCompressionOptionsDictionary = @{AVVideoQualityKey : qualityValue};
            videoSettingsDictonary[AVVideoCompressionPropertiesKey] =  videoCompressionOptionsDictionary;
        }
    }
    
    self.selectedPreset.videoSettings = [PresetVideoSettings settingsWithDict:videoSettingsDictonary];
    
    NSLog(@"Calculated Video Settings : %@", self.selectedPreset.videoSettings.settingsDictionary);
}

#pragma mark - Audio Prefs Actions


- (IBAction)selectAudioFormat:(id)sender
{
    NSLog(@"selected Audio Format: %@", [sender representedObject]);
    
    // If we are on passthrough encoder, then we disable all our options
    if(self.prefsAudioFormat.selectedItem.representedObject == [NSNull null])
    {
        // disable other ui
        self.prefsAudioBitrate.enabled = NO;
        [self.prefsAudioBitrate selectItemAtIndex:0];
        
        self.prefsAudioQuality.enabled = NO;
        [self.prefsAudioQuality selectItemAtIndex:0];
        
        self.prefsAudioRate.enabled = NO;
        [self.prefsAudioRate selectItemAtIndex:0];
    }
    else
    {
        // if we have linear linear PCM (uncompressed) we dont enable bitrate / quality
        
        if([self.prefsAudioFormat.selectedItem.representedObject isEqual: @(kAudioFormatLinearPCM)])
        {
            self.prefsAudioBitrate.enabled = NO;
            self.prefsAudioQuality.enabled = NO;
            self.prefsAudioRate.enabled = YES;
        }
        else
        {
            self.prefsAudioBitrate.enabled = YES;
            self.prefsAudioQuality.enabled = YES;
            self.prefsAudioRate.enabled = YES;
        }
    }
    
//    [self validateAudioPrefsUI];
    [self buildAudioPreferences];
}

- (IBAction)selectAudioSamplerate:(id)sender
{
    NSLog(@"selected Audio Sampleate: %@", [sender representedObject]);
//    [self validateAudioPrefsUI];
    [self buildAudioPreferences];
}

- (IBAction)selectAudioQuality:(id)sender
{
    NSLog(@"selected Audio Quality: %@", [sender representedObject]);
//    [self validateAudioPrefsUI];
    [self buildAudioPreferences];
}

- (IBAction)selectAudioBitrate:(id)sender
{
    NSLog(@"selected Audio Bitrate: %@", [sender representedObject]);
//    [self validateAudioPrefsUI];
    [self buildAudioPreferences];
}

#pragma mark - Audio Prefs

- (void) validateAudioPrefsUI
{
    // update UI / hack since we dont have validator code yet
    [self selectAudioFormat:self.prefsAudioFormat.selectedItem];
}


// Todo: Number of channels?
- (void) buildAudioPreferences
{
    NSMutableDictionary* audioSettingsDictonary = [NSMutableDictionary new];
    
    // get our fourcc from our compressor UI represented object and convert it to a string
    id audioFormat = self.prefsAudioFormat.selectedItem.representedObject;
    
    // If we are passthrough, we set out video prefs to nil and bail early
    if(audioFormat == [NSNull null] || audioFormat == nil)
    {
        self.selectedPreset.audioSettings = nil;
        return;
    }
    
    // Standard keys
    audioSettingsDictonary[AVFormatIDKey] = audioFormat;
    audioSettingsDictonary[AVSampleRateKey] = self.prefsAudioRate.selectedItem.representedObject;
    
    // for now, we let our encoder match source - this is handled in our transcoder
    audioSettingsDictonary[AVNumberOfChannelsKey] = [NSNull null];
    
    switch ([audioFormat intValue])
    {
        case kAudioFormatLinearPCM:
        {
            // Add LinearPCM required keys
            audioSettingsDictonary[AVLinearPCMBitDepthKey] = @(16);
            audioSettingsDictonary[AVLinearPCMIsBigEndianKey] = @(NO);
            audioSettingsDictonary[AVLinearPCMIsFloatKey] = @(NO);
            audioSettingsDictonary[AVLinearPCMIsNonInterleavedKey] = @(NO);
            
            break;
        }
        case kAudioFormatAppleLossless:
        case kAudioFormatMPEG4AAC:
        {
            // audioSettingsDictonary[AVEncoderAudioQualityKey] = self.prefsAudioQuality.selectedItem.representedObject;
            audioSettingsDictonary[AVEncoderBitRateKey] = self.prefsAudioBitrate.selectedItem.representedObject;
            audioSettingsDictonary[AVSampleRateConverterAlgorithmKey] = AVSampleRateConverterAlgorithm_Normal;
            audioSettingsDictonary[AVEncoderBitRateStrategyKey] = AVAudioBitRateStrategy_Constant;
            
        }
        default:
            break;
    }
    
    self.selectedPreset.audioSettings = [PresetAudioSettings settingsWithDict:audioSettingsDictonary];
    
    NSLog(@"Calculated Audio Settings : %@", self.selectedPreset.audioSettings.settingsDictionary);
}

#pragma mark - SplitView Delegate

- (CGFloat)splitView:(NSSplitView *)splitView constrainMinCoordinate:(CGFloat)proposedMin ofSubviewAt:(NSInteger)dividerIndex
{
    return 200;
}

- (CGFloat)splitView:(NSSplitView *)splitView constrainMaxCoordinate:(CGFloat)proposedMin ofSubviewAt:(NSInteger)dividerIndex
{
    return 400;
}


#pragma mark - Outline View Delegate

- (NSView *)outlineView:(NSOutlineView *)outlineView viewForTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
    NSTableCellView* view = (NSTableCellView*)[outlineView makeViewWithIdentifier:@"Preset" owner:self];
    
    if([item isKindOfClass:[PresetGroup class]])
    {
        PresetGroup* itemGroup = (PresetGroup*)item;
        view.objectValue = itemGroup;
        view.textField.stringValue = itemGroup.title;
        view.textField.editable = itemGroup.editable;
        view.textField.selectable = itemGroup.editable;
        view.imageView.image = [NSImage imageNamed:@"ic_folder_white"];
    }
    else if ([item isKindOfClass:[PresetObject class]])
    {
        PresetObject* presetItem = (PresetObject*)item;
        view.objectValue = presetItem;
        view.textField.stringValue = presetItem.title;
        view.textField.editable = presetItem.editable;
        view.textField.selectable = presetItem.editable;
        view.imageView.image = [NSImage imageNamed:@"ic_insert_drive_file_white"];
    }
    else if([item isKindOfClass:[PresetAudioSettings class]])
    {
        view.textField.editable = NO;
        view.textField.selectable = NO;

        view.textField.stringValue = @"Audio Settings";
        view.imageView.image = [NSImage imageNamed:@"ic_volume_up_white"];
    }
    
    else if([item isKindOfClass:[PresetVideoSettings class]])
    {
        view.textField.editable = NO;
        view.textField.selectable = NO;
        
        view.textField.stringValue = @"Video Settings";
        view.imageView.image = [NSImage imageNamed:@"ic_local_movies_white"];
    }
    else if([item isKindOfClass:[PresetAnalysisSettings class]])
    {
        view.textField.editable = NO;
        view.textField.selectable = NO;
        
        view.textField.stringValue = @"Analysis Settings";
        view.imageView.image = [NSImage imageNamed:@"ic_info_white"];
    }
    
    return view;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldSelectItem:(id)item
{
//    [self.videoContainerView removeFromSuperview];
//    [self.audioContainerView removeFromSuperview];
//    [self.analysisContainerView removeFromSuperview];
    [self.overviewContainerView removeFromSuperview];
    
    if([item isKindOfClass:[PresetGroup class]])
    {
        PresetGroup* itemGroup = (PresetGroup*)item;
        if(itemGroup.editable)
        {
            self.selectedPresetGroup = item;
        }
        else
        {
            self.selectedPresetGroup = self.customPresets;
        }
        
        self.selectedPreset = nil;

        return YES;
    }

    if([item isKindOfClass:[PresetObject class]])
    {
        self.overviewContainerView.frame = self.presetInfoContainerBox.bounds;
        [self.presetInfoContainerBox setContentView:self.overviewContainerView];
        
        self.selectedPresetGroup = [self.presetOutlineView parentForItem:item];

        [self configureOverviewContainerViewFromPreset:(PresetObject*)item];
        
        
        return YES;
    }

//    if([item isKindOfClass:[PresetAudioSettings class]])
//    {
//        self.selectedPreset = [self.presetOutlineView parentForItem:item];
//        self.selectedPresetGroup = [self.presetOutlineView parentForItem:self.selectedPreset];
//
//        [self.presetInfoContainerBox addSubview:self.audioContainerView];
//        self.audioContainerView.frame = self.presetInfoContainerBox.bounds;
//        
//        [self configureAudioSettingsFromPreset:self.selectedPreset];
//
//        return YES;
//    }
//    
//    if([item isKindOfClass:[PresetVideoSettings class]])
//    {
//        self.selectedPreset = [self.presetOutlineView parentForItem:item];
//        self.selectedPresetGroup = [self.presetOutlineView parentForItem:self.selectedPreset];
//        
//        [self.presetInfoContainerBox addSubview:self.videoContainerView];
//        self.videoContainerView.frame = self.presetInfoContainerBox.bounds;
//        
//        [self configureVideoSettingsFromPreset:self.selectedPreset];
//        
//        return YES;
//    }
//    
//    if([item isKindOfClass:[PresetAnalysisSettings class]])
//    {
//        self.selectedPreset = [self.presetOutlineView parentForItem:item];
//        self.selectedPresetGroup = [self.presetOutlineView parentForItem:self.selectedPreset];
//        
//        [self.presetInfoContainerBox addSubview:self.analysisContainerView];
//        self.analysisContainerView.frame = self.presetInfoContainerBox.bounds;
//        
//        [self configureAnalysisSettingsFromPreset:self.selectedPreset];
//        
//        return YES;
//    }
//    
    return NO;
}

#pragma mark - Outline View Data Source

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item
{
    // if item is nil, its our "root" item
    // we have 2 sources, built in and custom presets
    if(item == nil)
    {
        return 2;
    }
    else if([item isKindOfClass:[PresetGroup class]])
    {
        PresetGroup* itemGroup = (PresetGroup*)item;
        return itemGroup.children.count;
    }
    else if ([item isKindOfClass:[PresetObject class]])
    {
        // audio, video, analysis
        return 0; //3
    }
  
    return 0;
}

- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(id)item
{
    // root item
    if(item == nil)
    {
        if (index == 0)
        {
            return self.standardPresets;
        }
        if(index == 1)
        {
            return self.customPresets;
        }
    }
    
    else if([item isKindOfClass:[PresetGroup class]])
    {
        PresetGroup* itemGroup = (PresetGroup*)item;
        return itemGroup.children[index];
    }
    
//    else if ([item isKindOfClass:[PresetObject class]])
//    {
//        // return an NSNumber object that is the index
//        // 0 = audio, 1 = video, 2 = analysis;
//        
//        PresetObject* presetItem = (PresetObject*)item;
//        switch (index) {
//            case 0:
//                return presetItem.audioSettings;
//            case 1:
//                return presetItem.videoSettings;
//            case 2:
//                return presetItem.analyzerSettings;
//        }
//    }
    return nil;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item
{
    if(item == nil || [item isKindOfClass:[PresetGroup class]] )//|| [item isKindOfClass:[PresetObject class]])
        return YES;
    
    return NO;
}

#pragma mark - Presets

- (NSArray*) allPresets
{
    return [[self.standardPresets.children arrayByAddingObjectsFromArray:self.customPresets.children] copy];
}

- (IBAction)addPresetGroup:(id)sender
{
    PresetGroup* new = [[PresetGroup alloc] initWithTitle:@"New Group" editable:YES];
    
    NSArray* newChildren = [[self.selectedPresetGroup children] arrayByAddingObject:new];
    
    self.selectedPresetGroup.children = newChildren;
    
    [self.presetOutlineView reloadData];
}

- (IBAction)addPreset:(id)sender
{
    PresetObject* new = [[PresetObject alloc] initWithTitle:@"Unititled" audioSettings:[PresetAudioSettings none] videoSettings:[PresetVideoSettings none] analyzerSettings:[PresetAnalysisSettings none] useAudio:YES useVideo:YES useAnalysis:YES editable:YES];
    
    NSArray* newChildren = [[self.selectedPresetGroup children] arrayByAddingObject:new];
    
    self.selectedPresetGroup.children = newChildren;
    
    [self.presetOutlineView reloadData];
}

- (void) configureOverviewContainerViewFromPreset:(PresetObject*)preset
{
    self.selectedPreset = preset;
    
    self.overviewDescriptionTextField.stringValue = self.selectedPreset.description;
    
    [self configureAudioSettingsFromPreset:self.selectedPreset];
    [self configureVideoSettingsFromPreset:self.selectedPreset];
    [self configureAnalysisSettingsFromPreset:self.selectedPreset];
    
    [self validateVideoPrefsUI];
    [self validateAudioPrefsUI];
}

- (void) configureAudioSettingsFromPreset:(PresetObject*)preset
{
    // configure editability:
    self.useAudioCheckButton.enabled = preset.editable;
    self.prefsAudioFormat.enabled = preset.editable;
    self.prefsAudioBitrate.enabled = preset.editable;
    self.prefsAudioQuality.enabled = preset.editable;
    self.prefsAudioRate.enabled = preset.editable;

    // set values
//    self.prefsAudioFormat
}

- (void) configureVideoSettingsFromPreset:(PresetObject*)preset
{
    // configure editability:
    self.useVideoCheckButton.enabled = preset.editable;
    self.prefsVideoCompressor.enabled = preset.editable;
    self.prefsVideoDimensions.enabled = preset.editable;
    self.prefsVideoDimensionsCustomWidth.stringValue = @"";
    self.prefsVideoDimensionsCustomHeight.stringValue = @"";
    self.prefsVideoDimensionsCustomWidth.enabled = preset.editable;
    self.prefsVideoDimensionsCustomHeight.enabled = preset.editable;
    self.prefsVideoQuality.enabled = preset.editable;
    self.prefsVideoAspectRatio.enabled = preset.editable;
    
    if(preset.videoSettings.settingsDictionary)
    {
        // Codec
        if(preset.videoSettings.settingsDictionary[AVVideoCodecKey])
        {
            NSInteger index = [self.prefsVideoCompressor indexOfItemWithRepresentedObject:preset.videoSettings.settingsDictionary[AVVideoCodecKey]];
            if(index > 0)
                [self.prefsVideoCompressor selectItemAtIndex:index];
            else
                [self.prefsVideoCompressor selectItemAtIndex:0];
        }
        else
            [self.prefsVideoCompressor selectItemAtIndex:0];

        // Size
        if(preset.videoSettings.settingsDictionary[AVVideoWidthKey]
           && preset.videoSettings.settingsDictionary[AVVideoHeightKey])
        {
            float width = [preset.videoSettings.settingsDictionary[AVVideoWidthKey] floatValue];
            float height = [preset.videoSettings.settingsDictionary[AVVideoHeightKey] floatValue];
            
            NSSize presetSize = NSMakeSize(width, height);

            if(!NSEqualSizes(presetSize, NSZeroSize))
            {
                NSValue* sizeValue = [NSValue valueWithSize:presetSize];
                
                NSInteger index = [self.prefsVideoDimensions indexOfItemWithRepresentedObject:sizeValue];
                
                if(index > 0)
                    [self.prefsVideoDimensions selectItemAtIndex:index];
                // Custom size
                else
                {
                    [self.prefsVideoDimensions selectItemAtIndex:[self.prefsVideoDimensions itemArray].count - 1];
                    self.prefsVideoDimensionsCustomWidth.stringValue = [NSString stringWithFormat:@"%f", width, nil];
                    self.prefsVideoDimensionsCustomHeight.stringValue = [NSString stringWithFormat:@"%f", height, nil];
                    
                }
            }
            // Native size if NSZeroSize
            else
                [self.prefsVideoDimensions selectItemAtIndex:0];

        }
        else
            [self.prefsVideoDimensions selectItemAtIndex:0];

        // Quality
        if(preset.videoSettings.settingsDictionary[AVVideoQualityKey])
        {
            NSInteger index = [self.prefsVideoQuality indexOfItemWithRepresentedObject:preset.videoSettings.settingsDictionary[AVVideoQualityKey]];
            if(index > 0)
                [self.prefsVideoQuality selectItemAtIndex:index];
            else
                [self.prefsVideoQuality selectItemAtIndex:0];
        }
        else
            [self.prefsVideoQuality selectItemAtIndex:0];
        
        // Aspect Ratio
        if(preset.videoSettings.settingsDictionary[AVVideoScalingModeKey])
        {
            NSInteger index = [self.prefsVideoAspectRatio indexOfItemWithRepresentedObject:preset.videoSettings.settingsDictionary[AVVideoScalingModeKey]];
            
            if(index > 0)
                [self.prefsVideoAspectRatio selectItemAtIndex:index];
            else
                [self.prefsVideoAspectRatio selectItemAtIndex:0];
        }
        else
            [self.prefsVideoAspectRatio selectItemAtIndex:0];
        
    }
    // No video settings at all = passthrough
    else
        [self.prefsVideoCompressor selectItemAtIndex:0];

}

- (void) configureAnalysisSettingsFromPreset:(PresetObject*)preset
{
    
}



@end
