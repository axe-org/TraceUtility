//
//  main.m
//  TraceUtility
//
//  Created by Qusic on 7/9/15.
//  Copyright (c) 2015 Qusic. All rights reserved.
#import "InstrumentsPrivateHeader.h"
#import <objc/runtime.h>

static void TUPrint(NSString *format, ...) {
    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    printf("%s\n",[message UTF8String]);
}

static void TUFPrint(FILE *fp,NSString *format, ...) {
    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    if (fp) {
        fprintf(fp, "%s\n",[message UTF8String]);
    } else {
        printf("%s\n",[message UTF8String]);
    }
    
}

#pragma mark - hook instruments

#define TUIvarCast(object, name, type) (*(type *)(void *)&((char *)(__bridge void *)object)[ivar_getOffset(class_getInstanceVariable(object_getClass(object), #name))])
#define TUIvar(object, name) TUIvarCast(object, name, id const)

// Workaround to fix search paths for Instruments plugins and packages.
static NSBundle *(*NSBundle_mainBundle_original)(id self, SEL _cmd);
static NSBundle *NSBundle_mainBundle_replaced(id self, SEL _cmd) {
    return [NSBundle bundleWithPath:@"/Applications/Xcode.app/Contents/Applications/Instruments.app"];
}

static void __attribute__((constructor)) hook() {
    Method NSBundle_mainBundle = class_getClassMethod(NSBundle.class, @selector(mainBundle));
    NSBundle_mainBundle_original = (void *)method_getImplementation(NSBundle_mainBundle);
    method_setImplementation(NSBundle_mainBundle, (IMP)NSBundle_mainBundle_replaced);
}

#pragma mark parse arguments
static NSString *tracePath;
static NSString *outputPath;

static void printUsage () {
    TUPrint(@"TraceUtil: 0.1 \n Usage: TraceUtil trace-document-path [options]\n  options are:");
    TUPrint(@"-o <dir> output directory , or just print in stdout without path setting");
}

static BOOL parseArguments(NSArray<NSString *> *arguments) {
    if (arguments.count % 2 != 0) {
        printUsage();
        return NO;
    }
    tracePath = arguments[1];
    if (![[NSFileManager defaultManager] fileExistsAtPath:tracePath]) {
        TUPrint(@".trace文件不存在, 找不到 %@", tracePath);
        printUsage();
        return NO;
    }
    if (arguments.count > 2) {
        if ([arguments[2] isEqualToString:@"-o"]) {
            outputPath = arguments[3];
            if (![[NSFileManager defaultManager] fileExistsAtPath:outputPath]) {
                NSError *error;
                [[NSFileManager defaultManager] createDirectoryAtPath:outputPath withIntermediateDirectories:YES attributes:nil error:&error];
                if (error) {
                    TUPrint(@"error : %@", error);
                    printUsage();
                    return NO;
                }
            }
        }
    }
    return YES;
}

