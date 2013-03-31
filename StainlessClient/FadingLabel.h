//
//  FadingLabel.h
//  StainlessClient
//
//  Created by Danny Espinoza on 3/17/09.
//  Copyright 2009 Mesa Dynamics, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "OverlayWindow.h"
#import "LabelView.h"


@interface FadingLabel : NSPanel {
@private
	LabelView* _labelView;
	NSViewAnimation* _fade;
	NSTimer* _timer;

@protected
	NSWindow* underlay;
	int maxWidth;
}

@property(nonatomic, retain) NSWindow* underlay;
@property int maxWidth;

- (void)showLabel:(NSString*)string atPoint:(NSPoint)location;
- (void)hideLabel;
- (void)hideLabelNow;
- (void)hideLabelLater:(NSTimeInterval)time fade:(BOOL)fade;

@end
