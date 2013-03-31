//
//  LabelView.h
//  StainlessClient
//
//  Created by Danny Espinoza on 3/18/09.
//  Copyright 2009 Mesa Dynamics, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface LabelView : NSView {
@private
	//NSBezierPath* _label;
	NSBezierPath* _oval;
	NSRect _ovalRect;
	
@protected
	NSString* labelString;
	NSRect labelRect;
	
	NSFont* font;
	NSColor* color;
	NSColor* shadowColor;
	NSColor* backgroundColor;
	float height;
	float padX;
	float padY;
	BOOL rounded;
	BOOL shadowed;
}

@property(nonatomic, retain) NSString* labelString;
@property NSRect labelRect;

@property(nonatomic, retain) NSFont* font;
@property(nonatomic, retain) NSColor* color;
@property(nonatomic, retain) NSColor* shadowColor;
@property(nonatomic, retain) NSColor* backgroundColor;
@property float height;
@property float padX;
@property float padY;
@property BOOL rounded;
@property BOOL shadowed;

- (void)setLabel:(NSString*)string;

@end