#pragma mark - export data from instruments
void exportTimeProfilerData(NSMutableArray<XRContext *> *contexts) {
    FILE *fp = NULL;
    if (outputPath) {
        NSString *timeProfileFile = [outputPath stringByAppendingPathComponent:@"timeprofiler.txt"];
        fp = fopen(timeProfileFile.UTF8String, "w+");
    }
    // Time Profiler: print out all functions in descending order of self execution time.
    // 3 contexts: Profile, Narrative, Samples
    XRContext *context = contexts[0];
    [context display];
    XRAnalysisCoreCallTreeViewController *controller = TUIvar(context.container, _callTreeViewController);
    XRBacktraceRepository *backtraceRepository = TUIvar(controller, _backtraceRepository);
    static NSMutableArray<PFTCallTreeNode *> * (^ const flattenTree)(PFTCallTreeNode *) = ^(PFTCallTreeNode *rootNode) { // Helper function to collect all tree nodes.
        NSMutableArray *nodes = [NSMutableArray array];
        if (rootNode) {
            [nodes addObject:rootNode];
            for (PFTCallTreeNode *node in rootNode.children) {
                [nodes addObjectsFromArray:flattenTree(node)];
            }
        }
        return nodes;
    };
    NSMutableArray<PFTCallTreeNode *> *nodes = flattenTree(backtraceRepository.rootNode);

    TUFPrint(fp, @"thread|symbol|count|numberChildren|image");
    for (PFTCallTreeNode *node in nodes) {
        NSArray *symbolNamePath = [node symbolNamePath];
        if (symbolNamePath.count > 1) {
            TUFPrint(fp, @"%@|%@|%@|%@|%@", symbolNamePath[1] , node.symbolName, @(node.count), @(node.numberChildren), node.libraryName.lastPathComponent);
        }
    }
    fclose(fp);
//    TODO 获取函数调用时间。
//    XRContext *context = contexts[1];
//    [context display];
//    XRAnalysisCoreDetailViewController *detailVC = TUIvar(TUIvar(instrument, _viewController), _detailController);
//    XRAnalysisCoreTableViewController *controller = TUIvar(detailVC, _tabularViewController);
//    id provider = TUIvar(controller, _provider);
//    id activeResponse = TUIvar(provider, _activeResponse);
//    id content = TUIvar(activeResponse, _content);
//    XRAnalysisCorePivotArray *array = TUIvar(content, _rows);
//    XRTraceEngineeringTypeFormatter *formatter = (XRTraceEngineeringTypeFormatter *)TUIvarCast(array.source, _filter, XRAnalysisCoreTableQuery * const).fullTextSearchSpec.formatter;
//    TUFPrint(fp, @"time,thread,process,weight,backtrace");
//    [array access:^(XRAnalysisCorePivotArrayAccessor *accessor) {
//        [accessor readRowsStartingAt:0 dimension:0 block:^(XRAnalysisCoreReadCursor *cursor) {
//            while (XRAnalysisCoreReadCursorNext(cursor)) {
//                BOOL result = NO;
//                XRAnalysisCoreValue *object = nil;
//                result = XRAnalysisCoreReadCursorGetValue(cursor, 0, &object);
//                NSString *timestamp = result ? [formatter stringForObjectValue:object] : @"";
//                result = XRAnalysisCoreReadCursorGetValue(cursor, 1, &object);
//                NSString *thread = result ? [formatter stringForThreadEngineeringValue:object] : @"";
//                result = XRAnalysisCoreReadCursorGetValue(cursor, 2, &object);
//                NSString *process = result ? [formatter stringForProcessEngineeringValue:object] : @"";
//                result = XRAnalysisCoreReadCursorGetValue(cursor, 3, &object);
//                NSString *weight = result ? [formatter stringForObjectValue:object] : @"";
//                result = XRAnalysisCoreReadCursorGetValue(cursor, 4, &object);
//                NSString *backtrace = result ? [formatter stringForBacktraceEngineeringValue:object] : @"";
//                result = XRAnalysisCoreReadCursorGetValue(cursor, 5, &object);
//                NSString *backtrace5 = result ? [formatter stringForBacktraceEngineeringValue:object] : @"";
//                result = XRAnalysisCoreReadCursorGetValue(cursor, 6, &object);
//                NSString *backtrace6 = result ? [formatter stringForBacktraceEngineeringValue:object] : @"";
//                result = XRAnalysisCoreReadCursorGetValue(cursor, 7, &object);
//                NSString *backtrace7 = result ? [formatter stringForBacktraceEngineeringValue:object] : @"";
//                result = XRAnalysisCoreReadCursorGetValue(cursor, 8, &object);
//                NSString *backtrace8 = result ? [formatter stringForBacktraceEngineeringValue:object] : @"";
//                TUFPrint(fp, @"%@,%@,%@,%@,%@,%@,%@,%@,%@", timestamp, thread, process, weight, backtrace, backtrace5, backtrace6, backtrace7, backtrace8);
//            }
//        }];
//    }];
//    fclose(fp);
}


