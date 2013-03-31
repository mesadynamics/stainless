//
//  StainlessBarView.m
//  StainlessClient
//
//  Created by Danny Espinoza on 9/12/08.
//  Copyright 2008 Mesa Dynamics, LLC. All rights reserved.
//

#import "StainlessBarView.h"
#import "StainlessView.h"
#import "StainlessBridge.h"
#import "StainlessController.h"
#import "NewTabButton.h"

extern NSString* StainlessTabPboardType;
extern NSString* StainlessPrivateTabPboardType;

extern BOOL gPrivateMode;


@implementation StainlessBarView

- (id)initWithFrame:(NSRect)frame
{
    if(self = [super initWithFrame:frame]) {
		tabControllers = [[NSMutableDictionary alloc] init];
		activeTab = nil;
		
		newTabButton = nil;
		
		dragOffset = -1;
		dragIndex = -1;
	}
	
    return self;
}

- (void)awakeFromNib
{
	StainlessController* controller = (StainlessController*)[NSApp delegate];
	
	NSRect frame = [self frame];
	frame.origin.y += 8.0;
	frame.origin.x += 4.0;
	frame.size.width = 16.0;
	frame.size.height = 16.0;
	
    newTabButton = [[NewTabButton alloc] initWithFrame:frame];
	
	[[self superview] addSubview:newTabButton];
    [newTabButton setBezelStyle:NSRoundedBezelStyle];
    [newTabButton setButtonType:NSMomentaryChangeButton];
    [newTabButton setBordered:NO];
    [newTabButton setImage:[NSImage imageNamed:@"NSAddTemplate"]];
    [newTabButton setTitle:@""];
    [newTabButton setImagePosition:NSImageBelow];
    [newTabButton setTarget:controller];
    [newTabButton setFocusRingType:NSFocusRingTypeNone];
    [newTabButton setAction:@selector(newTab:)];
	[newTabButton setAutoresizingMask:NSViewMinYMargin]; 
	[newTabButton release];
}

- (void)dealloc
{
	[tabControllers release];
	
	[super dealloc];
}

- (void)drawRect:(NSRect)rect
{
	NSArray* subviews = [self subviews];
	int count = [subviews count];
	float w = 0.0;
	
	if([subviews count] > 0) {
		w = ([self frame].size.width - 24.0) / (float) count;
		
		if(w > 210.0)
			w = 210.0;
		else if(w < 40.0)
			w = 40.0;
	}
	
	NSRect lineRect = [self bounds];
	lineRect.size.width = 1.0;
	lineRect.size.height -= 6.0;
	lineRect.origin.x += 3.0;
	lineRect.origin.y += 2.0;
	int wi = (int)w;
	
	if([[self window] isKeyWindow])
		[[NSColor darkGrayColor] set];
	else
		[[NSColor grayColor] set];
	
	NSRect activeRect;
	if(activeTab)
		activeRect = NSInsetRect([activeTab frame], -1.0, 0.0);
	
	for(int i = 0; i < count; i++) {
		lineRect.origin.x += (float)wi;

		if(activeTab && [activeTab isHidden] == NO && NSIntersectsRect(activeRect, lineRect))
			continue;
	
		NSRectFill(lineRect);		
	}
}

- (void)prepareForDragging
{
	NSString* pboardType = (gPrivateMode ? StainlessPrivateTabPboardType : StainlessTabPboardType);
	[self registerForDraggedTypes:[NSArray arrayWithObject:pboardType]];
}

- (void)prepareForUndocking
{
	[self setHidden:YES];

	NSRect frame = [self frame];
	frame.origin.y += 8.0;
	frame.origin.x = 210.0 + 4.0;
	frame.size.width = 16.0;
	frame.size.height = 16.0;
	[newTabButton setFrame:frame];
}

- (void)updateClientWithIdentifier:(NSString*)identifier
{
	StainlessController* controller = (StainlessController*)[NSApp delegate];

	id connection = [controller connection];
	if(connection == nil)
		return;
	
	NSViewController* vc = [tabControllers objectForKey:identifier];
	if(vc) {
		StainlessTabView* tab = (StainlessTabView*)[vc view];
		if(tab) {
			StainlessClient* tabClient = [connection clientWithIdentifier:identifier];
			[tab setTabURL:[tabClient url]];
			[tab setTabTitle:[tabClient title]];
			[tab setTabIcon:[tabClient icon] fromServer:YES];
			
			if([tabClient busy])
				[tab startLoading];
			else
				[tab stopLoading];
		}
	}
}

