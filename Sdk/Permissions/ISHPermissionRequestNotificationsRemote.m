//
//  ISHPermissionRequestNotificationsRemote.m
//  ISHPermissionKit
//
//  Created by Sergio Mira on 21.04.15.
//  Copyright (c) 2014 iosphere GmbH. All rights reserved.
//

#import "ISHPermissionRequestNotificationsRemote.h"
#import "ISHPermissionRequest+Private.h"

@interface ISHPermissionRequestNotificationsRemote ()
@property (atomic, copy) ISHPermissionRequestCompletionBlock completionBlock;
@end

@implementation ISHPermissionRequestNotificationsRemote

@synthesize notificationSettings;
@synthesize completionBlock;

- (BOOL)allowsConfiguration {
    return YES;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (ISHPermissionState)permissionState {
    if (!NSClassFromString(@"UIUserNotificationSettings")) {
        return ISHPermissionStateAuthorized;
    }

    UIApplication* app = [UIApplication sharedApplication];
#ifdef __IPHONE_8_0
#if __IPHONE_OS_VERSION_MIN_REQUIRED < __IPHONE_8_0
    // Check if the new API is not available
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
    if (![app respondsToSelector:@selector(isRegisteredForRemoteNotifications:)])
    {
        // Use the old API
        return ([app enabledRemoteNotificationTypes] & UIRemoteNotificationTypeAlert)? ISHPermissionStateAuthorized : ISHPermissionStateUnknown;
    }
#pragma clang diagnostic pop
    else
#endif
    {
        return ([app isRegisteredForRemoteNotifications] && ([app currentUserNotificationSettings] != UIUserNotificationTypeNone))? ISHPermissionStateAuthorized : ISHPermissionStateUnknown;
    }
#else
    // Not building with the latest XCode that contains iOS 8 definitions
    return ([app enabledRemoteNotificationTypes] & UIRemoteNotificationTypeAlert)? ISHPermissionStateAuthorized : ISHPermissionStateUnknown;
#endif
}

- (void)requestUserPermissionWithCompletionBlock:(ISHPermissionRequestCompletionBlock)completion {
    NSAssert(completion, @"requestUserPermissionWithCompletionBlock requires a completion block", nil);
    if (![[[UIApplication sharedApplication] delegate] respondsToSelector:@selector(application:didRegisterUserNotificationSettings:)]) {
        // ensure that the app delegate implements the didRegisterMethods:
        NSLog(@"AppDelegate must implement application:didRegisterUserNotificationSettings: and post notification ISHPermissionNotificationApplicationDidRegisterUserNotificationSettings", nil);
    }
    
    ISHPermissionState currentState = self.permissionState;
    if (!ISHPermissionStateAllowsUserPrompt(currentState)) {
        completion(self, currentState, nil);
        return;
    }
    
    self.completionBlock = completion;
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(ISHPermissionNotificationApplicationDidRegisterUserNotificationSettings:)
                                                 name:ISHPermissionNotificationApplicationDidRegisterUserNotificationSettings
                                               object:nil];
    [ISHPermissionRequestNotificationsRemote registerForRemoteNotifications:self.notificationSettings];
}

-(void)requestUserPermissionWithoutCompleteBlock {
    [ISHPermissionRequestNotificationsRemote registerForRemoteNotifications:self.notificationSettings];
}

+(void)registerForRemoteNotifications:(UIUserNotificationSettings*)notificationSettings {
    UIApplication* app = [UIApplication sharedApplication];
#ifdef __IPHONE_8_0
#if __IPHONE_OS_VERSION_MIN_REQUIRED < __IPHONE_8_0
    // Check if the new push API is not available
    if (![app respondsToSelector:@selector(registerUserNotificationSettings:)])
    {
        // Use the old API
        [app registerForRemoteNotificationTypes:UIRemoteNotificationTypeAlert | UIRemoteNotificationTypeBadge | UIRemoteNotificationTypeSound];
    }
    else
#endif
    {
        NSAssert(notificationSettings, @"Requested notification settings should be set for request before requesting user permission", nil);
        [app registerUserNotificationSettings:notificationSettings];
        [app registerForRemoteNotifications];
    }
#else
    // Not building with the latest XCode that contains iOS 8 definitions
    [app registerForRemoteNotificationTypes:UIRemoteNotificationTypeAlert | UIRemoteNotificationTypeBadge | UIRemoteNotificationTypeSound];
#endif
}

- (void)ISHPermissionNotificationApplicationDidRegisterUserNotificationSettings:(NSNotification *)note {
#pragma unused(note)
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    if (self.completionBlock) {
        self.completionBlock(self, self.permissionState, nil);
        self.completionBlock = nil;
    }
}

@end