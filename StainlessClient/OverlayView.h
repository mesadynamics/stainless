//
//  OverlayView.h
//  StainlessClient
//
//  Created by Danny Espinoza on 10/28/08.
//  Copyright 2008 Mesa Dynamics, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface OverlayView : NSView {
	NSMutableArray* holes;
	NSPoint offset;
	NSRect selection;
}

@property(nonatomic, retain) NSMutableArray* holes;
@property NSPoint offset;
@property NSRect selection;

@end