void exportFPSData(NSMutableArray<XRContext *> *contexts) {
    FILE *fp = NULL;
    if (outputPath) {
        NSString *timeProfileFile = [outputPath stringByAppendingPathComponent:@"fps.txt"];
        fp = fopen(timeProfileFile.UTF8String, "w+");
    }
    XRContext *context = contexts[0];
    [context display];
    XRAnalysisCoreTableViewController *controller = TUIvar(context.container, _tabularViewController);
    XRAnalysisCorePivotArray *array = controller._currentResponse.content.rows;
    XREngineeringTypeFormatter *formatter = TUIvarCast(array.source, _filter, XRAnalysisCoreTableQuery * const).fullTextSearchSpec.formatter;
    TUFPrint(fp, @"timestamp|period|symbol|fps|gpu");
    [array access:^(XRAnalysisCorePivotArrayAccessor *accessor) {
        [accessor readRowsStartingAt:0 dimension:0 block:^(XRAnalysisCoreReadCursor *cursor) {
            while (XRAnalysisCoreReadCursorNext(cursor)) {
                BOOL result = NO;
                XRAnalysisCoreValue *object = nil;
                // 注意这里取值， 并不是从界面中取值，而是从XRAnalysisCore 中。 所以访问的表为 schema ,index为schema中的列的序号，而不是instruments界面上展示的顺序.
                result = XRAnalysisCoreReadCursorGetValue(cursor, 0, &object);
                NSString *timestamp = result ? [formatter stringForObjectValue:object] : @"";
                result = XRAnalysisCoreReadCursorGetValue(cursor, 1, &object);
                NSString *period = result ? object.objectValue : @0;
                result = XRAnalysisCoreReadCursorGetValue(cursor, 2, &object);
                double fps = result ? [object.objectValue doubleValue] : 0;
                result = XRAnalysisCoreReadCursorGetValue(cursor, 3, &object);
                double gpu = result ? [object.objectValue doubleValue] : 0;
                TUFPrint(fp, @"%@|%@|%2.0f|%4.1f%", timestamp, period, fps, gpu);
            }
        }];
    }];
    fclose(fp);
}

