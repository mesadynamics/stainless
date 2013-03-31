//
//  BookmarkView.m
//  StainlessClient
//
//  Created by Danny Espinoza on 1/30/09.
//  Copyright 2009 Mesa Dynamics, LLC. All rights reserved.
//

#import "BookmarkView.h"
#import "StainlessController.h"
#import "StainlessShelfView.h"
#import "StainlessCookieJar.h"
#import "StainlessBridge.h"

extern NSString* StainlessBookmarkPboardType;
extern NSString* StainlessIconPboardType;
extern NSString* StainlessSessionPboardType;
extern NSString* StainlessGroupPboardType;
extern NSString* WebURLPboardType;
extern NSString* WebURLNamePboardType;


@implementation BookmarkView

@synthesize bookmarkInfo;
@synthesize isJavascript;
@synthesize isGroup;
@synthesize isOpen;
@synthesize index;

+ (NSImage*)iconFromData:(NSData*)iconData urlString:(NSString*)urlString
{
	NSImage* iconImage = nil;
	if(iconData)
		iconImage = [[[NSImage alloc] initWithData:iconData] autorelease];
	
	if(iconImage == nil) {
		@try {
			Class webIconDatabaseClass = NSClassFromString(@"WebIconDatabase");
			if(webIconDatabaseClass) {
				id iconDB = [webIconDatabaseClass performSelector:@selector(sharedIconDatabase)];
				NSString* iconURL = [iconDB iconURLForURL:urlString];
				if([iconURL length])
					iconImage = [iconDB iconForURL:urlString withSize:NSMakeSize(16.0, 0.0)];
			}
		}
		
		@catch (NSException* anException) {
			iconImage = nil;
		}
	}
	
	if(iconImage == nil) {
		iconData = nil;
		iconImage = [NSImage imageNamed:@"Web"];
	}
	
	return iconImage;
}

- (id)initWithFrame:(NSRect)frame
{
    if(self = [super initWithFrame:frame]) {
		[self setIgnoresMultiClick:YES];
		
		[self setBezelStyle:NSRoundedBezelStyle];
		[self setButtonType:NSMomentaryChangeButton];
		[self setBordered:NO];
		[self setTitle:@""];
		[self setImagePosition:NSImageBelow];
		[self setFocusRingType:NSFocusRingTypeNone];
		[self setAutoresizingMask:NSViewMinYMargin]; 
				
		mouseDown = NO;
		needsUpdate = NO;
		isJavascript = NO;
		isGroup = NO;
		isOpen = NO;
		
		index = 0;
		
		autoOpen = NO;
	}
	
    return self;
}

- (id)initWithFrame:(NSRect)frame pasteBoard:(NSPasteboard*)pboard
{
	if(self = [self initWithFrame:frame]) {
		NSString* urlString = [pboard stringForType:WebURLPboardType];
		if(urlString == nil) {
			NSURL* url = [NSURL URLFromPasteboard:pboard];
			urlString = [url absoluteString];
		}
		
		if(urlString) {
			NSString* title = [pboard stringForType:WebURLNamePboardType];
			
			NSImage* iconImage = nil;
			NSData* iconData = [pboard dataForType:StainlessIconPboardType];
			if(iconData)
				iconImage = [[[NSImage alloc] initWithData:iconData] autorelease];
			
			if(iconImage)
				iconImage = [iconImage thumbnailWithSize:NSMakeSize(16.0, 16.0)];
			else {
				@try {
					Class webIconDatabaseClass = NSClassFromString(@"WebIconDatabase");
					if(webIconDatabaseClass) {
						id iconDB = [webIconDatabaseClass performSelector:@selector(sharedIconDatabase)];
						NSString* iconURL = [iconDB iconURLForURL:urlString];
						if([iconURL length])
							iconImage = [iconDB iconForURL:urlString withSize:NSMakeSize(16.0, 0.0)];
					}
				}
				
				@catch (NSException* anException) {
					iconImage = nil;
				}
			}
			
			if(iconImage == nil) {
				iconData = nil;
				iconImage = [NSImage imageNamed:@"Web"];
			}
			
			NSString* session = [pboard stringForType:StainlessSessionPboardType];
			
			self.bookmarkInfo = [NSMutableDictionary dictionary];
			[bookmarkInfo setObject:urlString forKey:@"url"];
			if(title)
				[bookmarkInfo setObject:title forKey:@"title"];
			if(iconData)
				[bookmarkInfo setObject:iconData forKey:@"icon"];
			if(session) {
				NSString* domain = [StainlessCookieJar domainForURLString:urlString];
				if(domain) {
					[bookmarkInfo setObject:domain forKey:@"domain"];
					
					NSString* group = [pboard stringForType:StainlessGroupPboardType];
					if(group) {
						CFUUIDRef uuidObj = CFUUIDCreate(NULL);
						CFStringRef uuidString = CFUUIDCreateString(NULL, uuidObj);
						NSString* sessionStamp = [NSString stringWithString:(NSString*)uuidString];
						CFRelease(uuidString);
						CFRelease(uuidObj);
						
						[[StainlessCookieJar sharedCookieJar] copyDomain:domain inGroup:group inSession:session toSession:sessionStamp];
						
						[bookmarkInfo setObject:sessionStamp forKey:@"session"];
					}
					else
						[bookmarkInfo setObject:session forKey:@"session"];
				}
			}
			
			[self setTag:[urlString hash]];
			
			[self setImage:iconImage];
			if([urlString hasPrefix:@"javascript:"])
				[self setIsJavascript:YES];
			//if(title)
			//	[self setToolTip:title];
			//else
			//	[self setToolTip:urlString];
			
			if(NSIsEmptyRect(frame) == NO && iconData == nil)
				[self updateOnIconChange];

			if([urlString hasPrefix:@"group:"])
				[self setIsGroup:YES];
		}
	}
	
	return self;
}

