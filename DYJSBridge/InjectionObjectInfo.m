//
//  InjectionObjectInfo.m
//  DYJSBridge
//
//  Created by yangdy on 2019/7/23.
//  Copyright © 2019 DY. All rights reserved.
//

#import "InjectionObjectInfo.h"
#include <objc/runtime.h>
#pragma mark - aliasName & selectorName
static NSString* aliasNameForSelector(NSString *selectorName) {
    NSCParameterAssert(selectorName);
    NSString *tempName = selectorName;
    if([selectorName rangeOfString:@"__JSBRIGE_EXPORT_AS__"].location != NSNotFound) {
        tempName = [[selectorName componentsSeparatedByString:@"__JSBRIGE_EXPORT_AS__"] lastObject];
    }
    NSArray<NSString *> *tempArray = [tempName componentsSeparatedByString:@":"];
    NSMutableString *selector_aliasName =[NSMutableString string];
    [tempArray enumerateObjectsUsingBlock:^(NSString * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [selector_aliasName appendString:idx == 0 ? obj : [obj capitalizedString]];
    }];
    return selector_aliasName;
}
static  NSMutableDictionary<NSString *,NSString *> *selectorNameAndAliasName(unsigned int methodCount,struct objc_method_description *method_description_list) {
    NSMutableDictionary<NSString *,NSString *> *dict = [NSMutableDictionary<NSString *,NSString *> dictionary];
    for (int i = 0; i < methodCount ; i ++){
        struct objc_method_description description = method_description_list[i];
        NSString *selectorName = NSStringFromSelector(description.name);
        NSString *selector_aliasName = aliasNameForSelector(selectorName);
        if([selectorName rangeOfString:@"__JSBRIGE_EXPORT_AS__"].location != NSNotFound) {
            selectorName = [[selectorName componentsSeparatedByString:@"__JSBRIGE_EXPORT_AS__"] firstObject];
        }
        dict[selector_aliasName] = selectorName;
    }
    return dict;
}
static NSDictionary *protocolMethodNameList(id<JSBridgeExport> bridge) {
    NSMutableDictionary *methodLists = [NSMutableDictionary dictionary];
    unsigned int classProtocolCount = 0;
    Protocol * __unsafe_unretained *classProtocolList = class_copyProtocolList(object_getClass(bridge),&classProtocolCount);
    Protocol *protocol = @protocol(JSBridgeExport);
    for (int i = 0; i < classProtocolCount; i++) {
        Protocol *pro = classProtocolList[i];
        if(protocol_conformsToProtocol(pro, protocol)) {
            unsigned int methodCount = 0;
            struct objc_method_description *method_description_list = protocol_copyMethodDescriptionList(pro, NO, YES, &methodCount);
            NSMutableDictionary<NSString *,NSString *> *optionalMethodDict = selectorNameAndAliasName(methodCount,method_description_list);
            NSArray<NSString *> *allValues = [optionalMethodDict allValues];
            //optional
            [methodLists addEntriesFromDictionary:optionalMethodDict];
            free(method_description_list);
            //required
            method_description_list = protocol_copyMethodDescriptionList(pro, YES, YES, &methodCount);
            NSMutableDictionary<NSString *,NSString *> *requiredMethodDict = selectorNameAndAliasName(methodCount,method_description_list);
            // filter repeated method
            NSArray<NSString *> *allKeys = [requiredMethodDict allKeys];
            for (NSString *key in allKeys) {
                if([allValues containsObject:requiredMethodDict[key]]) {
                    [requiredMethodDict removeObjectForKey:key];
                }
            }
            [methodLists addEntriesFromDictionary:requiredMethodDict];
            free(method_description_list);
        }
    }
    free(classProtocolList);
    return methodLists;
}
#pragma mark - parseObjCType function
DYEncodingType parseObjCType(const char* position)
{
    assert(*position);
    switch (*position++) {
        case 'v':
            return DYEncodingTypeVoid;
        case 'B':
            return DYEncodingTypeBool;
        case 'c':
            return DYEncodingTypeInt8;
        case 'C':
            return DYEncodingTypeUInt8;
        case 's':
            return DYEncodingTypeInt16;
        case 'S':
            return DYEncodingTypeUInt16;
        case 'i':
            return DYEncodingTypeInt32;
        case 'I':
            return DYEncodingTypeUInt32;
        case 'l':
            return DYEncodingTypeInt32;
        case 'L':
            return DYEncodingTypeUInt32;
        case 'q':
            return DYEncodingTypeInt64;
        case 'Q':
            return DYEncodingTypeUInt64;
        case 'f':
            return DYEncodingTypeFloat;
        case 'd':
            return DYEncodingTypeDouble;
        case 'D':
            return DYEncodingTypeLongDouble;
            
        case '@': { // An object (whether statically typed or typed id)
            if (position[0] == '?') {
                return DYEncodingTypeBlock;
            }
            return DYEncodingTypeObject;
        }
        case '{': { // {name=type...} A structure
            return DYEncodingTypeStruct;
        }
            // NOT supporting C strings, arrays, pointers, unions, bitfields, function pointers.
        case '*': // A character string (char *)
            return DYEncodingTypeCString;
        case '[': // [array type] An array
            return DYEncodingTypeCArray;
        case '(': // (name=type...) A union
            return DYEncodingTypeUnion;
        case 'b': // bnum A bit field of num bits
        case '^': // ^type A pointer to type
            return  DYEncodingTypePointer;
        case '?': // An unknown type (among other things, this code is used for function pointers)
            // NOT supporting Objective-C Class, SEL
        case '#': // A class object (Class)
            return DYEncodingTypeClass;
        case ':': // A method selector (SEL)
            return DYEncodingTypeSEL;
        default:
            return DYEncodingTypeUnknown;
    }
}