void exportNetworkData(NSMutableArray<XRContext *> *contexts) {
    FILE *fp = NULL;
    if (outputPath) {
        NSString *timeProfileFile = [outputPath stringByAppendingPathComponent:@"network.txt"];
        fp = fopen(timeProfileFile.UTF8String, "w+");
    }
    XRContext *context = contexts[0];
    [context display];
    XRAnalysisCoreTableViewController *controller = TUIvar(context.container, _tabularViewController);
    XRAnalysisCorePivotArray *array = controller._currentResponse.content.rows;
    XREngineeringTypeFormatter *formatter = TUIvarCast(array.source, _filter, XRAnalysisCoreTableQuery * const).fullTextSearchSpec.formatter;
    TUFPrint(fp, @"timestamp|interval|serialNumber|owner|interface|protocol|local|remote|packetsIn|bytesIn|packetsOut|bytesOut|mrtt|artt");
    [array access:^(XRAnalysisCorePivotArrayAccessor *accessor) {
        [accessor readRowsStartingAt:0 dimension:0 block:^(XRAnalysisCoreReadCursor *cursor) {
            while (XRAnalysisCoreReadCursorNext(cursor)) {
                BOOL result = NO;
                XRAnalysisCoreValue *object = nil;
                // 注意这里取值， 并不是从界面中取值，而是从XRAnalysisCore 中。 所以访问的表为 schema ,index为schema中的列的序号，而不是instruments界面上展示的顺序.
                result = XRAnalysisCoreReadCursorGetValue(cursor, 0, &object);
                NSString *timestamp = result ? [formatter stringForObjectValue:object] : @"";
                result = XRAnalysisCoreReadCursorGetValue(cursor, 1, &object);
                NSString *interval = result ? object.objectValue : @0;
                result = XRAnalysisCoreReadCursorGetValue(cursor, 2, &object);
                NSString *serialNumber = result ? [formatter stringForObjectValue:object] : @"";
                result = XRAnalysisCoreReadCursorGetValue(cursor, 3, &object);
                NSString *owner = result ? [formatter stringForObjectValue:object] : @"";
                result = XRAnalysisCoreReadCursorGetValue(cursor, 4, &object);
                NSString *interface = result ? [formatter stringForObjectValue:object] : @"";
                result = XRAnalysisCoreReadCursorGetValue(cursor, 5, &object);
                NSString *protocol = result ? [formatter stringForObjectValue:object] : @"";
                result = XRAnalysisCoreReadCursorGetValue(cursor, 6, &object);
                NSString *local = result ? [formatter stringForObjectValue:object] : @"";
                result = XRAnalysisCoreReadCursorGetValue(cursor, 7, &object);
                NSString *remote = result ? [formatter stringForObjectValue:object] : @"";
                result = XRAnalysisCoreReadCursorGetValue(cursor, 9, &object);
                NSNumber *packetsIn = result ? object.objectValue : @0;
                result = XRAnalysisCoreReadCursorGetValue(cursor, 10, &object);
                NSNumber *bytesIn = result ? object.objectValue : @0;
                result = XRAnalysisCoreReadCursorGetValue(cursor, 11, &object);
                NSNumber *packetsOut = result ? object.objectValue : @0;
                result = XRAnalysisCoreReadCursorGetValue(cursor, 12, &object);
                NSNumber *bytesOut = result ? object.objectValue : @0;
                result = XRAnalysisCoreReadCursorGetValue(cursor, 16, &object);
                NSNumber *mrtt = result ? object.objectValue : @0;
                result = XRAnalysisCoreReadCursorGetValue(cursor, 17, &object);
                NSNumber *artt = result ? object.objectValue : @0;
                
                TUFPrint(fp, @"%@|%@|%@|%@|%@|%@|%@|%@|%@|%@|%@|%@|%@|%@", timestamp, interval, serialNumber, owner, interface,
                         protocol, local, remote, packetsIn, bytesIn, packetsOut, bytesOut, mrtt,artt);
            }
        }];
    }];
    fclose(fp);
}


void exportActivityData(NSMutableArray<XRContext *> *contexts) {
    FILE *fp = NULL;
    if (outputPath) {
        NSString *timeProfileFile = [outputPath stringByAppendingPathComponent:@"activity.txt"];
        fp = fopen(timeProfileFile.UTF8String, "w+");
    }
    XRContext *context = contexts[0];
    [context display];
    XRAnalysisCoreTableViewController *controller = TUIvar(context.container, _tabularViewController);
    XRAnalysisCorePivotArray *array = controller._currentResponse.content.rows;
    XREngineeringTypeFormatter *formatter = TUIvarCast(array.source, _filter, XRAnalysisCoreTableQuery * const).fullTextSearchSpec.formatter;
    TUFPrint(fp, @"timestamp|interval|cpu|userTime|memory|diskRead|diskWrite");
    [array access:^(XRAnalysisCorePivotArrayAccessor *accessor) {
        [accessor readRowsStartingAt:0 dimension:0 block:^(XRAnalysisCoreReadCursor *cursor) {
            while (XRAnalysisCoreReadCursorNext(cursor)) {
                BOOL result = NO;
                XRAnalysisCoreValue *object = nil;
                // 注意这里取值， 并不是从界面中取值，而是从XRAnalysisCore 中。 所以访问的表为 schema ,index为schema中的列的序号，而不是instruments界面上展示的顺序.
                result = XRAnalysisCoreReadCursorGetValue(cursor, 0, &object);
                NSString *timestamp = result ? [formatter stringForObjectValue:object] : @"";
                result = XRAnalysisCoreReadCursorGetValue(cursor, 1, &object);
                NSString *interval = result ? object.objectValue : @0;
                result = XRAnalysisCoreReadCursorGetValue(cursor, 10, &object);
                NSNumber *cpu = result ? object.objectValue : @0;
                result = XRAnalysisCoreReadCursorGetValue(cursor, 12, &object);
                NSNumber *userTime = result ? object.objectValue : @0;
                result = XRAnalysisCoreReadCursorGetValue(cursor, 18, &object);
                NSNumber *memory = result ? object.objectValue : @0;
                result = XRAnalysisCoreReadCursorGetValue(cursor, 13, &object);
                NSNumber *diskRead = result ? object.objectValue : @0;
                result = XRAnalysisCoreReadCursorGetValue(cursor, 14, &object);
                NSNumber *diskWrite = result ? object.objectValue : @0;
                
                TUFPrint(fp, @"%@|%@|%@|%@|%@|%@|%@", timestamp, interval, cpu, userTime, memory, diskRead, diskWrite);
            }
        }];
    }];
    fclose(fp);
}

