//
//  StainlessPanel.h
//  Stainless
//
//  Created by Danny Espinoza on 4/17/09.
//  Copyright 2009 Mesa Dynamics, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface StainlessPanel : NSPanel {
	NSInteger focusWid;
	NSInteger focusMode;
	BOOL focusOnAppChange;
}

@property NSInteger focusWid;
@property NSInteger focusMode;
@property BOOL focusOnAppChange;

@end
