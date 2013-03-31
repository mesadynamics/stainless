//
//  InspectorView.m
//  StainlessClient
//
//  Created by Danny Espinoza on 5/6/09.
//  Copyright 2009 Mesa Dynamics, LLC. All rights reserved.
//

#import "InspectorView.h"
#import "StainlessBridge.h"
#import "StainlessController.h"


@implementation InspectorView

@synthesize bookmark;
@synthesize shelf;
@synthesize isDirty;

- (id)initWithFrame:(NSRect)frame
{
    if(self = [super initWithFrame:frame]) {
		gradient = nil;
		selectGradient = nil;
		
		bookmark = nil;
		shelf = nil;
		isDirty = NO;
	}
	
    return self;
}

- (void)dealloc
{
	[bookmark release];
	[shelf release];	
	
	[selectGradient release];
	[gradient release];
	
	[super dealloc];
}

- (BOOL)mouseDownCanMoveWindow
{
	return NO;
}

- (void)drawRect:(NSRect)rect
{
	NSRect frame = [self bounds];
	
	NSRect gradientFrame = frame;
	gradientFrame.origin.x = 0.0;
	gradientFrame.origin.y = frame.size.height - 25.0;
	gradientFrame.size.height = 25.0;
		
	if(gradient == nil)
		gradient = [[NSGradient alloc] initWithStartingColor:[NSColor colorWithCalibratedWhite:0.90 alpha:1.0] endingColor:[NSColor colorWithCalibratedWhite:0.80 alpha:1.0]];
	
	[gradient drawInRect:gradientFrame angle:270.0];
	
	NSRect fillFrame = frame;
	[[NSColor colorWithCalibratedWhite:0.90 alpha:1.0] set];
	fillFrame.size.height -= 25.0;
	NSRectFill(fillFrame);
	
	if([[self window] isKeyWindow])
		[[NSColor darkGrayColor] set];
	else
		[[NSColor grayColor] set];
	
	NSRect lineRect = frame;
	lineRect.origin.x = frame.size.width - 1.0;
	lineRect.origin.y = 0.0;
	lineRect.size.width = 1.0;		
	NSRectFill(lineRect);

	[[NSColor grayColor] set];
	lineRect.origin.x = 9.0;
	NSRectFill(lineRect);
	
	NSRect selectFrame = frame;
	selectFrame.size.width = 9.0;
	
	if(selectGradient == nil)
		selectGradient = [[NSGradient alloc] initWithStartingColor:[NSColor colorWithCalibratedWhite:0.90 alpha:1.0] endingColor:[NSColor colorWithCalibratedWhite:0.8 alpha:1.0]];
	
	[selectGradient drawInRect:selectFrame angle:0.0];
}

- (IBAction)revertChanges:(id)sender
{
	if(bookmark) {
		NSDictionary* bookmarkInfo = [bookmark bookmarkInfo];
		
		NSString* cellTypes[3] = { @"title", @"url", @"tags", };
		
		for(int i = 0; i < 3; i++) {
			NSFormCell* cell = [form cellAtIndex:i];
			
			NSString* cellData = [bookmarkInfo objectForKey:cellTypes[i]];
			if(cellData)
				[cell setStringValue:[NSString stringWithString:cellData]];
			else
				[cell setStringValue:@""];
		}
		
		NSImage* iconImage = nil;
		NSData* iconData = [bookmarkInfo objectForKey:@"image"];
		if(iconData)
			iconImage = [[[NSImage alloc] initWithData:iconData] autorelease];
		
		if(iconImage)
			[icon setImage:iconImage];
		else
			[icon setImage:nil];
		
		[form selectTextAtIndex:0];
	}
	
	self.isDirty = NO;
}

