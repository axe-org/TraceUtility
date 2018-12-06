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

// 是一个树的结构。
@interface CallNode : NSObject

@property (nonatomic, assign) NSTimeInterval startTime;
@property (nonatomic, strong) NSString *label;
@property (nonatomic, strong) PFTDisplaySymbol *symbol;
@property (nonatomic, strong) CallNode *subNode;
@property (nonatomic, weak) CallNode *parent;

// runLoopType , 为 “__CFRunLoopDoObservers” ，"__CFRunLoopDoBlocks" , "__CFRunLoopDoSources0" , "__CFRUNLOOP_IS_SERVICING_THE_MAIN_DISPATCH_QUEUE__" , "__CFRunLoopDoSource1"
@property (nonatomic, strong) NSString *runLoopType;

// 当子node已有超时的情况下，不考虑父节点的超时。 设置这个属性的原因，是当我们发生新的卡顿时，我们应该优先解决所有小的卡顿问题，再一点一点解决问题。
@property (nonatomic, assign) BOOL ignoreBecauseSubNode;

@end

@implementation CallNode

+ (CallNode *)nodesFromLabels:(NSArray *)labels startTime:(NSTimeInterval)startTime {
    if (labels.count == 0) {
        return nil;
    }
    // 先检测RunLoop.
    NSArray *runLoopTypes = @[@"__CFRunLoopDoObservers", @"__CFRunLoopDoBlocks", @"__CFRunLoopDoSources0", @"__CFRunLoopDoSource1", @"__CFRUNLOOP_IS_SERVICING_THE_MAIN_DISPATCH_QUEUE__"];
    NSString *runLoopType;
    for (PFTDisplaySymbol *symbol in labels) {
        if ([runLoopTypes containsObject:[symbol symbolNameForDisplay]]) {
            runLoopType = [symbol symbolNameForDisplay];
            break;
        }
    }
    // 如果没有runLoopType，则进行忽略。
    if (!runLoopType) {
        return nil;
    }
    CallNode *root;
    CallNode *prev;
    for (PFTDisplaySymbol *symbol in labels) {
        // 过滤 System library
        if ([symbol.libraryPath containsString:@"Library/Developer/Xcode/iOS DeviceSupport"]) {
            // 系统库放在 /Users/xxx/Library/Developer/Xcode/iOS DeviceSupport/12.1 (16B5084a)/Symbols 下，进行简单检测。
            continue;
        }
        CallNode *current = [[CallNode alloc] init];
        current.startTime = startTime;
        current.symbol = symbol;
        current.label = [symbol symbolNameForDisplay];
        current.parent = prev;
        current.runLoopType = runLoopType;
        if (!root) {
            root = current;
        } else {
            prev.subNode = current;
        }
        prev = current;
    }
    root.runLoopType = runLoopType;
    return root;
}

// 找到层次最多的，超过耗时的子孙。
- (CallNode *)findSubNodeAtTime:(NSTimeInterval)time overTimeInterval:(NSTimeInterval)interval {
    if (time - _startTime > interval) {
        CallNode *subFind = [_subNode findSubNodeAtTime:time overTimeInterval:interval];
        if (subFind) {
            return subFind;
        } else {
            // 只有自己时，要判断自己是否有标记。
            return _ignoreBecauseSubNode ? nil : self;
        }
    } else {
        return nil;
    }
}

@end

