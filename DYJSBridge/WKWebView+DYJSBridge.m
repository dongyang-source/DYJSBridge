//
//  WKWebView+DYJSBridge.m
//  DYJSBridge
//
//  Created by yangdy on 2019/7/23.
//  Copyright © 2019 DY. All rights reserved.
//

#import "WKWebView+DYJSBridge.h"
#import <objc/Runtime.h>
#import "InjectionObjectInfo.h"
#pragma mark -  function
static NSString *jsCommandForMethodName(NSArray *aliasNames,NSString *name) {
    if(aliasNames.count == 0) {
        return @"";
    }
    NSString *path =  [[NSBundle bundleForClass:[InjectionObjectInfo class]] pathForResource:@"FunctionName" ofType:@"js"];;
    NSString *jsCommand = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
    NSMutableArray *allFunctions = [NSMutableArray arrayWithCapacity:aliasNames.count];
    for (NSString *selectorName in aliasNames) {
        [allFunctions addObject:[NSString stringWithFormat:jsCommand,selectorName,name,selectorName]];
    }
    return [NSString stringWithFormat:@"%@ = {\n\t%@\n};",name,[allFunctions componentsJoinedByString:@",\n\t"]];
}

@implementation WKWebView (DYJSBridge)
+ (void)load {
    Method originalMethod = class_getInstanceMethod(self, @selector(initWithFrame:configuration:));
    Method swizzledMethod = class_getInstanceMethod(self, @selector(js_initWithFrame:configuration:));
    method_exchangeImplementations(originalMethod, swizzledMethod);
}
- (instancetype)js_initWithFrame:(CGRect)frame configuration:(WKWebViewConfiguration *)configuration {
    // Forward to primary implementation.
    [self js_initWithFrame:frame configuration:configuration];
    [self injectionJS];
    return self;
}
- (void)addJavascriptInterface:(id<JSBridgeExport>)bridge name:(NSString *)name {
    NSParameterAssert(bridge && name.length > 0);
    InjectionObjectInfo *objectInfo = [[InjectionObjectInfo alloc] initWithBridge:bridge];
    NSString *jsCommand = jsCommandForMethodName(objectInfo.methodAliasNames.allKeys,name);
    if(jsCommand.length > 0) {
        self.injectionObjectMap[name] = objectInfo;
        WKUserScript *userScript = [[WKUserScript alloc] initWithSource:jsCommand injectionTime:WKUserScriptInjectionTimeAtDocumentStart forMainFrameOnly:YES];
        [self.configuration.userContentController addUserScript:userScript];
    }
}
- (void)injectionJS {
    NSString *path =  [[NSBundle bundleForClass:[InjectionObjectInfo class]] pathForResource:@"JavascriptBridge" ofType:@"js"];;
    NSString *jsCommand = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
    NSParameterAssert(jsCommand.length > 0);
    WKUserScript *userScript = [[WKUserScript alloc] initWithSource:jsCommand injectionTime:WKUserScriptInjectionTimeAtDocumentStart forMainFrameOnly:YES];
    [self.configuration.userContentController addUserScript:userScript];
    [self.configuration.userContentController addScriptMessageHandler:self name:@"webViewApp"];
}
#pragma mark - native call js
- (void)callHandler:(NSString *)handlerName data:(nullable id)data callback:(nullable JSBridgeCallback)callback completionHandler:(void (^ _Nullable)(_Nullable id, NSError * _Nullable error))completionHandler {
    NSParameterAssert(handlerName.length > 0);
    [self callHandler:handlerName responseId:nil data:data callback:callback completionHandler:completionHandler];
}
- (void)callHandler:(NSString *)handlerName responseId:(NSString *)responseId data:(nullable id)data callback:(nullable JSBridgeCallback)callback completionHandler:(void (^ _Nullable)(_Nullable id, NSError * _Nullable error))completionHandler {
    NSParameterAssert(handlerName.length > 0 || responseId.length > 0);
    NSMutableDictionary *message = [NSMutableDictionary dictionary];
    if (data) {
        message[@"data"] = data;
    }
    if(responseId) {
        message[@"responseId"] = responseId;
    }else {
        if (handlerName) {
            message[@"handlerName"] = handlerName;
        }
        if (callback) {
            NSString* callbackId = [NSString stringWithFormat:@"objc_cb_%ld", ++self.uniqueId];
            self.responseCallbacks[callbackId] = callback;
            message[@"callbackId"] = callbackId;
        }
    }
    [self execJSFunction:@"JSBridge.handleMessageFromObjC" param:message completionHandler:completionHandler];
}
- (void)execJSFunction:(NSString *)funcName param:(id)param completionHandler:(void (^ _Nullable)(_Nullable id, NSError * _Nullable error))completionHandler {
    NSString *messageJSON;
    if([param isKindOfClass:[NSDictionary class]] || [param isKindOfClass:[NSArray class]]) {
        messageJSON = [[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:param options:0 error:nil] encoding:NSUTF8StringEncoding];
    }else {
        messageJSON = [NSString stringWithFormat:@"%@",param];
    }
    messageJSON = [messageJSON stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"];
    messageJSON = [messageJSON stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];
    messageJSON = [messageJSON stringByReplacingOccurrencesOfString:@"\'" withString:@"\\\'"];
    messageJSON = [messageJSON stringByReplacingOccurrencesOfString:@"\n" withString:@"\\n"];
    messageJSON = [messageJSON stringByReplacingOccurrencesOfString:@"\r" withString:@"\\r"];
    messageJSON = [messageJSON stringByReplacingOccurrencesOfString:@"\f" withString:@"\\f"];
    messageJSON = [messageJSON stringByReplacingOccurrencesOfString:@"\u2028" withString:@"\\u2028"];
    messageJSON = [messageJSON stringByReplacingOccurrencesOfString:@"\u2029" withString:@"\\u2029"];
    NSString*javascriptCommand = [NSString stringWithFormat:@"%@('%@');",funcName, messageJSON];
    [self execJSFunction:javascriptCommand completionHandler:completionHandler];
}
- (void)execJSFunction:(NSString *)func completionHandler:(void (^ _Nullable)(_Nullable id, NSError * _Nullable error))completionHandler{
    dispatch_block_t voidBlock = ^{
        [self evaluateJavaScript:func completionHandler:completionHandler];
    };
    if ([NSThread isMainThread]) {
        voidBlock();
    } else {
        dispatch_async(dispatch_get_main_queue(), voidBlock);
    }
    
}
#pragma mark - WKScriptMessageHandler
- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message {
    if([message.name isEqualToString:@"webViewApp"] && [message.body isKindOfClass:[NSDictionary class]]) {
        NSDictionary *dict = message.body;
        NSString *responseId = dict[@"responseId"];
        NSMutableArray *arguments = dict[@"arguments"];
        if(responseId && self.responseCallbacks[responseId]) {
            JSBridgeCallback resonse = self.responseCallbacks[responseId];
            resonse(arguments);
            [self.responseCallbacks removeObjectForKey:responseId];
            return;
        }
        // callback
        NSString *callbackId = dict[@"callbackId"];
        JSBridgeCallback callback;
        if(callbackId) {
            __weak __typeof__(self) wself = self;
            callback = ^(id data) {
                [wself callHandler:nil responseId:callbackId data:data callback:nil completionHandler:nil];
            };
            arguments ? [arguments addObject:callback] : (arguments = [NSMutableArray arrayWithObject:callback]);
        }
        NSString *handlerName = dict[@"handlerName"];
        NSString *name = dict[@"name"];
        InjectionObjectInfo *objectInfo = self.injectionObjectMap[name];
        if(objectInfo && objectInfo.bridge && objectInfo.methodAliasNames[handlerName]) {
            id target = objectInfo.bridge;
            InjectionObjectMethodInfo *methodInfo = objectInfo.methodAliasNames[handlerName];
            SEL selector = NSSelectorFromString(methodInfo.selectorName);
            NSMethodSignature *signature = [[target class] instanceMethodSignatureForSelector:selector];
            NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
            [invocation setSelector:selector];
            [methodInfo setArgument:invocation firstArgument:2 arguments:arguments];
            
            if(callbackId && [[methodInfo.argumentTypes lastObject] unsignedIntegerValue] == DYEncodingTypeBlock) {
                [invocation setArgument:&callback atIndex:methodInfo.argumentTypes.count - 1];
            }
            [invocation invokeWithTarget:target];
        }
    }
}

#pragma mark - setter getter
// name <-> injectionObject
- (NSMutableDictionary *)injectionObjectMap {
    NSMutableDictionary *injectionObjectMap = objc_getAssociatedObject(self, _cmd);
    if(!injectionObjectMap) {
        injectionObjectMap = [NSMutableDictionary dictionary];
        objc_setAssociatedObject(self, _cmd, injectionObjectMap, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return injectionObjectMap;
}
//callbackId <-> callback block
- (NSMutableDictionary<NSString *,JSBridgeCallback> *)responseCallbacks {
    NSMutableDictionary<NSString *,JSBridgeCallback> *responseCallbacks = objc_getAssociatedObject(self, _cmd);
    if(!responseCallbacks) {
        responseCallbacks = [NSMutableDictionary<NSString *,JSBridgeCallback> dictionary];
        objc_setAssociatedObject(self, _cmd, responseCallbacks, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return responseCallbacks;
}
- (long)uniqueId{
    return [objc_getAssociatedObject(self, _cmd) longValue];
}
- (void)setUniqueId:(long)uniqueId{
    objc_setAssociatedObject(self, @selector(uniqueId), @(uniqueId), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
@end
