//
//  TranscodeOperation.m
//  MetadataTranscoderTestHarness
//
//  Created by vade on 3/31/15.
//  Copyright (c) 2015 metavisual. All rights reserved.
//

#import "TranscodeOperation.h"
#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>
#import <VideoToolbox/VideoToolbox.h>
#import <VideoToolbox/VTProfessionalVideoWorkflow.h>

const NSString* kMetavisualVideoTranscodeSettion = @"kMetavisualVideoTranscodeSettion";
const NSString* kMetavisualAudioTranscodeSettion = @"kMetavisualAudioTranscodeSettion";

NSString* kMetavisualMetadataIdentifier = @"mdta/org.metavisual.somethingsomething";

@interface TranscodeOperation ()
{
    
}
// Prerequisites
@property (atomic, readwrite, strong) NSDictionary* transcodeOptions;
@property (atomic, readwrite, strong) NSURL* sourceURL;
@property (atomic, readwrite, strong) NSURL* destinationURL;

@property (atomic, readwrite, assign) BOOL usingPassthrough;


// Reading the original sample Data
@property (atomic, readwrite, strong) AVURLAsset* transcodeAsset;
@property (atomic, readwrite, strong) AVAssetReader* transcodeAssetReader;
@property (atomic, readwrite, strong) AVAssetReaderTrackOutput* transcodeAssetReaderVideo;
@property (atomic, readwrite, strong) AVAssetReaderTrackOutput* transcodeAssetReaderAudio;

// We have optional pass through readers, which allow us to output pixel formats for analysis
// But we pass through the original data un-re-encoded to avoid generational loss
// Note that these are only used if our transcodeOptions dictionary is correctly configured
// See header for info.
@property (atomic, readwrite, strong) AVAssetReaderTrackOutput* transcodeAssetReaderVideoPassthrough;
@property (atomic, readwrite, strong) AVAssetReaderTrackOutput* transcodeAssetReaderAudioPassthrough;

// Writing new sample data (passthrough or transcode) + Metdata
@property (atomic, readwrite, strong) AVAssetWriter* transcodeAssetWriter;
@property (atomic, readwrite, strong) AVAssetWriterInput* transcodeAssetWriterVideo;
@property (atomic, readwrite, strong) AVAssetWriterInput* transcodeAssetWriterAudio;

// See above passthrough notes for reasoning
@property (atomic, readwrite, strong) AVAssetWriterInput* transcodeAssetWriterVideoPassthrough;
@property (atomic, readwrite, strong) AVAssetWriterInput* transcodeAssetWriterAudioPassthrough;

// And most importantly, the star of our show:
@property (atomic, readwrite, strong) AVAssetWriterInput* transcodeAssetWriterMetadata;
@property (atomic, readwrite, strong) AVAssetWriterInputMetadataAdaptor* transcodeAssetWriterMetadataAdaptor;

@end

@implementation TranscodeOperation

- (id) initWithSourceURL:(NSURL*)sourceURL destinationURL:(NSURL*)destinationURL transcodeOptions:(NSDictionary*)transcodeOptions
{
    self = [super init];
    if(self)
    {
        VTRegisterProfessionalVideoWorkflowVideoDecoders();
        VTRegisterProfessionalVideoWorkflowVideoEncoders();
        
        self.sourceURL = sourceURL;
        self.destinationURL = destinationURL;
        self.transcodeOptions = transcodeOptions;
        
        // if we dont have transcode options, we use passthrough
        // Note we still want to do analysis, so we still spool up our decompressors
        // We just dont need to spool up our encoders
        
        self.usingPassthrough = (self.transcodeOptions) ? NO : YES;
        
        [self setupTranscodeShitSucessfullyOrDontWhatverMan];
    }
    return self;
}

- (NSString*) description
{
    return [NSString stringWithFormat:@"Transcode Operation: %p, Source: %@, Destination: %@, options: %@", self, self.sourceURL, self.destinationURL, self.transcodeOptions];
}

- (void) main
{
    NSLog(@"%@", self);
    
    [self transcodeAndAnalyzeAsset];

    NSLog(@"FINISHED");

    [super main];
}