void exportMemoryData(NSMutableArray<XRContext *> *contexts) {
    FILE *fp = NULL;
    if (outputPath) {
        NSString *timeProfileFile = [outputPath stringByAppendingPathComponent:@"memory.txt"];
        fp = fopen(timeProfileFile.UTF8String, "w+");
    }
    XRContext *context = contexts[0];
    [context display];
    XRAnalysisCoreTableViewController *controller = TUIvar(context.container, _tabularViewController);
    XRAnalysisCorePivotArray *array = controller._currentResponse.content.rows;
    XREngineeringTypeFormatter *formatter = TUIvarCast(array.source, _filter, XRAnalysisCoreTableQuery * const).fullTextSearchSpec.formatter;
    TUFPrint(fp, @"timestamp|interval|cpu|userTime");
    [array access:^(XRAnalysisCorePivotArrayAccessor *accessor) {
        [accessor readRowsStartingAt:0 dimension:0 block:^(XRAnalysisCoreReadCursor *cursor) {
            while (XRAnalysisCoreReadCursorNext(cursor)) {
                BOOL result = NO;
                XRAnalysisCoreValue *object = nil;
                // 注意这里取值， 并不是从界面中取值，而是从XRAnalysisCore 中。 所以访问的表为 schema ,index为schema中的列的序号，而不是instruments界面上展示的顺序.
                result = XRAnalysisCoreReadCursorGetValue(cursor, 0, &object);
                NSString *timestamp = result ? [formatter stringForObjectValue:object] : @"";
                result = XRAnalysisCoreReadCursorGetValue(cursor, 1, &object);
                NSString *interval = result ? object.objectValue : @0;
                result = XRAnalysisCoreReadCursorGetValue(cursor, 10, &object);
                NSNumber *cpu = result ? object.objectValue : @0;
                result = XRAnalysisCoreReadCursorGetValue(cursor, 12, &object);
                NSNumber *userTime = result ? object.objectValue : @0;
                
                TUFPrint(fp, @"%@|%@|%@|%@", timestamp, interval, cpu, userTime);
            }
        }];
    }];
    fclose(fp);
}

