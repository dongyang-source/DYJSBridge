//
//  WKWebView+DYJSBridge.h
//  DYJSBridge
//
//  Created by yangdy on 2019/7/23.
//  Copyright © 2019 DY. All rights reserved.
//
#import <WebKit/WebKit.h>
NS_ASSUME_NONNULL_BEGIN
@protocol JSBridgeExport
@end

#define JSBrigeExportAs(PropertyName, Selector) \
@optional Selector __JSBRIGE_EXPORT_AS__##PropertyName:(id)argument; @required Selector
typedef void (^JSBridgeCallback)(id responseData);

@interface WKWebView (DYJSBridge)<WKScriptMessageHandler>
// injection object into webVeiw
- (void)addJavascriptInterface:(id<JSBridgeExport>)bridge name:(NSString *)name;
// native call js
- (void)callHandler:(NSString *)handlerName data:(nullable id)data callback:(nullable JSBridgeCallback)callback completionHandler:(void (^ _Nullable)(_Nullable id, NSError * _Nullable error))completionHandler;
@end

NS_ASSUME_NONNULL_END
