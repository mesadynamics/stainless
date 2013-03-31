//
//  StainlessProxy.h
//  StainlessClient
//
//  Created by Danny Espinoza on 1/29/09.
//  Copyright 2009 Mesa Dynamics, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "StainlessBridge.h"
#import "StainlessController.h"


@interface StainlessProxy : NSObject <StainlessClientProxy> {
	StainlessController* controller;
}

@property(retain) StainlessController* controller;

@end