- (void)syncClientList:(NSArray*)clientList inWindowWithIdentifier:(NSString*)clientIdentifier
{	
	[clientList retain];
	
	NSArray* subviews = [self subviews];
	[subviews makeObjectsPerformSelector:@selector(suspend)];

	float x = 3.0;
	float w = 0.0;
	
	if([clientList count] > 0) {
		w = ([self frame].size.width - 24.0) / (float) [clientList count];
		
		if(w > 210.0)
			w = 210.0;
		else if(w < 40.0)
			w = 40.0;
	}
	
	int wi = (int)w;

	for(NSDictionary* client in clientList) {
		NSString* identifier = [client objectForKey:@"Identifier"];
		
		BOOL newTab = NO;
		
		NSViewController* vc = [tabControllers objectForKey:identifier];
		if(vc == nil) {
			@try {
				vc = [[NSViewController alloc] initWithNibName:@"Tab" bundle:nil];
				[tabControllers setObject:vc forKey:identifier];
				[vc release];
			
				newTab = YES;
			}
			
			@catch (NSException* anException) {
				NSLog(@"%@ exception instantiating tab %@: %@", [anException name], identifier, [anException reason]);
				continue;
			}			
		}
		
		StainlessTabView* tab = (StainlessTabView*)[vc view];
		if(tab == nil) {
			NSLog(@"Error loading tab view: %@", identifier);
			continue;
		}
		
		if(newTab) {
			[tab setIdentifier:identifier];
			
			if(activeTab == nil && [identifier isEqualToString:clientIdentifier]) {
				[tab highlight];
				activeTab = tab;
			}
		}
		
		if([subviews containsObject:tab] == NO)
			[self addSubview:tab];
		
		[tab unsuspend];

		[tab setFrame:NSMakeRect(x, 0.0, (float)wi, 25.0)];
		x += (float)wi;

		NSString* session = [client objectForKey:@"Session"];
		if(session)
			[tab setTabSpecial];

		NSString* url = [client objectForKey:@"URL"];
		[tab setTabURL:url];
		
		NSString* title = [client objectForKey:@"Title"];
		[tab setTabTitle:title];
		
		NSNumber* busy = [client objectForKey:@"Busy"];
		if(busy && [busy boolValue] == YES)
			[tab startLoading];
		else
			[tab stopLoading];
		
		NSData* iconData = [client objectForKey:@"IconData"];
		NSString* iconName = [client objectForKey:@"IconName"];
		[tab setTabIconData:iconData withName:iconName];
	}
	
	[clientList release];
	
	NSArray* allTabs = [NSArray arrayWithArray:[self subviews]];
	for(StainlessTabView* tab in allTabs) {
		if([tab isSuspended]) {
			[tabControllers removeObjectForKey:[tab identifier]];
			[tab removeFromSuperview];
		}
	}
	
	NSRect frame = [self frame];
	frame.origin.y += 8.0;
	frame.origin.x = x + 4.0;
	frame.size.width = 16.0;
	frame.size.height = 16.0;
	[newTabButton setFrame:frame];
	
	[self setHidden:NO];
	[self setNeedsDisplay:YES];
}

- (void)resizeToWindow
{
	NSArray* subviews = [self subviews];
	
	float x = 3.0;
	float w = 0.0;
	
	if([subviews count] > 0) {
		w = ([self frame].size.width - 24.0) / (float) [subviews count];
		
		if(w > 210.0)
			w = 210.0;
		else if(w < 40.0)
			w = 40.0;
	}
	
	int wi = (int)w;

	NSArray* sortedTabs = [subviews sortedArrayUsingSelector:@selector(leftToRightCompare:)];
	for(StainlessTabView* tab in sortedTabs) {
		[tab setFrame:NSMakeRect(x, 0.0, (float)wi, 25.0)];
		x += (float)wi;
	}

	NSRect frame = [self frame];
	frame.origin.y += 8.0;
	frame.origin.x = x + 4.0;
	frame.size.width = 16.0;
	frame.size.height = 16.0;
	[newTabButton setFrame:frame];
}

- (NSArray*)allTabs
{
	NSArray* subviews = [self subviews];
	return [subviews sortedArrayUsingSelector:@selector(leftToRightCompare:)];
}

- (StainlessTabView*)nextTab
{
	NSArray* subviews = [self subviews];
	
	NSArray* sortedTabs = [subviews sortedArrayUsingSelector:@selector(leftToRightCompare:)];
	if([sortedTabs count] == 1)
		return nil;
	
	BOOL foundActive = NO;
	for(StainlessTabView* tab in sortedTabs) {
		if([tab isEqualTo:activeTab])
			foundActive = YES;
		else if(foundActive)
			return tab;
	}
	
	return [sortedTabs objectAtIndex:0];
}

