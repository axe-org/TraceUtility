//
//  InstrumentsPrivateHeader.h
//  TraceUtility
//
//  Created by Qusic on 8/9/15.
//  Copyright (c) 2015 Qusic. All rights reserved.
//

#import <AppKit/AppKit.h>

NSString *PFTDeveloperDirectory(void);
void DVTInitializeSharedFrameworks(void);
BOOL PFTLoadPlugins(void);
void PFTClosePlugins(void);

@interface DVTDeveloperPaths : NSObject
+ (NSString *)applicationDirectoryName;
+ (void)initializeApplicationDirectoryName:(NSString *)name;
@end

@interface XRInternalizedSettingsStore : NSObject
+ (NSDictionary *)internalizedSettings;
+ (void)configureWithAdditionalURLs:(NSArray *)urls;
@end

@interface XRCapabilityRegistry : NSObject
+ (instancetype)applicationCapabilities;
- (void)registerCapability:(NSString *)capability versions:(NSRange)versions;
@end

typedef UInt64 XRTime; // in nanoseconds
typedef struct { XRTime start, length; } XRTimeRange;

@interface XRRun : NSObject
- (SInt64)runNumber;
- (NSString *)displayName;
- (XRTimeRange)timeRange;
- (double)startTime;
- (double)endTime;
@end

@interface PFTInstrumentType : NSObject
- (NSString *)uuid;
- (NSString *)name;
- (NSString *)category;
- (NSString *)version;
@end

@protocol XRInstrumentViewController;

@interface XRInstrument : NSObject
- (PFTInstrumentType *)type;
- (id<XRInstrumentViewController>)viewController;
- (void)setViewController:(id<XRInstrumentViewController>)viewController;
- (NSArray<XRRun *> *)allRuns;
- (XRRun *)currentRun;
- (void)setCurrentRun:(XRRun *)run;
- (NSString *)uuid;
@end

@interface PFTInstrumentList : NSObject
- (NSArray<XRInstrument *> *)allInstruments;
@end

@interface XRIntKeyedDictionary : NSObject
- (id)allObjects;
@end

@interface XRTrace : NSObject {
    XRIntKeyedDictionary *_coresByRunNumber;
}
- (PFTInstrumentList *)allInstrumentsList;
@end

@interface XRDevice : NSObject
- (NSString *)deviceIdentifier;
- (NSString *)deviceDisplayName;
- (NSString *)deviceDescription;
- (NSString *)productType;
- (NSString *)productVersion;
- (NSString *)buildVersion;
@end

@interface PFTProcess : NSObject
- (NSString *)bundleIdentifier;
- (NSString *)processName;
- (NSString *)displayName;
@end

@interface PFTTraceDocument : NSDocument
- (XRTrace *)trace;
- (XRDevice *)targetDevice;
- (PFTProcess *)defaultProcess;
@end

@interface PFTDocumentController : NSDocumentController
@end

@protocol XRContextContainer;

@interface XRContext : NSObject
- (NSString *)label;
- (id<NSCoding>)value;
- (id<XRContextContainer>)container;
- (instancetype)parentContext;
- (instancetype)rootContext;
- (void)display;
@end

@protocol XRContextContainer <NSObject>
- (XRContext *)contextRepresentation;
- (NSArray<XRContext *> *)siblingsForContext:(XRContext *)context;
- (void)displayContext:(XRContext *)context;
@end

@protocol XRFilteredDataSource <NSObject>
@end

@protocol XRSearchTarget <NSObject>
@end

@protocol XRCallTreeDataSource <NSObject>
@end

@protocol XRAnalysisCoreViewSubcontroller <XRContextContainer, XRFilteredDataSource>
@end

typedef NS_ENUM(SInt32, XRAnalysisCoreDetailViewType) {
    XRAnalysisCoreDetailViewTypeProjection = 1,
    XRAnalysisCoreDetailViewTypeCallTree = 2,
    XRAnalysisCoreDetailViewTypeTabular = 3,
};

@interface XRAnalysisCoreDetailNode : NSObject
- (instancetype)firstSibling;
- (instancetype)nextSibling;
- (XRAnalysisCoreDetailViewType)viewKind;
@end

