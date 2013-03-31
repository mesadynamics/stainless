//
//  StainlessTabView.m
//  StainlessClient
//
//  Created by Danny Espinoza on 9/5/08.
//  Copyright 2008 Mesa Dynamics, LLC. All rights reserved.
//

#import "StainlessTabView.h"
#import "StainlessController.h"

static NSDictionary* gSpecialAttributes = nil;

extern NSString* StainlessTabPboardType;
extern NSString* StainlessPrivateTabPboardType;

extern NSString* StainlessIconPboardType;
extern NSString* StainlessSessionPboardType;
extern NSString* StainlessGroupPboardType;
extern NSString* WebURLPboardType;
extern NSString* WebURLNamePboardType;

extern BOOL gPrivateMode;
extern BOOL gSingleSession;


@implementation StainlessTabView

@synthesize identifier;
@synthesize url;
@synthesize active;

- (id)initWithFrame:(NSRect)frame
{
    if(self = [super initWithFrame:frame]) {
		closeButton = nil;
		identifier = nil;
		url = nil;
		
		active = NO;
		special = NO;

		loading = NO;
		suspended = NO;
		mouseDown = NO;
		middleDown = NO;
	}
	
    return self;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[identifier release];
	[url release];
	
	[super dealloc];
}

- (void)awakeFromNib
{
	StainlessController* controller = (StainlessController*)[NSApp delegate];
    closeButton = [[NSButton alloc] initWithFrame:NSMakeRect([self frame].size.width - 17.0, 5.0, 13.0, 13.0)];
	
	[self addSubview:closeButton];
  	[closeButton setIgnoresMultiClick:YES];
	[closeButton setBezelStyle:NSRoundedBezelStyle];
    [closeButton setButtonType:NSMomentaryChangeButton];
    [closeButton setBordered:NO];
    [closeButton setImage:[NSImage imageNamed:@"TabClose"]];
    [closeButton setTitle:@""];
    [closeButton setImagePosition:NSImageBelow];
    [closeButton setTarget:controller];
    [closeButton setFocusRingType:NSFocusRingTypeNone];
    [closeButton setAction:@selector(closeTab:)];
	[closeButton setAutoresizingMask:NSViewMinXMargin]; 
    [closeButton release];
		
	[self setPostsFrameChangedNotifications:YES];
}

- (void)setTabIcon:(NSImage*)image fromServer:(BOOL)remote
{
	if(image == nil)
		return;

	NSString* imageName = nil;
	
	if(remote) {
		imageName = [image name];
		NSString* iconName = [[favicon image] name];
		
		if(iconName && [iconName isEqualToString:imageName]) {
			return;
		}
	}
	
	@try {
		NSData* iconData = [image TIFFRepresentationUsingCompression:NSTIFFCompressionNone factor:1.0];
		if(iconData) {
			NSImage* icon = [[[NSImage alloc] initWithData:iconData] autorelease];
			[icon setScalesWhenResized:YES];
			[icon setSize:NSMakeSize(16.0, 16.0)];
			if(remote)
				[icon setName:[NSString stringWithString:imageName]];
			[favicon setImage:icon];
		}
	}
	
	@catch (NSException* anException) {
	}	
}

- (void)setTabIconData:(NSData*)data withName:(NSString*)name
{
	if(data == nil)
		return;
	
	if(name) {
		NSString* iconName = [[favicon image] name];
		
		if(iconName && [iconName isEqualToString:name]) {
			return;
		}
	}

	@try {
		NSImage* icon = [[[NSImage alloc] initWithData:data] autorelease];
		[icon setScalesWhenResized:YES];
		[icon setSize:NSMakeSize(16.0, 16.0)];
		if(name)
			[icon setName:[NSString stringWithString:name]];
		[favicon setImage:icon];
	}
	
	@catch (NSException* anException) {
	}	
}

- (void)setTabURL:(NSString*)string
{
	if(string && (url == nil || [string isEqualToString:url] == NO)) {
		self.url = string;
	}	
}

- (void)setTabTitle:(NSString*)string
{
	if(string && [string isEqualToString:[title stringValue]] == NO) {
		if(special) {
			if(gSpecialAttributes == nil)
				gSpecialAttributes = [[NSDictionary alloc] initWithObjectsAndKeys:
										[NSFont systemFontOfSize:[NSFont smallSystemFontSize]], NSFontAttributeName,
										[NSNumber numberWithFloat:.155], NSObliquenessAttributeName,
										nil];
			
			NSAttributedString* aString = [[[NSAttributedString alloc] initWithString:string attributes:gSpecialAttributes] autorelease];
			[title setAttributedStringValue:aString];
		}
		else
			[title setStringValue:[NSString stringWithString:string]];
		
		[self setToolTip:[NSString stringWithString:string]];
	}	
}

- (void)setTabSpecial
{
	if(special == NO) {
		//NSFont* font = [[NSFontManager sharedFontManager] convertFont:[NSFont systemFontOfSize:11.0] toFamily:@"Lucida Sans"];
		//font = [[NSFontManager sharedFontManager] convertFont:font toHaveTrait:NSItalicFontMask];
		//[title setFont:font];

		special = YES;
	}
}

