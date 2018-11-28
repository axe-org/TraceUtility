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
@end

@interface PFTInstrumentType : NSObject
- (NSString *)uuid;
- (NSString *)name;
- (NSString *)category;
@end

@protocol XRInstrumentViewController;

@interface XRInstrument : NSObject
- (PFTInstrumentType *)type;
- (id<XRInstrumentViewController>)viewController;
- (void)setViewController:(id<XRInstrumentViewController>)viewController;
- (NSArray<XRRun *> *)allRuns;
- (XRRun *)currentRun;
- (void)setCurrentRun:(XRRun *)run;
@end

@interface PFTInstrumentList : NSObject
- (NSArray<XRInstrument *> *)allInstruments;
@end

@interface XRTrace : NSObject
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

@interface PFTCallTreeNode : NSObject
- (NSString *)libraryName;
- (NSString *)symbolName;
- (UInt64)address;
- (NSArray *)symbolNamePath; // Call stack
- (instancetype)root;
- (instancetype)parent;
- (NSArray *)children;
- (SInt32)numberChildren;
- (SInt32)terminals; // An integer value of this node, such as self running time in millisecond.
- (SInt32)count; // Total value of all nodes of the subtree whose root node is this node. It means that if you increase terminals by a value, count will also be increased by the same value, and that the value of count is calculated automatically and you connot modify it.
- (UInt64)weightCount; // Count of different kinds of double values;
- (Float64)selfWeight:(UInt64)index; // A double value similar to terminal at the specific index.
- (Float64)weight:(UInt64)index; // A double value similar to count at the specific index. The difference is that you decide how weigh should be calculated.
- (Float64)selfCountPercent; // self.terminal / root.count
- (Float64)totalCountPercent; // self.count / root.count
- (Float64)parentCountPercent; // parent.count / root.count
- (Float64)selfWeightPercent:(UInt64)index; // self.selfWeight / root.weight
- (Float64)totalWeightPercent:(UInt64)index; // self.weight / root.weight
- (Float64)parentWeightPercent:(UInt64)index; // parent.weight / root.weight
@end

@interface XRBacktraceRepository : NSObject
- (PFTCallTreeNode *)rootNode;
- (id)libraryForAddress:(unsigned long long)arg1;
- (id)symbolForPC:(unsigned long long)arg1;
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
@end

@interface XRAnalysisCoreTableViewControllerResponse : NSObject
- (XRAnalysisCorePivotArray *)rows;
@end

@interface DTRenderableContentResponse : NSObject
- (XRAnalysisCoreTableViewControllerResponse *)content;
@end

@interface XRAnalysisCoreTableViewController : NSViewController <XRFilteredDataSource, XRSearchTarget>
- (DTRenderableContentResponse *)_currentResponse;
@end

@interface XRManagedEventArrayController : NSArrayController
@end

@interface XRLegacyInstrument : XRInstrument <XRInstrumentViewController, XRContextContainer>
- (NSArray<XRContext *> *)_permittedContexts;
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

@interface XRObjectAllocEventViewController : NSObject {
    XRManagedEventArrayController *_ac;
}
@end

@interface XRObjectAllocInstrument : XRLegacyInstrument {
    XRObjectAllocEventViewController *_objectListController;
}
- (NSArray<XRContext *> *)_topLevelContexts;
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
