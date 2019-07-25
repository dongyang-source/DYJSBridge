//
//  DYViewController.m
//  DYJSBridge
//
//  Created by ydy on 07/23/2019.
//  Copyright (c) 2019 ydy. All rights reserved.
//

#import "DYViewController.h"
#import "WKWebView+DYJSBridge.h"
typedef void (^callbackBlock)(id respData);
@protocol WebViewJSExport<JSBridgeExport>
// js -> OC
- (void)testMethodOne;
//NSDictionary,NSArray,NSString,NSDate,NSNumber,nil,NSInteger,double,short,BOOL等
- (void)testMethodTwo:(NSDate *)date day:(NSInteger)day;
// callback
- (void)testMethodThree:(callbackBlock)callback;
//用宏转换下，将JS函数名字指定为testMethodFour；
JSBrigeExportAs(testMethodFour, - (void)testMethodFour:(NSDate *)date day:(NSInteger)day callback:(callbackBlock)callback);
@end
//JSBrigeExportAs  修改名字 注意至少有一个参数

@interface DYViewController ()<WebViewJSExport>
@property (strong, nonatomic) WKWebView *webView;
@end
@implementation DYViewController
- (void)viewDidLoad
{
    [super viewDidLoad];
    self.title = @"测试";
	// Do any additional setup after loading the view, typically from a nib.
    WKWebViewConfiguration *configuration = [[WKWebViewConfiguration alloc] init];
    self.webView = [[WKWebView alloc] initWithFrame:[UIScreen mainScreen].bounds configuration:configuration];
    [self.view addSubview:self.webView];
    [self.view sendSubviewToBack:self.webView];
    
    [self.webView addJavascriptInterface:self name:@"nativeBridge"];
    NSString *htmlPath = [[NSBundle mainBundle] pathForResource:@"test" ofType:@"html"];
    [_webView loadRequest:[NSURLRequest requestWithURL:[NSURL fileURLWithPath:htmlPath]]];
}
#pragma mark - js call OC
- (void)testMethodOne {
    NSLog(@"%s",__FUNCTION__);
}
- (void)testMethodTwo:(NSDate *)date day:(NSInteger)day {
     NSLog(@"%s__%@__%ld",__FUNCTION__,date,day);
}
- (void)testMethodThree:(callbackBlock)callback {
    NSLog(@"%s",__FUNCTION__);
    if(callback) {
        callback([NSString stringWithFormat:@"%s %lf",__FUNCTION__,[NSDate date].timeIntervalSince1970]);
    }
}

- (void)testMethodFour:(NSDate *)date day:(NSInteger)day callback:(callbackBlock)callback {
    if(callback) {
        callback([NSString stringWithFormat:@"%s__%@__%ld",__FUNCTION__,date,day]);
    }
}

#pragma mark - OC call js
// 传递参数(NSDictionary,NSString,NSNumber,nil)
- (IBAction)calljsAction:(id)sender {
    [self.webView callHandler:@"callByOC" data:@([NSDate date].timeIntervalSince1970) callback:nil completionHandler:nil];
}
- (IBAction)calljsWithCallbackAction:(id)sender {
    [self.webView callHandler:@"callByOCWithcallBack" data:@([NSDate date].timeIntervalSince1970) callback:^(id  _Nonnull responseData) {
        NSLog(@"js 回调参数:%@",responseData);
    } completionHandler:nil];
}



- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}
@end
