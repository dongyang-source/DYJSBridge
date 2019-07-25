//
//  InjectionObjectInfo.h
//  DYJSBridge
//
//  Created by yangdy on 2019/7/23.
//  Copyright © 2019 DY. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "WKWebView+DYJSBridge.h"
NS_ASSUME_NONNULL_BEGIN
typedef NS_OPTIONS(NSUInteger, DYEncodingType) {
    DYEncodingTypeUnknown    = 0,  ///< unknown
    DYEncodingTypeVoid       = 1, ///< void
    DYEncodingTypeBool       = 2, ///< bool
    DYEncodingTypeInt8       = 3, ///< char / BOOL
    DYEncodingTypeUInt8      = 4, ///< unsigned char
    DYEncodingTypeInt16      = 5, ///< short
    DYEncodingTypeUInt16     = 6, ///< unsigned short
    DYEncodingTypeInt32      = 7, ///< int
    DYEncodingTypeUInt32     = 8, ///< unsigned int
    DYEncodingTypeInt64      = 9, ///< long long
    DYEncodingTypeUInt64     = 10, ///< unsigned long long
    DYEncodingTypeFloat      = 11, ///< float
    DYEncodingTypeDouble     = 12, ///< double
    DYEncodingTypeLongDouble = 13, ///< long double
    DYEncodingTypeObject     = 14, ///< id
    DYEncodingTypeClass      = 15, ///< Class
    DYEncodingTypeSEL        = 16, ///< SEL
    DYEncodingTypeBlock      = 17, ///< block
    DYEncodingTypePointer    = 18, ///< void*
    DYEncodingTypeStruct     = 19, ///< struct
    DYEncodingTypeUnion      = 20, ///< union
    DYEncodingTypeCString    = 21, ///< char*
    DYEncodingTypeCArray     = 22 ///< char[10] (for example)
};

@class InjectionObjectMethodInfo;
@interface InjectionObjectInfo : NSObject
@property (weak, nonatomic) id<JSBridgeExport> bridge;
@property (strong, nonatomic) NSMutableDictionary<NSString *,InjectionObjectMethodInfo *> *methodAliasNames;
- (instancetype)initWithBridge:(id<JSBridgeExport>)bridge;
@end

@interface InjectionObjectMethodInfo : NSObject
@property (copy, nonatomic) NSString *selectorName;
@property (copy, nonatomic) NSString *aliasName;
// runturn
@property (assign, nonatomic) DYEncodingType resultType;
// argumentTypes
@property (strong, nonatomic) NSArray *argumentTypes;

- (void)setArgument:(NSInvocation *)invocation firstArgument:(int)firstArgument arguments:(NSArray *)arguments;
@end
NS_ASSUME_NONNULL_END