@class XRAnalysisCoreProjectionViewController, XRAnalysisCoreCallTreeViewController, XRAnalysisCoreTableViewController;

@interface XRAnalysisCoreDetailViewController : NSViewController <XRAnalysisCoreViewSubcontroller> {
    XRAnalysisCoreDetailNode *_firstNode;
    XRAnalysisCoreProjectionViewController *_projectionViewController;
    XRAnalysisCoreCallTreeViewController *_callTreeViewController;
    XRAnalysisCoreTableViewController *_tabularViewController;
}
- (void)restoreViewState;
@end

XRContext *XRContextFromDetailNode(XRAnalysisCoreDetailViewController *detailController, XRAnalysisCoreDetailNode *detailNode);

@protocol XRInstrumentViewController <NSObject>
- (id<XRContextContainer>)detailContextContainer;
- (id<XRFilteredDataSource>)detailFilteredDataSource;
- (id<XRSearchTarget>)detailSearchTarget;
- (void)instrumentDidChangeSwitches;
- (void)instrumentChangedTableRequirements;
- (void)instrumentWillBecomeInvalid;
@end

@interface XRAnalysisCoreStandardController : NSObject <XRInstrumentViewController>
- (instancetype)initWithInstrument:(XRInstrument *)instrument document:(PFTTraceDocument *)document;
@end

@interface XRAnalysisCoreProjectionViewController : NSViewController <XRSearchTarget>
@end

@interface PFTCallTreeNode : NSObject{
@public
    unsigned long long parentalAddress;
    struct {
        double selfWeight;
        double weight;
    } weights[1];
}
+ (id)newNodeWithWeightCount:(unsigned long long)arg1 name:(id)arg2;
+ (id)newNodeWithWeightCount:(unsigned long long)arg1;
+ (id)allocWithWeightCount:(unsigned long long)arg1;
+ (void)initialize;
- (id)initWithCoder:(id)arg1;
- (void)encodeWithCoder:(id)arg1;
- (long long)lineNumberForDisplay;
- (id)pathForDisplay;
- (id)symbolNameForUse;
- (BOOL)getWeight:(double *)arg1 at:(unsigned long long)arg2;
- (id)symbolNameForDisplay;
- (id)libraryForDisplay;
- (id)libraryPath;
- (NSString *)libraryName;
- (unsigned long long)lineNumber;
- (id)sourcePath;
- (unsigned long long)address;
- (BOOL)recursivelyTrimLibraries:(id)arg1 keepBoundaries:(BOOL)arg2;
- (BOOL)recursivelyTrimSymbols:(id)arg1 prune:(BOOL)arg2;
- (void)recursivelyPruneLeavingLibraryNames:(id)arg1 requireAny:(BOOL)arg2;
- (void)recursivelyPruneLeavingSymbolNames:(id)arg1 requireAny:(BOOL)arg2;
- (void)recursivePruneByWeightWithMin:(long long)arg1 max:(long long)arg2;
- (void)recursivePruneByCountWithMin:(unsigned int)arg1 max:(unsigned int)arg2;
- (void)mergeWithNode:(id)arg1 factor:(int)arg2;
- (void)flattenAllRecursion;
- (void)pruneChild:(id)arg1;
- (void)flattenChild:(id)arg1;
- (BOOL)recursiveFlattenWithDataSelector:(SEL)arg1 filterNonZero:(BOOL)arg2;
- (BOOL)recursiveFlattenWithPredicate:(id)arg1;
- (id)_heaviestInvolvingNodeWithStyle:(int)arg1;
- (id)heaviestInvolvingNodeAsCounts;
- (id)heaviestInvolvingNodeAsWeights;
- (id)heaviestInvolvingNodeAsBytes;
- (id)heaviestInvolvingNode;
- (double)selfCountPercent;
- (double)totalCountPercent;
- (double)parentCountPercent;
- (double)selfWeightPercent:(unsigned long long)arg1;
- (double)totalWeightPercent:(unsigned long long)arg1;
- (double)parentWeightPercent:(unsigned long long)arg1;
- (id)symbolData;
- (id)_symbolData;
- (id)data;
- (id)symbol;
- (void)setName:(id)arg1;
- (id)symbolName;
- (void)setShowAsCounts:(id)arg1;
- (void)setShowAsBytes:(id)arg1;
- (id)totalBytes;
- (id)selfBytes;
- (int)terminals;
- (int)count;
- (double)selfWeight:(unsigned long long)arg1;
- (double)weight:(unsigned long long)arg1;
- (unsigned long long)weightCount;
- (int)pid;
- (int)numberChildren;
- (id)children;
- (id)uidSet;
- (id)childWithSymbolName:(id)arg1;
- (id)childWithUid:(id)arg1;
- (id)symbolNamePath;
- (id)uidPath;
- (id)uid;
- (PFTCallTreeNode *)parent;
- (id)root;
- (id)_gatherSamples;
- (void)_recursiveGatherSamples:(id)arg1;
- (id)_assembleLineSpecificData;
- (void)_recursiveAssembleLineSpecificData:(id)arg1 baseSymbolData:(id)arg2;
- (void)setRoot:(id)arg1;
- (void)adopt:(id)arg1 merge:(BOOL)arg2 compare:(BOOL)arg3;
- (unsigned int)_thread;
- (void)fixupCounts;
- (id)getConcreteParent;
- (void)setDoNotRecalcWeightFlag;
- (void)setTopFunctionsFlag;
- (void)setIsTopOfStackFlag;
- (void)setPrivateDataFlag;
- (void)setIsInvertedFlag;
- (void)addTerminals:(int)arg1;
- (void)addSelfWeight:(double)arg1 forIndex:(unsigned long long)arg2;
- (void)addWeight:(double)arg1 forIndex:(unsigned long long)arg2;
- (id)addNewChildWithData:(id)arg1;
- (id)childThatMatchesNode:(id)arg1;
@property(readonly, copy) NSString *description;
- (id)representedObject;
@end
@interface XRBacktraceRepository : NSObject
- (PFTCallTreeNode *)rootNode;
- (void)refreshTreeRoot;
@property(nonatomic) BOOL trimSystemLibraries;
- (id)libraryForAddress:(unsigned long long)arg1;
- (id)symbolForPC:(unsigned long long)arg1;
@end

