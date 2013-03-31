//
//  StainlessTabView.h
//  StainlessClient
//
//  Created by Danny Espinoza on 9/5/08.
//  Copyright 2008 Mesa Dynamics LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface StainlessTabView : NSView {
	IBOutlet NSImageView* favicon;
	IBOutlet NSProgressIndicator* busy;
	IBOutlet NSTextField* title;

	NSButton* closeButton;
	
	NSString* identifier;
	NSString* url;
	
	BOOL active;
	BOOL special;
	
	BOOL loading;
	BOOL suspended;
	BOOL mouseDown;
	BOOL middleDown;
	
	NSPoint dragPoint;
}

@property(retain) NSString* identifier;
@property(retain) NSString* url;
@property BOOL active;

- (void)setTabIcon:(NSImage*)image fromServer:(BOOL)remote;
- (void)setTabIconData:(NSData*)data withName:(NSString*)name;
- (void)setTabURL:(NSString*)string;
- (void)setTabTitle:(NSString*)string;
- (void)setTabSpecial;

- (NSString*)tabURL;
- (NSString*)tabTitle;
- (NSData*)tabIconData;

- (void)highlight;

- (void)startLoading;
- (void)stopLoading;
- (void)suspend;
- (void)unsuspend;
- (BOOL)isSuspended;

- (BOOL)writeToPasteboard:(NSPasteboard*)pasteBoard;

- (NSComparisonResult)leftToRightCompare:(StainlessTabView*)view;

@end
