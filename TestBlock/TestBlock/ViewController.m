//
//  ViewController.m
//  TestBlock
//
//  Created by 罗贤明 on 2018/12/25.
//  Copyright © 2018 罗贤明. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()
@property (nonatomic, strong) NSMutableData *data;
@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic,assign) CFRunLoopObserverRef observer;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    _data = [NSMutableData new];
    for (NSInteger i = 0; i < 2000000; i ++) {
        [_data appendBytes:"aaaaaaaaaa" length:10];
    }
}

- (IBAction)testLock:(id)sender {
    // 测试锁时，要在开始和结束的位置添加上一些耗时操作，否则容易抓不到这个函数的执行。
    for (NSInteger i = 0; i < 20; i++) {
        [[NSFileManager defaultManager] fileExistsAtPath:NSTemporaryDirectory()];
    }
    dispatch_semaphore_t semphore = dispatch_semaphore_create(0);
    dispatch_semaphore_wait(semphore, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(20 * NSEC_PER_MSEC)));
    for (NSInteger i = 0; i < 20; i++) {
        [[NSFileManager defaultManager] fileExistsAtPath:NSTemporaryDirectory()];
    }
}

- (IBAction)testFile:(id)sender {
    // 大文件读写。
    int64_t start = CFAbsoluteTimeGetCurrent() * 1000;
    NSString *tmpPath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"test.txt"];
    [_data writeToFile:tmpPath atomically:NO];
    [[NSFileManager defaultManager] removeItemAtPath:tmpPath error:nil];
    int64_t end = CFAbsoluteTimeGetCurrent() * 1000;
    NSLog(@"耗时 ：%@", @(end - start));
}

- (IBAction)testTimer:(UIButton *)sender {
    if (!_timer) {
        [sender setTitle:@"Timer On" forState:UIControlStateNormal];
        _timer = [NSTimer scheduledTimerWithTimeInterval:0.05 repeats:YES block:^(NSTimer * _Nonnull timer) {
            for (NSInteger i = 0; i < 20; i++) {
                [[NSFileManager defaultManager] fileExistsAtPath:NSTemporaryDirectory()];
            }
        }];
    } else {
        [sender setTitle:@"Timer Off" forState:UIControlStateNormal];
        [_timer invalidate];
        _timer = nil;
    }
}

- (IBAction)testObserver:(UIButton *)sender {
    if (!_observer) {
        [sender setTitle:@"Observer On" forState:UIControlStateNormal];
        _observer = CFRunLoopObserverCreateWithHandler(NULL, kCFRunLoopAllActivities, YES, 0, ^(CFRunLoopObserverRef observer, CFRunLoopActivity activity) {
            for (NSInteger i = 0; i < 20; i++) {
                [[NSFileManager defaultManager] fileExistsAtPath:NSTemporaryDirectory()];
            }
        });
        CFRunLoopAddObserver([[NSRunLoop mainRunLoop] getCFRunLoop], _observer, kCFRunLoopCommonModes);
    } else {
        CFRunLoopRemoveObserver([[NSRunLoop mainRunLoop] getCFRunLoop], _observer, kCFRunLoopCommonModes);
        _observer = nil;
        [sender setTitle:@"Observer Off" forState:UIControlStateNormal];
    }
}
@end