void exportLeaksData(XRInstrument *instrument) {
    FILE *fp = NULL;
    if (outputPath) {
        NSString *timeProfileFile = [outputPath stringByAppendingPathComponent:@"leaks.txt"];
        fp = fopen(timeProfileFile.UTF8String, "w+");
    }
    // 内存泄漏检测, 有些不够精准。
    // 可以通过断点，查找内存元素来快速发现数据路径。
    XRLeaksRun *run = [instrument valueForKeyPath:@"_run"];
    XRBacktraceRepository *respository = run.backtraceRepository;
    NSArray<XRLeak *> *allLeaks = [run valueForKeyPath:@"_allLeaks"];
    TUFPrint(fp, @"allocationTimestamp|discoveryTimestamp|name|address|symbol|size|count|image");
    for (XRLeak *leak in allLeaks) {
        // 打印泄漏，需要过滤
        NSString *binaryImageName = [leak valueForKeyPath:@"_layout.binaryName"];
        
        // 寻找需要展示的堆栈信息。
        NSString *symbol = @"";
        unsigned long long *frames = leak.backtrace.frames;
        // 堆栈数量。
        NSInteger frameCount = leak.backtrace.count;
        // TODO这里会有 binaryImage为空的情况。
        if (binaryImageName) {
            for (NSInteger i = 0; i < frameCount; i ++) {
                unsigned long long frame = frames[i];
                PFTOwnerData *ownerData = [respository libraryForAddress:frame];
                NSString *imageName = [ownerData libraryName];
                if ([imageName isEqualToString:binaryImageName]) {
                    symbol = [respository symbolForPC:frame];
                    break;
                }
            }
        } else {
            // TODO binaryImage 为空时，暂时无法分析调用函数的来源，所以暂时不输出该类型。
            continue;
        }
        TUFPrint(fp, @"%@|%@|%@|%@|%@|%@|%@|%@", @(leak.allocationTimestamp), @(leak.discoveryTimestamp), leak.className,
                leak.displayAddress, symbol, @(leak.size),@(leak.count),binaryImageName);
    }
    fclose(fp);
}

// TODO 未搞定 allocations
//void exportAllocationData (XRObjectAllocInstrument *instrument) {
//    FILE *fp = NULL;
//    if (outputPath) {
//        NSString *timeProfileFile = [outputPath stringByAppendingPathComponent:@"allocation.txt"];
//        fp = fopen(timeProfileFile.UTF8String, "w+");
//    }
//    XRContext *context = instrument._topLevelContexts[1];
//    [context display];
//    XRAnalysisCoreCallTreeViewController *controller = TUIvar(context.container, _callTreeViewController);
//    XRBacktraceRepository *backtraceRepository = TUIvar(controller, _backtraceRepository);
//
//    static NSMutableArray<PFTCallTreeNode *> * (^ const flattenTree)(PFTCallTreeNode *) = ^(PFTCallTreeNode *rootNode) { // Helper function to collect all tree nodes.
//        NSMutableArray *nodes = [NSMutableArray array];
//        if (rootNode) {
//            [nodes addObject:rootNode];
//            for (PFTCallTreeNode *node in rootNode.children) {
//                [nodes addObjectsFromArray:flattenTree(node)];
//            }
//        }
//        return nodes;
//    };
//    NSMutableArray<PFTCallTreeNode *> *nodes = flattenTree(backtraceRepository.rootNode);
//
//    TUFPrint(fp, @"thread|symbol|count|numberChildren|image");
//    for (PFTCallTreeNode *node in nodes) {
//        NSArray *symbolNamePath = [node symbolNamePath];
//        if (symbolNamePath.count > 3) {
//            TUFPrint(fp, @"%@|%@|%@|%@|%@", symbolNamePath[3] , node.symbolName, @(node.count), @(node.numberChildren), node.libraryName.lastPathComponent);
//        }
//    }
//    fclose(fp);
//}


int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSArray<NSString *> *arguments = NSProcessInfo.processInfo.arguments;

        if (!parseArguments(arguments)) {
            return 1;
        }
        // Required. Each instrument is a plugin and we have to load them before we can process their data.
        DVTInitializeSharedFrameworks();
        [DVTDeveloperPaths initializeApplicationDirectoryName:@"Instruments"];
        [XRInternalizedSettingsStore configureWithAdditionalURLs:nil];
        [[XRCapabilityRegistry applicationCapabilities]registerCapability:@"com.apple.dt.instruments.track_pinning" versions:NSMakeRange(1, 1)];
        PFTLoadPlugins();

        // Instruments has its own subclass of NSDocumentController without overriding sharedDocumentController method.
        // We have to call this eagerly to make sure the correct document controller is initialized.
        [PFTDocumentController sharedDocumentController];
        // Open a trace document.
        NSError *error = nil;
        PFTTraceDocument *document = [[PFTTraceDocument alloc]initWithContentsOfURL:[NSURL fileURLWithPath:tracePath] ofType:@"com.apple.instruments.trace" error:&error];
        if (error) {
            TUPrint(@"Error: %@", error);
            return 1;
        }

        // List some useful metadata of the document.
