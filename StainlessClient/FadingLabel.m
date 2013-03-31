//
//  FadingLabel.m
//  StainlessClient
//
//  Created by Danny Espinoza on 3/17/09.
//  Copyright 2009 Mesa Dynamics, LLC. All rights reserved.
//

#import "FadingLabel.h"


@implementation FadingLabel

@synthesize underlay;
@synthesize maxWidth;

- (id)initWithContentRect:(NSRect)contentRect styleMask:(NSUInteger)aStyle backing:(NSBackingStoreType)bufferingType defer:(BOOL)flag
{
	if(self = [super initWithContentRect:contentRect styleMask:NSBorderlessWindowMask backing:NSBackingStoreBuffered defer:NO]) {
		_labelView = nil;
		_fade = nil;
		_timer = nil;
				
		maxWidth = 0;
		
		[self setBackgroundColor:[NSColor clearColor]];
		[self setAlphaValue:0.0];
		[self setOpaque:NO];
		
		[self setIgnoresMouseEvents:YES];
	}
	
	return self;
}

- (void)_resetLabel
{
	if(_timer) {
		[_timer invalidate];
		_timer = nil;
	}
	
	if(_fade) {
		[_fade stopAnimation];
		[_fade setCurrentProgress:0.0];
		[_fade release];
		_fade = nil;
	}
}

- (void)dealloc
{
	[self _resetLabel];
	
	[_labelView release];
	[underlay release];
	
	[super dealloc];
}

- (void)showLabel:(NSString*)string atPoint:(NSPoint)location
{
	if(string) {
		[self _resetLabel];

		if(_labelView == nil) {
			_labelView = [[LabelView alloc] initWithFrame:NSZeroRect];
			[[self contentView] addSubview:_labelView];
			[_labelView release];

			if([[self title] isEqualToString:@"Status"]) {
				//[_labelView setBackgroundColor:[NSColor colorWithCalibratedWhite:0.0 alpha:.60]];
				[_labelView setFont:[NSFont systemFontOfSize:13.0]];
				[_labelView setHeight:16.0];
				[_labelView setPadY:1.0];
				[_labelView setRounded:NO];
				//[_labelView setShadowed:NO];
			}
		}
		
		[_labelView setLabel:string];
	}
	
	NSRect labelRect = [_labelView labelRect];
	labelRect.origin = location;
	labelRect.size.height = [_labelView height];
	labelRect.size.width += ([_labelView padX] * 2.0);
	if(maxWidth) {
		float w = (float)maxWidth;
		if(labelRect.size.width > w)
			labelRect.size.width = w;
	}
	
	[self setFrame:labelRect display:NO];
	[_labelView setFrame:[[self contentView] frame]];
	[_labelView setNeedsDisplay:YES];
	
	if([self parentWindow] == nil)
		[underlay addChildWindow:self ordered:NSWindowAbove];
	
	[self setAlphaValue:1.0];
}

- (void)hideLabel
{
	if([self parentWindow] && _fade == nil) {	
		NSDictionary* animation = [NSDictionary dictionaryWithObjectsAndKeys:
								   self, NSViewAnimationTargetKey,
								   NSViewAnimationFadeOutEffect, NSViewAnimationEffectKey,
								   nil];
		_fade = [[NSViewAnimation alloc] initWithViewAnimations:[NSArray arrayWithObject:animation]];

		[_fade setDelegate:self];
		[_fade setDuration:0.20];
		//[_fade setAnimationBlockingMode:NSAnimationNonblocking];
		[_fade setAnimationCurve:NSAnimationLinear];
		[_fade startAnimation];
	}
}

- (void)hideLabelNow
{
	if([self parentWindow]) {
		[self _resetLabel];

		[underlay removeChildWindow:self];
		[self setAlphaValue:0.0];
		[self orderOut:self];
	}
}

- (void)_hideOnTimerFire:(NSTimer*)theTimer
{
	NSNumber* fadeValue = (NSNumber*)[theTimer userInfo];
	if([fadeValue boolValue])
		[self hideLabel];
	else
		[self hideLabelNow];
	
	_timer = nil;
}

- (void)hideLabelLater:(NSTimeInterval)time fade:(BOOL)fade
{
	if([self parentWindow]) {
		if(_timer)
			[_timer invalidate];
		
		_timer = [NSTimer scheduledTimerWithTimeInterval:time target:self selector:@selector(_hideOnTimerFire:) userInfo:[NSNumber numberWithBool:fade] repeats:NO];
	}
}

// NSAnimation deleagte
- (void)animationDidEnd:(NSAnimation *)animation
{
	[self hideLabelNow];
}

@end