void exportTimeProfilerData(NSMutableArray<XRContext *> *contexts, XRInstrument *instrument) {
    // timeProfile 输出3份数据，一个是全部，一个是过滤系统库调用，只留有APP相关的调用, 还有一个是 所有APP调用的卡顿情况（目前可能不够精确）。
    FILE *allFp = NULL;
    FILE *filterFP = NULL;
    FILE *blockFP = NULL;
    if (outputPath) {
        NSString *timeProfileFile = [outputPath stringByAppendingPathComponent:@"timeprofiler.txt"];
        allFp = fopen(timeProfileFile.UTF8String, "w+");
        timeProfileFile = [outputPath stringByAppendingPathComponent:@"timeprofiler-filtered.txt"];
        filterFP = fopen(timeProfileFile.UTF8String, "w+");
        timeProfileFile = [outputPath stringByAppendingPathComponent:@"blockedcall.txt"];
        blockFP = fopen(timeProfileFile.UTF8String, "w+");
    }
    // Time Profiler: print out all functions in descending order of self execution time.
    // 3 contexts: Profile, Narrative, Samples
    XRContext *context = contexts[0];
    [context display];
    XRAnalysisCoreCallTreeViewController *controller = TUIvar(context.container, _callTreeViewController);
    XRBacktraceRepository *backtraceRepository = TUIvar(controller, _backtraceRepository);

    static void (^ const traversalNode)(PFTCallTreeNode *, FILE *) = ^(PFTCallTreeNode *node, FILE *fp) { // Helper function to collect all tree nodes.
        if (node) {
            NSString *symbol = [node symbolNameForUse];
            if ([node lineNumberForDisplay]) {
                NSString *sourcePath = [node sourcePath];
                sourcePath = sourcePath.lastPathComponent;
                symbol = [symbol stringByAppendingFormat:@"(%@:%@)", sourcePath, @([node lineNumberForDisplay])];
                // 不知道哪里多出来一个 \x10
                symbol = [symbol stringByReplacingOccurrencesOfString:@"\x10" withString:@""];
            }
            TUFPrint(fp, @"%@|%@|%@|%@|%@|%@", @((long long)node), symbol, [node libraryForDisplay], @((long long)[node parent]), @([node numberChildren]), @(node.count));
            if (node.numberChildren) {
                NSArray *children = [node children];
                for (PFTCallTreeNode *childNode in children) {
                    traversalNode(childNode, fp);
                }
            }
        }
    };
    TUFPrint(allFp, @"id|symbol|library|parent|childCount|count");
    traversalNode(backtraceRepository.rootNode, allFp);
    fclose(allFp);
    // 过滤system.
    XRCallTreeDetailView *detailView = TUIvar(controller, _callTreeView);
    [detailView setValue:@1 forUndefinedKey:@"trimSystemLibraries"];
    TUFPrint(filterFP, @"id|symbol|library|parent|childCount|count");
    traversalNode(backtraceRepository.rootNode, filterFP);
    fclose(filterFP);
    
    // 获取block数据。
    context = contexts[2];
    [context display];
    XRAnalysisCoreDetailViewController *detailVC = TUIvar(TUIvar(instrument, _viewController), _detailController);
    XRAnalysisCoreTableViewController *coreTableViewController = TUIvar(detailVC, _tabularViewController);
    id response = TUIvar(coreTableViewController, __response);
    id content;
    if (response) {
        content = TUIvar(response, _content);
    }
    if (!content) {
        id provider = TUIvar(coreTableViewController, _provider);
        response = TUIvar(provider, _activeResponse);
        content = TUIvar(response, _content);
    }
    XRAnalysisCorePivotArray *array = TUIvar(content, _rows);
    XRTraceEngineeringTypeFormatter *formatter = (XRTraceEngineeringTypeFormatter *)TUIvarCast(array.source, _filter, XRAnalysisCoreTableQuery * const).fullTextSearchSpec.formatter;
    TUFPrint(blockFP, @"time|symbol|library|cost");
    // 目前思路为 ： 以所有非系统库构建树， 去除掉main函数。 同时根据RunLoop状态，进行切换。
    __block CallNode *rootNode;
    static NSTimeInterval checkTimeInterval = 17;// 大于等于17认为发生卡顿。
    // Instruments Time Profiler的原理是每隔一段时间检测一次CPU的状态，然后记录堆栈进行分析。 这个间隔默认为1毫米。
    // 而默认的监控没有记录线程状态，即是否休眠。 导致需要通过一个间隔来区分现场休眠情况。
    // 这个鬼东西的误差在于 IO操作和其他操作，会进行等待。导致无法了解到线程的实际状态。
    // 或者可以考虑通过 黑名单来解决问题？
    static NSTimeInterval maxIntervalInFrame = 10; // 超过10毫秒，则认为主线程发生了休眠，进行清空。
    static NSTimeInterval lastTime = -1000;
    [array access:^(XRAnalysisCorePivotArrayAccessor *accessor) {
        [accessor readRowsStartingAt:0 dimension:0 block:^(XRAnalysisCoreReadCursor *cursor) {
            while (XRAnalysisCoreReadCursorNext(cursor)) {
                BOOL result = NO;
                XRAnalysisCoreValue *object = nil;
                // 取毫秒时间。
                result = XRAnalysisCoreReadCursorGetValue(cursor, 0, &object);
                NSTimeInterval time = [object.objectValue doubleValue] / 1000000;
                result = XRAnalysisCoreReadCursorGetValue(cursor, 1, &object);
                NSString *thread = result ? [formatter stringForThreadEngineeringValue:object] : @"";
                result = XRAnalysisCoreReadCursorGetValue(cursor, 6, &object);
                // 检测是否是主线程。
                if (![thread containsString:@"Main Thread"]) {
                    continue;
                }
                XRBacktraceTypeAdapter *adapter = [[XRBacktraceTypeAdapter alloc] initWithAnalysisCoreValue:object];
                NSArray *labels = [coreTableViewController _objectForStackDataElement:adapter];
                labels = [[labels reverseObjectEnumerator] allObjects];
                if (!rootNode) {
                    rootNode = [CallNode nodesFromLabels:labels startTime:time];
                } else {
                    // 先拿 runLoopType ,判断是否发生变化。
                    CallNode *newRootNode = [CallNode nodesFromLabels:labels startTime:time];
                    // 先检测是否发生了 runLoop 变化。
                    if (time - lastTime > maxIntervalInFrame || ![newRootNode.runLoopType isEqualToString:rootNode.runLoopType]) {
                        // 如果runloop发生变化，我们认为一次调用完成，清理掉之前的堆栈。
                        // 第一个node是 main函数，进行忽略。
                        CallNode *overTimeNode = [rootNode.subNode findSubNodeAtTime:lastTime + 1 overTimeInterval:checkTimeInterval];
                        if (overTimeNode) {
                            NSString *library = [overTimeNode.symbol libraryForDisplay];
                            TUFPrint(blockFP, @"%@|%@|%@|%@", @(overTimeNode.startTime), overTimeNode.label, library, @(time - overTimeNode.startTime));
                        }
                        rootNode = newRootNode;
                    } else {
                        // 如果RunLoop不变。
                        // 检测链路上是否发生变更。
                        CallNode *giveupNode = rootNode;
                        CallNode *prevNode = rootNode;
                        CallNode *newNode = newRootNode;
                        for (NSInteger i = 0; i < labels.count; i++) {
                            if ([newNode.label isEqualToString:giveupNode.label]) {
                                prevNode = giveupNode;
                                giveupNode = giveupNode.subNode;
                                newNode = newNode.subNode;
                            } else {
                                break;
                            }
                        }
                        if (giveupNode) {
                            // 如果有要放弃的节点。 根节点始终是 main.
                            giveupNode.parent.subNode = newNode;
                            newNode.parent = giveupNode.parent;
                            
                        } else if(newNode) {
                            newNode.parent = prevNode;
                            prevNode.subNode = newNode;
                        }
                        if (newNode) {
                            rootNode.runLoopType = newNode.runLoopType;
                        }
                        // 计算giveup连上是否有超时。
                        CallNode *overTimeNode = [giveupNode findSubNodeAtTime:lastTime + 1 overTimeInterval:checkTimeInterval];
                        if (overTimeNode) {
                            // 如果找到了超时节点，要将父类的节点都设置上标记。
                            CallNode *parent = overTimeNode.parent;
                            while (parent) {
                                parent.ignoreBecauseSubNode = YES;
                                parent = parent.parent;
                            }
                            NSString *library = [overTimeNode.symbol libraryForDisplay];
                            TUFPrint(blockFP, @"%@|%@|%@|%@", @(overTimeNode.startTime), overTimeNode.label, library, @(time - overTimeNode.startTime));
                        }
                        
                    }
                }
                lastTime = time;
            }
        }];
    }];
    fclose(blockFP);
}