- (void)dealloc
{
	if(needsUpdate)
		[[NSNotificationCenter defaultCenter] removeObserver:self name:@"WebIconDatabaseDidAddIconNotification" object:nil];

	[bookmarkInfo release];
	[super dealloc];
}

- (void)drawRect:(NSRect)rect
{
	if(isOpen) {
		NSImage* icon = [NSImage imageNamed:@"NSGoRightTemplate"];
		NSRect rect = [self bounds];
		rect.origin.x++;
		[icon drawInRect:NSInsetRect(rect, 2.0, 2.0) fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:.50];
	}
	else
		[super drawRect:rect];
}

- (NSMenu *)menuForEvent:(NSEvent *)theEvent
{
	StainlessShelfView* shelf = (StainlessShelfView*) [self superview];
	[shelf setSelection:self];
	[shelf hideBookmark:YES];

	return [super menuForEvent:theEvent];
}

- (void)updateTrackingAreas
{
	NSTrackingAreaOptions options = NSTrackingMouseEnteredAndExited + NSTrackingActiveInKeyWindow + NSTrackingInVisibleRect;
	NSTrackingArea* tracker = [[NSTrackingArea alloc] initWithRect:[self bounds] options:options owner:self userInfo:nil];
	[self addTrackingArea:tracker];
	
	[super updateTrackingAreas];
}

- (BOOL)acceptsFirstMouse:(NSEvent *)theEvent
{
	return YES;
}

- (void)otherMouseUp:(NSEvent *)theEvent
{
	[self performClick:self];
}

- (void)mouseEntered:(NSEvent *)theEvent
{
	extern BOOL gMouseOverGroups;
	
	if(gMouseOverGroups && isGroup && !isOpen && autoOpen == NO) {
		autoOpen = YES;
		[NSTimer scheduledTimerWithTimeInterval:0.75 target:self selector:@selector(_autoOpen:) userInfo:nil repeats:NO];
	}
	
	StainlessShelfView* shelf = (StainlessShelfView*) [self superview];
	[shelf showBookmark:self];
}

- (void)mouseExited:(NSEvent *)theEvent
{
	StainlessShelfView* shelf = (StainlessShelfView*) [self superview];
	[shelf hideBookmark:NO];
	
	autoOpen = NO;
}

- (void)mouseDown:(NSEvent *)theEvent
{
	NSPoint dragPosition = [theEvent locationInWindow];
	hysteresis = NSMakeRect(dragPosition.x - 3.0, dragPosition.y - 3.0, 7.0, 7.0);
		
	[self highlight:YES];
	
	mouseDown = YES;
}

- (void)mouseUp:(NSEvent *)theEvent
{
	if(mouseDown)
		[self performClick:nil];
	
	[self highlight:NO];

	mouseDown = NO;
}