@interface XRObjectAllocRun : XRRun
- (void)setLifecycleFilter:(int)arg1;
@end

@interface XRCallTreeDetailView : NSTableView
- (void)forceReloadDetailData;
- (void)setValue:(id)arg1 forUndefinedKey:(id)arg2;
@end


@interface PFTOwnerData : NSObject
- (id)libraryPath;
- (id)libraryName;

@end

@interface XRMultiProcessBacktraceRepository : XRBacktraceRepository
@end

@interface XRAnalysisCoreCallTreeViewController : NSViewController <XRFilteredDataSource, XRCallTreeDataSource> {
    XRBacktraceRepository *_backtraceRepository;
}
@end

typedef void XRAnalysisCoreReadCursor;
typedef union {
    UInt32 uint32;
    UInt64 uint64;
    UInt32 iid;
} XRStoredValue;

@interface XRAnalysisCoreValue : NSObject
- (XRStoredValue)storedValue;
- (id)objectValue;
@end

BOOL XRAnalysisCoreReadCursorNext(XRAnalysisCoreReadCursor *cursor);
SInt64 XRAnalysisCoreReadCursorColumnCount(XRAnalysisCoreReadCursor *cursor);
XRStoredValue XRAnalysisCoreReadCursorGetStored(XRAnalysisCoreReadCursor *cursor, UInt8 column);
BOOL XRAnalysisCoreReadCursorGetValue(XRAnalysisCoreReadCursor *cursor, UInt8 column, XRAnalysisCoreValue * __strong *pointer);


struct XRUInt64Array {
    unsigned long long *values;
    unsigned int count;
};

union XRStoredValue {
    unsigned int uint32;
    unsigned long long uint64;
    unsigned int iid;
};


struct XRStoredUInt64Array {
    struct XRUInt64Array _field1;
    union XRStoredValue _field2;
};

struct XRBacktraceFragment {
    unsigned int _field1;
    int _field2;
    union {
        struct XRUInt64Array _field1;
        struct XRStoredUInt64Array _field2;
    } _field3;
};