void exportFPSData(NSMutableArray<XRContext *> *contexts, int64_t startTime) {
    FILE *fp = NULL;
    if (outputPath) {
        NSString *timeProfileFile = [outputPath stringByAppendingPathComponent:@"fps.txt"];
        fp = fopen(timeProfileFile.UTF8String, "w+");
    }
    XRContext *context = contexts[0];
    [context display];
    XRAnalysisCoreTableViewController *controller = TUIvar(context.container, _tabularViewController);
    XRAnalysisCorePivotArray *array = controller._currentResponse.content.rows;
    TUFPrint(fp, @"timestamp|period|fps|gpu");
    [array access:^(XRAnalysisCorePivotArrayAccessor *accessor) {
        [accessor readRowsStartingAt:0 dimension:0 block:^(XRAnalysisCoreReadCursor *cursor) {
            while (XRAnalysisCoreReadCursorNext(cursor)) {
                BOOL result = NO;
                XRAnalysisCoreValue *object = nil;
                // 注意这里取值， 并不是从界面中取值，而是从XRAnalysisCore 中。 所以访问的表为 schema ,index为schema中的列的序号，而不是instruments界面上展示的顺序.
                result = XRAnalysisCoreReadCursorGetValue(cursor, 0, &object);
                // 重置时间。
                int64_t timestamp = startTime + [object.objectValue longLongValue] / 1000000;
                result = XRAnalysisCoreReadCursorGetValue(cursor, 1, &object);
                int64_t period = [object.objectValue longLongValue] / 1000000;
                result = XRAnalysisCoreReadCursorGetValue(cursor, 2, &object);
                double fps = result ? [object.objectValue doubleValue] : 0;
                result = XRAnalysisCoreReadCursorGetValue(cursor, 3, &object);
                double gpu = result ? [object.objectValue doubleValue] : 0;
                TUFPrint(fp, @"%@|%@|%2.0f|%4.1f%", @(timestamp), @(period), fps, gpu);
            }
        }];
    }];
    fclose(fp);
}