- (StainlessTabView*)previousTab
{
	NSArray* subviews = [self subviews];
	
	NSArray* sortedTabs = [subviews sortedArrayUsingSelector:@selector(leftToRightCompare:)];
	if([sortedTabs count] == 1)
		return nil;
	
	BOOL foundActive = NO;
	for(StainlessTabView* tab in [sortedTabs reverseObjectEnumerator]) {
		if([tab isEqualTo:activeTab])
			foundActive = YES;
		else if(foundActive)
			return tab;
	}
	
	return  [sortedTabs objectAtIndex:[sortedTabs count] - 1];
}

- (StainlessTabView*)tabWithIndex:(int)index
{
	NSArray* subviews = [self subviews];
	
	NSArray* sortedTabs = [subviews sortedArrayUsingSelector:@selector(leftToRightCompare:)];
	if([sortedTabs count] == 1)
		return nil;
	
	StainlessTabView* tab = [sortedTabs objectAtIndex:index - 1];
	if([tab isEqualTo:activeTab])
		return nil;
	
	return tab;
}

// NSDraggingDestination protocol
- (NSDragOperation)draggingEntered:(id < NSDraggingInfo >)sender
{
	dragOffset = -1;
	dragIndex = -1;
	
	return NSDragOperationMove;
}

- (NSDragOperation)draggingUpdated:(id < NSDraggingInfo >)sender
{
	int newDragOffset = [sender draggingLocation].x;
	if(dragOffset != newDragOffset) {
		dragOffset = newDragOffset;
		
		NSArray* subviews = [self subviews];
		int subviewCount = [subviews count];
		
		float x = 3.0;
		float w = 0.0;
		
		if(subviewCount > 0) {
			w = ([self frame].size.width - 24.0) / (float) [subviews count];
			
			if(w > 210.0)
				w = 210.0;
			else if(w < 40.0)
				w = 40.0;
		}

		int wi = (int)w;
		
		int newDragIndex = 0;
		int d = (int) (w * 0.5);
		while(d < dragOffset) {
			d += wi;
			newDragIndex++;
		}
		
		if(newDragIndex > [subviews count])
			newDragIndex = [subviews count] + 1;
		
		if(dragIndex != newDragIndex) {
			dragIndex = newDragIndex;

			d = 0;
			NSArray* sortedTabs = [subviews sortedArrayUsingSelector:@selector(leftToRightCompare:)];
			for(StainlessTabView* tab in sortedTabs) {
				if(d >= 0 && d++ == dragIndex) {
					x += (float)wi;
					d = -1;
				}

				if([tab isHidden] == YES) {
					[tab setFrame:NSMakeRect(x, 0.0, (float)wi, 25.0)];
					continue;
				}
				
				
				[tab setFrame:NSMakeRect(x, 0.0, (float)wi, 25.0)];
				x += (float)wi;
			}
			
			if(d != -1) {
				x += (float)wi;
			}
			
			NSRect frame = [self frame];
			frame.origin.y += 8.0;
			frame.origin.x = x + 4.0;
			frame.size.width = 16.0;
			frame.size.height = 16.0;
			[newTabButton setFrame:frame];
		}
	}
	
	return NSDragOperationMove;
}

- (void)draggingExited:(id < NSDraggingInfo >)sender
{
	if(dragOffset != -1) {
		dragOffset = -1;
		dragIndex = -1;
		
		[self resizeToWindow];
	}
}

- (BOOL)performDragOperation:(id < NSDraggingInfo >)sender
{
	BOOL update = YES;
	
	if(dragOffset != -1) {
		NSString* pboardType = (gPrivateMode ? StainlessPrivateTabPboardType : StainlessTabPboardType);

		NSPasteboard* pboard = [sender draggingPasteboard];
		[pboard types];
		NSData* data = [pboard dataForType:pboardType];
		NSString* clientIdentifier = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
		NSString* insertIdentifier = nil;
			
		NSArray* subviews = [self subviews];
		NSArray* sortedTabs = [subviews sortedArrayUsingSelector:@selector(leftToRightCompare:)];
		if(dragIndex < [sortedTabs count]) {
			NSView* tab = (NSView*)[sender draggingSource];
			if(tab) {
				int tabIndex = [sortedTabs indexOfObject:tab];
				if(tabIndex == dragIndex)
					clientIdentifier = nil;
			}
			
			insertIdentifier = [[sortedTabs objectAtIndex:dragIndex] identifier];
		}
		
		if(clientIdentifier) {
			update = NO;
			
			StainlessController* controller = (StainlessController*)[NSApp delegate];
			[controller dockTabWithIdentifier:clientIdentifier beforeTabWithIdentifier:insertIdentifier];
		}
		
		dragOffset = -1;
		dragIndex = -1;
	}
	
	if(update) {
		[self resizeToWindow];
	}
	
	return YES;
}

- (BOOL)wantsPeriodicDraggingUpdates
{
	return YES;
}

@synthesize activeTab;

@end
