//
//  StainlessShelfView.m
//  StainlessClient
//
//  Created by Danny Espinoza on 1/29/09.
//  Copyright 2009 Mesa Dynamics, LLC. All rights reserved.
//

#import "StainlessShelfView.h"
#import "stainlessController.h"
#import "StainlessBridge.h"
#import "FadingLabel.h"
#import <Carbon/Carbon.h>

extern BOOL gIconEditor;

extern NSMutableString* StainlessBookmarkPboardType;
extern NSString* WebURLPboardType;


@implementation StainlessShelfView

@synthesize context;
@synthesize groupContext;
@synthesize label;

@synthesize signature;
@synthesize parent;
@synthesize child;
@synthesize width;
@synthesize selection;
@synthesize focus;
@synthesize owner;
@synthesize canSync;
@synthesize canCommit;
@synthesize shelfIndex;

- (id)initWithFrame:(NSRect)frame
{
    if(self = [super initWithFrame:frame]) {
		gradient = nil;
		help = nil;
		
		signature = nil;
		parent = nil;
		child = nil;
		width = frame.size.width;
		
		selection = nil;
		focus = nil;
		owner = nil;
		
		canSync = YES;
		canCommit = NO;
		
		shelfIndex = 0;
    }
	
    return self;
}

- (void)dealloc
{
	[signature release];
	[parent release];
	[child release];
	
	[selection release];
	[focus release];
	[owner release];
	
	[label release];
	[help release];
	[gradient release];
	
	[super dealloc];
}

- (void)awakeFromNib
{
	[self finishInit];
}

- (void)finishInit
{
	[self registerForDraggedTypes:[NSArray arrayWithObjects:NSURLPboardType, WebURLPboardType, nil]];
	[label setUnderlay:[self window]];
}

- (void)setHidden:(BOOL)flag
{
	if(flag) {
		[child setHidden:flag];
		[super setHidden:flag];
	}
	else {
		[super setHidden:flag];
		[child setHidden:flag];
	}
}

- (void)setFrame:(NSRect)frameRect
{
	if(child) {
		NSRect frame = [child frame];
		frame.origin.y = frameRect.origin.y;
		frame.size.height = frameRect.size.height;
		[child setFrame:frame];
	}
	
	[super setFrame:frameRect];
}

/*- (void)updateTrackingAreas
{
	NSTrackingAreaOptions options = NSTrackingMouseEnteredAndExited + NSTrackingActiveInKeyWindow + NSTrackingInVisibleRect;
	NSTrackingArea* tracker = [[NSTrackingArea alloc] initWithRect:[self bounds] options:options owner:self userInfo:nil];
	[self addTrackingArea:tracker];

	[super updateTrackingAreas];
}

- (void)mouseExited:(NSEvent *)theEvent
{
	if(label) {
		NSPoint event_location = [theEvent locationInWindow];
		NSPoint local_point = [[self superview] convertPoint:event_location fromView:nil];
		
		NSView* view = [self hitTest:local_point];
		if([view isEqualTo:self] == NO && [view isMemberOfClass:[BookmarkView class]] == NO)
			[self hideBookmark:NO];
	}
}*/

- (void)viewDidHide
{
	if(label)
		[label hideLabel];
}

- (NSBezierPath *) _renderHelpString: (NSString *) string
{
	float x = 0;
	float y = 0;
	NSFont* font = [NSFont systemFontOfSize:13.0];
	
    NSTextView *textview;
    textview = [[NSTextView alloc] init];
	
    [textview setString: string];
    [textview setFont: font];
	
    NSLayoutManager *layoutManager;
    layoutManager = [textview layoutManager];
	
    NSRange range;
    range = [layoutManager glyphRangeForCharacterRange:
			 NSMakeRange (0, [string length])
								  actualCharacterRange: nil];
    NSGlyph *glyphs;
    glyphs = (NSGlyph *) malloc (sizeof(NSGlyph)
                                 * (range.length * 2));
    [layoutManager getGlyphs: glyphs  range: range];
	
    NSBezierPath *path;
    path = [NSBezierPath bezierPath];
	
    [path moveToPoint: NSMakePoint (x, y)];
    [path appendBezierPathWithGlyphs: glyphs
							   count: range.length  inFont: font];
	
    free (glyphs);
    [textview release];

	NSAffineTransform *transform = [NSAffineTransform transform];
	[transform translateXBy: 17.0 yBy: 8.0];
	[transform rotateByDegrees:90.0];
	[path transformUsingAffineTransform: transform];
			
    return (path);
	
} // makePathFromString