- (void)mouseDragged:(NSEvent *)theEvent
{
	if(mouseDown) {
		NSPoint dragPosition = [theEvent locationInWindow];
		if(NSPointInRect(dragPosition, hysteresis)) {
			return;
		}
		
		[self highlight:NO];
		
		mouseDown = NO;
				
		NSPasteboard* pboard = [NSPasteboard pasteboardWithName:NSDragPboard];
		if([self writeToPasteboard:pboard]) {
			NSPoint framePosition = [self convertPoint:[theEvent locationInWindow] fromView:nil];
			NSPoint dragPosition = [theEvent locationInWindow];
			dragPosition.x -= framePosition.x;
			dragPosition.y -= framePosition.y;
			
			StainlessShelfView* shelf = (StainlessShelfView*) [self superview];
			[shelf hideBookmark:YES];

			[self setHidden:YES];
			
			[[self window] dragImage:[self image] at:dragPosition offset:NSMakeSize(0.0, 0.0) event:theEvent pasteboard:pboard source:self slideBack:NO];

			[self setHidden:NO];
		}
	}
}

- (void)_autoOpen:(NSTimer*)aTimer
{
	if(!isOpen && autoOpen)
		[self performClick:self];
	
	autoOpen = NO;
}

- (void)_receivedIconChangedNotification:(NSNotification *)notification
{
	NSDictionary* userInfo = [notification userInfo];
	if([userInfo isKindOfClass:[NSDictionary class]]) {
		// ref: WebIconDatabase.mm (WebKit)
 		NSString* iconUrlString = [userInfo objectForKey:@"WebIconNotificationUserInfoURLKey"];
		if([iconUrlString isKindOfClass:[NSString class]]) {
			NSString* urlString = [bookmarkInfo objectForKey:@"url"];
			if ([urlString isEqualTo:iconUrlString]) {
				NSImage* iconImage = nil;
				
				@try {
					Class webIconDatabaseClass = NSClassFromString(@"WebIconDatabase");
					if(webIconDatabaseClass) {
						id iconDB = [webIconDatabaseClass performSelector:@selector(sharedIconDatabase)];
						iconImage = [iconDB iconForURL:urlString withSize:NSMakeSize(16.0, 16.0)];
					}
				}
				
				@catch (NSException* anException) {
					iconImage = nil;
				}
				
				if(iconImage) {
					needsUpdate = NO;

					[self setImage:iconImage];
					
					NSData* iconData = [iconImage TIFFRepresentation];
					[bookmarkInfo setObject:iconData forKey:@"icon"];

					[[NSNotificationCenter defaultCenter] removeObserver:self name:@"WebIconDatabaseDidAddIconNotification" object:nil];

					StainlessShelfView* shelf = (StainlessShelfView*) [self superview];
					[shelf commitBookmarks];
				}
			}
		}
	}
}

- (void)updateOnIconChange
{
	if(needsUpdate == NO) {
		needsUpdate = YES;
		
		// ref: WebIconDatabase.mm (WebKit)
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_receivedIconChangedNotification:) name:@"WebIconDatabaseDidAddIconNotification" object:nil];        
	}
}

- (BOOL)writeToPasteboard:(NSPasteboard*)pboard
{
	NSString* urlString = [bookmarkInfo objectForKey:@"url"];
	if(urlString) {
		NSString* title = [bookmarkInfo objectForKey:@"title"];
		NSData* iconData = [bookmarkInfo objectForKey:@"icon"];
		
		[pboard declareTypes:[NSArray arrayWithObjects:NSURLPboardType, WebURLPboardType, WebURLNamePboardType, NSStringPboardType, StainlessBookmarkPboardType, StainlessIconPboardType, nil] owner:self];
		
		StainlessController* controller = (StainlessController*)[NSApp delegate];
		StainlessShelfView* shelf = (StainlessShelfView*) [self superview];
		NSString* bookString = [NSString stringWithFormat:@"bookmark:p%d/s%d/u%qi", [controller clientPid], [shelf shelfIndex], [self tag]];
		[pboard setString:bookString forType:StainlessBookmarkPboardType];
				
		NSURL* url = [NSURL URLWithString:urlString];
		[url writeToPasteboard:pboard];
		[pboard setString:urlString forType:WebURLPboardType];
		if(title)
			[pboard setString:title forType:WebURLNamePboardType];
		[pboard setString:urlString forType:NSStringPboardType];
		if(iconData)
			[pboard setData:iconData forType:StainlessIconPboardType];

		return YES;
	}

	return NO;
}

// NSComparisonMethods protocol
- (NSComparisonResult)topToBottomCompare:(BookmarkView*)view
{
	if([view frame].origin.y < [self frame].origin.y)
		return NSOrderedAscending;
	
	return NSOrderedDescending;
}

@end