@interface XRBacktraceTypeAdapter : NSObject
{
@public
    int _pid;
    unsigned int _totalFrameCount;
    unsigned int _fragCount;
    struct XRBacktraceFragment __fragStore[5];
    struct XRBacktraceFragment *_fragments;
    double *_weights;
    unsigned long long _weightCount;
    unsigned int _sampleCount;
    unsigned int _kernelIID;
}

- (void)copyWeightArray:(const double *)arg1 outputDeltas:(double *)arg2 weightCount:(unsigned long long)arg3 sampleCount:(unsigned int)arg4 sampleCountDelta:(unsigned int *)arg5;
- (BOOL)bottomIsTruncated;
- (void)setBottomIsTruncated:(BOOL)arg1;
- (BOOL)topIsTruncated;
- (void)setTopIsTruncated:(BOOL)arg1;
- (long long)count;
//- (void)enumerateFramesInRange:(struct _NSRange)arg1 options:(unsigned long long)arg2 block:(CDUnknownBlockType)arg3;
- (unsigned long long *)frames;
- (int)pid;
- (id)init;
- (void)dealloc;
- (id)initWithAnalysisCoreValue:(id)arg1;

// Remaining properties
@property(readonly, copy) NSString *debugDescription;
@property(readonly, copy) NSString *description;
@property(readonly) unsigned long long hash;
@property(readonly) Class superclass;

@end

@interface PFTDisplaySymbol : NSObject

- (id)copyWithZone:(struct _NSZone *)arg1;
- (void)encodeWithCoder:(id)arg1;
- (id)initWithCoder:(id)arg1;
- (long long)lineNumberForDisplay;
- (id)pathForDisplay;
- (id)symbolNameForUse;
- (NSString *)symbolNameForDisplay;
- (id)libraryForDisplay;
- (id)resolvedSymbol;
- (NSString *)libraryPath;
- (id)libraryName;
- (id)symbolName;
- (int)pid;
- (unsigned long long)lineNumber;
- (id)sourcePath;
- (unsigned long long)address;
@end

@interface XREngineeringTypeFormatter : NSFormatter
@end

@interface XRTraceEngineeringTypeFormatter : XREngineeringTypeFormatter
- (id)stringForCoreProfileBacktraceEngineeringValue:(id)arg1;
- (id)stringForTextSymbolEngineeringValue:(id)arg1;
- (id)stringForBacktraceEngineeringValue:(id)arg1;
- (id)stringForUserIDEngineeringValue:(id)arg1;
- (id)stringForThreadEngineeringValue:(id)arg1;
- (id)stringForInstrumentTypeEngineeringValue:(id)arg1;
- (id)stringForProcessEngineeringValue:(id)arg1;
- (id)stringForSocketAddrEngineeringValue:(id)arg1;
@end

@interface XRAnalysisCoreFullTextSearchSpec : NSObject
- (XREngineeringTypeFormatter *)formatter;
@end

@interface XRAnalysisCoreTableQuery : NSObject
- (XRAnalysisCoreFullTextSearchSpec *)fullTextSearchSpec;
@end

@interface XRAnalysisCoreRowArray : NSObject {
    XRAnalysisCoreTableQuery *_filter;
}
@end

@interface XRAnalysisCorePivotArrayAccessor : NSObject
- (UInt64)rowInDimension:(UInt8)dimension closestToTime:(XRTime)time intersects:(SInt8 *)intersects;
- (void)readRowsStartingAt:(UInt64)index dimension:(UInt8)dimension block:(void (^)(XRAnalysisCoreReadCursor *cursor))block;
@end

@interface XRAnalysisCorePivotArray : NSObject
- (XRAnalysisCoreRowArray *)source;
- (UInt64)count;
- (void)access:(void (^)(XRAnalysisCorePivotArrayAccessor *accessor))block;
- (id)initWithRowArray:(id)arg1 sortDescriptors:(id)arg2;
- (void)refresh;
@end

@interface XRAnalysisCoreTableViewControllerResponse : NSObject
- (XRAnalysisCorePivotArray *)rows;
@end

@interface DTRenderableContentResponse : NSObject
- (XRAnalysisCoreTableViewControllerResponse *)content;
@end

