//
//  CDVWebResource.m
//  Pods
//
//  Created by chenyijun on 16/10/6.
//
//

#import "CDVWebResource.h"
#import <Cordova/CDVPlugin.h>
#import "SSZipArchive.h"
#import "AFNetworking.h"

@implementation CDVWebResource {
    NSString* _wwwPath;
    NSString* _versionFileName;
    NSString* _appName;
    
    NSString* _docPath;
    NSString* _version;
}

- (void)pluginInitialize {
    _wwwPath = [self settingForKey:@"WebResourceWWWPath"];
    _versionFileName = [self settingForKey:@"WebResourceVersionFileName"];
    _appName = [self settingForKey:@"WebResourceAppName"];
    
    _wwwPath = (!_wwwPath) ? @"www" : _wwwPath;
    _versionFileName = (!_versionFileName) ? @"VERSION" : _versionFileName;
    _appName = (!_appName) ? @"app" : _appName;
    
    _wwwPath = [[NSBundle mainBundle] pathForResource:_wwwPath ofType:nil];
    _docPath = [[[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:_wwwPath] stringByAppendingPathComponent:_appName];
    
    NSString* originAppDir = [_wwwPath stringByAppendingPathComponent:_appName];
    NSString* originAppZipFile = [originAppDir stringByAppendingString:@".zip"];
    
    [self unzipResources:originAppZipFile fromWWW:YES delDestDir:NO];
}

- (void) unzipResources:(NSString*)zipFile fromWWW:(Boolean)fromWWW delDestDir:(Boolean)delDest {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString* versionFile = [_docPath stringByAppendingPathComponent:_versionFileName];
    
    if (![fileManager fileExistsAtPath:_docPath]) {
        [fileManager createDirectoryAtPath:_docPath withIntermediateDirectories:YES attributes:nil error:nil];
        if (fromWWW) {
            [SSZipArchive unzipFileAtPath:zipFile toDestination: _docPath];
            return;
        }
    } else {
        if (fromWWW) {
            return;
        }
    }
    
    if ([fileManager fileExistsAtPath:zipFile]) {
        [SSZipArchive unzipFileAtPath:zipFile toDestination: _docPath];
        [fileManager removeItemAtPath:zipFile error:nil];
    }
    _version = [NSString stringWithContentsOfFile:versionFile encoding:NSUTF8StringEncoding error:nil];
}

- (void) checkAndUpdate:(CDVInvokedUrlCommand*)command {
    CDVPluginResult* pluginResult = nil;
    if ([command.arguments count] < 2) {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        return;
    }
    NSString* version = [command.arguments objectAtIndex:0];
    NSString* zipUrl = [command.arguments objectAtIndex:1];
    if([version isEqualToString:_version]) {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsInt:0];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        return;
    }
    
    NSURL *URL = [NSURL URLWithString:zipUrl];
    NSURLRequest *request = [NSURLRequest requestWithURL:URL];
    
    NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
    AFURLSessionManager *manager = [[AFURLSessionManager alloc] initWithSessionConfiguration:configuration];

    __weak __typeof(self) weakSelf = self;
    NSURLSessionDownloadTask *downloadTask = [manager downloadTaskWithRequest:request progress:^(NSProgress * _Nonnull downloadProgress) {
        if (weakSelf) {
            __typeof(&*weakSelf) strongSelf = weakSelf;
            int64_t complete = [downloadProgress completedUnitCount];
            int64_t total = [downloadProgress totalUnitCount];
            
            NSArray* message = [NSArray arrayWithObjects:[NSNumber numberWithLongLong:complete], [NSNumber numberWithLongLong:total], nil];
            CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:message];
            [pluginResult setKeepCallbackAsBool:YES];
            [strongSelf.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        }
    } destination:^NSURL *(NSURL *targetPath, NSURLResponse *response) {
        NSURL *documentsDirectoryURL = [[NSFileManager defaultManager] URLForDirectory:NSCachesDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:NO error:nil];

        return [documentsDirectoryURL URLByAppendingPathComponent:[response suggestedFilename]];
    } completionHandler:^(NSURLResponse *response, NSURL *filePath, NSError *error) {
        if (!weakSelf) {
            return;
        }
        __typeof(&*weakSelf) strongSelf = weakSelf;
        CDVPluginResult* pluginResult = nil;
        if (error) {
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR];
            [strongSelf.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
            return;
        }
        
        [strongSelf unzipResources:[filePath path] fromWWW:NO delDestDir:NO];
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsInt:1];
        [strongSelf.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }];
    [downloadTask resume];
}

- (void) getResource:(CDVInvokedUrlCommand*)command {
    CDVPluginResult* pluginResult = nil;
    NSArray* files = command.arguments;
    if ([files count] < 1) {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        return;
    }
    NSMutableArray* contents = [NSMutableArray arrayWithCapacity:[files count]];
    for (NSString* file in files) {
        NSString* content = [NSString stringWithContentsOfFile:[_docPath stringByAppendingPathComponent:file] encoding:NSUTF8StringEncoding error:nil];
        if (!content) {
            [contents addObject:@""];
        } else {
            [contents addObject:[content stringByTrimmingCharactersInSet: [NSCharacterSet newlineCharacterSet]]];
        }
    }
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:contents];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) getVersion:(CDVInvokedUrlCommand *)command {
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:_version];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (id)settingForKey:(NSString*)key {
    return [self.commandDelegate.settings objectForKey:[key lowercaseString]];
}

#if !__has_feature(objc_arc)
- (void)dealloc {
    [_wwwPath release];
    [_versionFileName release];
    [_path release];
    [_docPath release];
    [_version release];
    [super dealloc];
}
#endif


@end
