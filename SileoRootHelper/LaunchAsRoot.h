//
//  LaunchAsRoot.h
//  Sileo
//
//  Created by Amy on 05/04/2021.
//  Copyright © 2021 Amy While. All rights reserved.
//

#ifndef LaunchAsRoot_h
#define LaunchAsRoot_h
#import <Foundation/Foundation.h>
#import <Security/Authorization.h>

@protocol LaunchAsRootProtocol
-(id)init;
-(void)launchAsRoot;
@end

@interface LaunchAsRoot: NSObject<LaunchAsRootProtocol>
@end
#endif /* LaunchAsRoot_h */