@interface XRAnalysisCoreTableViewController : NSViewController <XRFilteredDataSource, XRSearchTarget>
- (DTRenderableContentResponse *)_currentResponse;
- (DTRenderableContentResponse *)_lastResponse;
- (id)_objectForStackDataElement:(id)arg1;
@end

@interface XRManagedEventArrayController : NSArrayController
@end

@interface XRLegacyInstrument : XRInstrument <XRInstrumentViewController, XRContextContainer>
- (NSArray<XRContext *> *)_permittedContexts;
- (id)viewForContext:(id)arg1;
@end

@interface XRRawBacktrace : NSObject <NSSecureCoding>
{
    unsigned long long *_frames;
    unsigned int _count;
    int _pid;
    unsigned long long _hash;
    unsigned int _flags;
}

+ (BOOL)supportsSecureCoding;
+ (void)initialize;
- (BOOL)backtraceIsEqual:(id)arg1;
- (unsigned long long)backtraceHash;
- (BOOL)bottomIsTruncated;
- (void)setBottomIsTruncated:(BOOL)arg1;
- (BOOL)topIsTruncated;
- (void)setTopIsTruncated:(BOOL)arg1;
- (int)pid;
- (long long)kernelFrameCount;
- (long long)count;
- (unsigned long long *)frames;
- (id)initWithCoder:(id)arg1;
- (void)encodeWithCoder:(id)arg1;
- (void)setFrames:(unsigned long long *)arg1 count:(unsigned int)arg2;
- (void)dealloc;
- (id)initWithFrames:(unsigned long long *)arg1 count:(long long)arg2 pid:(int)arg3;

// Remaining properties
@property(readonly, copy) NSString *debugDescription;
@property(readonly, copy) NSString *description;
@property(readonly) unsigned long long hash;
@property(readonly) Class superclass;

@end

@interface XRManagedEvent : NSObject
- (UInt32)identifier;
@end

@interface XRObjectAllocEvent : XRManagedEvent
- (UInt32)allocationEvent;
- (UInt32)destructionEvent;
- (UInt32)pastEvent;
- (UInt32)futureEvent;
- (BOOL)isAliveThroughIdentifier:(UInt32)identifier;
- (NSString *)eventTypeName;
- (NSString *)categoryName;
- (XRTime)timestamp; // Time elapsed from the beginning of the run.
- (SInt32)size; // in bytes
- (SInt32)delta; // in bytes
- (UInt64)address;
- (UInt64)slot;
- (UInt64)data;
- (XRRawBacktrace *)backtrace;
- (int)refCountDelta;
- (NSString *)categoryNameOrDescription;
@end

@interface XROutlineDetailView : NSTableView
- (void)expandItem:(id)arg1 expandChildren:(BOOL)arg2;
@end
@interface PFTTableDetailView : NSTableView
- (void)_copyWithHeader:(BOOL)arg1;
+ (id)_stringForRows:(id)arg1 inView:(id)arg2 delimiter:(unsigned short)arg3 header:(BOOL)arg4;
@end

@interface XRObjectAllocEventViewController : NSObject {
    @public
    XRManagedEventArrayController *_ac;
    PFTTableDetailView *_view;
}
@end

@interface XRObjectAllocInstrument : XRLegacyInstrument {
@public
    XRObjectAllocEventViewController *_objectListController;
    NSMutableDictionary *_configurationOptions;
}
- (NSArray<XRContext *> *)_topLevelContexts;
- (BOOL)refreshDataSources;
@property(nonatomic) BOOL discardLifecycleComplete;
- (void)setNeedsForceReloadData:(BOOL)need;
- (void)_refreshFilterPredicate;
- (void)updateCurrentDetailView:(BOOL)arg1;
@end


@interface XROAEventSummary : NSObject <NSCoding, NSCopying>
{
    @public
    long long totalBytes;
    long long activeBytes;
    int totalAllocationCount;
    int activeAllocationCount;
    int totalEvents;
    int livingCount;
    int transitoryCount;
    int categoryIdentifier;
    long long livingBytes;
    long long transitoryBytes;
    NSString *categoryName;
}