- (NSString*)tabURL
{
	if(url == nil)
		return nil;
	
	return [NSString stringWithString:url];
}

- (NSString*)tabTitle
{
	return [NSString stringWithString:[self toolTip]];
}

- (NSData*)tabIconData
{
	@try {
		NSImage* image = [favicon image];
		return [image TIFFRepresentationUsingCompression:NSTIFFCompressionNone factor:1.0];
	}
	
	@catch (NSException* anException) {
	}	

	return nil;
}

- (BOOL)acceptsFirstMouse:(NSEvent *)theEvent
{
	return YES;
}

- (void)otherMouseDown:(NSEvent *)theEvent
{
	if(middleDown == NO) {
		[closeButton highlight:YES];
		middleDown = YES;
	}
}

- (void)otherMouseUp:(NSEvent *)theEvent
{
	if(middleDown) {
		[closeButton highlight:NO];

		NSPoint dragPosition = [self convertPoint:[theEvent locationInWindow] fromView:nil];
		if(NSPointInRect(dragPosition, [self bounds]))
			[closeButton performClick:self];
		
		middleDown = NO;
	}
}

- (void)otherMouseDragged:(NSEvent *)theEvent
{
	if(middleDown) {
		NSPoint dragPosition = [self convertPoint:[theEvent locationInWindow] fromView:nil];
		if(NSPointInRect(dragPosition, [self bounds]))
			[closeButton highlight:YES];
		else
			[closeButton highlight:NO];
	}
}

- (void)mouseDown:(NSEvent *)theEvent
{	
	StainlessController* controller = (StainlessController*)[NSApp delegate];

	if(active) {
		if([controller canDragClientWindow])
			mouseDown = YES;
	}
	else {
		mouseDown = NO;
		[controller switchTab:self];
		
		/*NSPoint mouse = [NSEvent mouseLocation];
		mouse = [[self window] mouseLocationOutsideOfEventStream];
		mouse = [[self window] convertBaseToScreen:mouse];
		NSScreen* screen = [[self window] screen];
		mouse.y = [screen frame].size.height - mouse.y;
		
		CGEventRef mu = CGEventCreateMouseEvent(NULL, kCGEventLeftMouseUp, NSPointToCGPoint(mouse), kCGMouseButtonLeft);
		if(mu) {
			CGEventPost(kCGSessionEventTap, mu);
			CFRelease(mu);
		}
		
		CGEventRef md = CGEventCreateMouseEvent(NULL, kCGEventLeftMouseDown, NSPointToCGPoint(mouse), kCGMouseButtonLeft);
		if(md) {
			CGEventPost(kCGSessionEventTap, md);
			CFRelease(md);
		}*/
	}
}

- (void)mouseUp:(NSEvent *)theEvent
{
	mouseDown = NO;
}

- (void)mouseEntered:(NSEvent *)theEvent
{
	StainlessController* controller = (StainlessController*)[NSApp delegate];
	if(active && [controller canDragClientWindow])
		[[self window] setMovableByWindowBackground:NO];
}

- (void)mouseExited:(NSEvent *)theEvent
{
	if(active)
		[[self window] setMovableByWindowBackground:YES];
}

- (void)mouseDragged:(NSEvent *)theEvent
{
	if(mouseDown) {		
		mouseDown = NO;
		
		StainlessController* controller = (StainlessController*)[NSApp delegate];
		
#if 0	
		NSImage* webImage = [controller webViewImage];
		NSSize webImageSize = [webImage size];
		float scale = 400.0 / webImageSize.width;
		float newHeight = scale * webImageSize.height;
		NSSize newSize = NSMakeSize(400.0, newHeight);
#endif
		
		[closeButton setHidden:YES];
		
		NSRect bounds = NSInsetRect([self bounds], 0.0, 0.0);
			
		NSImage* tabImage = [[NSImage alloc] initWithSize:bounds.size];
		[self lockFocus];
		NSBitmapImageRep* bitmap = [[[NSBitmapImageRep alloc] initWithFocusedViewRect:bounds] autorelease];
		[self unlockFocus];
		[tabImage addRepresentation:bitmap];

		NSImage* moveImage = [[NSImage alloc] initWithSize:bounds.size];
		[moveImage lockFocus];
		[tabImage drawInRect:bounds fromRect:NSZeroRect operation:NSCompositeCopy fraction:0.75];
		[moveImage unlockFocus];
		
		NSPoint dragPosition = [self convertPoint:[theEvent locationInWindow] fromView:nil];
		dragPoint = dragPosition;
		dragPosition.y = bounds.origin.y;
		dragPosition.x = bounds.origin.x;
		
		NSString* pboardType = (gPrivateMode ? StainlessPrivateTabPboardType : StainlessTabPboardType);
		
		NSPasteboard* pboard = [NSPasteboard pasteboardWithName:NSDragPboard];
		[pboard declareTypes:[NSArray arrayWithObject:pboardType] owner:self];
		NSData* data = [[controller identifier] dataUsingEncoding:NSUTF8StringEncoding];
		[pboard setData:data forType:pboardType];
		
		[self setHidden:YES];
		[[self superview] setNeedsDisplay:YES];
		
		[self dragImage:moveImage at:dragPosition offset:NSMakeSize(0.0, 0.0) event:theEvent pasteboard:pboard source:self slideBack:NO];
	}
}

