//
//  WebAuthImplement.m
//  Runner
//
//  Created by CodingIran on 2023/6/25.
//  Copyright © 2023 The Flutter Authors. All rights reserved.
//

#import "WebAuthImplement.h"
#import <IQObjcRuntime/IQObjcRuntime.h>

#if TARGET_OS_OSX

@implementation FlutterAppDelegate (WebAuthImplement)

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *productName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"];
        NSString *className = [NSString stringWithFormat:@"%@.AppDelegate", productName];
        SEL selector = @selector(applicationDidFinishLaunching:);
        Class class = NSClassFromString(className);
        OverrideImplementation(class, selector, ^id _Nonnull(__unsafe_unretained Class  _Nonnull originClass, SEL  _Nonnull originCMD, IMP  _Nonnull (^ _Nonnull originalIMPProvider)(void)) {
            return ^(__kindof FlutterAppDelegate *selfObject, NSNotification* firstArgv) {
                [selfObject webAuth_applicationDidFinishLaunching:firstArgv];

                // call super
                IMP originalIMP = originalIMPProvider();
                void (*originSelectorIMP)(id, SEL, NSNotification *);
                originSelectorIMP = (void (*)(id, SEL, NSNotification *))originalIMP;
                originSelectorIMP(selfObject, originCMD, firstArgv);
            };
        });
    });
}

- (void)webAuth_applicationDidFinishLaunching:(NSNotification *)notification {
    dispatch_async(dispatch_get_main_queue(), ^ {
        [self webAuth_addURLSchemeEvent];
    });
}

- (void)webAuth_addURLSchemeEvent {
    NSAppleEventManager *appleEventManager = NSAppleEventManager.sharedAppleEventManager;
    [appleEventManager setEventHandler:self andSelector:@selector(webAuth_handleAppleEvent:withReplyEvent:) forEventClass:kInternetEventClass andEventID:kAEGetURL];
}

- (void)webAuth_handleAppleEvent:(NSAppleEventDescriptor *)event withReplyEvent:(NSAppleEventDescriptor *)reply {
    NSString *path = [[event paramDescriptorForKeyword:keyDirectObject] stringValue];
    if (path) {
        [NSNotificationCenter.defaultCenter postNotificationName:@"FlutterWebAuth2_URLScheme_notification" object:nil userInfo:@{@"info" : path}];
    }
}

@end

#endif