void exportNetworkData(NSMutableArray<XRContext *> *contexts, int64_t startTime) {
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
                int64_t timestamp = startTime + [object.objectValue longLongValue] / 1000000;
                result = XRAnalysisCoreReadCursorGetValue(cursor, 1, &object);
                int64_t interval = [object.objectValue longLongValue] / 1000000;
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
                
                TUFPrint(fp, @"%@|%@|%@|%@|%@|%@|%@|%@|%@|%@|%@|%@|%@|%@", @(timestamp), @(interval), serialNumber, owner, interface,
                         protocol, local, remote, packetsIn, bytesIn, packetsOut, bytesOut, mrtt,artt);
            }
        }];
    }];
    fclose(fp);
}


void exportActivityData(NSMutableArray<XRContext *> *contexts, int64_t startTime) {
    FILE *fp = NULL;
    if (outputPath) {
        NSString *timeProfileFile = [outputPath stringByAppendingPathComponent:@"activity.txt"];
        fp = fopen(timeProfileFile.UTF8String, "w+");
    }
    XRContext *context = contexts[0];
    [context display];
    XRAnalysisCoreTableViewController *controller = TUIvar(context.container, _tabularViewController);
    XRAnalysisCorePivotArray *array = controller._currentResponse.content.rows;
    TUFPrint(fp, @"timestamp|interval|cpu|userTime|memory|diskRead|diskWrite");
    [array access:^(XRAnalysisCorePivotArrayAccessor *accessor) {
        [accessor readRowsStartingAt:0 dimension:0 block:^(XRAnalysisCoreReadCursor *cursor) {
            while (XRAnalysisCoreReadCursorNext(cursor)) {
                BOOL result = NO;
                XRAnalysisCoreValue *object = nil;
                // 注意这里取值， 并不是从界面中取值，而是从XRAnalysisCore 中。 所以访问的表为 schema ,index为schema中的列的序号，而不是instruments界面上展示的顺序.
                result = XRAnalysisCoreReadCursorGetValue(cursor, 0, &object);
                int64_t timestamp = startTime + [object.objectValue longLongValue] / 1000000;
                result = XRAnalysisCoreReadCursorGetValue(cursor, 1, &object);
                int64_t interval = [object.objectValue longLongValue] / 1000000;
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
                
                TUFPrint(fp, @"%@|%@|%@|%@|%@|%@|%@", @(timestamp), @(interval), cpu, userTime, memory, diskRead, diskWrite);
            }
        }];
    }];
    fclose(fp);
}