//        XRDevice *device = document.targetDevice;
//        TUPrint(@"Device: %@ (%@ %@ %@)\n", device.deviceDisplayName, device.productType, device.productVersion, device.buildVersion);
//        PFTProcess *process = document.defaultProcess;
//        TUPrint(@"Process: %@ (%@)\n", process.displayName, process.bundleIdentifier);

        // Each trace document consists of data from several different instruments.
        XRTrace *trace = document.trace;
        
        for (XRInstrument *instrument in trace.allInstrumentsList.allInstruments) {
//            TUPrint(@"\nInstrument: %@ (%@)\n", instrument.type.name, instrument.type.uuid);

            // Each instrument can have multiple runs.
            NSArray<XRRun *> *runs = instrument.allRuns;
            if (runs.count == 0) {
                TUPrint(@"No data.");
                continue;
            }
            for (XRRun *run in runs) {
                TUPrint(@"Run #%@: %@", @(run.runNumber), run.displayName);
                instrument.currentRun = run;

                // Common routine to obtain contexts for the instrument.
                NSMutableArray<XRContext *> *contexts = [NSMutableArray array];
                if (![instrument isKindOfClass:XRLegacyInstrument.class]) {
                    XRAnalysisCoreStandardController *standardController = [[XRAnalysisCoreStandardController alloc]initWithInstrument:instrument document:document];
                    instrument.viewController = standardController;
                    [standardController instrumentDidChangeSwitches];
                    [standardController instrumentChangedTableRequirements];
                    XRAnalysisCoreDetailViewController *detailController = TUIvar(standardController, _detailController);
                    [detailController restoreViewState];
                    XRAnalysisCoreDetailNode *detailNode = TUIvar(detailController, _firstNode);
                    while (detailNode) {
                        [contexts addObject:XRContextFromDetailNode(detailController, detailNode)];
                        detailNode = detailNode.nextSibling;
                    }
                }
                
                // Different instruments can have different data structure.
                // Here are some straightforward example code demonstrating how to process the data from several commonly used instruments.
                NSString *instrumentID = instrument.type.uuid;
                TUPrint(@"instrumentID : %@", instrumentID);
                if ([instrumentID isEqualToString:@"org.axe.instruments.time-profiler"]) {
                    //com.apple.xray.instrument-type.coresampler2
                    exportTimeProfilerData(contexts);
                } else if ([instrumentID isEqualToString:@"org.axe.instruments.gpu"]) {
                    exportFPSData(contexts);
                } else if ([instrumentID isEqualToString:@"org.axe.instruments.network"]) {
                    exportNetworkData(contexts);
                } else if ([instrumentID isEqualToString:@"org.axe.instruments.system"]) {
                    exportActivityData(contexts);
                } else if ([instrumentID isEqualToString:@"com.apple.xray.instrument-type.oa"]) {
//                    exportAllocationData(instrument);
                } else if ([instrumentID isEqualToString:@"com.apple.xray.instrument-type.homeleaks"]) {
                    exportLeaksData(instrument);
                } else {
                    TUPrint(@"Data processor has not been implemented for this type of instrument.");
                }

                // Common routine to cleanup after done.
                if (![instrument isKindOfClass:XRLegacyInstrument.class]) {
                    [instrument.viewController instrumentWillBecomeInvalid];
                    instrument.viewController = nil;
                }
            }
        }

        // Close the document safely.
        [document close];
        PFTClosePlugins();
    }
    return 0;
}