- (NSError*) setupTranscodeShitSucessfullyOrDontWhatverMan
{
    self.transcodeAsset = [AVURLAsset URLAssetWithURL:self.sourceURL options:@{AVURLAssetPreferPreciseDurationAndTimingKey : @TRUE}];
    
    BOOL hasVideo = [self.transcodeAsset tracksWithMediaCharacteristic:AVMediaCharacteristicVisual].count ? YES : NO;
    BOOL hasAudio = [self.transcodeAsset tracksWithMediaCharacteristic:AVMediaCharacteristicAudible].count ? YES : NO;
    
    // TODO: error checking / handling
    NSError* error = nil;
    
    // Readers
    self.transcodeAssetReader = [AVAssetReader assetReaderWithAsset:self.transcodeAsset error:&error];
    
    // Video Reader -
    if(hasVideo)
    {
        AVAssetTrack* firstVideoTrack = [self.transcodeAsset tracksWithMediaCharacteristic:AVMediaCharacteristicVisual][0];
        self.transcodeAssetReaderVideo = [AVAssetReaderTrackOutput assetReaderTrackOutputWithTrack:firstVideoTrack
                                                                                    outputSettings:@{ (NSString*)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_32BGRA),
                                                                                                      (NSString*)kCVPixelBufferCGBitmapContextCompatibilityKey : @YES,
                                                                                                      (NSString*)kCVPixelBufferCGImageCompatibilityKey: @(YES)}];
        self.transcodeAssetReaderVideo.alwaysCopiesSampleData = YES;

        // Passthrough Video Reader -
        self.transcodeAssetReaderVideoPassthrough = [AVAssetReaderTrackOutput assetReaderTrackOutputWithTrack:firstVideoTrack
                                                                                               outputSettings:nil];
        self.transcodeAssetReaderVideoPassthrough.alwaysCopiesSampleData = YES;
    }
    
    // Audio Reader -
    if(hasAudio)
    {
        AVAssetTrack* firstAudioTrack = [self.transcodeAsset tracksWithMediaCharacteristic:AVMediaCharacteristicAudible][0];
        self.transcodeAssetReaderAudio = [AVAssetReaderTrackOutput assetReaderTrackOutputWithTrack:firstAudioTrack
                                                                                outputSettings:@{(NSString*) AVFormatIDKey : @(kAudioFormatLinearPCM)}];
        self.transcodeAssetReaderAudio.alwaysCopiesSampleData = YES;
        
        // Passthrough Audio Reader -
        self.transcodeAssetReaderAudioPassthrough = [AVAssetReaderTrackOutput assetReaderTrackOutputWithTrack:firstAudioTrack
                                                                                               outputSettings:nil];
        self.transcodeAssetReaderAudioPassthrough.alwaysCopiesSampleData = YES;
    }

    // Assign all our specific Outputs to our Reader
    if(hasVideo)
    {
        if([self.transcodeAssetReader canAddOutput:self.transcodeAssetReaderVideo]
           && [self.transcodeAssetReader canAddOutput:self.transcodeAssetReaderVideoPassthrough])
        {
            // only add outputs if we are using them.
//            [self.transcodeAssetReader addOutput:self.transcodeAssetReaderVideo];
            [self.transcodeAssetReader addOutput:self.transcodeAssetReaderVideoPassthrough];
        }
    }

    if(hasAudio)
    {
        if([self.transcodeAssetReader canAddOutput:self.transcodeAssetReaderAudio]
           && [self.transcodeAssetReader canAddOutput:self.transcodeAssetReaderAudioPassthrough])
        {
            // only add outputs if we are using them.
            //[self.transcodeAssetReader addOutput:self.transcodeAssetReaderAudio];
            [self.transcodeAssetReader addOutput:self.transcodeAssetReaderAudioPassthrough];
        }
    }
    
    // Writers
    self.transcodeAssetWriter = [AVAssetWriter assetWriterWithURL:self.destinationURL fileType:AVFileTypeQuickTimeMovie error:&error];
    
    // Do we need to transcode?
    if(!self.usingPassthrough)
    {
        NSDictionary* videoEncodingDictionary = self.transcodeOptions[kMetavisualVideoTranscodeSettion];
        NSDictionary* audioEncodingDictionary = self.transcodeOptions[kMetavisualAudioTranscodeSettion];
        self.transcodeAssetWriterVideo = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:videoEncodingDictionary];
        self.transcodeAssetWriterAudio = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeAudio outputSettings:audioEncodingDictionary];
    }
    
    // Passthrough Video and Audio
    self.transcodeAssetWriterVideoPassthrough = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:nil];
    self.transcodeAssetWriterAudioPassthrough = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeAudio outputSettings:nil];

    // Metadata
    CMFormatDescriptionRef metadataFormatDescription = NULL;
    NSArray *specs = @[
                       @{(__bridge NSString *)kCMMetadataFormatDescriptionMetadataSpecificationKey_Identifier : kMetavisualMetadataIdentifier,
                         (__bridge NSString *)kCMMetadataFormatDescriptionMetadataSpecificationKey_DataType : (__bridge NSString *)kCMMetadataBaseDataType_UTF8}];
    
    
    OSStatus err = CMMetadataFormatDescriptionCreateWithMetadataSpecifications(kCFAllocatorDefault, kCMMetadataFormatType_Boxed, (__bridge CFArrayRef)specs, &metadataFormatDescription);
    self.transcodeAssetWriterMetadata = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeMetadata outputSettings:nil sourceFormatHint:metadataFormatDescription];
    self.transcodeAssetWriterMetadataAdaptor = [AVAssetWriterInputMetadataAdaptor assetWriterInputMetadataAdaptorWithAssetWriterInput:self.transcodeAssetWriterMetadata];
    
    // Assign all our specific inputs to our Writer
    if([self.transcodeAssetWriter canAddInput:self.transcodeAssetWriterVideoPassthrough]
       && [self.transcodeAssetWriter canAddInput:self.transcodeAssetWriterAudioPassthrough]
       && [self.transcodeAssetWriter canAddInput:self.transcodeAssetWriterMetadata]
       )
    {
        [self.transcodeAssetWriter addInput:self.transcodeAssetWriterMetadata];

        if(hasVideo)
            [self.transcodeAssetWriter addInput:self.transcodeAssetWriterVideoPassthrough];
        
        if(hasAudio)
            [self.transcodeAssetWriter addInput:self.transcodeAssetWriterAudioPassthrough];
    }
    
    if( (!self.usingPassthrough) && self.transcodeAssetWriterVideo && self.transcodeAssetWriterAudio)
    {
        if([self.transcodeAssetWriter canAddInput:self.transcodeAssetWriterVideo]
           && [self.transcodeAssetWriter canAddInput:self.transcodeAssetWriterAudio])
        {
            if(hasVideo)
                [self.transcodeAssetWriter addInput:self.transcodeAssetWriterVideo];
            
            if(hasAudio)
                [self.transcodeAssetWriter addInput:self.transcodeAssetWriterAudio];
        }
    }
    
    return error;
}