@implementation InjectionObjectInfo
- (instancetype)initWithBridge:(id<JSBridgeExport>)bridge {
    if(self = [super init]) {
        self.bridge = bridge;
        NSDictionary *methodLists = protocolMethodNameList(bridge);
        NSArray *allKey = methodLists.allKeys;
        self.methodAliasNames = [NSMutableDictionary dictionaryWithCapacity:allKey.count];
        NSObject * target = (NSObject *)bridge;
        for (NSString *key in allKey) {
            NSString *selectorName = methodLists[key];
            SEL selector = NSSelectorFromString(selectorName);
            if([target respondsToSelector:selector]) {
                NSMethodSignature *signature = [[target class] instanceMethodSignatureForSelector:selector];
                NSUInteger numberOfArguments = signature.numberOfArguments;
                NSMutableArray *argumentTypes = [NSMutableArray arrayWithCapacity:numberOfArguments];
                for (NSUInteger i = 0; i<numberOfArguments; i++) {
                    const char *argumentType = [signature getArgumentTypeAtIndex:i];
                    [argumentTypes addObject:@(parseObjCType(argumentType))];
                }
                InjectionObjectMethodInfo *info = [InjectionObjectMethodInfo new];
                info.selectorName = selectorName;
                info.aliasName = key;
                info.resultType = parseObjCType(signature.methodReturnType);
                info.argumentTypes = argumentTypes;
                self.methodAliasNames[key] = info;
            }
        }
    }
    return self;
}
@end
@implementation InjectionObjectMethodInfo
- (void)setArgument:(NSInvocation *)invocation firstArgument:(int)firstArgument arguments:(NSArray *)arguments {
    for (int i = 0; i< arguments.count; i++) {
        int argumentIndex = i + firstArgument;
        id item = arguments[i];
        NSNumber *typeItem = argumentIndex < self.argumentTypes.count ? self.argumentTypes[argumentIndex] : nil;
        DYEncodingType type = [typeItem unsignedIntValue];
        // block  __NSStackBlock__ -> __NSStackBlock -> NSBlock
        if(type == DYEncodingTypeBlock || [item isKindOfClass:NSClassFromString(@"__NSStackBlock")]) {
            if(type == DYEncodingTypeBlock && [item isKindOfClass:NSClassFromString(@"__NSStackBlock")]) {
                [invocation setArgument:&item atIndex:i];
            }
            continue;
        }
        // NSNumber、NSString
        if([item isKindOfClass:[NSNumber class]] || [item isKindOfClass:[NSString class]]) {
            switch (type) {
                case DYEncodingTypeBool: {
                    BOOL value = [item boolValue];
                    [invocation setArgument:&value atIndex:argumentIndex];
                    break;
                }
                case DYEncodingTypeInt8: {
                    char value = [item charValue];
                    [invocation setArgument:&value atIndex:argumentIndex];
                    break;
                }
                case DYEncodingTypeUInt8: {
                    unsigned char value = [item unsignedCharValue];
                    [invocation setArgument:&value atIndex:argumentIndex];
                    break;
                }
                case DYEncodingTypeInt16: {
                    short value = [item shortValue];
                    [invocation setArgument:&value atIndex:argumentIndex];
                    break;
                }
                case DYEncodingTypeUInt16: {
                    unsigned short value = [item unsignedShortValue];
                    [invocation setArgument:&value atIndex:argumentIndex];
                    break;
                }
                case DYEncodingTypeInt32: {
                    int value = [item intValue];
                    [invocation setArgument:&value atIndex:argumentIndex];
                    break;
                }
                case DYEncodingTypeUInt32: {
                    unsigned int value = [item unsignedIntValue];
                    [invocation setArgument:&value atIndex:argumentIndex];
                    break;
                }
                case DYEncodingTypeInt64: {
                    long long value = [item longLongValue];
                    [invocation setArgument:&value atIndex:argumentIndex];
                    break;
                }
                case DYEncodingTypeUInt64: {
                    unsigned long long value = [item unsignedLongLongValue];
                    [invocation setArgument:&value atIndex:argumentIndex];
                    break;
                }
                case DYEncodingTypeFloat: {
                    float value = [item floatValue];
                    [invocation setArgument:&value atIndex:argumentIndex];
                    break;
                }
                case DYEncodingTypeDouble: {
                    double value = [item doubleValue];
                    [invocation setArgument:&value atIndex:argumentIndex];
                    break;
                }
                case DYEncodingTypeLongDouble: {
                    long double value = [item doubleValue];
                    [invocation setArgument:&value atIndex:argumentIndex];
                    break;
                }
                case DYEncodingTypeObject: {
                    [invocation setArgument:&item atIndex:argumentIndex];
                    break;
                }
                default:
                    break;
            }
        }else if(type == DYEncodingTypeObject && ([item isKindOfClass:[NSDictionary class]] || [item isKindOfClass:[NSArray class]] || [item isKindOfClass:[NSDate class]])){
            [invocation setArgument:&item atIndex:argumentIndex];
        }
    }
}
@end
