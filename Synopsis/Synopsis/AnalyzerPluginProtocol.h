//
//  SampleBufferAnalyzerPluginProtocol.h
//  MetadataTranscoderTestHarness
//
//  Created by vade on 4/3/15.
//  Copyright (c) 2015 Synopsis. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <AVFoundation/AVFoundation.h>


#pragma mark - Standard Analyzer and Spotlight Keys

// These keys are used within our Spotlight plugin, and our Standard Analyzer plugin to ensure spotlight and our analyzer agree on key names.
// These particular keys allow for a spotlight UI to be created, certain keys to be visible in the ui (and others to not be)
// This lets users easily find specific information in the Finder and in the UI.

// To be clear, if a plugin writes out custom summary metadata, that metada will be included in the HFS extended attributes
// under the com.apple.metadata: key allowing programmatic spotlight searches to work (along with command line searches).
// The only limitation is that a custom UI wont be made (as the spotlight schema wont match).

// Note, these strings need to match our schema.xml file exactly.

// A multivalue (NSArray) that holds the actual RGB (or RGBA) values (another NSArray) for a color.
// Note, this is an Array of colors. Or an Array of Arrays.
// Not exposed to the UI
extern NSString * const kStandardAnalyzerKey_DominantColorValues;
// A multivalue (NSArray) of of NSStrings for readable color names.
// values can be Black, White, Gray, Red, Green, Blue, Cyan, Magenta, Yellow, Orange, Brown
extern NSString * const kStandardAnalyzerKey_DominantColorName;

#pragma mark - Plugin Particulars

// Rough amount of overhead a particular plugin or module has
// For example very very taxing
typedef enum : NSUInteger {
    SynopsisAnalysisOverheadNone = 0,
    SynopsisAnalysisOverheadLow,
    SynopsisAnalysisOverheadMedium,
    SynopsisAnalysisOverheadHigh,
} SynopsisAnalysisOverhead;


typedef NSInteger SynopsisModuleIndex;

enum : SynopsisModuleIndex {
    SynopsisModuleIndexNone = -1,
};

// Should a plugin have configurable quality settings
// Hint the plugin to use a specific quality hint
typedef enum : NSUInteger {
    SynopsisAnalysisQualityHintLow,
    SynopsisAnalysisQualityHintMedium,
    SynopsisAnalysisQualityHintHigh,
    // No downsampling
    SynopsisAnalysisQualityHintOriginal = NSUIntegerMax,
} SynopsisAnalysisQualityHint;

typedef void (^LogBlock)(NSString* log);

@protocol AnalyzerPluginProtocol <NSObject>

@required

// Human Readable Plugin Named Also used in UI
@property (readonly) NSString* pluginName;

// Metadata Tag identifying the analyzers metadata section in the aggegated metatada track
// This should be something like info.v002.Synopsis.pluginname -

// all metadata either global or per frame is within a dictionary under this key

@property (readonly) NSString* pluginIdentifier;

// Authors for Credit - array of NSStrings
@property (readonly) NSArray* pluginAuthors;

// Human Readable Description
@property (readonly) NSString* pluginDescription;

// Expected host API Version
@property (readonly) NSUInteger pluginAPIVersionMajor;
@property (readonly) NSUInteger pluginAPIVersionMinor;

// Plugin Version (for tuning / changes to capabilities, etc)
@property (readonly) NSUInteger pluginVersionMajor;
@property (readonly) NSUInteger pluginVersionMinor;

// The type of media the plugin analyzes.
// For now, plugins only work with Video or Audio, we dont pass in two buffers at once.
// Supported values are currently only AVMediaTypeVideo, or AVMediaTypeAudio.
// Perhaps Muxed comes in the future.
@property (readonly) NSString* pluginMediaType;

// Logging callbacks fo inclusion in the UI
@property (copy) LogBlock errorLog;
@property (copy) LogBlock successLog;
@property (copy) LogBlock warningLog;
@property (copy) LogBlock verboseLog;

// Processing overhead for the plugin
//@property (readonly) SynopsisAnalysisOverhead pluginOverhead;

#pragma mark - Analysis Methods

// Initialize any resources required by the plugin for Analysis
// This is where one might initialize resources that exist over the lifetime of the module
// For example, feature detectors, OpenGL/CL/Cuda contexts
// Memory pools, etc.
- (void) beginMetadataAnalysisSessionWithQuality:(SynopsisAnalysisQualityHint)qualityHint;

// Updates the cached read only video buffer to be used for every module an analyzer implements.
// This is where one would do color conversion cache lower resolution proxies, submit to OpenCL, Cuda, etc
// This is called once per frame, and the cache
- (void) submitAndCacheCurrentBatchedVideoBuffer:(void*)baseAddress width:(size_t)width height:(size_t)height bytesPerRow:(size_t)bytesPerRow batchSize:(NSUInteger)batchSize forBatchIndex:(NSUInteger)batchIndex;


// Analyze a sample buffer.
// The resulting dictionary is aggregated with all other plugins and added to the 
// If a module name is supplied, the plugin should run analysis for that module only.
//
// This method will be called once per frame, once per enabled module.
// This method may be called from a different thread per invocation.

- (NSDictionary*) analyzeMetadataDictionaryForModuleIndex:(SynopsisModuleIndex)moduleIndex error:(NSError**)error;


// Finalize any calculations required to return global metadata
// Global Metadata is metadata that describes the entire file, not the individual frames or samples
// Things like most prominent colors over all, agreggate amounts of motion, etc
- (NSDictionary*) finalizeMetadataAnalysisSessionWithError:(NSError**)error;

#pragma mark - Module Support

// A module is a method that is wholly independent of any other processing in the plugin
// A module relys only on the input buffer
// A module may be processed on a thread, concurrently with another module from the same plugin

// THIS MEANS THAT MODULES MUST BE THREAD SAFE

- (BOOL) hasModules;

@optional

// An array of keys used to enable or disable modules within the plugin.
// A plugin may support multiple types modes of analysis - called modules
// Each module may have overhead associated with it (processing time, etc), and end users may which to enable or disable modules

@property (readonly) NSArray* moduleClasses;


// Human Readable Description for the module in question
-(NSString*) descriptionForModule:(NSString*)moduleNameKey;

// Approximate computational overhead for a module - to hint user interface of computation 'expense' / duration etc.
-(SynopsisAnalysisOverhead) overheadForModule:(NSString*)moduleNameKey;

// return a method specific for a module
- (SEL) methodForModule:(NSString*)moduleName;

@end