- (void) transcodeAndAnalyzeAsset
{
    if([self.transcodeAssetWriter startWriting] && [self.transcodeAssetReader startReading])
    {
        [self.transcodeAssetWriter startSessionAtSourceTime:kCMTimeZero];
    
        // We need a dispatch group since we have to wrangle multiple queues successfully.
        // Signal both audio and video are done within this task
        dispatch_group_t g = dispatch_group_create();

        // 0 = use as much as you want.
        // Probably want to throttle this and set a small usleep to keep threads happy
        // Or use the CMBufferqueue callbacks with a semaphore signal
        CMItemCount numBuffers = 0;
        
//        CMBufferQueueRef decodeVideoBufferQueue;
//        CMBufferQueueRef decodeAudioBufferQueue;
//        CMBufferQueueRef metadataVideoAnalysisQueue;

        // Decode and Encode Queues - each pair writes or reads to a CMBufferQueue
    
        CMBufferQueueRef passthroughVideoBufferQueue;
        CMBufferQueueCreate(kCFAllocatorDefault, numBuffers, CMBufferQueueGetCallbacksForSampleBuffersSortedByOutputPTS(), &passthroughVideoBufferQueue);

        dispatch_queue_t videoPassthroughDecodeQueue = dispatch_queue_create("videoPassthroughDecodeQueue", 0);
        dispatch_group_enter(g);
        
        dispatch_queue_t videoPassthroughEncodeQueue = dispatch_queue_create("videoPassthroughEncodeQueue", 0);
        dispatch_group_enter(g);
        
//        CMBufferQueueRef passthroughAudioBufferQueue;
//        CMBufferQueueCreate(kCFAllocatorDefault, numBuffers, CMBufferQueueGetCallbacksForSampleBuffersSortedByOutputPTS(), &passthroughAudioBufferQueue);
//
//        dispatch_queue_t audioPassthroughDecodeQueue = dispatch_queue_create("audioPassthroughDecodeQueue", 0);
//        dispatch_group_enter(g);
//
//        dispatch_queue_t audioPassthroughEncodeQueue = dispatch_queue_create("audioPassthroughEncodeQueue", 0);
//        dispatch_group_enter(g);
        

        __block BOOL finishedReadingAllPassthroughVideo;
        
        // Passthrough Video Read into our Buffer Queue
        dispatch_async(videoPassthroughDecodeQueue, ^{
            
            // read sample buffers from our video reader - and append them to the queue.
            // only read while we have samples, and while our buffer queue isnt full
            
            while(self.transcodeAssetReader.status == AVAssetReaderStatusReading)
            {
                @autoreleasepool
                {
                    // Only enqueue if we have room
//                    if( CMBufferQueueGetBufferCount(passthroughVideoBufferQueue) < numBuffers )
                    {
                        CMSampleBufferRef passthroughVideoSampleBuffer = [self.transcodeAssetReaderVideoPassthrough copyNextSampleBuffer];
                        if(passthroughVideoSampleBuffer)
                        {
//                            NSLog(@"Got Sample Buffer and Enqued it");
                            CMBufferQueueEnqueue(passthroughVideoBufferQueue, passthroughVideoSampleBuffer);
                            
                            CFRelease(passthroughVideoSampleBuffer);
                        }
                        else
                        {
                            // Got NULL - were done
                            break;
                        }
                    }
//                    else
//                    {
//                        // Take a moment to let the reader queue read.
//                        // Could use a semaphor but holy fuck this is getting insane
//                        usleep(10);
//                    }
                }
            }
            
            finishedReadingAllPassthroughVideo = YES;
            NSLog(@"Reading Done");

            dispatch_group_leave(g);
        });
        
        // TODO : look at SampleTimingInfo Struct to better get a handle on this shit.
        __block NSUInteger sampleCount = 0;
        __block CMTimeRange lastSampleTimeRange = kCMTimeRangeZero;
        
        // Passthrough Video Write from Buffer Queue
        [self.transcodeAssetWriterVideoPassthrough requestMediaDataWhenReadyOnQueue:videoPassthroughEncodeQueue usingBlock:^
        {
//            NSLog(@"Started Requesting Media");
            while([self.transcodeAssetWriterVideoPassthrough isReadyForMoreMediaData]
                  && [self.transcodeAssetWriterMetadata isReadyForMoreMediaData])
            {
                // Are we done reading,
                if(finishedReadingAllPassthroughVideo )
                {
//                    NSLog(@"Finished Reading waiting to empty queue...");
                    if(CMBufferQueueIsEmpty(passthroughVideoBufferQueue))
                    {
                        [self.transcodeAssetWriterVideo markAsFinished];
                        [self.transcodeAssetWriterMetadata markAsFinished];
//                        NSLog(@"Writing Done");
                        
                        dispatch_group_leave(g);
                        break;
                    }
                }
                
                CMSampleBufferRef passthroughVideoSampleBuffer = (CMSampleBufferRef) CMBufferQueueDequeueAndRetain(passthroughVideoBufferQueue);
                if(passthroughVideoSampleBuffer)
                {
                    [self.transcodeAssetWriterVideoPassthrough appendSampleBuffer:passthroughVideoSampleBuffer];
                    
                    CMTime currentSamplePTS = CMSampleBufferGetPresentationTimeStamp(passthroughVideoSampleBuffer);
                    CMTime currentSampleDuration = CMSampleBufferGetOutputDuration(passthroughVideoSampleBuffer);
                    CMTimeRange currentSampleTimeRange = CMTimeRangeMake(currentSamplePTS, currentSampleDuration);

                    NSLog(@"Sample Count %i", sampleCount);
                    
                    CFStringRef desc = CMTimeRangeCopyDescription(kCFAllocatorDefault, currentSampleTimeRange);
                    NSLog(@"Sample Timing Info: %@", desc);

                    // Write Metadata
                    
                    // Check that our metadata times are sensible. We need to ensure that each time range is:
                    // a incremented from the last
                    // b valid
                    // c has no zero duration (should be the duration of a frame)
                    // d - there are probably other issues too.
                    
                    if(CMTIMERANGE_IS_VALID(currentSampleTimeRange)
                       && CMTIME_COMPARE_INLINE(currentSampleTimeRange.start, >=, lastSampleTimeRange.start)
                       && CMTIME_COMPARE_INLINE(currentSampleTimeRange.duration, >, kCMTimeZero)
                       )
                    {
                        NSLog(@"Sample %i PASSED", sampleCount);
                        // Annotation text item
                        AVMutableMetadataItem *textItem = [AVMutableMetadataItem metadataItem];
                        textItem.identifier = kMetavisualMetadataIdentifier;
                        textItem.dataType = (__bridge NSString *)kCMMetadataBaseDataType_UTF8;
                        textItem.value = [NSString stringWithFormat:@"Sample Numver %lu", (unsigned long)sampleCount];
                        
                        AVTimedMetadataGroup *group = [[AVTimedMetadataGroup alloc] initWithItems:@[textItem] timeRange:currentSampleTimeRange];

                        [self.transcodeAssetWriterMetadataAdaptor appendTimedMetadataGroup:group];
                    }
                    else
                    {
                        NSLog(@"Sample %i FAILED", sampleCount);
                    }
                    
                    sampleCount++;
                    lastSampleTimeRange = currentSampleTimeRange;
                    CFRelease(passthroughVideoSampleBuffer);
                }
            }
            
//            NSLog(@"Stopped Requesting Media");
            
        }];
        
        // Wait until every queue is finished processing
        dispatch_group_wait(g, DISPATCH_TIME_FOREVER);
        
        [self.transcodeAssetWriter finishWritingWithCompletionHandler:^{
//            NSLog(@"DONE WITH SHIT MAYBE");
        }];
    }
}


@end