+ (void)initialize;
- (unsigned int)categoryIdentifier;
- (id)category;
- (void)add:(id)arg1;
- (void)clear;
- (BOOL)isEqual:(id)arg1;
- (id)copyWithZone:(struct _NSZone *)arg1;
- (id)initWithCoder:(id)arg1;
- (void)encodeWithCoder:(id)arg1;
- (id)description;
- (void)dealloc;
- (id)initWithCategory:(id)arg1 identifier:(unsigned int)arg2;

@end



@class DVT_VMUClassInfo, NSData, NSString;



@interface XRLeak : NSObject <NSCoding>
{
    unsigned long long _discoveryTimestamp;
    NSData *_content;
    unsigned long long _remoteAddress;
    unsigned long long _remoteIsa;
    unsigned int _remoteSize;
    BOOL _isRoot;
    BOOL _inCycle;
    unsigned long long _allocationTimestamp;
    unsigned int _allocationIdentifier;
//    id <CommonRawStack> _backtrace;
    unsigned int _reachableSize;
    unsigned int _reachableCount;
    DVT_VMUClassInfo *_layout;
    unsigned int _classInfoIndex;
}

+ (void)initialize;
@property(nonatomic) XRRawBacktrace *backtrace;
@property unsigned int classInfoIndex; // @synthesize classInfoIndex=_classInfoIndex;
@property(retain) DVT_VMUClassInfo *classInfo; // @synthesize classInfo=_layout;
@property(nonatomic) BOOL inCycle; // @synthesize inCycle=_inCycle;
@property(nonatomic) BOOL isRootLeak; // @synthesize isRootLeak=_isRoot;
@property(nonatomic) unsigned int reachableCount; // @synthesize reachableCount=_reachableCount;
@property(nonatomic) unsigned int reachableSize; // @synthesize reachableSize=_reachableSize;
@property(copy, nonatomic) NSData *content; // @synthesize content=_content;
@property(nonatomic) unsigned long long allocationTimestamp; // @synthesize allocationTimestamp=_allocationTimestamp;
@property(nonatomic) unsigned int allocationIdentifier; // @synthesize allocationIdentifier=_allocationIdentifier;
@property(readonly) unsigned long long discoveryTimestamp; // @synthesize discoveryTimestamp=_discoveryTimestamp;
@property(readonly) unsigned long long remoteIsa; // @synthesize remoteIsa=_remoteIsa;
@property(readonly) unsigned int size; // @synthesize size=_remoteSize;
@property(readonly) unsigned long long address; // @synthesize address=_remoteAddress;
@property(readonly) NSString *name;
@property(readonly) unsigned int count;
@property(readonly) NSString *displayAddress;
@property(readonly) NSString *className;
- (unsigned long long)timestamp;
- (BOOL)isEqual:(id)arg1;
- (id)copyWithZone:(struct _NSZone *)arg1;
- (id)initWithCoder:(id)arg1;
- (void)encodeWithCoder:(id)arg1;
- (id)initWithAddress:(unsigned long long)arg1 size:(unsigned int)arg2 classInfoIndex:(unsigned int)arg3 classInfo:(id)arg4 discoveryTimestamp:(unsigned long long)arg5;

@end

// 可以通过获取内存，查找到指定的 XRRun 以分析数据。
@interface XRLeaksRun : XRRun
{
    XRBacktraceRepository *_repository;
    NSMutableArray *_allLeaks;
    NSMutableArray *_cyclicLeaks;
//    CDStruct_fc8fca5f _allReferences;
//    DVT_VMUClassInfoMap *_knownLayouts;
    NSMutableArray *_leakSnapshotInfo;
    unsigned long long _firstLeakTime;
//    XRObjectAllocRunSharedData *_oaData;
    BOOL _backtracesAvailable;
    BOOL _referencesAvailable;
    NSMapTable *_btAggregatedLeaks;
    NSString *_status;
    struct __CFDictionary *_addressToLeak;
    unsigned long long _latestTimestamp;
    NSArray *_filterTokens;
    BOOL _filterOr;
//    struct XRTimeRange _activeTimeRange;
//    NSMutableArray *_failedLookups;
//    XRLeaksReceiver *_dataReceiver;
    int _pid;
    unsigned int _options;
    BOOL _autoLeaksEnabled;
    unsigned long long _autoLeaksInterval;
    unsigned long long _autoLeaksTriggerTime;
    NSObject<OS_dispatch_source> *_timerSource;
    NSObject<OS_dispatch_queue> *_workerQueue;
    unsigned long long _legacyStartTime;
}