- (void)drawRect:(NSRect)rect
{
	NSRect frame = [self bounds];
	[[NSImage imageNamed:@"Shelf"] drawInRect:frame fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
	
	if([[self subviews] count] == 0) {
		if(help == nil)
			help = [[self _renderHelpString:NSLocalizedString(@"ShelfHelp", @"")] retain];
		
		[[NSColor darkGrayColor] set];
		[help fill];
	}
}
		
- (NSArray*)syncBookmarks:(BOOL)force
{
	return [self syncBookmarks:force andUpdate:YES];
}

- (NSArray*)syncBookmarks:(BOOL)force andUpdate:(BOOL)update
{
	static NSMutableDictionary* lastModDateTable = nil;
	
	if(force == NO && canSync == NO)
		return nil;
	
	NSFileManager* fm = [NSFileManager defaultManager];
	NSString* libraryPath = [NSString stringWithFormat:@"%@/Library/Preferences/Stainless", NSHomeDirectory()];
	if([fm fileExistsAtPath:libraryPath] == NO) {
		[fm createDirectoryAtPath:libraryPath attributes:nil];
		return nil;
	}
	
	NSString* path = nil;
	if(signature == nil)
		path = [NSString stringWithFormat:@"%@/Shelf.plist", libraryPath];
	else {
		NSString* groupPath = [NSString stringWithFormat:@"%@/Groups", libraryPath];
		if([fm fileExistsAtPath:groupPath] == NO)
			[fm createDirectoryAtPath:groupPath attributes:nil];

		path = [NSString stringWithFormat:@"%@/%@.plist", groupPath, signature];
	}
	
	if(path == nil || [fm fileExistsAtPath:path] == NO) {
		canCommit = YES;
		return nil;
	}
		
	NSDictionary* attributes = [fm fileAttributesAtPath:path traverseLink:NO];
	NSDate* lastModDate = [lastModDateTable objectForKey:path];
	
	NSDate* fileModDate;
	if(fileModDate = [attributes objectForKey:NSFileModificationDate]) {
		if(lastModDate && [lastModDate compare:fileModDate] != NSOrderedAscending) {
			if(force == NO) {
				return nil;
			}
		}
		else {
			if(lastModDateTable == nil)
				lastModDateTable = [[NSMutableDictionary alloc] initWithCapacity:1];
			
			[lastModDateTable setObject:fileModDate forKey:path];
		}
	}
		
	int oldCount = [[self subviews] count];
	int newCount = 0;
	int index = 1;
	
	NSMutableArray* subviews = nil;
	NSMutableArray* updateIcons = nil;
	
	@try {
		id plist = nil;
		
		if([[NSFileManager defaultManager] fileExistsAtPath:path]) {
			NSString* error = nil;
			NSData* data = [NSData dataWithContentsOfFile:path];
			plist = [NSPropertyListSerialization propertyListFromData:data
													 mutabilityOption:NSPropertyListMutableContainersAndLeaves
															   format:nil
													 errorDescription:&error];
			
			if(error) {
				NSLog(@"Error deserializing %@: %@", path, error);
				[error release];
				
				plist = nil;
			}
		}
		
		if(plist) {
			subviews = [NSMutableArray arrayWithCapacity:[plist count]];

			float height = [self frame].size.height;
			NSRect frame = NSMakeRect(4.0, height - 24.0, 16.0, 16.0);
			StainlessController* controller = (StainlessController*)[NSApp delegate];
			
			for(NSMutableDictionary* bookmarkInfo in plist) {
				NSString* urlString = [bookmarkInfo objectForKey:@"url"];
				if(urlString == nil)
					continue;
								
				//NSString* title = [bookmarkInfo objectForKey:@"title"];
	
				NSData* iconData = [bookmarkInfo objectForKey:@"icon"];
				NSImage* iconImage = [BookmarkView iconFromData:iconData urlString:urlString];

				[iconImage setScalesWhenResized:YES];
				[iconImage setSize:NSMakeSize(16.0, 16.0)];
				
				NSImage* customImage = nil;
				NSData* customData = [bookmarkInfo objectForKey:@"image"];
				if(customData)
					customImage = [[[NSImage alloc] initWithData:customData] autorelease];
				
				BookmarkView* icon = [[BookmarkView alloc] initWithFrame:frame];
				[icon setIndex:index++];
				[icon setTag:[urlString hash]];
				[icon setImage:(customImage ? customImage : iconImage)];
				[icon setBookmarkInfo:bookmarkInfo];
				if([urlString hasPrefix:@"javascript:"])
					[icon setIsJavascript:YES];
				//if(title)
				//	[icon setToolTip:title];
				//else
				//	[icon setToolTip:urlString];
				
				if(iconData == nil) {
					if(updateIcons == nil)
						updateIcons = [NSMutableArray arrayWithCapacity:1];
					
					[updateIcons addObject:icon];
						
					//[icon updateOnIconChange];
				}
				
				if([urlString hasPrefix:@"group:"]) {
					[icon setIsGroup:YES];
					[icon setTarget:self];
					[icon setAction:@selector(openBookmarkGroup:)];
					[icon setMenu:groupContext];
				}
				else {
					[icon setTarget:controller];
					[icon setAction:@selector(openBookmark:)];
					[icon setMenu:context];
				}
				
				[subviews addObject:icon];
				[icon release];
				
				frame.origin.y -= 24.0;
			}
		}
		
		canCommit = YES;
	}
	
	@catch (NSException* anException) {
		NSLog(@"%@ exception reading %@: %@", [anException name], path, [anException reason]);
	}
	
	if(subviews && update) {
		newCount = [subviews count];
		[self setSubviews:subviews];

		if(updateIcons)
			[updateIcons makeObjectsPerformSelector:@selector(updateOnIconChange)];
			
		if(newCount == 0 || oldCount == 0)
			[self setNeedsDisplay:YES];
		
		if(child) {
			BookmarkView* orphan = nil;
			
			NSString* groupString = [child signature];
			if(groupString) {
				for(BookmarkView* bookmark in [self subviews]) {
					NSString* urlString = [[bookmark bookmarkInfo] objectForKey:@"url"];
					if(urlString && [groupString isEqualToString:[urlString substringFromIndex:6]]) {
						orphan = bookmark;
						break;
					}
				}
			}
			
			if(orphan) {
				[orphan setIsOpen:YES];
				self.focus = orphan;
			}
			else
				[self closeBookmarkGroup:nil];
		}
	}
	
	return subviews;
}

- (void)commitBookmarks
{
	[self commitBookmarksWithSignature:signature fromArray:nil];
}

- (void)commitBookmarksWithSignature:(NSString*)bookmarkSignature fromArray:(NSArray*)bookmarkArray
{
	if(canCommit == NO)
		return;
	
	NSFileManager* fm = [NSFileManager defaultManager];
	NSString* libraryPath = [NSString stringWithFormat:@"%@/Library/Preferences/Stainless", NSHomeDirectory()];
	if([fm fileExistsAtPath:libraryPath] == NO)
		[fm createDirectoryAtPath:libraryPath attributes:nil];
	
	NSString* path = nil;
	if(bookmarkSignature == nil)
		path = [NSString stringWithFormat:@"%@/Shelf.plist", libraryPath];
	else {
		NSString* groupPath = [NSString stringWithFormat:@"%@/Groups", libraryPath];
		if([fm fileExistsAtPath:groupPath] == NO)
			[fm createDirectoryAtPath:groupPath attributes:nil];
		
		path = [NSString stringWithFormat:@"%@/%@.plist", groupPath, bookmarkSignature];
	}
		
	if([fm fileExistsAtPath:path]) {
		NSString* trimPath = [path substringToIndex:[path length] - 5];
		NSString* bakPath = [trimPath stringByAppendingString:@"bak.plist"];
		[fm copyPath:path toPath:bakPath handler:nil];
	}

	NSArray* bookmarks = nil;
	
	if(bookmarkArray)
		bookmarks = bookmarkArray;
	else {
		NSArray* subviews = [self subviews];
		NSMutableArray* subviewBookamrks = [NSMutableArray arrayWithCapacity:[subviews count]];
		NSArray* sortedIcons = [subviews sortedArrayUsingSelector:@selector(topToBottomCompare:)];
		for(BookmarkView* icon in sortedIcons) {
			[subviewBookamrks addObject:[icon bookmarkInfo]];
		}
		
		bookmarks = subviewBookamrks;
	}
	
	@try {
		NSString* error = nil;
		NSData* data = [NSPropertyListSerialization dataFromPropertyList:bookmarks format:kCFPropertyListBinaryFormat_v1_0 errorDescription:&error];
		
		if(error) {
			NSLog(@"Error serializing write %@: %@", path, error);
			[error release];
			
			data = nil;
		}
		
		if(data) {
			if([data writeToFile:path atomically:YES] == NO)
				NSLog(@"Error writing %@.", path);
		}	
	}
	
	@catch (NSException* anException) {
		NSLog(@"%@ exception writing %@: %@", [anException name], path, [anException reason]);
	}
	
	StainlessController* controller = (StainlessController*)[NSApp delegate];
	[controller refreshBookmarks];
}

- (void)deleteBookmarksForGroup:(BookmarkView*)bookmark
{
	NSFileManager* fm = [NSFileManager defaultManager];
	NSString* libraryPath = [NSString stringWithFormat:@"%@/Library/Preferences/Stainless", NSHomeDirectory()];
	if([fm fileExistsAtPath:libraryPath] == NO) {
		[fm createDirectoryAtPath:libraryPath attributes:nil];
		return;
	}
	
	if(bookmark == nil)
		return;
	
	NSString* groupPath = [NSString stringWithFormat:@"%@/Groups", libraryPath];
	if([fm fileExistsAtPath:groupPath] == NO) {
		[fm createDirectoryAtPath:groupPath attributes:nil];
		return;
	}
	
	NSString* groupURL = [[bookmark bookmarkInfo] objectForKey:@"url"];
	NSString* path = [NSString stringWithFormat:@"%@/%@.plist", groupPath, [groupURL substringFromIndex:6]];
	
	if([fm fileExistsAtPath:path])
		[fm removeItemAtPath:path error:nil];
	
	path = [NSString stringWithFormat:@"%@/%@.bak.plist", groupPath, [groupURL substringFromIndex:6]];
	
	if([fm fileExistsAtPath:path])
		[fm removeItemAtPath:path error:nil];
}

- (void)resizeToWindow
{
	float y = [self frame].size.height - 24.0;
	float h = 24.0;
		
	int index = 1;
	
	NSArray* subviews = [self subviews];
	NSArray* sortedIcons = [subviews sortedArrayUsingSelector:@selector(topToBottomCompare:)];
	for(BookmarkView* icon in sortedIcons) {
		[icon setFrame:NSMakeRect(4.0, y, 16.0, 16.0)];
		[icon setIndex:index++];
		
		y -= h;
	}
}

- (void)setLoading:(BOOL)set
{
	for(BookmarkView* icon in [self subviews]) {
		if([icon isJavascript])
			[icon setEnabled:!set];
	}
}

- (id)shelfAtIndex:(int)index
{
	if(shelfIndex == index)
		return self;
	
	return [child shelfAtIndex:index];
}

- (id)bookmarkWithTag:(NSInteger)tag
{	
	for(NSView* icon in [self subviews]) {
		if([icon tag] == tag)
			return icon;
	}
	
	return nil;
}

- (BOOL)shelfExists:(StainlessShelfView*)shelf
{
	return NO;
}

- (BOOL)bookmarkExists:(BookmarkView*)bookmark
{
	for(BookmarkView* icon in [self subviews]) {
		if([icon isEqualTo:bookmark])
			return YES;
	}
	
	if(child)
		return [child bookmarkExists:bookmark];
	
	return NO;
}

- (IBAction)createGroup:(id)sender
{
	NSString* groupStamp = [NSString stringWithFormat:@"group:%f", [NSDate timeIntervalSinceReferenceDate]];
	
	NSMutableDictionary* bookmarkInfo = [NSMutableDictionary dictionary];
	[bookmarkInfo setObject:groupStamp forKey:@"url"];
	[bookmarkInfo setObject:@"Group" forKey:@"title"];
	
	NSImage* folderImage = [[NSWorkspace sharedWorkspace] iconForFileType:NSFileTypeForHFSTypeCode(kGenericFolderIcon)];
	NSImage* iconImage = [folderImage thumbnailWithSize:NSMakeSize(16.0, 16.0)];
	NSData* iconData = [iconImage TIFFRepresentation];
	[bookmarkInfo setObject:iconData forKey:@"icon"];

	NSArray* subviews = [self subviews];

	int count = [subviews count];
	if(count == 0)
		[self setNeedsDisplay:YES];
	
	float height = [self frame].size.height;
	NSRect frame = NSMakeRect(4.0, height - 24.0, 16.0, 16.0);
	frame.origin.y -= (24.0 * (float)count);
	
	BookmarkView* icon = [[BookmarkView alloc] initWithFrame:frame];
	[icon setTag:[groupStamp hash]];
	[icon setImage:iconImage];
	[icon setBookmarkInfo:bookmarkInfo];
	
	[icon setIsGroup:YES];
	[icon setTarget:self];
	[icon setAction:@selector(openBookmarkGroup:)];
	[icon setMenu:groupContext];

	[self addSubview:icon];
	[icon release];
	
	[self resizeToWindow];
	[self commitBookmarks];

	self.selection = icon;
	
	StainlessController* controller = (StainlessController*)[NSApp delegate];
	[controller openEditor:selection];
}

- (IBAction)createGroupFromTabs:(id)sender
{
	[self createGroup:sender];
	
	NSString* groupString = nil;
	NSMutableArray* groupArray = nil;
	
	NSString* urlString = [[selection bookmarkInfo] objectForKey:@"url"];
	if(urlString && [urlString hasPrefix:@"group:"])
		groupString = [urlString substringFromIndex:6];

	if(groupString == nil)
		return;
	
	StainlessController* controller = (StainlessController*)[NSApp delegate];
	StainlessBarView* bar = [controller bar];
	NSArray* tabs = [bar allTabs];
	for(StainlessTabView* tab in tabs) {
		NSPasteboard* pboard = [NSPasteboard pasteboardWithName:@"StainlessPboard"];
		if([tab writeToPasteboard:pboard]) {
			BookmarkView* icon = [[BookmarkView alloc] initWithFrame:NSZeroRect pasteBoard:pboard];
			
			if(icon) {
				if(groupArray == nil)
					groupArray = [NSMutableArray array];
				
				[groupArray addObject:[icon bookmarkInfo]];
				
				[icon autorelease];
			}
		}
	}
	
	if(groupArray)
		[self commitBookmarksWithSignature:groupString fromArray:groupArray];
}

- (IBAction)closeGroup:(id)sender
{
	if(parent == nil) {
		StainlessController* controller = (StainlessController*)[NSApp delegate];
		[controller toggleIconShelf:self];
		[controller arrangeShelvesForEditing:gIconEditor];
	}
	else {
		if(child)
			[child closeGroup:nil];
		
		[parent closeBookmarkGroup:owner];
	}
}

- (void)openBookmarkGroup:(BookmarkView*)bookmark
{	
	if([bookmark isOpen]) {
		if(child)
			[child closeGroup:nil];

		[self closeBookmarkGroup:bookmark];
		return;
	}
	
	[bookmark setIsOpen:YES];
	
	StainlessController* controller = (StainlessController*)[NSApp delegate];
	
	if(child) {
		[[child child] closeGroup:nil];
		[focus setIsOpen:NO];
		[focus setNeedsDisplay:YES];
	}
	else {
		StainlessShelfView* top = [controller iconShelf];
		NSRect frame = [self frame];
			
		NSRect childFrame = frame;
		childFrame.origin.x += frame.size.width;
		child = [[StainlessShelfView alloc] initWithFrame:childFrame];
		[child finishInit];
		[child setShelfIndex:shelfIndex + 1];
		
		[child setParent:self];
		[[top superview] addSubview:child];
		[child setHidden:NO];
		
		NSMenu* childMenu = [[self menu] copy];
		[[childMenu itemArray] makeObjectsPerformSelector:@selector(setTarget:) withObject:child];
		[child setMenu:childMenu];
		
		NSMenu* childContext = [context copy];
		[[childContext itemArray] makeObjectsPerformSelector:@selector(setTarget:) withObject:child];
		[childContext setDelegate:child];
		[child setContext:childContext];
		
		NSMenu* childGroupContext = [groupContext copy];
		[[childGroupContext itemArray] makeObjectsPerformSelector:@selector(setTarget:) withObject:child];
		[childGroupContext setDelegate:child];
		[child setGroupContext:childGroupContext];
		
		[child setLabel:[self label]];
		
		[controller toggleIconShelf:nil];
		[controller arrangeShelvesForEditing:gIconEditor];
		float w = [top width] + frame.size.width;
		[top setWidth:w];
		[controller toggleIconShelf:nil];
	}

	NSString* urlString = [[bookmark bookmarkInfo] objectForKey:@"url"];
	if(urlString && [urlString hasPrefix:@"group:"]) {
		NSString* groupString = [urlString substringFromIndex:6];
		[child setSignature:groupString];
	}
	else
		[child setSignature:nil];
	
	[child setOwner:bookmark];
	if([child syncBookmarks:YES] == nil) {
		[child setSubviews:[NSArray array]];
		[child setNeedsDisplay:YES];
	}

	[controller syncShelves];

	self.focus = bookmark;
}

- (void)closeBookmarkGroup:(BookmarkView*)bookmark
{
	[bookmark setIsOpen:NO];

	if(child) {
		StainlessController* controller = (StainlessController*)[NSApp delegate];
		StainlessShelfView* top = [controller iconShelf];
		
		NSRect frame = [self frame];
		
		NSMenu* childMenu = [child menu];
		[childMenu release];
		
		NSMenu* childContext = [child context];
		[childContext setDelegate:nil];
		[childContext release];
		
		[child retain];
		[child setParent:nil];
		[child removeFromSuperview];
		[child release];
		child = nil;

		[controller toggleIconShelf:nil];
		[controller arrangeShelvesForEditing:gIconEditor];
		float w = [top width] - frame.size.width;
		[top setWidth:w];
		[controller toggleIconShelf:nil];
	
		[controller syncShelves];
	}
	
	self.focus = nil;
}

- (void)expandToGroupPath:(NSString*)path
{
	StainlessController* controller = (StainlessController*)[NSApp delegate];
	[controller setIgnoreSync:YES];
	
	if(path == nil) {
		if(child) {
			[child closeGroup:nil];
			
			[self closeBookmarkGroup:focus];
		}
	}
	else {
		StainlessShelfView* shelf = self;
		
		NSArray* groups = [path componentsSeparatedByString:@"/"];
		for(NSString* group in groups) {
			BOOL foundTrail = NO;
			
			for(BookmarkView* bookmark in [shelf subviews]) {
				NSString* urlString = [[bookmark bookmarkInfo] objectForKey:@"url"];
				if(urlString && [group isEqualToString:[urlString substringFromIndex:6]]) {
					if([bookmark isOpen] == NO)
						[shelf openBookmarkGroup:bookmark];
					
					shelf = [shelf child];
					foundTrail = YES;
					break;
				}
			}
			
			if(foundTrail == NO)
				break;
		}
		
		if(shelf && [shelf child]) {
			[[shelf child] closeGroup:nil];
			
			[shelf closeBookmarkGroup:[shelf focus]];
		}
	}

	[controller setIgnoreSync:NO];
}

- (void)showBookmark:(BookmarkView*)bookmark
{
	NSPoint windowOrigin = [[self window] frame].origin;
	NSPoint bookmarkOrigin = [bookmark convertPoint:NSMakePoint(26.0, 18.0) toView:nil];
	
	NSMutableDictionary* bookmarkInfo = [bookmark bookmarkInfo];

	extern UInt32 GetCurrentKeyModifiers();

	NSString* title = nil;
	if(GetCurrentKeyModifiers() & optionKey)
		title = [bookmarkInfo objectForKey:@"url"];
	else
		title = [bookmarkInfo objectForKey:@"title"];
	
	[label showLabel:title atPoint:NSMakePoint(windowOrigin.x + bookmarkOrigin.x, windowOrigin.y + bookmarkOrigin.y)];
}

- (void)hideBookmark:(BOOL)now
{
	if(now)
		[label hideLabelNow];
	else
		[label hideLabelLater:0.1 fade:YES];
}

- (IBAction)handleBookmarkAction:(id)sender
{
	int tag = [sender tag];
	
	if(selection == nil)
		return;
	
	switch(tag) {
		case bookmarkOpen:
		case bookmarkOpenTab:
		case bookmarkOpenWindow:
		{
			StainlessController* controller = (StainlessController*)[NSApp delegate];
			if([selection isGroup]) {
				NSString* groupString = nil;
				NSArray* bookmarks = nil;
				
				//if([selection isOpen] && [focus isEqualTo:selection])
				//	bookmarks = [child subviews];
				//else 
				if(selection) {
					NSDictionary* bookmarkInfo = [selection bookmarkInfo];
					NSString* urlString = [bookmarkInfo objectForKey:@"url"];
					if(urlString && [urlString hasPrefix:@"group:"]) {
						NSString* saveSignature = [[self signature] retain];

						groupString = [urlString substringFromIndex:6];
						[self setSignature:groupString];
						bookmarks = [self syncBookmarks:YES andUpdate:NO];
						[self setSignature:saveSignature];
						
						[saveSignature release];
					}
				}
				
				if(bookmarks) {
					[[controller connection] resetFocus];

					StainlessController* controller = (StainlessController*) [NSApp delegate];
					long i = 1;

					for(BookmarkView* bookmark in bookmarks) {
						if([bookmark isGroup] == NO) {
							[[controller connection] setSpawnIndex:i++];
							[controller openBookmark:bookmark inGroup:groupString forceTab:(tag == bookmarkOpenTab) forceWindow:(tag == bookmarkOpenWindow) checkModifiers:NO];
						}
					}
					
					[[controller connection] trimFocus:i];
				}					
			}
			else
				[controller openBookmark:selection inGroup:nil forceTab:(tag == bookmarkOpenTab) forceWindow:(tag == bookmarkOpenWindow) checkModifiers:NO];
			break;
		}
			
		case bookmarkCopy:
		{
			NSPasteboard* pboard = [NSPasteboard pasteboardWithName:NSGeneralPboard];
			[selection writeToPasteboard:pboard];
			
			break;
		}
			
		case bookmarkDelete:
		{
			if([selection isGroup]) {
				NSAlert* alert = [NSAlert alertWithMessageText:NSLocalizedString(@"DeleteTitle", @"")
												 defaultButton:NSLocalizedString(@"DeleteOK", @"")
											   alternateButton:NSLocalizedString(@"DeleteCancel", @"")
												   otherButton:nil
									 informativeTextWithFormat:NSLocalizedString(@"DeleteMessage", @"")];
				
				NSImage* icon = [[[NSImage alloc] initWithSize:NSMakeSize(64.0, 64.0)] autorelease];
				[icon lockFocus];
				[[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationHigh];
				[[NSImage imageNamed:@"Stainless"] drawInRect:NSMakeRect(0.0, 0.0, 64.0, 64.0) fromRect:NSZeroRect operation:NSCompositeCopy fraction:1.0];
				[icon unlockFocus];
				[alert setIcon:icon];
				
				[alert setAlertStyle:NSCriticalAlertStyle];
				[alert beginSheetModalForWindow:[self window] modalDelegate:self didEndSelector:@selector(alertDidEnd:returnCode:contextInfo:) contextInfo:nil];
				
				break;
			}
		}
			
		case bookmarkConfirmDelete:
		{	
			StainlessController* controller = (StainlessController*)[NSApp delegate];

			if([selection isOpen])
				[self closeBookmarkGroup:selection];
			if([selection isGroup])
				[self deleteBookmarksForGroup:selection];			
			
			[controller deleteBookmark:selection];

			[selection removeFromSuperview];
			[self resizeToWindow];
			
			[self commitBookmarks];
			
			if([[self subviews] count] == 0)
				[self setNeedsDisplay:YES];
			
			self.selection = nil;
			
			break;
		}
			
		case bookmarkEdit:
		{
			StainlessController* controller = (StainlessController*)[NSApp delegate];
			[controller openEditor:selection];
			break;
		}
	}
}

// NSMenu delegate
- (void)menuNeedsUpdate:(NSMenu *)menu
{
	BOOL enabled = (selection == nil ? NO : YES);
	BOOL javascript = NO;
	
	NSDictionary* bookmarkInfo = [selection bookmarkInfo];
	NSString* urlString = [bookmarkInfo objectForKey:@"url"];
	if([urlString hasPrefix:@"javascript:"])
		javascript = YES;
	
	for(NSMenuItem* item in [menu itemArray]) {
		if(javascript && ([item tag] == 200 || [item tag] == 300))
			[item setEnabled:NO];
		else
			[item setEnabled:enabled];
	}	
}

// NSDraggingDestination protocol
- (NSDragOperation)draggingEntered:(id < NSDraggingInfo >)sender
{
	dragOffset = -1;
	dragIndex = -1;

	NSPasteboard* pboard = [sender draggingPasteboard];
	[pboard types];
	
	NSString* bookmarkIndexString = [pboard stringForType:StainlessBookmarkPboardType];
	if(bookmarkIndexString)
		return NSDragOperationMove;
	
	return NSDragOperationCopy;
}

- (NSDragOperation)draggingUpdated:(id < NSDraggingInfo >)sender
{
	float height = [self frame].size.height;
	
	int newDragOffset = height - [sender draggingLocation].y;
	if(dragOffset != newDragOffset) {
		dragOffset = newDragOffset;
		
		NSArray* subviews = [self subviews];
		
		float y = height - 24.0;
		float w = 24.0;
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
			NSArray* sortedIcons = [subviews sortedArrayUsingSelector:@selector(topToBottomCompare:)];
			for(BookmarkView* icon in sortedIcons) {
				if(d >= 0 && d++ == dragIndex) {
					y -= (float)wi;
					d = -1;
				}
				
				if([icon isHidden] == YES) {
					[icon setFrame:NSMakeRect(4.0, y, 16.0, 16.0)];
					continue;
				}
				
				
				[icon setFrame:NSMakeRect(4.0, y, 16.0, 16.0)];
				y -= (float)wi;
			}
			
			if(d != -1) {
				y -= (float)wi;
			}
		}
	}
	
	NSPasteboard* pboard = [sender draggingPasteboard];
	[pboard types];
	
	NSString* bookmarkIndexString = [pboard stringForType:StainlessBookmarkPboardType];
	if(bookmarkIndexString)
		return NSDragOperationMove;
	
	return NSDragOperationCopy;
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
	
	StainlessController* controller = (StainlessController*)[NSApp delegate];
	
	if(dragOffset != -1) {
		NSPasteboard* pboard = [sender draggingPasteboard];
		[pboard types];
		
		float height = [self frame].size.height;
		dragIndex++;

		NSString* bookmarkIndexString = [pboard stringForType:StainlessBookmarkPboardType];
		if(bookmarkIndexString) {
			BOOL crossProcessDrop = NO;
			BOOL crossShelfDrop = NO;
	
			NSString* processPrefix = [NSString stringWithFormat:@"bookmark:p%d", [controller clientPid]];
			if([bookmarkIndexString hasPrefix:processPrefix] == NO)
				crossProcessDrop = YES;
			
			NSString* shelfPrefix = [processPrefix stringByAppendingFormat:@"/s%d", shelfIndex];
			if([bookmarkIndexString hasPrefix:shelfPrefix] == NO)
				crossShelfDrop = YES;
						
			NSInteger tag = -1;
			NSRange r = [bookmarkIndexString rangeOfString:@"/u"];
			if(r.location != NSNotFound)
				tag = [[bookmarkIndexString substringFromIndex:r.location + 2] longLongValue];
			
			BookmarkView* icon = nil;
			
			if(crossProcessDrop == NO) {
				if(crossShelfDrop == NO) {
					icon = [self bookmarkWithTag:tag];
				}
				else {
					int destShelfIndex = -1;
					
					r = [bookmarkIndexString rangeOfString:@"/s"];
					if(r.location != NSNotFound) {
						NSString* originString = [bookmarkIndexString substringFromIndex:r.location + 2];
						r = [originString rangeOfString:@"/u"];
						if(r.location != NSNotFound)
							destShelfIndex = [[originString substringToIndex:r.location] intValue];
					}
					
					StainlessShelfView* source = [[controller iconShelf] shelfAtIndex:destShelfIndex];
					if(destShelfIndex != -1)
						icon = [source bookmarkWithTag:tag];
										
					if(icon && [icon isOpen]) {
						if([self frame].origin.x > [source frame].origin.x) {
							NSBeep();
							icon = nil;
						}
						else
							[source closeBookmarkGroup:icon];
					}
					
					if(icon) {
						[icon retain];
						[icon removeFromSuperview];
						[source resizeToWindow];
						[source commitBookmarks];

						if([[source subviews] count] == 0)
							[source setNeedsDisplay:YES];
						
						NSString* urlString = [pboard stringForType:WebURLPboardType];
						if([urlString hasPrefix:@"group:"])
							[icon setTarget:self];
						
						if([[self subviews] count] == 0)
							[self setNeedsDisplay:YES];
						
						[self addSubview:icon];
						[icon release];
					}
				}
			}
			
			if(icon) {
				float y =  height - (dragIndex * 24.0);
				NSRect oldFrame = [icon frame];
				if(crossShelfDrop == NO && y < oldFrame.origin.y)
					y += 24.0;
				
				NSRect frame = NSMakeRect(4.0, y, 16.0, 16.0);
				[icon setFrame:frame];
				
				update = NO;
			}			
		}
		else {
			NSRect frame = NSMakeRect(4.0, height - (dragIndex * 24.0), 16.0, 16.0);

			BookmarkView* icon = [[BookmarkView alloc] initWithFrame:frame pasteBoard:pboard];
			
			if(icon) {
				if([icon isGroup]) {
					[icon setTarget:self];
					[icon setAction:@selector(openBookmarkGroup:)];
					[icon setMenu:groupContext];
					
				}
				else {
					[icon setTarget:controller];
					[icon setAction:@selector(openBookmark:)];
					[icon setMenu:context];
				}
				
				if([[self subviews] count] == 0)
					[self setNeedsDisplay:YES];
				
				[self addSubview:icon];
				[icon release];
				
				update = NO;
			}
		}
		
		dragOffset = -1;
		dragIndex = -1;
	}
	
	[self resizeToWindow];
	
	if(update == NO) {
		[self commitBookmarks];
		[controller updateEditorIfNeeded];
	}
	
	return YES;	
}

- (BOOL)wantsPeriodicDraggingUpdates
{
	return YES;
}

// Callbacks
- (void)alertDidEnd:(NSAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo
{		
	if(returnCode) {
		NSMenuItem* item = [[[NSMenuItem alloc] initWithTitle:@"" action:@selector(paste:) keyEquivalent:@""] autorelease];
		[item setTag:bookmarkConfirmDelete];
		[self handleBookmarkAction:item];
	}
}
			   
@end
