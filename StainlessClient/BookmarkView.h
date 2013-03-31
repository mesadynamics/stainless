//
//  BookmarkView.h
//  StainlessClient
//
//  Created by Danny Espinoza on 1/30/09.
//  Copyright 2009 Mesa Dynamics, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface BookmarkView : NSButton {
	BOOL mouseDown;
	BOOL needsUpdate;
	BOOL isJavascript;
	BOOL isGroup;
	BOOL isOpen;
	NSMutableDictionary* bookmarkInfo;
	NSRect hysteresis;
	
	BOOL autoOpen;
	int index;
}

- (id)initWithFrame:(NSRect)frame pasteBoard:(NSPasteboard*)pboard;

@property(nonatomic, retain) NSMutableDictionary* bookmarkInfo;
@property BOOL isJavascript;
@property BOOL isGroup;
@property BOOL isOpen;
@property int index;

+ (NSImage*)iconFromData:(NSData*)iconData urlString:(NSString*)urlString;

- (void)updateOnIconChange;
- (BOOL)writeToPasteboard:(NSPasteboard*)pboard;

@end