- (void)drawRect:(NSRect)rect
{
	NSRect frame = [self bounds];

	if(active) {
		NSImage* left = [NSImage imageNamed:(gPrivateMode ? @"PrivateTabLeft" : @"TabLeft")];
		NSImage* middle = [NSImage imageNamed:(gPrivateMode ? @"PrivateTabMiddle" : @"TabMiddle")];
		NSImage* right = [NSImage imageNamed:(gPrivateMode ? @"PrivateTabRight" : @"TabRight")];
				
		NSDrawThreePartImage(frame, left, middle, right, NO, NSCompositeSourceOver, 1.0, NO);
	}
}

- (void)updateTrackingAreas
{
	NSTrackingAreaOptions options = NSTrackingMouseEnteredAndExited + NSTrackingActiveInKeyWindow + NSTrackingInVisibleRect;
	NSTrackingArea* tracker = [[NSTrackingArea alloc] initWithRect:[self bounds] options:options owner:self userInfo:nil];
	[self addTrackingArea:tracker];
	
	[super updateTrackingAreas];
}

- (void)highlight
{	
	[self setActive:YES];
}

- (void)startLoading
{
	if(loading == NO) {
		loading = YES;
	
		[favicon setHidden:YES];
		[busy startAnimation:self];
	}
}

- (void)stopLoading
{
	if(loading) {
		loading = NO;
		
		[busy stopAnimation:self];
		[favicon setHidden:NO];
	}
}

- (void)suspend
{
	suspended = YES;
}

- (void)unsuspend
{
	suspended = NO;
}

- (BOOL)isSuspended
{
	return suspended;
}

- (BOOL)writeToPasteboard:(NSPasteboard*)pasteBoard
{
	if(url && [url length]) {
		NSString* urlString = [self tabURL];
		NSString* tabTitle = [self tabTitle];
		NSData* tabIconData = [self tabIconData];
		
		[pasteBoard declareTypes:[NSArray arrayWithObjects: NSURLPboardType, WebURLPboardType, WebURLNamePboardType, NSStringPboardType, StainlessIconPboardType, StainlessSessionPboardType, StainlessGroupPboardType, nil] owner:self];
		
		NSURL* tabURL = [NSURL URLWithString:urlString];
		[tabURL writeToPasteboard:pasteBoard];
		[pasteBoard setString:urlString forType:WebURLPboardType];
		if(tabTitle)
			[pasteBoard setString:tabTitle forType:WebURLNamePboardType];
		[pasteBoard setString:urlString forType:NSStringPboardType];
		if(tabIconData)
			[pasteBoard setData:tabIconData forType:StainlessIconPboardType];
		
		// todo: session and group need to come from tab info, not from parent process controller
		
		StainlessController* controller = (StainlessController*)[NSApp delegate];
		
		NSString* session = @"default";
		if(gSingleSession)
			session = [NSString stringWithString:[controller session]];
		[pasteBoard setString:session forType:StainlessSessionPboardType];
		
		if(gSingleSession) {
			NSString* group = [NSString stringWithString:[controller group]];
			[pasteBoard setString:group forType:StainlessGroupPboardType];
		}
		
		return YES;
	}
	
	return NO;
}

// NSComparisonMethods protocol
- (NSComparisonResult)leftToRightCompare:(StainlessTabView*)view
{
	if([view frame].origin.x > [self frame].origin.x)
		return NSOrderedAscending;
	
	return NSOrderedDescending;
}

// NSDraggingSource protocol
- (NSDragOperation)draggingSourceOperationMaskForLocal:(BOOL)isLocal
{
	return NSDragOperationPrivate;
}

- (void)draggedImage:(NSImage *)anImage endedAt:(NSPoint)aPoint operation:(NSDragOperation)operation
{
	[closeButton setHidden:NO];
	[self setHidden:NO];
	[[self superview] setNeedsDisplay:YES];
			
	if(operation == NSDragOperationNone) {
		NSPoint windowPoint = [NSEvent mouseLocation];
		windowPoint.x -= [self frame].origin.x;
		windowPoint.x -= dragPoint.x;
		windowPoint.y -= [self frame].origin.y;
		windowPoint.y += ([self frame].size.height - dragPoint.y);
		windowPoint.y -= [[self window] contentRectForFrameRect:[[self window] frame]].size.height;
		
		windowPoint.x += [self frame].origin.x;

		StainlessController* controller = (StainlessController*)[NSApp delegate];
		NSRect frame = [[self window] frame];
		frame.origin = windowPoint;
		frame.origin.x -= 3.0;
		[controller undockTabToFrame:frame];	
		
		[[self window] setFrameOrigin:windowPoint];
	}

	if([[self window] isVisible] == NO)
		[[self window] makeKeyAndOrderFront:self];	
}

@end