void exportLeaksData(XRLegacyInstrument *instrument, XRContext *context, int64_t startTime) {
    // 内存泄漏检测, 有些不够精准。
    // 可以通过断点，查找内存元素来快速发现数据路径。
    FILE *fp = NULL;
    if (outputPath) {
        NSString *timeProfileFile = [outputPath stringByAppendingPathComponent:@"leaks.txt"];
        fp = fopen(timeProfileFile.UTF8String, "w+");
    }
    // 先从界面上找到 泄漏地址与  Responsibe Library 和 Responsibe Frame
    id view = [instrument viewForContext:context];
    XROutlineDetailView *tableView = TUIvar(TUIvar(view, _contentView),_docView);
    XRContext *leaksContext = TUIvar(instrument, _topLevelContexts)[0];
    [leaksContext display];
    XRLeaksRun *run = [instrument valueForKeyPath:@"_run"];
    NSMapTable *table = TUIvar(run, _btAggregatedLeaks);
    for (id aggregatedLeak in table.objectEnumerator) {
        [tableView expandItem:aggregatedLeak expandChildren:NO];
    }
    [tableView selectAll:nil];
    NSString *output = [PFTTableDetailView _stringForRows:tableView.selectedRowIndexes inView:tableView delimiter:'|' header:NO];
    NSArray *lines = [output componentsSeparatedByString:@"\n"];
    
    NSArray<XRLeak *> *allLeaks = [run valueForKeyPath:@"_allLeaks"];
    TUFPrint(fp, @"allocationTimestamp|discoveryTimestamp|name|address|symbol|size|count|image");
    for (XRLeak *leak in allLeaks) {
        NSString *symbolName;
        NSString *binaryImageName;
        for (NSString *line in lines) {
            NSArray *splitedString = [line componentsSeparatedByString:@"|"];
            if (splitedString.count == 6) {
                NSString *address = splitedString[2];
                if ([address isEqualToString:leak.displayAddress]) {
                    symbolName = splitedString[5];
                    binaryImageName = splitedString[4];
                    break;
                }
            }
        }
        int64_t timestamp = startTime + leak.allocationTimestamp / 1000000;
        int64_t discoveryTime = startTime + leak.discoveryTimestamp / 1000000;
        TUFPrint(fp, @"%@|%@|%@|%@|%@|%@|%@|%@", @(timestamp), @(discoveryTime), leak.className,
                leak.displayAddress, symbolName, @(leak.size),@(leak.count),binaryImageName);
    }
    fclose(fp);
}


void exportAllocationData (XRObjectAllocInstrument *allocInstrument, XRObjectAllocRun *run) {
    // allocation输出三分数据， 两份 calltree, 一份全部列表:
    // calltree : 函数调用中，内存增长情况， 又根据是否过滤系统库 即 ‘Hide System Libraries’，分成两份。
    // list: 所有  Persistent 内存信息， 用于之后的内存泄漏分析。
    FILE *allCallTreeFile = NULL;
    FILE *filteredCallTreeFile = NULL;
    FILE *allocListFile = NULL;
    if (outputPath) {
        NSString *file = [outputPath stringByAppendingPathComponent:@"allocation.calltree.txt"];
        allCallTreeFile = fopen(file.UTF8String, "w+");
        file = [outputPath stringByAppendingPathComponent:@"allocation.calltree.filtered.txt"];
        filteredCallTreeFile = fopen(file.UTF8String, "w+");
        file = [outputPath stringByAppendingPathComponent:@"allocation.list.txt"];
        allocListFile = fopen(file.UTF8String, "w+");
    }
    
    // calltree 获取：
    static void (^ const traversalNode)(PFTCallTreeNode *, FILE *) = ^(PFTCallTreeNode *node, FILE *fp) { // Helper function to collect all tree nodes.
        if (node) {
            NSString *symbol = [node symbolNameForUse];
            if ([node lineNumberForDisplay]) {
                NSString *sourcePath = [node sourcePath];
                sourcePath = sourcePath.lastPathComponent;
                symbol = [symbol stringByAppendingFormat:@"(%@:%@)", sourcePath, @([node lineNumberForDisplay])];
                // 不知道哪里多出来一个 \x10
                symbol = [symbol stringByReplacingOccurrencesOfString:@"\x10" withString:@""];
            }
            TUFPrint(fp, @"%@|%@|%@|%@|%@|%@|%@", @((long long)node), symbol, [node libraryForDisplay], @((long long)[node parent]), @([node numberChildren]), @(node->weights[0].weight), @(node.count));
            if (node.numberChildren) {
                NSArray *children = [node children];
                for (PFTCallTreeNode *childNode in children) {
                    traversalNode(childNode, fp);
                }
            }
        }
    };
    // 逆向心得记录， 用Xcode 连接到运行中的 Instruments 中， 然后根据界面、头文件， 打上断点， 观察函数调用， 最终确定实际调用方式。
    // 以下代码是设置选择全部创建元素，以分析内存创建情况。 不含有以下代码，分析的时创建的持久化数据。
    // 即 Instruments 下方的 All Allocations . 默认为 Created & Persistent.
    //    [run setLifecycleFilter:NO];
    //    [allocInstrument updateCurrentDetailView:YES];
    
    // 展示后，获取到数据。
    [allocInstrument._topLevelContexts[1] display];
    XRContext *context = allocInstrument._topLevelContexts[1];
    XRCallTreeDetailView *callTreeView = TUIvar(context.container,_currentView);
    XRBacktraceRepository *backtraceRepository = TUIvar(callTreeView , backtraceDataSource);
    [backtraceRepository refreshTreeRoot];
    // 遍历并输出。
    TUFPrint(allCallTreeFile, @"id|symbol|library|parent|childCount|bytes|count");
    traversalNode(backtraceRepository.rootNode, allCallTreeFile);
    fclose(allCallTreeFile);
    // 过滤系统库
    backtraceRepository.trimSystemLibraries = YES;
    [backtraceRepository refreshTreeRoot];
    // 遍历并输出。
    TUFPrint(filteredCallTreeFile, @"id|symbol|library|parent|childCount|bytes|count");
    traversalNode(backtraceRepository.rootNode, filteredCallTreeFile);
    fclose(filteredCallTreeFile);
    
    // 输出 list.
    TUFPrint(allocListFile, @"id|address|name|time|*|bytes|library|symbol");
    [allocInstrument._topLevelContexts[2] display];
    PFTTableDetailView *tableView = TUIvar(TUIvar(allocInstrument, _objectListController), _view);
    [tableView selectAll:nil];
    NSString *output = [PFTTableDetailView _stringForRows:tableView.selectedRowIndexes inView:tableView delimiter:'|' header:NO];
    TUFPrint(allocListFile, @"%@", output);
    fclose(allocListFile);
}