+ (void)initialize;
@property(readonly) unsigned long long firstLeakTime; // @synthesize firstLeakTime=_firstLeakTime;
@property(readonly) NSArray *leakSnapshotInfo; // @synthesize leakSnapshotInfo=_leakSnapshotInfo;
@property(readonly) BOOL backtracesAvailable; // @synthesize backtracesAvailable=_backtracesAvailable;
@property(readonly) BOOL referencesAvailable; // @synthesize referencesAvailable=_referencesAvailable;
@property(readonly) NSArray *allLeaks; // @synthesize allLeaks=_allLeaks;
@property(readonly) unsigned long long latestTimestamp; // @synthesize latestTimestamp=_latestTimestamp;
@property(nonatomic) unsigned long long autoLeaksInterval; // @synthesize autoLeaksInterval=_autoLeaksInterval;
@property(nonatomic) BOOL autoLeaksEnabled; // @synthesize autoLeaksEnabled=_autoLeaksEnabled;
@property(readonly, copy) NSString *statusString; // @synthesize statusString=_status;
//- (void).cxx_destruct;
//- (id)operation:(id)arg1 commentsForSymbol:(id)arg2 inSourceManager:(id)arg3 callTreeInformation:(id)arg4;
//- (void)filterWithTokens:(id)arg1 matchesAny:(BOOL)arg2;
//- (void)setSelectedTimeRange:(struct XRTimeRange)arg1;
//- (CDUnknownBlockType)_activeFilter;
- (id)backtracesForCategory:(id)arg1 timeRange:(struct XRTimeRange)arg2 savedIndex:(unsigned long long *)arg3;
- (id)backtraceRepository;
- (id)backtraceForLeak:(id)arg1;
- (void)stopWithReceiverError:(id)arg1;
- (id)eventHistoryForPointer:(unsigned long long)arg1;
- (id)inverseReferencesForLeak:(id)arg1;
- (id)referencesForLeak:(id)arg1;
- (id)infoForIsa:(unsigned long long)arg1;
//- (void)_enumerateLeakReferences:(id)arg1 inverse:(BOOL)arg2 withBlock:(CDUnknownBlockType)arg3;
//- (id)leakReferenceFromInfo:(CDStruct_0a4d7299)arg1;
- (id)leakWithAddress:(unsigned long long)arg1;
@property(readonly) NSArray *cyclicLeaks;
@property(readonly) NSArray *rootLeaks;
@property(readonly) NSArray *aggregatedLeaks;
//@property(readonly) XRMetadataTagTable *pairingTable;
@property(readonly) BOOL historiesAvailable;
- (void)_updateStatusString;
//- (void)_handleNewLeaks:(CDStruct_cbbc06c7 *)arg1 ofCount:(unsigned int)arg2 withContents:(id *)arg3 references:(CDStruct_fc8fca5f)arg4 layouts:(id)arg5 timestamp:(unsigned long long)arg6;
- (void)_aggregateLeakByBacktrace:(id)arg1;
- (void)_assignBacktracesToLeaks:(id)arg1 time:(unsigned long long)arg2;
- (void)stopRecording;
- (void)requestLeaksCheck;
- (BOOL)recordWithDevice:(id)arg1 pid:(int)arg2 objectAllocInstrument:(id)arg3;
- (void)_armTimer;
@property(nonatomic) BOOL recordLeakContents;
- (id)initWithCoder:(id)arg1;
- (void)encodeWithCoder:(id)arg1;
- (void)dealloc;
- (id)init;
- (void)_commonLeaksRunSetup;

// Remaining properties
@property(readonly, copy) NSString *debugDescription;
@property(readonly, copy) NSString *description;
@property(readonly) unsigned long long hash;
@property(readonly) Class superclass;

@end




//@interface XRVideoCardRun : XRRun {
//    NSArrayController *_controller;
//}
//@end
//
//@interface XRVideoCardInstrument : XRLegacyInstrument
//@end

