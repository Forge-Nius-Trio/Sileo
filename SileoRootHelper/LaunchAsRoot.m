//
//  LaunchAsRoot.m
//  SileoRootHelper
//
//  Created by Amy on 05/04/2021.
//  Copyright © 2021 Amy While. All rights reserved.
//

#import "LaunchAsRoot.h"
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

@implementation LaunchAsRoot
-(void)launchAsRoot {
    if (geteuid()) {
        OSStatus status;
        AuthorizationFlags flags = kAuthorizationFlagDefaults;
        AuthorizationRef authRef;
        
        status = AuthorizationCreate(NULL, kAuthorizationEmptyEnvironment, flags, &authRef);
        if (status != errAuthorizationSuccess) exit(0);
        
        AuthorizationItem items = {kAuthorizationRightExecute, 0, NULL, 0};
        AuthorizationRights rights = {1, &items};
        flags = kAuthorizationFlagDefaults |
        kAuthorizationFlagInteractionAllowed |
        kAuthorizationFlagPreAuthorize |
        kAuthorizationFlagExtendRights;
        status = AuthorizationCopyRights(authRef, &rights, NULL, flags, NULL );
        
        
        if (status != errAuthorizationSuccess) {
            exit(0);
        }
        
        const char * path = [[[NSBundle mainBundle] executablePath] UTF8String];
        char * args[] = {NULL};
        
        flags = kAuthorizationFlagDefaults;
        status = AuthorizationExecuteWithPrivileges(authRef, path, flags, args,
                                                      NULL);
        AuthorizationFree(authRef, kAuthorizationFlagDefaults);
        exit(0);
    }
}
@end


