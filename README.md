# DYJSBridge

[![Version](https://img.shields.io/cocoapods/v/DYJSBridge.svg?style=flat)](https://cocoapods.org/pods/DYJSBridge)
[![License](https://img.shields.io/cocoapods/l/DYJSBridge.svg?style=flat)](https://cocoapods.org/pods/DYJSBridge)
[![Platform](https://img.shields.io/cocoapods/p/DYJSBridge.svg?style=flat)](https://cocoapods.org/pods/DYJSBridge)  

* 一个使用简单的WKWebView和原生通信框架，支持iOS8+。


## 🌟 功能
- [x] 使用简单，无侵入性。
- [x] 支持向WKWebview注入对象，如同UIWebView时代，通过JSContext向UIWebView注入对象一样。
- [x] 支持注入对象方法在js中函数名字。
- [x] 支持js调用OC时匿名函数回调、OC调用js时Block回调。
- [x] 支持js调用OC时基本类型数据的传递(比如：NSInteger , double , short , BOOL 等),OC 调用JS时非字符串对象的传递(比如：NSDictionary , NSString , NSNumber )。


## 🔮 案例

运行 Example/DYJSBridge.xcworkspace.

## 🐒 如何使用
### js 调用 OC
##### 第一步:test.html代码如下
```bash
<div class="btn" onclick="nativeBridge.testMethodOne()">无参调用</div>
<div class="btn" onclick="nativeBridge.testMethodTwoDay((new Date()),2)">带普通参调用</div>
<div class="btn" onclick="testMethodThree()">带回调函数的调用</div>
<div class="btn" onclick="testMethodFour()">重命名方法的调用</div>
<div class="btn" hidden="hidden"></div>
<script>
	function testMethodThree() {
		 nativeBridge.testMethodThree(function (argument) {
				// body...
				var x = document.getElementsByClassName("btn")[2];
				x.innerHTML = "带回调函数的调用" + argument;
				})
        }
	function testMethodFour() {
		nativeBridge.testMethodFour(new Date(),2,function (argument) {
				// body...
				var x = document.getElementsByClassName("btn")[3];
				x.innerHTML = "重命名方法的调用" + argument;
				})
        }
	function callByOC(argument) {
			var x = document.getElementsByClassName("btn")[4];
          x.removeAttribute('hidden');
          x.innerHTML = argument;
       }
	function callByOCWithcallBack(argument,responseCallback) {
          var x = document.getElementsByClassName("btn")[4];
          x.removeAttribute('hidden');
          x.innerHTML =  argument;
          responseCallback(new Date());
       }
@end
```
##### 第二步：实现一个继承JSBridgeExport的协议WebViewJSExport
```bash
typedef void (^callbackBlock)(id respData);
@protocol WebViewJSExport<JSBridgeExport>

- (void)testMethodOne;

//支持 NSDictionary,NSArray,NSString,NSDate,NSNumber,nil,NSInteger,double,short,BOOL等
- (void)testMethodTwo:(NSDate *)date day:(NSInteger)day;

// callback 支持
- (void)testMethodThree:(callbackBlock)callback;

//用宏转换下，将JS函数名字指定为testMethodFour；
JSBrigeExportAs(testMethodFour, - (void)testMethodFour:(NSDate *)date day:(NSInteger)day callback:(callbackBlock)callback);

@end

```
##### 第三步：当前VC需要实现WebViewJSExport

```bash
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
    
    // 注入对象
    [self.webView addJavascriptInterface:self name:@"nativeBridge"];
    NSString *htmlPath = [[NSBundle mainBundle] pathForResource:@"test" ofType:@"html"];
    [self.webView loadRequest:[NSURLRequest requestWithURL:[NSURL fileURLWithPath:htmlPath]]];
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
@end
```

### OC call js
```bash
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
```


## 📲 集成
 * 使用cocoapods `pod DYJSBridge`
 * 手动集成
	* 将所有在DYJSBridge项目中的文件拖入工程中
	* 导入头文件 `#import "WKWebView+DYJSBridge.h"`


## 👨🏻‍💻 作者

dongyang, 1060380608@qq.com

## 👮🏻 协议

DYJSBridge 基于 MIT 协议进行分发和使用，更多信息参见 协议文件。

感谢 YYModel 和 WebViewJavascriptBridge 带来的灵感!