//@interface XRNetworkAddressFormatter : NSFormatter
//@end
//
//@interface XRNetworkingInstrument : XRLegacyInstrument {
//    XRContext * __strong *_topLevelContexts;
//    NSArrayController * __strong *_controllersByTable;
//    XRNetworkAddressFormatter *_localAddrFmtr;
//    XRNetworkAddressFormatter *_remoteAddrFmtr;
//}
//- (void)selectedRunRecomputeSummaries;
//@end

//typedef struct {
//    XRTimeRange range;
//    UInt64 idx;
//    UInt32 recno;
//} XRPowerTimelineEntry;
//
//@interface XRPowerTimeline : NSObject
//- (UInt64)count;
//- (UInt64)lastIndex;
//- (XRTime)lastTimeOffset;
//- (void)enumerateTimeRange:(XRTimeRange)timeRange sequenceNumberRange:(NSRange)numberRange block:(void (^)(const XRPowerTimelineEntry *entry, BOOL *stop))block;
//@end
//
//@interface XRPowerStreamDefinition : NSObject
//- (UInt64)columnsInDataStreamCount;
//@end
//
//@interface XRPowerDatum : NSObject
//- (XRTimeRange)time;
//- (NSString *)labelForColumn:(SInt64)column;
//- (id)objectValueForColumn:(SInt64)column;
//@end
//
//@interface XRPowerDetailController : NSObject
//- (XRPowerDatum *)datumAtObjectIndex:(UInt64)index;
//@end
//
//@interface XRStreamedPowerInstrument : XRLegacyInstrument {
//    XRPowerDetailController *_detailController;
//}
//- (XRPowerStreamDefinition *)definitionForCurrentDetailView;
//- (XRPowerTimeline *)selectedEventTimeline;
//@end




typedef void (^CDUnknownBlockType)(void);

@interface XRAnalysisCoreQueryManager : NSObject
+ (BOOL)isTicketDestination:(id)arg1;
+ (id)queryPanelAccessTicketForCore:(id)arg1;
+ (int)_identifierForSignposting;
+ (BOOL)_establishesAffinity;
+ (BOOL)_enableConcurrentActivities;
- (void)_escortMinorFrameAgentToExit:(id)arg1;
- (void)_prepareMinorFrameAgent:(id)arg1;
- (void)setupVisitWithQueryPanel:(id)arg1 agent:(id)arg2 mode:(id)arg3;
- (id)changeSortDescriptors:(id)arg1 array:(id)arg2;
- (id)refreshPivotArray:(id)arg1;
- (id)refreshRowArray:(id)arg1;
- (void)randomAccessForTableID:(unsigned int)arg1 block:(CDUnknownBlockType)arg2;
- (void)query:(id)arg1 tableID:(unsigned int)arg2 handler:(id)arg3;
- (id)asyncQuery:(id)arg1 tableID:(unsigned int)arg2 handler:(id)arg3;
- (id)selectRowsWithQuery:(id)arg1 core:(id)arg2 tableID:(unsigned int)arg3 sortDescriptors:(id)arg4;
- (id)selectRowsWithQuery:(id)arg1 core:(id)arg2 tableID:(unsigned int)arg3;

@end

@interface XRAnalysisCoreTableSchema : NSObject {
    NSString *_name;
}
@property(readonly) unsigned long long columnCount;
@end

@interface XRAnalysisCoreTable : NSObject
@property(readonly, nonatomic) XRAnalysisCoreTableSchema *schema;
@end

@interface XRAnalysisCoreBindingHemisphere : NSObject
- (void)query:(id)arg1 tableID:(unsigned int)arg2 handler:(id)arg3 activity:(id)arg4;
- (XRAnalysisCoreTable *)tableWithID:(unsigned int)arg1;
- (id)requiredTableSpecForID:(unsigned int)arg1;
- (void)removeObsoleteStores;
- (void)removeRequiredTableWithID:(unsigned int)arg1;
- (unsigned int)addRequiredTableWithSpec:(id)arg1;
@end


@interface XRAnalysisCore : NSObject
- (XRAnalysisCorePivotArray *)selectRowsWithQuery:(id)arg1 tableID:(unsigned int)arg2;
- (XRAnalysisCoreTable *)tableWithID:(unsigned int)arg1;
@end