int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSArray<NSString *> *arguments = NSProcessInfo.processInfo.arguments;
//        arguments = @[@"TraceUtil", @"/Users/luoxianming/Documents/Testing/traceTest/Leaks.trace", @"-o", @"/Users/luoxianming/Documents/Testing/traceTest/xxx"];
        if (!parseArguments(arguments)) {
            return 1;
        }
        // Required. Each instrument is a plugin and we have to load them before we can process their data.
        DVTInitializeSharedFrameworks();
        [DVTDeveloperPaths initializeApplicationDirectoryName:@"Instruments"];
        [XRInternalizedSettingsStore configureWithAdditionalURLs:nil];
        [[XRCapabilityRegistry applicationCapabilities] registerCapability:@"com.apple.dt.instruments.track_pinning" versions:NSMakeRange(1, 1)];
        PFTLoadPlugins();

        // Instruments has its own subclass of NSDocumentController without overriding sharedDocumentController method.
        // We have to call this eagerly to make sure the correct document controller is initialized.
        [PFTDocumentController sharedDocumentController];
        // Open a trace document.
        NSError *error = nil;
        PFTTraceDocument *document = [[PFTTraceDocument alloc] initWithContentsOfURL:[NSURL fileURLWithPath:tracePath] ofType:@"com.apple.instruments.trace" error:&error];
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
                // 用时间戳标记时间。 文档中的时间戳，是服务器时间，不是设备时间，所以可信。
                int64_t startTime = run.startTime * 1000;

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
                if ([instrumentID isEqualToString:@"com.apple.xray.instrument-type.coresampler2"]) {
                    exportTimeProfilerData(contexts, instrument);
                } else if ([instrumentID isEqualToString:@"org.axe.instruments.gpu"]) {
                    exportFPSData(contexts, startTime);
                } else if ([instrumentID isEqualToString:@"org.axe.instruments.network"]) {
                    exportNetworkData(contexts, startTime);
                } else if ([instrumentID isEqualToString:@"org.axe.instruments.system"]) {
                    exportActivityData(contexts, startTime);
                } else if ([instrumentID isEqualToString:@"com.apple.xray.instrument-type.oa"]) {
                    exportAllocationData((XRObjectAllocInstrument *)instrument, (XRObjectAllocRun *)run);
                } else if ([instrumentID isEqualToString:@"com.apple.xray.instrument-type.homeleaks"]) {
                    XRContext *context = TUIvar(document, _restorationContext);
                    exportLeaksData((XRLegacyInstrument *)instrument, context, startTime);
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