- (IBAction)applyChanges:(id)sender
{
	if(bookmark) {
		NSMutableDictionary* bookmarkInfo = [bookmark bookmarkInfo];
		
		NSString* cellTypes[3] = { @"title", @"url", @"tags", };
		
		for(int i = 0; i < 3; i++) {
			NSFormCell* cell = [form cellAtIndex:i];
			
			NSString* cellData = [cell stringValue];
			
			if(i == 2) {
				NSArray* tags = [cellData componentsSeparatedByString:@","];
				NSMutableArray* tagList = [NSMutableArray arrayWithCapacity:[tags count]];
				
				for(NSString* tag in tags) {
					NSString* cleanTag = [tag stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
					[tagList addObject:cleanTag];
				}
				
				cellData = [tagList componentsJoinedByString:@", "];
			}
			
			[bookmarkInfo setObject:cellData forKey:cellTypes[i]];
		}
		
		NSImage* iconImage = [icon image];
		if(iconImage) {
			NSImage* thumbImage = [iconImage thumbnailWithSize:NSMakeSize(16.0, 16.0)];
			if(thumbImage) {
				NSData* iconData = [thumbImage TIFFRepresentation];
				if(iconData) {
					[bookmarkInfo setObject:iconData forKey:@"image"];
					[bookmark setImage:thumbImage];
				}
			}
		}
		else {
			[bookmarkInfo removeObjectForKey:@"image"];
			
			NSString* urlString = [bookmarkInfo objectForKey:@"url"];
			NSData* iconData = [bookmarkInfo objectForKey:@"icon"];
			NSImage* iconImage = [BookmarkView iconFromData:iconData urlString:urlString];
			
			if(iconImage)
				[bookmark setImage:iconImage];
			else
				[bookmark setImage:nil];
		}
		
		[shelf commitBookmarks];
		
		[form selectTextAtIndex:0];
	}
	
	self.isDirty = NO;

	NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
	NSDictionary* stainlessDefaults = [defaults persistentDomainForName:@"com.stainlessapp.Stainless"];
	
	NSNumber* closeNow = [stainlessDefaults objectForKey:@"ClosePropertiesOnChanges"];
	if(closeNow && [closeNow boolValue]) {
		StainlessController* controller = (StainlessController*)[NSApp delegate];
		[controller closeEditor:self];
	}
}

- (IBAction)iconDidChange:(id)sender
{
	self.isDirty = YES;
}

- (void)updateBookmark:(BookmarkView*)newBookmark
{	
	if(bookmark == nil) {
		self.bookmark = newBookmark;
		[self revertChanges:self];
	}
	else {
		if(newBookmark == nil) {
			self.bookmark = nil;
			
			for(int i = 0; i < 3; i++) {
				NSFormCell* cell = [form cellAtIndex:i];
				[cell setStringValue:@""];
			}
			
			[icon setImage:nil];
		}
		else if([newBookmark isEqualTo:bookmark] == NO) {
			self.bookmark = newBookmark;
			
			[self revertChanges:self];
		}
	}
	
	if(newBookmark)
		self.shelf = (StainlessShelfView*)[newBookmark superview];
	else
		self.shelf = nil;
	
	BOOL enableURL = YES;
	if(bookmark) {
		NSMutableDictionary* bookmarkInfo = [bookmark bookmarkInfo];
		NSString* urlString = [bookmarkInfo objectForKey:@"url"];
		if(urlString && [urlString hasPrefix:@"group:"])
			enableURL = NO;
	}
	
	NSFormCell* cell = [form cellAtIndex:1];
	[cell setEnabled:enableURL];
	
	[self updateArrow];
}

- (void)updateArrow
{
	if(bookmark == nil) {
		[arrow setHidden:YES];
	}
	else {
		NSRect frame = [arrow frame];
		frame.origin.y = [bookmark frame].origin.y + 4.0;
		[arrow setFrame:frame];
		
		[arrow setHidden:NO];
	}
}

// NSControl delegate
- (void)controlTextDidChange:(NSNotification *)aNotification
{
	self.isDirty = YES;
}

@end
