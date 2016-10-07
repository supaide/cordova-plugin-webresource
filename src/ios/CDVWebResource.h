//
//  CDVWebResource.h
//  Pods
//
//  Created by chenyijun on 16/10/6.
//
//

#import <Cordova/CDVPlugin.h>

@interface CDVWebResource : CDVPlugin

- (void) checkAndUpdate:(CDVInvokedUrlCommand*)command;
- (void) getResource:(CDVInvokedUrlCommand*)command;
- (void) getVersion:(CDVInvokedUrlCommand*)command;

- (void)echo:(CDVInvokedUrlCommand*)command;

@end
