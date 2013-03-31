//
//  StainlessController.m
//  StainlessClient
//
//  Created by Danny Espinoza on 9/5/08.
//  Copyright 2008 Mesa Dynamics, LLC. All rights reserved.
//

#import "StainlessController.h"
#import "StainlessBridge.h"
#import "StainlessProxy.h"
#import "StainlessView.h"
#import "StainlessTabView.h"
#import "StainlessApplication.h"
#import "StainlessBrowser.h"
#import "StainlessShelfView.h"
#import "OverlayWindow.h"
#import "OverlayView.h"
#import <SecurityInterface/SFCertificateTrustPanel.h>
#import "StainlessCookieJar.h"
#import "MainWindow.h"
#import "InspectorView.h"
#import "CGSInternal.h"

extern BOOL gTerminate;
extern BOOL gPrivateMode;
extern BOOL gSingleSession;
extern BOOL gIconShelf;
extern BOOL gIconEditor;
extern BOOL gStatusBar;
extern BOOL gChildClient;

BOOL gAutoHideShowShelf = NO;
BOOL gMouseOverGroups = NO;
BOOL gClickCloseGroups = NO;
BOOL gAutoCloseGroups = NO;

static
void handleSpaceChanged(CGSNotificationType type, void* data, unsigned int dataLength, void* inUserData)
{
	int workspaceID = *((int*)data);
	
	if(workspaceID < kCGSTransitioningWorkspaceID) {
		StainlessController* controller = (StainlessController*) inUserData;
		[controller spaceDidChange];
	}
}


@implementation StainlessController

@synthesize bar;
@synthesize iconShelf;
@synthesize completion;

@synthesize identifier;
@synthesize group;
@synthesize session;
@synthesize mouseNode;
@synthesize completionArray;
@synthesize completionString;
@synthesize securityRequest;
@synthesize securityHost;
@synthesize securityError;
@synthesize clientPid;
@synthesize ignoreSync;

- (id)init
{
	if(self = [super init]) {		
		port = nil;
		proxy = nil;
		identifier = nil;
		group = nil;
		session = nil;
		
		workspace = -1;
		syncspace = 0;
		
		saveQuery = nil;
		lastQuery = nil;
		nextTitle = nil;
		nextBookmark = nil;
		
		lastSearch = nil;		
		searchIndex = 0;
		searchCount = 0;
		searchRange = nil;
		searchRect = NSZeroRect;
		
		restoreWebFocus = NO;
		syncOnActivate = NO;
		ignoreActivation = NO;
		//ignoreLayering = NO;
		ignoreDisconnect = NO;
		ignoreSearch = NO;
		ignoreSync = NO;
		
		saveFrameOnDeactivate = NO;
		ignoreResize = NO;
		ignoreModifiers = NO;
		searchMode = NO;
		firstSearch = YES;
		
		trackedClients = nil;
		
		securityRequest = nil;
		securityHost = nil;
		securityError = nil;
		
		downloads = nil;
		handlers = nil;
		paths = nil;
		
		autoClose = NO;
		autoShow = NO;
		autoHide = NO;
		
		completion = nil;
		
		pageTitles = [[NSMutableDictionary alloc] init];
	}
	
	return self;
}

- (void)awakeFromNib
{	
	NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
	NSDictionary* stainlessDefaults = [defaults persistentDomainForName:@"com.stainlessapp.Stainless"];
	
	NSString* urlString = [stainlessDefaults objectForKey:@"HomePage"];
	if(urlString && [urlString length])
		[self performSelectorOnMainThread:@selector(_refreshClient:) withObject:SMShowHomeButton waitUntilDone:NO];
	else
		[self performSelectorOnMainThread:@selector(_refreshClient:) withObject:SMHideHomeButton waitUntilDone:NO];	
	
	NSMutableString* bundlePath = [[[NSBundle mainBundle] bundlePath] mutableCopy];
	[bundlePath replaceOccurrencesOfString:@"Helpers/StainlessClient.app" withString:@"Resources/Stainless.icns" options:0 range:NSMakeRange(0, [bundlePath length])];
	NSImage* image = [[NSImage alloc] initWithContentsOfFile:bundlePath];
		
	if(image)
		[image setName:@"Stainless"];
	 
	[[self window] setBottomCornerRounded:NO];

	[webViewController addObserver:self forKeyPath:@"selection.canGoBack" options:0 context:nil];
	[webViewController addObserver:self forKeyPath:@"selection.canGoForward" options:0 context:nil];
	[webViewController addObserver:self forKeyPath:@"selection.isLoading" options:0 context:nil];
	
	[webView setHostWindow:[self window]];
	[webView setShouldCloseWithWindow:YES];

	id cookieConnection = [NSConnection rootProxyForConnectionWithRegisteredName:@"StainlessCookieServer" host:nil];
	if(cookieConnection) {
		[cookieConnection retain];
		[cookieConnection setProtocolForProxy:@protocol(StainlessCookieServer)];
		
		[[StainlessCookieJar sharedCookieJar] setCookieServer:cookieConnection];
	}
	
	[webView setResourceLoadDelegate:[StainlessCookieJar sharedCookieJar]];
	
	if([WebView respondsToSelector:@selector(_canHandleRequest:forMainFrame:)])
		webViewCanCheckRequests = YES;
	else
		webViewCanCheckRequests = NO;
	
	WebFrame* mainFrame = [webView mainFrame];
	WebFrameView* mainFrameView = [mainFrame frameView];
	NSView* documentView = [mainFrameView documentView];
	NSClipView* clipView = (NSClipView *)[documentView superview];
		
	[clipView setPostsFrameChangedNotifications:YES];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(clipViewChanged:) name:NSViewBoundsDidChangeNotification object:clipView];

	[statusLabel setUnderlay:[self window]];
}

- (id)connection
{
	if(ignoreDisconnect)
		return nil;
	
	NSDistantObject* connection = proxy;
	
	if(port && connection == nil) {
		@try {
			connection = [NSConnection rootProxyForConnectionWithRegisteredName:@"StainlessServer" host:nil];
		}
		
		@catch (NSException* anException) {
			connection = nil;
		}
		
		if(connection) {			
			proxy = [connection retain];
			[proxy setProtocolForProxy:@protocol(StainlessServerProxy)];
			
			[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(disconnect:) name:@"NSConnectionDidDieNotification" object:[proxy connectionForProxy]];
		}
		else
			[self performSelectorOnMainThread:@selector(_closeClient) withObject:nil waitUntilDone:NO];
	}
	
	return connection;
}

- (StainlessClient*)client
{
	return [[self connection] clientWithIdentifier:identifier];
}

- (void)mouseDownInProcess:(BOOL)force
{
	if(ignoreActivation)
		return;
	
	if(force == NO) {
		if([[self window] isKeyWindow])
			return;
		
		NSDictionary* activeApplication = [[NSWorkspace sharedWorkspace] activeApplication];
		NSString* activeBundle = [activeApplication objectForKey:@"NSApplicationBundleIdentifier"];
		if([activeBundle hasPrefix:@"com.stainlessapp.Stainless"])
			return;
	}
	
	
	NSWindow* window = [self window];
	
	BOOL windowFlushing = [window isFlushWindowDisabled];
	if(windowFlushing == NO)
		[window disableFlushWindow];
	
	[[self connection] hold];
			
	SetFrontProcess(&serverProcess);					
	SetFrontProcess(&clientProcess);

	if(windowFlushing == NO)
		[window enableFlushWindow];
}

- (void)renderProcess
{
	if([[self window] isVisible] == NO) {
		static BOOL firstOpen = YES;
		
		if(firstOpen) {
			StainlessClient* client = [self client];
			StainlessWindow* container = [[self connection] getWindowForClient:client];
			
			if(container && ![container isMultiClient]) {
				NSScreen* screen = [[self window] screen];
				if(screen == nil)
					screen = [NSScreen mainScreen];
				
				NSRect frame = [[self window] frame];
				NSRect screenFrame = [screen visibleFrame];
				
				NSRect intersection = NSIntersectionRect(frame, screenFrame);
				if(NSIsEmptyRect(intersection))
					[[self window] center];
				else
					[[self window] setFrame:intersection display:NO];
			}
			
			firstOpen = NO;
		}
		
		if([[self window] isFlushWindowDisabled])
			[[self window] enableFlushWindow];

		if(searchMode && [overlay parentWindow])
			[self resizeOverlay];

		[[self window] disableScreenUpdatesUntilFlush];
		[[self window] makeKeyAndOrderFront:self];
	}
	else {
		//CGSOrderWindow(_CGSDefaultConnection(), clientWid, kCGSOrderAbove, (CGSWindowID) NULL);
		[[self window] orderFrontRegardless];
		[[self window] update];
	}
}

- (void)activateProcess
{
	NSPoint mouse = [[self window] mouseLocationOutsideOfEventStream];
	NSView* view = [bar hitTest:mouse];
	if(view)
		[view mouseEntered:nil];
	
	//if(ignoreLayering) {
	//	ignoreLayering = NO;
	//	return;
	//}
	
	StainlessWindow* container = [[self connection] getWindowForClient:[self client]];
	[[self connection] layerWindow:container];
}

- (void)updateClientIfHidden
{
	ProcessSerialNumber frontProcess;
	GetFrontProcess(&frontProcess);
		
	Boolean result;
	SameProcess(&frontProcess, &clientProcess, &result);
	if(result == false) {
		[[self connection] updateClient:self];
	}		
}

- (WebView*)webView
{
	return webView;
}

- (NSImage*)webViewImage
{
	NSBitmapImageRep* bitmap = bitmap = [webView bitmapImageRepForCachingDisplayInRect:[webView bounds]];
	[webView cacheDisplayInRect:[webView bounds] toBitmapImageRep:bitmap];
	NSImage* image = [[[NSImage alloc] init] autorelease];
	[image addRepresentation:bitmap];
	
	return image;
}

- (NSRect)webViewFrame
{
	return [webView frame];
}

- (BOOL)canDragClientWindow
{
	return [[self connection] isMultiClient];
}

- (void)switchTab:(id)sender
{
	StainlessTabView* tab = (StainlessTabView*)sender;
	[[self connection] focusClientWithIdentifier:[tab identifier]];
}

- (void)closeTab:(id)sender
{
	StainlessTabView* tab = (StainlessTabView*)[sender superview];
	[[self connection] closeClientWithIdentifier:[tab identifier]];
}

- (IBAction)performCommand:(id)sender
{
	[[self connection] clientToServerCommand:[sender title]];
}

- (IBAction)terminate:(id)sender
{
	NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
	NSDictionary* stainlessDefaults = [defaults persistentDomainForName:@"com.stainlessapp.Stainless"];
	NSNumber* quitValue = [stainlessDefaults objectForKey:@"ConfirmKeyboardQuit"];
		
	if(quitValue && [quitValue boolValue] && [[self connection] isActiveClient]) {
		NSAlert* alert = [NSAlert alertWithMessageText:NSLocalizedString(@"QuitTitle", @"")
										 defaultButton:NSLocalizedString(@"QuitOK", @"")
									   alternateButton:NSLocalizedString(@"QuitCancel", @"")
										   otherButton:nil
							 informativeTextWithFormat:NSLocalizedString(@"QuitMessage", @"")];
		
		NSImage* icon = [[[NSImage alloc] initWithSize:NSMakeSize(64.0, 64.0)] autorelease];
		[icon lockFocus];
		[[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationHigh];
		[[NSImage imageNamed:@"Stainless"] drawInRect:NSMakeRect(0.0, 0.0, 64.0, 64.0) fromRect:NSZeroRect operation:NSCompositeCopy fraction:1.0];
		[icon unlockFocus];
		[alert setIcon:icon];
		
		[alert setAlertStyle:NSCriticalAlertStyle];
		[alert beginSheetModalForWindow:[self window] modalDelegate:self didEndSelector:@selector(alertDidEnd:returnCode:contextInfo:) contextInfo:[sender title]];
	}
	else
		[[self connection] clientToServerCommand:[sender title]];
}

- (IBAction)clickToggle:(id)sender
{
	int clickedSegment = [sender selectedSegment];
	int clickedSegmentTag = [[sender cell] tagForSegment:clickedSegment];
	
	if(clickedSegmentTag == 0)
		[webView goBack:self];
	else
		[webView goForward:self];
}

- (IBAction)clickDirection:(id)sender
{
	int clickedSegment = [sender selectedSegment];
	int clickedSegmentTag = [[sender cell] tagForSegment:clickedSegment];

	if(clickedSegmentTag == 1)
		[self searchNext:self];
	else
		[self searchPrevious:self];
}

- (IBAction)closeTabOrWindow:(id)sender
{
	StainlessClient* client = [self client];
	if(client)	
		[[self connection] closeClient:client];
	else
		[[self window] performClose:self];	 
}

- (IBAction)goHome:(id)sender
{
	NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
	NSDictionary* stainlessDefaults = [defaults persistentDomainForName:@"com.stainlessapp.Stainless"];
	
	NSString* urlString = [stainlessDefaults objectForKey:@"HomePage"];
	if(urlString) {
		[query setStringValue:[NSString stringWithString:urlString]];
		[(StainlessBrowser*)webView takeStringRequestFrom:query];
	}
}

- (IBAction)nextTab:(id)sender
{
	StainlessTabView* tab = [bar nextTab];
	if(tab)
		[self switchTab:tab];
}

- (IBAction)previousTab:(id)sender
{
	StainlessTabView* tab = [bar previousTab];
	if(tab)
		[self switchTab:tab];
}

- (IBAction)gotoTab:(id)sender
{
	NSInteger index = [(NSMenuItem*)sender tag];
	StainlessTabView* tab = [bar tabWithIndex:index];
	if(tab)
		[self switchTab:tab];	
}

- (IBAction)nextWindow:(id)sender
{
	[[self connection] clientToServerCommand:@"Select Next Window"];
}

- (IBAction)previousWindow:(id)sender
{
	[[self connection] clientToServerCommand:@"Select Previous Window"];
}

- (IBAction)search:(id)sender
{
	if(searchMode == NO)
		return;
	
	ignoreSearch = YES;
	
	[[self window] disableFlushWindow];
	
	WebFrame* mainFrame = [webView mainFrame];
	WebFrameView* mainFrameView = [mainFrame frameView];
	id documentView = [mainFrameView documentView];
	NSClipView* clipView = (NSClipView *)[documentView superview];
	
	BOOL match = NO;
	NSString* matchString = nil;

	NSString* searchString = [search stringValue];
	NSMutableArray* holes = nil;

	if(lastSearch && searchString && [lastSearch isEqualToString:searchString]) {
	} else {
		searchIndex = 0;
		
		if(searchString) {
			[lastSearch release];
			lastSearch = [[NSString alloc] initWithString:searchString];
		}
	}

	if(searchRange) {
		[searchRange release];
		searchRange = nil;
	}
	
	searchRect = NSZeroRect;
	
	[webView setSelectedDOMRange:nil affinity:[webView selectionAffinity]];
	
	searchCount = 0;
	
	while([webView searchFor:searchString direction:YES caseSensitive:NO wrap:NO]) {
		match = YES;
		
		if(holes == nil) {
			holes = [[[NSMutableArray alloc] init] autorelease];
		}
		
		NSRect holeRect = [documentView selectionRect];
		[holes addObject:[NSValue valueWithRect:holeRect]];
	
		if(searchCount == searchIndex) {
			searchRange = [[webView selectedDOMRange] retain];
			searchRect = holeRect;
		}
		
		if(++searchCount == 100) {
			holes = nil;
			break;
		}
	}
			
	OverlayView* view = (OverlayView *)[overlay contentView];
	[view setHoles:holes];
	[view setSelection:searchRect];

	if(searchRange) {
		[webView setSelectedDOMRange:searchRange affinity:[webView selectionAffinity]];
		[webView centerSelectionInVisibleArea:self];
		[webView setSelectedDOMRange:nil affinity:[webView selectionAffinity]];
	}
	else {
		[webView setSelectedDOMRange:nil affinity:[webView selectionAffinity]];
	}
	
	[[self window] enableFlushWindow];
		
	if(match) {
		if(searchCount == 1)
			matchString = [NSString stringWithFormat:@"1 %@", NSLocalizedString(@"SearchMatch", @"")];
		else if(searchCount == 100)
			matchString = NSLocalizedString(@"SearchManyMatches", @"");
		else
			matchString = [NSString stringWithFormat:@"%d %@", searchCount, NSLocalizedString(@"SearchMatches", @"")];
		
		if([overlay parentWindow] == NO) {
			[self resizeOverlay];
			[[self window] addChildWindow:overlay ordered:NSWindowAbove];
			[overlay orderFront:self];
			[[overlay animator] setAlphaValue:1.0];
		}
	}
	else {
		matchString = NSLocalizedString(@"SearchNoMatches", @"");
		
		if([overlay parentWindow]) {
			[[self window] removeChildWindow:overlay];
			[overlay orderOut:self];
			[[overlay animator] setAlphaValue:0.0];
		}
	}
	
	if([searchString length] == 0)
		[results setStringValue:@""];
	else
		[results setStringValue:matchString];

	/*[webView setEditable:YES];
	NSColorPanel* p = [NSColorPanel sharedColorPanel];
	[p setColor:[NSColor yellowColor]];
	[webView changeDocumentBackgroundColor:p];
	[p setColor:[NSColor blackColor]];
	[webView changeColor:p];*/

	[backForwardSearch setEnabled:([searchString length] == 0 || searchCount < 2 ? NO : YES)];

	if([sender isEqualTo:self] == NO) {
		[[self window] makeFirstResponder:search];
		[[search currentEditor] setSelectedRange:NSMakeRange([searchString length], 1)];
	}
	
	ignoreSearch = NO;

	[view setOffset:[clipView bounds].origin];
	[self resizeOverlay];
}

- (IBAction)searchNext:(id)sender
{
	if(searchMode == NO && [sender isMemberOfClass:[NSMenuItem class]]) {
		[self openSearch:self];
	}
	else {
		if(searchIndex < searchCount - 1)
			searchIndex++;
		else
			searchIndex = 0;
	}
	
	[self search:self];
}

- (IBAction)searchPrevious:(id)sender
{
	if(searchMode == NO && [sender isMemberOfClass:[NSMenuItem class]]) {
		[self openSearch:self];
	}
	else {
		if(searchIndex == 0)
			searchIndex = searchCount - 1;
		else
			searchIndex--;
	}
	
	[self search:self];
}

- (IBAction)searchThis:(id)sender
{
	NSPasteboard* pb = [NSPasteboard generalPasteboard];
	[pb types];
	NSString* saveString = [[pb stringForType:NSStringPboardType] retain];

	[webView copy:self];
	[pb types];
	NSString* webSelection = [pb stringForType:NSStringPboardType];
	if(webSelection) {
		[search setStringValue:webSelection];
		[pb declareTypes:[NSArray arrayWithObject:NSStringPboardType] owner:nil];
		[pb setString:saveString forType:NSStringPboardType];
		[saveString release];
		
		if(searchMode == NO && [sender isMemberOfClass:[NSMenuItem class]]) {
			[self openSearch:self];
		}
		
		[self search:self];
	}
}

- (IBAction)selectThis:(id)sender
{
	[webView centerSelectionInVisibleArea:self];
}

- (IBAction)toggleIconShelf:(id)sender
{
	gIconShelf = !gIconShelf;
	[iconShelf setHidden:!gIconShelf];

	NSRect frame = [webView frame];
	float w = [iconShelf width];

	if(gIconShelf == NO) {
		if(gIconEditor) {
			[iconEditor setHidden:YES];
			
			w += [iconEditor frame].size.width;
		}
		
		frame.origin.x -= w;
		frame.size.width += w;
		[webView setFrame:frame];
				
		NSRect searchFrame = [searchBar frame];
		searchFrame.origin.x -= w;
		searchFrame.size.width += w;
		[searchBar setFrame:searchFrame];
	}
	else {
		if(gIconEditor) {
			[iconEditor setHidden:NO];
			
			w += [iconEditor frame].size.width;
		}
		
		frame.origin.x += w;
		frame.size.width -= w;
		[webView setFrame:frame];
		
		NSRect searchFrame = [searchBar frame];
		searchFrame.origin.x += w;
		searchFrame.size.width -= w;
		[searchBar setFrame:searchFrame];
	}

	self.mouseNode = nil;
	if(gStatusBar == NO)
		[statusLabel hideLabelNow];

	[[[self window] contentView] setNeedsDisplay:YES];
	
	if(sender /*&& gChildClient == NO */) {
		StainlessWindow* container = [[self connection] getWindowForClient:[self client]];
		[container setStoreIconShelf:gIconShelf];
	}
}

- (IBAction)toggleStatusBar:(id)sender
{
	gStatusBar = !gStatusBar;
	[status setHidden:!gStatusBar];
	
	if(gStatusBar == NO) {
		self.mouseNode = nil;
		
		NSRect frame = [webView frame];
		frame.size.height += 16.0;
		frame.origin.y -= 16.0;
		[webView setFrame:frame];
		
		frame = [iconEditor frame];
		frame.size.height += 16.0;
		frame.origin.y -= 16.0;
		[iconEditor setFrame:frame];
		
		NSRect shelfFrame = [iconShelf frame];
		shelfFrame.size.height += 16.0;
		shelfFrame.origin.y -= 16.0;
		[iconShelf setFrame:shelfFrame];
	}
	else {
		[statusLabel hideLabelNow];

		NSRect frame = [webView frame];
		frame.size.height -= 16.0;
		frame.origin.y += 16.0;
		[webView setFrame:frame];
		
		frame = [iconEditor frame];
		frame.size.height -= 16.0;
		frame.origin.y += 16.0;
		[iconEditor setFrame:frame];
		
		NSRect shelfFrame = [iconShelf frame];
		shelfFrame.size.height -= 16.0;
		shelfFrame.origin.y += 16.0;
		[iconShelf setFrame:shelfFrame];
	}
	
	[[[self window] contentView] setNeedsDisplay:YES];
	
	if(sender /*&& gChildClient == NO */) {
		StainlessWindow* container = [[self connection] getWindowForClient:[self client]];
		[container setStoreStatusBar:gStatusBar];
	}
}

- (IBAction)openSearch:(id)sender
{
	if(searchMode == NO) {
		searchMode = YES;
		
		if(firstSearch == YES) {
			NSData* iconData = [[NSImage imageNamed:@"NSGoLeftTemplate"] TIFFRepresentationUsingCompression:NSTIFFCompressionNone factor:1.0];
			if(iconData) {
				NSImage* icon = [[NSImage alloc] initWithData:iconData];
				[icon setScalesWhenResized:YES];
				[icon setSize:NSMakeSize(8.0, 8.0)];
				[backForwardSearch setImage:icon forSegment:0];
			}
	
			iconData = [[NSImage imageNamed:@"NSGoRightTemplate"] TIFFRepresentationUsingCompression:NSTIFFCompressionNone factor:1.0];
			if(iconData) {
				NSImage* icon = [[NSImage alloc] initWithData:iconData];
				[icon setScalesWhenResized:YES];
				[icon setSize:NSMakeSize(8.0, 8.0)];
				[backForwardSearch setImage:icon forSegment:1];
			}
				
			firstSearch = NO;
		}
				
		NSRect searchFrame = [searchBar frame];
		NSRect frame = [webView frame];
		//frame.origin.y += searchFrame.size.height;
		frame.size.height -= searchFrame.size.height;
		[webView setFrame:frame];

		//[(StainlessBrowser*)webView setIsSearching:YES];
		
		//[navBar setHidden:YES];
		[searchBar setHidden:NO];
		
		[backForwardSearch setEnabled:NO];
		//[search setStringValue:@""];
		[results setStringValue:@""];
	}
	
	[[self window] makeFirstResponder:search];
}

- (IBAction)closeSearch:(id)sender
{
	if(searchMode) {
		if([overlay parentWindow]) {
			[[self window] removeChildWindow:overlay];
			[overlay orderOut:self];
		}
		
		//[(StainlessBrowser*)webView setIsSearching:NO];

		[searchBar setHidden:YES];
		//[navBar setHidden:NO];
		
		NSRect searchFrame = [searchBar frame];
		NSRect frame = [webView frame];
		//frame.origin.y -= searchFrame.size.height;
		frame.size.height += searchFrame.size.height;
		[webView setFrame:frame];
		
		if(searchRange) {
			[[self window] makeFirstResponder:webView];
			[webView setSelectedDOMRange:searchRange affinity:[webView selectionAffinity]];
		}
		
		[results setStringValue:@""];
		
		searchMode = NO;
	}
}

- (IBAction)openEditor:(id)sender
{
	if(sender) {
		[iconEditor updateBookmark:(BookmarkView*)sender];
		
		[self arrangeShelvesForEditing:YES];
	}
	
	if(gIconEditor == NO) {
		[iconEditor setHidden:NO];

		NSRect editorFrame = [iconEditor frame];
		NSRect frame = [webView frame];
		float w = editorFrame.size.width;
		
		frame.origin.x += w;
		frame.size.width -= w;
		[webView setFrame:frame];
		
		NSRect searchFrame = [searchBar frame];
		searchFrame.origin.x += w;
		searchFrame.size.width -= w;
		[searchBar setFrame:searchFrame];

		self.mouseNode = nil;
		if(gStatusBar == NO)
			[statusLabel hideLabelNow];

		gIconEditor = YES;
	}
}

- (IBAction)closeEditor:(id)sender
{
	if(gIconEditor) {
		[iconEditor updateBookmark:nil];
		
		[iconEditor setHidden:YES];
		[self arrangeShelvesForEditing:NO];
		
		NSRect editorFrame = [iconEditor frame];
		NSRect frame = [webView frame];
		float w = editorFrame.size.width;

		frame.origin.x -= w;
		frame.size.width += w;
		[webView setFrame:frame];
		
		NSRect searchFrame = [searchBar frame];
		searchFrame.origin.x -= w;
		searchFrame.size.width += w;
		[searchBar setFrame:searchFrame];

		self.mouseNode = nil;
		if(gStatusBar == NO)
			[statusLabel hideLabelNow];

		gIconEditor = NO;
	}
}

- (IBAction)printWebView:(id)sender
{
	NSString* urlString = [webView mainFrameURL];
	if([urlString hasSuffix:@".pdf"]) {
		//[webView print:sender];
		//return;
	}
	
	WebFrame* mainFrame = [webView mainFrame];
	WebFrameView* mainFrameView = [mainFrame frameView];
	NSView* documentView = [mainFrameView documentView];
	[documentView print:sender];
}

- (IBAction)collapseOneShelf:(id)sender
{
	StainlessShelfView* endShelf = nil;
	
	id child = [iconShelf child];
	while(child) {
		endShelf = child;
		child = [child child];
	}
	
	if(endShelf)
		[[endShelf parent] closeBookmarkGroup:[endShelf owner]];
}

- (IBAction)collapseAllShelves:(id)sender
{
	StainlessShelfView* child = [iconShelf child];
	if(child) {
		[child closeGroup:nil];
	
		[iconShelf closeBookmarkGroup:[iconShelf focus]];
	}
}

- (IBAction)gotoBookmark:(id)sender
{
	if(gIconShelf) {
		NSInteger index = [(NSMenuItem*)sender tag];
			
		StainlessShelfView* endShelf = iconShelf;
		while([endShelf child])
			endShelf = [endShelf child];
		
		NSArray* subviews = [endShelf subviews];
		NSArray* sortedIcons = [subviews sortedArrayUsingSelector:@selector(topToBottomCompare:)];
		if(index >= 1 && index <= [sortedIcons count]) {
			ignoreModifiers = YES;
			
			BookmarkView* bookmark = [sortedIcons objectAtIndex:index - 1];
			[bookmark performClick:bookmark];
		}
	}
}

- (IBAction)gotoGroup:(id)sender
{
}

- (IBAction)autoComplete:(id)sender
{
	if(completion == nil)
		return;
	
	int selectedRow = [smartBar selectedRow];
	if(selectedRow == -1)
		return;
	
	NSString* selection = [completionArray objectAtIndex:selectedRow];
	[query setStringValue:selection];
	
	if(sender)
		[(StainlessBrowser*)webView takeStringRequestFrom:query];
	
	NSDictionary* animation = [NSDictionary dictionaryWithObjectsAndKeys:
							   completion, NSViewAnimationTargetKey,
							   NSViewAnimationFadeOutEffect, NSViewAnimationEffectKey,
							   nil];
	
	NSViewAnimation* _fade = [[NSViewAnimation alloc] initWithViewAnimations:[NSArray arrayWithObject:animation]];
	
	[_fade setDelegate:self];
	[_fade setDuration:0.05];
	//[_fade setAnimationBlockingMode:NSAnimationNonblocking];
	[_fade setAnimationCurve:NSAnimationLinear];
	[_fade startAnimation];
}

- (void)openCompletion
{
	NSString* queryString = [query stringValue];
	if([queryString length] == 0)
		goto closeCompletion;
	
	NSString* urlString = queryString;
	if([urlString hasPrefix:@"about:"] | [urlString hasPrefix:@"javascript:"])
		goto closeCompletion;
	
	BOOL includeSearch = YES;
	
	if([urlString hasPrefix:@"http://"] || [urlString hasPrefix:@"file://"] || [urlString hasPrefix:@"feed://"]) {
		urlString = [urlString substringFromIndex:7];
		includeSearch = NO;
	}
	else if([urlString hasPrefix:@"https://"]) {
		urlString = [urlString substringFromIndex:8];
		includeSearch = NO;
	}
	
	if(completionString && [completionString length] && [urlString hasPrefix:completionString] && completionArray && [completionArray count] == 0)
		goto closeCompletion;
	
	NSArray* remoteArray = [[self connection] completionForURLString:urlString includeSearch:includeSearch];
	NSMutableArray* localArray = [[NSMutableArray alloc] initWithArray:remoteArray copyItems:YES];
	[localArray removeObject:queryString];
	self.completionArray = localArray;
	[localArray autorelease];
	
	self.completionString = urlString;

	
	if([completionArray count] == 0)
		goto closeCompletion;
	
	[smartBar deselectAll:self];
	[smartBar reloadData];
	
	if(completion == nil) {
		NSRect frame = [completionView frame];
		frame.size.width = [query frame].size.width;
		frame.size.height = 12.0 + (19.0 * [smartBar numberOfRows]);
		if([completionArray containsObject:@"-"])
			frame.size.height -= 10.0;
		[completionView setFrame:frame];
		
		NSPoint queryPoint = [query convertPoint:NSMakePoint(20.0, 22.0) toView:nil];
		completion = [[MAAttachedWindow alloc] initWithView:completionView
											attachedToPoint:queryPoint 
												   inWindow:[self window] 
													 onSide:MAPositionBottomRight
												 atDistance:0.0];
		
		//[[completion contentView] setWantsLayer:YES];
		
		[completion setArrowHeight:15.0];
		[completion setArrowBaseWidth:25.0];
		[completion setBackgroundColor:[NSColor colorWithCalibratedWhite:0.085 alpha:.85]];
		[completion setBorderColor:[NSColor colorWithCalibratedWhite:1.0 alpha:0.85]];
		[completion setInnerBorderColor:[NSColor colorWithCalibratedWhite:0.15 alpha:1.0]];
		[completion setInnerBorderWidth:1.0];
		
		[[self window] addChildWindow:completion ordered:NSWindowAbove];
	}
	else {
		NSRect frame = [completionView frame];
		float newHeight = 12.0 + (19.0 * [smartBar numberOfRows]);
		if([completionArray containsObject:@"-"])
			newHeight -= 10.0;
		NSRect windowFrame = [completion frame];
		windowFrame.size.height += newHeight - frame.size.height;
		[completion setFrame:windowFrame display:YES];
	}		
	
	return;
	
closeCompletion:
	[self closeCompletion];
}

- (void)closeCompletion
{
	if(completion) {
		[[self window] removeChildWindow:completion];
		[completion orderOut:self];
		completion = nil;
	}
}

- (void)restoreCompletion
{
	[[self window] makeFirstResponder:webView];

	if(saveQuery)
		[query setStringValue:saveQuery];
}

- (void)newTabWithQuery
{
	NSString* requestString = nil;
	
	if(completion) {
		int selectedRow = [smartBar selectedRow];
		if(selectedRow != -1)
			requestString = [completionArray objectAtIndex:selectedRow];
		
		[self closeCompletion];
	}
	
	if(requestString == nil)
		requestString = [query stringValue];
	
	NSString* urlString = [(StainlessBrowser*)webView requestStringToURL:requestString sender:nil];
		
	if(saveQuery) {
		[query setStringValue:saveQuery];
		[[self window] makeFirstResponder:query];
	}
	
	[self openURLString:urlString];
}

- (void)forceQuery:(NSString*)prefix
{
	NSString* requestString = nil;
	
	if(completion) {
		int selectedRow = [smartBar selectedRow];
		if(selectedRow != -1)
			requestString = [completionArray objectAtIndex:selectedRow];
		
		[self closeCompletion];
	}
	
	if(requestString == nil)
		requestString = [query stringValue];

	if([requestString hasPrefix:prefix] == NO)
		requestString = [NSString stringWithFormat:@"%@%@", prefix, requestString];
	
	NSString* urlString = [(StainlessBrowser*)webView requestStringToURL:requestString sender:nil];
	
	if([webView isLoading])
		[webView stopLoading:self];
	
	[[self window] makeFirstResponder:webView];
	
	NSURL* url = [NSURL URLWithString:urlString];
	[[webView mainFrame] loadRequest:[NSURLRequest requestWithURL:url]];
}

- (void)newTab:(id)sender
{
	[[self connection] clientToServerCommand:@"New Tab"];
}

- (void)undockTabToFrame:(NSRect)frame
{
	[bar prepareForUndocking];
	
	CGSWindowID wid = [[self window] windowNumber];
	int cid = _CGSDefaultConnection();
	CGSWorkspaceID ws;
	CGSGetWindowWorkspace(cid, wid, &ws);
	
	CGSWorkspaceID space;
	CGSGetWorkspace(cid, &space);
	
	if(space && ws != space && space < kCGSTransitioningWorkspaceID) {
		CGSMoveWorkspaceWindowList(cid, &wid, 1, space);
		//CGSOrderWindow(_CGSDefaultConnection(), clientWid, kCGSOrderAbove, (CGSWindowID) NULL);
		[[self window] orderFrontRegardless];

		NSWindow* window = [self window];
		
		BOOL windowFlushing = [window isFlushWindowDisabled];
		if(windowFlushing == NO)
			[window disableFlushWindow];
		
		[[self connection] hold];
		
		SetFrontProcess(&serverProcess);					
		SetFrontProcess(&clientProcess);
		
		if(windowFlushing == NO)
			[window enableFlushWindow];
	}
	
	[[self connection] setSpawnFrame:frame];

	StainlessClient* client = [self client];
	[[self connection] undockClient:client];
	
	StainlessWindow* container = [[self connection] getWindowForClient:client];
	[[self connection] layerWindow:container];
}

- (void)dockTabWithIdentifier:(NSString*)clientIdentifier beforeTabWithIdentifier:(NSString*)insertIdentifier
{
	StainlessClient* client = [self client];
	StainlessWindow* container = [[self connection] getWindowForClient:client];
	
	[[self connection] setSpawnAndFocus:YES];
	[[self connection] dockClientWithIdentifier:clientIdentifier intoWindow:container beforeClientWithIdentifier:insertIdentifier];
}

- (void)resizeOverlay
{
	NSRect frame = [(StainlessBrowser*)webView clippedDocumentFrame];
	[overlay setFrame:frame display:NO];
	[overlay display];
}

- (BOOL)keyDownForCompletion:(int)key
{
	int selectedRow = [smartBar selectedRow];

	if(key == kVK_UpArrow) {
		if(selectedRow == -1)
			;
		else if(selectedRow == 0)
			[smartBar deselectAll:self];
		else {
			int next = 1;
			NSString* s = [completionArray objectAtIndex:selectedRow-1];
			if([s isEqualToString:@"-"])
				next++;

			[smartBar selectRowIndexes:[NSIndexSet indexSetWithIndex:selectedRow-next] byExtendingSelection:NO];
		}
	}
	else if(key == kVK_DownArrow) {
		if(selectedRow == -1)
			[smartBar selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
		else if(selectedRow < [smartBar numberOfRows] - 1) {
			int next = 1;
			NSString* s = [completionArray objectAtIndex:selectedRow+1];
			if([s isEqualToString:@"-"])
				next++;
			
			[smartBar selectRowIndexes:[NSIndexSet indexSetWithIndex:selectedRow+next] byExtendingSelection:NO];
		}
	}
	else if(key == kVK_Escape) {
		[self closeCompletion];
	}
	else if(key == kVK_Return || key == kVK_Tab) {
		if(selectedRow == -1)
			return NO;
		else {
			[self autoComplete:(key == kVK_Return ? self : nil)];
		}
	}
	
	return YES;
}

- (void)updateEditorIfNeeded
{
	if(gIconEditor) {
		if([iconShelf shelfExists:[iconEditor shelf]] == NO || [iconShelf bookmarkExists:[iconEditor bookmark]] == NO)
			[self closeEditor:self];
	}
}

- (void)updateShelves
{
	if(gIconEditor)
		[self closeEditor:self];
	
	id child = iconShelf;
	while(child) {
		[child syncBookmarks:NO];
		
		child = [child child];
	}
}

- (void)arrangeShelvesForEditing:(BOOL)editing
{
	NSRect shelfFrame = [iconShelf frame];
	NSMutableArray* accordion = [NSMutableArray arrayWithObject:iconShelf];
	
	id child = [iconShelf child];
	while(child) {
		[accordion addObject:child];
		child = [child child];
	}
	
	id editShelf = nil;
	if(editing)
		editShelf = [iconEditor shelf];
	
	float x = 0.0;
	for(NSView* shelf in accordion) {
		shelfFrame = [shelf frame];
		shelfFrame.origin.x = x;
		[shelf setFrame:shelfFrame];
		x += shelfFrame.size.width;
		
		if(editShelf && [shelf isEqualTo:editShelf]) {
			NSRect editorFrame = [iconEditor frame];
			editorFrame.origin.x = x;
			[iconEditor setFrame:editorFrame];
			x += editorFrame.size.width;
		}
	}
}

- (NSString*)shelfPath
{
	NSString* path = nil;

	if(gIconShelf) {
		id child = [iconShelf child];
		while(child) {
			NSString* groupString = [child signature];
			if(groupString) {
				if(path == nil)
					path = [NSString stringWithString:groupString];
				else
					path = [path stringByAppendingFormat:@"/%@", groupString];
			}
			
			child = [child child];
		}
	}	
	
	return path;
}

- (void)syncShelves
{
	if(ignoreSync == NO && gIconShelf) {
		StainlessWindow* container = [[self connection] getWindowForClient:[self client]];
		[container setShelfPath:[self shelfPath]];
	}
}

- (void)trackRemoteClient:(StainlessRemoteClient*)remoteClient withIdentifier:(NSString*)clientIdentifier
{
	if(trackedClients == nil)
		trackedClients = [[NSMutableDictionary alloc] initWithCapacity:1];
	
	[trackedClients setObject:remoteClient forKey:clientIdentifier];
}

- (void)untrackRemoteClientWithIdentifier:(NSString*)clientIdentifier
{
	[trackedClients removeObjectForKey:clientIdentifier];
}

- (void)openURLString:(NSString*)urlString
{
	[self openURLString:urlString expandGroup:YES];
}

- (void)openURLString:(NSString*)urlString expandGroup:(BOOL)expand
{
	if(gPrivateMode)
		[[self connection] setSpawnPrivate:YES];

	if(gSingleSession)
		[[self connection] copySpawnSession:session];

	if(expand)
		[[self connection] copySpawnGroup:group];
		
	StainlessClient* client = [self client];
	StainlessWindow* container = [[self connection] getWindowForClient:client];
	[[self connection] spawnClientWithURL:urlString inWindow:container];
}

- (NSString*)resolveURLString:(NSString*)urlString
{
	NSString* resolvedURLString = urlString;
	
	if([urlString hasPrefix:@"bookmark:"]) {
		NSString* signature = nil;
		int index;
		
		NSRange range = [urlString rangeOfString:@"."];
		NSString* bookmarkData = [urlString substringFromIndex:9];
		if(range.location == NSNotFound) {
			index = [bookmarkData intValue];
		}
		else {
			NSArray* components = [bookmarkData componentsSeparatedByString:@"."];
			signature = [[components objectAtIndex:0] retain];
			index = [[components objectAtIndex:1] intValue];
		}
		
		
		if(signature)
			[iconShelf setSignature:signature];
		NSArray* subviews = [iconShelf syncBookmarks:YES andUpdate:NO];
		if(signature)
			[iconShelf setSignature:nil];
		
		if(subviews && index >= 1 && index <= [subviews count]) {
			BookmarkView* bookmark = [subviews objectAtIndex:index - 1];
			NSDictionary* bookmarkInfo = [bookmark bookmarkInfo];
			
			NSString* bookmarkDomain = [bookmarkInfo objectForKey:@"domain"];
			NSString* bookmarkSession = [bookmarkInfo objectForKey:@"session"];
			if(bookmarkDomain && bookmarkSession)
				[[StainlessCookieJar sharedCookieJar] overrideDomain:bookmarkDomain inGroup:group inSession:session toSession:bookmarkSession];
			
			resolvedURLString = [bookmarkInfo objectForKey:@"url"];
		}
	}
	
	if(resolvedURLString == nil)
		resolvedURLString = @"";
	
	return [NSString stringWithString:resolvedURLString];
}

- (void)deleteBookmark:(BookmarkView*)bookmark
{
	if(gIconEditor) {
		BookmarkView* editBookmark = [iconEditor bookmark];
		if(editBookmark && [editBookmark isEqualTo:bookmark]) {
			[self closeEditor:self];
		}
	}
}

- (void)openBookmark:(BookmarkView*)bookmark
{		
	StainlessShelfView* shelf = (StainlessShelfView*) [bookmark superview];
	NSString* shelfGroup = [shelf signature];
	
	if(ignoreModifiers) {
		[self openBookmark:bookmark inGroup:shelfGroup forceTab:NO forceWindow:NO checkModifiers:NO];
		ignoreModifiers = NO;
	}
	else
		[self openBookmark:bookmark inGroup:shelfGroup forceTab:NO forceWindow:NO checkModifiers:YES];
}

- (void)openBookmark:(BookmarkView*)bookmark inGroup:(NSString*)signature forceTab:(BOOL)forceTab forceWindow:(BOOL)forceWindow checkModifiers:(BOOL)checkModifiers
{
	if(gClickCloseGroups)
		[self collapseAllShelves:self];

	[[self window] makeFirstResponder:webView];

	extern UInt32 GetCurrentKeyModifiers();
	NSNumber* modifier = [NSNumber numberWithUnsignedInt:(checkModifiers ? GetCurrentKeyModifiers() : 0)];
	
	NSDictionary* bookmarkInfo = [bookmark bookmarkInfo];
	NSString* urlString = [bookmarkInfo objectForKey:@"url"];
	
	if([urlString hasPrefix:@"http:"] || [urlString hasPrefix:@"https:"] || [urlString hasPrefix:@"file:"]) {
		BOOL middleButtonDown = NO;
		if(checkModifiers)
			middleButtonDown = ([(StainlessApplication*)NSApp lastMouseDown] == NSOtherMouseDown ? YES : NO);

		if(forceTab || forceWindow) {
			if(forceWindow)
				[[self connection] setSpawnWindow:YES];

			NSString* urlString = nil;
			if(signature)
				urlString = [NSString stringWithFormat:@"bookmark:%@.%d", signature, [bookmark index]];
			else
				urlString = [NSString stringWithFormat:@"bookmark:%d", [bookmark index]];
			[self openURLString:urlString expandGroup:NO];
		}
		else if(middleButtonDown || ([modifier unsignedIntValue] & cmdKey)) {
			if(([modifier unsignedIntValue] & shiftKey))
				[[self connection] setSpawnAndFocus:YES];
			
			if(([modifier unsignedIntValue] & optionKey))
				[[self connection] setSpawnWindow:YES];

			NSString* urlString = nil;
			if(signature)
				urlString = [NSString stringWithFormat:@"bookmark:%@.%d", signature, [bookmark index]];
			else
				urlString = [NSString stringWithFormat:@"bookmark:%d", [bookmark index]];
			[self openURLString:urlString expandGroup:NO];
		}
		else {
			NSString* bookmarkDomain = [bookmarkInfo objectForKey:@"domain"];
			NSString* bookmarkSession = [bookmarkInfo objectForKey:@"session"];
			if(bookmarkDomain && bookmarkSession)
				[[StainlessCookieJar sharedCookieJar] overrideDomain:bookmarkDomain inGroup:group inSession:session toSession:bookmarkSession];
			
			NSURL* url = [NSURL URLWithString:urlString];
			[[webView mainFrame] loadRequest:[NSURLRequest requestWithURL:url]];

			//[query setStringValue:urlString];
			//[(StainlessBrowser*)webView takeStringRequestFrom:query];
		}
	}
	else if([urlString hasPrefix:@"javascript:"]) {
		if([webView isLoading] == NO) {
			NSString* script = [urlString substringFromIndex:11];
			NSString* unescapedScript = [script stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
			WebFrame* mainFrame = [webView mainFrame];
			if([mainFrame respondsToSelector:@selector(_stringByEvaluatingJavaScriptFromString:forceUserGesture:)])
				[mainFrame _stringByEvaluatingJavaScriptFromString:unescapedScript forceUserGesture:YES];
			else {
				WebScriptObject* wso = [webView windowScriptObject];
				[wso evaluateWebScript:unescapedScript];
			}
		}
	}
}

- (void)refreshBookmarks
{
	if(gIconEditor)
		[iconEditor updateArrow];
	
	[[self connection] updateClientWindow:self];
}

- (void)updateStatus:(NSString*)message reset:(BOOL)reset
{
	NSPoint windowOrigin = [[self window] frame].origin;
	NSPoint webViewOrigin = [webView convertPoint:NSMakePoint(0.0, 1.0) toView:nil];
	//NSPoint webViewOrigin = NSMakePoint(150.0, [[self window] frame].size.height - 57.0);
	
	
	NSRect webViewFrame = [webView frame];
	NSRect targetFrame = webViewFrame;
	targetFrame.size.height = 16.0;
	
	webViewOrigin.y--;
	
	NSPoint mouse = [[self window] mouseLocationOutsideOfEventStream];
	if(NSPointInRect(mouse, targetFrame)) {
		webViewOrigin.y -= 16.0;
	}
	
	NSPoint target = NSMakePoint(windowOrigin.x + webViewOrigin.x, windowOrigin.y + webViewOrigin.y);
	NSRect screenFrame = [[[self window] screen] frame];
	if(target.y < screenFrame.origin.y)
		target.y = screenFrame.origin.y;

	if(reset)
		self.mouseNode = nil;
	
	[statusLabel setMaxWidth:webViewFrame.size.width];
	[statusLabel showLabel:message atPoint:target];
}

// StainlessClientProtocol
- (void)_registerClient:(NSString*)arg
{
	gTerminate = YES;
	
	id server = [self connection];

	NSString* clientIdentifier = [NSString stringWithString:identifier];
	StainlessClient* client = (StainlessClient*) [server registerClientWithIdentifier:clientIdentifier key:arg];
	
	extern SInt32 gOSVersion;

	if(client && gOSVersion < 0x1060) {
		NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
		NSDictionary* stainlessDefaults = [defaults persistentDomainForName:@"com.stainlessapp.Stainless"];
		NSNumber* gears = [stainlessDefaults objectForKey:@"EnableGears"];
		
		if(gears && [gears boolValue] == YES) {
			NSFileManager* fm = [NSFileManager defaultManager];
			NSString* gearsPath = @"/Library/InputManagers/GearsEnabler/GearsEnabler.bundle";
			if([fm fileExistsAtPath:gearsPath]) {
				NSBundle* gearsBundle = [NSBundle bundleWithPath:gearsPath];
				if(gearsBundle) {
					[gearsBundle load];
					
					Class principalClass = [gearsBundle principalClass];
					if(principalClass)
						[principalClass loadGears];
				}
			}
		}		
	}
	
	if(client) {
		GetCurrentProcess(&clientProcess);
		[client setHiPSN:clientProcess.highLongOfPSN];
		[client setLoPSN:clientProcess.lowLongOfPSN];
		
		if(GetProcessPID(&clientProcess, &clientPid) == noErr)
			[client setPid:clientPid];
				
		//StainlessClient* client = [self client];
		NSArray* hosts = [server getPermittedHosts];
		if(hosts) {
			for(NSString* host in hosts)
				[NSURLRequest setAllowsAnyHTTPSCertificate:YES forHost:host];
		}
				
		StainlessWindow* container = [server getWindowForClient:client];

		clientWid = [[self window] windowNumber];
		[container setWid:clientWid];
		
		NSString* clientGroup = [client group];
		if(clientGroup)
			group = [[NSString alloc] initWithString:clientGroup];
		else
			group = [[NSString alloc] initWithString:identifier];

		[[StainlessCookieJar sharedCookieJar] setGroup:group];
		
		NSString* clientSession = [client session];
		if(clientSession) {
			session = [[NSString alloc] initWithString:clientSession];
			[[StainlessCookieJar sharedCookieJar] setSession:session];
			
			gSingleSession = YES;
		}
		
		if([container privateMode]) {
			if(gSingleSession == NO) {
				session = [[NSString alloc] initWithString:@"private"];
				[[StainlessCookieJar sharedCookieJar] setSession:@"private"];
			}
			
			gPrivateMode = YES;
		}
		else {
			[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(textDidBeginEditing:) name:NSControlTextDidBeginEditingNotification object:query];
			[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(textDidChange:) name:NSControlTextDidChangeNotification object:query];
			[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(textDidEndEditing:) name:NSControlTextDidEndEditingNotification object:query];
		}
		
		WebHistory* history = [WebHistory optionalSharedHistory];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(historyDidModifyItems:) name:WebHistoryItemsAddedNotification object:history];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(historyDidModifyItems:) name:WebHistoryItemsRemovedNotification object:history];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(historyDidModifyItems:) name:WebHistoryAllItemsRemovedNotification object:history];
		
		if(session == nil)
			session = [[NSString alloc] initWithString:@"default"];
				
		[(StainlessBrowser*)webView setupPreferences:gPrivateMode];
								
		NSString* urlString = [self resolveURLString:[client url]];

		if([urlString length]) {
			[iconShelf syncBookmarks:YES];
			
			[client copyTitle:urlString];
			
			[query setStringValue:urlString];
			[(StainlessBrowser*)webView takeStringRequestFrom:query];

			if([webView hostWindow]) {
				if([[[self window] firstResponder] isMemberOfClass:[WebHTMLView class]])
					restoreWebFocus = YES;
				
				[webView retain];
				[webView setHostWindow:nil];
				[webView removeFromSuperviewWithoutNeedingDisplay];
			}
		}
		else {
			[client copyIcon:[NSImage imageNamed:@"Stainless"]];
			[client copyTitle:NSLocalizedString(@"NewTab", @"")];
			
			[[self window] makeFirstResponder:query];
		}
		
		if([client isChild]) {
			gChildClient = YES;

			//if(gStatusBar)
			//	[self toggleStatusBar:nil];

			saveFrameOnDeactivate = NO;
		}
		else
			saveFrameOnDeactivate = YES;
		
		[bar prepareForDragging];

		[server focusWindow:container];
		
		gTerminate = NO;
	}
	
	if(gTerminate)
		[NSApp terminate:self];
	else {
		CGSRegisterNotifyProc((CGSNotifyProcPtr)handleSpaceChanged, kCGSNotificationWorkspaceChanged, (void*)self);
	}
}

- (void)_updateClientWithIdentifier:(NSString*)clientIdentifier
{	
	//[bar updateClientWithIdentifier:clientIdentifier];
	//NSString* arg = [NSString stringWithString:clientIdentifier];
	[bar performSelectorOnMainThread:@selector(updateClientWithIdentifier:) withObject:clientIdentifier waitUntilDone:NO];
}

- (void)_notifyClientWithIdentifier:(NSString*)clientIdentifier
{
	StainlessRemoteClient* remoteClient = [trackedClients objectForKey:clientIdentifier];
	WebView* remoteWebView = [remoteClient webView];
	[remoteWebView setGroupName:nil];
}

- (void)_activateClient:(NSDictionary*)arg
{	
	if([webView hostWindow] == nil) {
		NSView* contentView = [[self window] contentView];
		[contentView addSubview:webView];
		[webView setHostWindow:[self window]];
		[webView release];
		
		if(restoreWebFocus)
			[[self window] makeFirstResponder:webView];
	}

	NSRect frame = [[arg objectForKey:@"Frame"] rectValue];
	int space = [[arg objectForKey:@"Space"] intValue];
	BOOL showIconShelf = [[arg objectForKey:@"Shelf"] boolValue];
	BOOL showStatusBar = [[arg objectForKey:@"Bar"] boolValue];
	NSArray* clientList = [arg objectForKey:@"ClientList"];

	//NSLog(@"%@ space is %d != 65544 && workspace is %d", self, space, workspace);

	if(space && space != 65544 && workspace != space) {
		workspace = space;
		
 		CGSWindowID wid = clientWid;
		int cid = _CGSDefaultConnection();
		CGSWorkspaceID ws;
		CGSGetWindowWorkspace(cid, wid, &ws);
		if(ws != space) {
			//NSLog(@"%@ moving into space %d from %d", self, space, ws);
			CGSMoveWorkspaceWindowList(cid, &wid, 1, space);
		}
	}
	
	ignoreResize = YES;
	[[self window] setFrame:frame display:NO animate:NO];

	//if(gChildClient == NO) {
		if(showIconShelf == !gIconShelf)
			[self toggleIconShelf:nil];
		
		if(showStatusBar == !gStatusBar)
			[self toggleStatusBar:nil];
	//}
	
	[self updateShelves];
	
	if(gIconShelf && ignoreSync == NO) {
		NSString* currentPath = [self shelfPath];
		NSString* newPath = [arg objectForKey:@"Path"];
		
		if((currentPath && newPath == nil) || (newPath && currentPath == nil) || (currentPath && newPath && [currentPath isEqualToString:newPath] == NO))
			[iconShelf expandToGroupPath:newPath];
	}

	[bar syncClientList:clientList inWindowWithIdentifier:identifier];

	if([webView isLoading])
		[iconShelf setLoading:YES];

	[self renderProcess];
}

- (void)_activateClientFront:(NSDictionary*)arg
{		
	if([webView hostWindow] == nil) {
		 NSView* contentView = [[self window] contentView];
		 [contentView addSubview:webView];
		 [webView setHostWindow:[self window]];
		 [webView release];
		
		if(restoreWebFocus)
			[[self window] makeFirstResponder:webView];
	 }
	
	NSRect frame = [[arg objectForKey:@"Frame"] rectValue];
	BOOL showIconShelf = [[arg objectForKey:@"Shelf"] boolValue];
	BOOL showStatusBar = [[arg objectForKey:@"Bar"] boolValue];
	NSArray* clientList = [arg objectForKey:@"ClientList"];
	
	ignoreResize = YES;
	[[self window] setFrame:frame display:NO animate:NO];
	
	//if(gChildClient == NO) {
		if(showIconShelf == !gIconShelf)
			[self toggleIconShelf:nil];
		
		if(showStatusBar == !gStatusBar)
			[self toggleStatusBar:nil];
	//}

	[self updateShelves];
	
	if(gIconShelf && ignoreSync == NO) {
		NSString* currentPath = [self shelfPath];
		NSString* newPath = [arg objectForKey:@"Path"];
		
		if((currentPath && newPath == nil) || (newPath && currentPath == nil) || (currentPath && newPath && [currentPath isEqualToString:newPath] == NO))
			[iconShelf expandToGroupPath:newPath];
	}
	
	[bar syncClientList:clientList inWindowWithIdentifier:identifier];

	if([webView isLoading])
		[iconShelf setLoading:YES];
	
	syncspace = [[arg objectForKey:@"Space"] intValue];
	if(syncspace == 65544) {
		[[self window] setCollectionBehavior:NSWindowCollectionBehaviorCanJoinAllSpaces];
		syncspace = 0;
	}
	else
		[[self window] setCollectionBehavior:NSWindowCollectionBehaviorDefault];
	
	syncOnActivate = YES;			
	SetFrontProcess(&clientProcess);
}

- (void)_deactivateClient
{
	if([[self window] isFlushWindowDisabled])
		[[self window] enableFlushWindow];
	
	ignoreActivation = NO;
	
	[[self window] disableScreenUpdatesUntilFlush];
	
	if([[self window] isVisible])
		[[self window] orderOut:self];

	if([[self window] hasShadow])
		[[self window] setHasShadow:NO];

	/*if([webView hostWindow]) {
		[webView retain];
		[webView setHostWindow:nil];
		[webView removeFromSuperviewWithoutNeedingDisplay];
	}*/
}

- (void)_reactivateClient
{
	//ignoreLayering = YES;
	//SetFrontProcess(&clientProcess);
	
	BOOL clientIsInActiveSpace = NO;
	
	NSWindow* window = [self window];
	if([window respondsToSelector:@selector(isOnActiveSpace)]) {
		clientIsInActiveSpace = [window isOnActiveSpace];
	}
	else {
		CGSWindowID wid = clientWid;
		int cid = _CGSDefaultConnection();
		CGSWorkspaceID ws;
		CGSGetWindowWorkspace(cid, wid, &ws);
		
		CGSWorkspaceID space;
		CGSGetWorkspace(cid, &space);
		
		if(ws == space) {
			clientIsInActiveSpace = YES;
		}
	}

	if(clientIsInActiveSpace) {
		//CGSOrderWindow(_CGSDefaultConnection(), clientWid, kCGSOrderAbove, (CGSWindowID) NULL);
		[[self window] orderFrontRegardless];
	}
}

- (void)_refreshClient:(NSString*)arg
{
	if([arg isEqualToString:SMShowShadow]) {
		if([[self window] hasShadow] == NO)  {
			[[self window] setHasShadow:YES];
		}
	}
	else if([arg isEqualToString:SMHideShadow]){
		if([[self window] hasShadow])
			[[self window] setHasShadow:NO];
	}
	else if([arg isEqualToString:SMPrepareToSpawn]) {
		if([[self window] isMiniaturized])
			[[self window] deminiaturize:self];
	}
	else if([arg isEqualToString:SMShowHomeButton]) {
		if([home isHidden]) {
			[home setHidden:NO];
			
			NSRect frame = [query frame];
			frame.origin.x += 36.0;
			frame.size.width -= 36.0;
			[query setFrame:frame];
		}
		
		[self performSelector:@selector(updatePreferences) withObject:nil afterDelay:1.0];
	}
	else if([arg isEqualToString:SMHideHomeButton]) {
		if([home isHidden] == NO) {
			[home setHidden:YES];
			
			NSRect frame = [query frame];
			frame.origin.x -= 36.0;
			frame.size.width += 36.0;
			[query setFrame:frame];
		}
		
		[self performSelector:@selector(updatePreferences) withObject:nil afterDelay:1.0];
	}
	else if([arg isEqualToString:SMUpdateIconShelf]) {
		if(gIconEditor)
			[self closeEditor:self];
		
		[iconShelf syncBookmarks:NO];

		if([webView isLoading])
			[iconShelf setLoading:YES];
	}
	else if([arg isEqualToString:SMHidePopups]) {
		WebPreferences* preferences = [webView preferences];
		[preferences setJavaScriptCanOpenWindowsAutomatically:NO];
	}
	else if([arg isEqualToString:SMShowPopups]) {
		WebPreferences* preferences = [webView preferences];
		[preferences setJavaScriptCanOpenWindowsAutomatically:YES];
	}
}

- (void)_closeClient
{
	if(ignoreDisconnect)
		return;
	
	ignoreDisconnect = YES;
	
	if([NSApp delegate]) {
		[NSApp setDelegate:nil];
		
		[[self window] setDelegate:nil];
		[[self window] orderOut:self];
		
		[iconShelf setCanSync:NO];
		[iconShelf setCanCommit:NO];
		
		[webView setFrameLoadDelegate:nil];
		[webView setPolicyDelegate:nil];
		[webView setResourceLoadDelegate:nil];
		[webView setUIDelegate:nil];

		if(downloads && [downloads count]) {
			[webView retain]; // necessary?
			
			ignoreDisconnect = NO;
			return;
		}
	}
	
	[webView setDownloadDelegate:nil];

	[[NSNotificationCenter defaultCenter] removeObserver:self];

	@try {
		[port registerName:nil];
		[port invalidate];
	}
	
	@catch (NSException* anException) {
	}
	
		
	[NSApp terminate:self];
}

- (void)_freezeClient:(NSNumber*)arg
{
	BOOL freeze = [arg boolValue];
	
	if(freeze) {
		if([[self window] isFlushWindowDisabled] == NO)
			[[self window] disableFlushWindow];
		
		ignoreActivation = YES;
	}
	else {
		if([[self window] isFlushWindowDisabled])
			[[self window] enableFlushWindow];
		
		ignoreActivation = NO;
	}
}

- (void)_hideClient:(NSNumber*)arg
{
	BOOL hide = [arg boolValue];
	
	if(hide)
		[NSApp hide:self];
	else
		[NSApp unhide:self];
}

- (void)_redirectClient:(NSString*)arg
{
	NSString* urlString = [self resolveURLString:arg];
	
	NSURL* url = [NSURL URLWithString:urlString];
	[[webView mainFrame] loadRequest:[NSURLRequest requestWithURL:url]];
}

- (void)_permitClient:(NSString*)arg
{
	[NSURLRequest setAllowsAnyHTTPSCertificate:YES forHost:arg];
}

- (void)_resizeClient:(NSValue*)arg
{
	NSRect frame = [arg rectValue];
	[[self window] setFrame:frame display:YES animate:NO];
}

- (void)_serverToClientCommand:(NSString*)arg
{	
	NSMenu* targetMenu = nil;
	BOOL sendToFirstResponder = NO;
		
	@try {
		if(
		   [arg isEqualToString:@"Close Tab"] ||
		   [arg isEqualToString:@"Print..."]
		   )
			targetMenu = [[[NSApp mainMenu] itemAtIndex:1] submenu];
		else if(
				[arg isEqualToString:@"Undo"] ||
				[arg isEqualToString:@"Redo"] ||
				[arg isEqualToString:@"Cut"] ||
				[arg isEqualToString:@"Copy"] ||
				[arg isEqualToString:@"Paste"] ||
				[arg isEqualToString:@"Delete"] ||
				[arg isEqualToString:@"Select All"]
				) {
			targetMenu = [[[NSApp mainMenu] itemAtIndex:2] submenu];
			sendToFirstResponder = YES;
		}
		else if(
				[arg hasPrefix:@"Find"] ||
				[arg isEqualToString:@"Use Selection for Find"] ||
				[arg isEqualToString:@"Jump to Selection"]
				) {
			targetMenu = [[[NSApp mainMenu] itemAtIndex:2] submenu];
			targetMenu = [[targetMenu itemAtIndex:[targetMenu indexOfItemWithTitle:@"Find"]] submenu];
		}
		else if([arg isEqualToString:@"Bookmark Shelf"] || [arg isEqualToString:@"Status Bar"] || [arg isEqualToString:@"Page Source"])
			targetMenu = [[[NSApp mainMenu] itemAtIndex:3] submenu];
		else if([arg isEqualToString:@"Minimize"] || [arg isEqualToString:@"Zoom"])
			targetMenu = [[[NSApp mainMenu] itemAtIndex:4] submenu];
		else if([arg isEqualToString:@"Stainless Help"])
			targetMenu = [[[NSApp mainMenu] itemAtIndex:5] submenu];
		
		if(targetMenu) {
			int index = [targetMenu indexOfItemWithTitle:arg];
			
			if(sendToFirstResponder) {
				NSMenuItem* item = [targetMenu itemAtIndex:index];
				
				NSResponder* chain = [[self window] firstResponder];
				while(chain) {
					if([chain respondsToSelector:@selector(validateUserInterfaceItem:)]) {
						if([chain performSelector:@selector(validateUserInterfaceItem:) withObject:item]) {
							[[[self window] firstResponder] doCommandBySelector:[item action]];
							break;
						}
					}
					
					chain = [chain nextResponder];
				}
			}
			else
				[targetMenu performActionForItemAtIndex:index];
		}
	}
	
	@catch (NSException* anException) {
	}
}

- (void)_cancelDownloadForClient:(NSString*)arg
{
	for(NSString* key in [downloads allKeys]) {
		NSString* downloadStamp = [downloads objectForKey:key];
		
		if([downloadStamp isEqualToString:arg]) {
			[downloads removeObjectForKey:key];
			
			NSURLDownload* download = [handlers objectForKey:key];
			[download cancel];
			
			[handlers removeObjectForKey:key];
			
			NSString* path = [paths objectForKey:key];
			if(path)
				[[NSFileManager defaultManager] removeItemAtPath:path error:nil];

			[paths removeObjectForKey:key];

			if([downloads count] == 0 && [NSApp delegate] == nil)
				[self performSelectorOnMainThread:@selector(_closeClient) withObject:nil waitUntilDone:NO];
			
			return;
		}
	}
}

// NSKeyValueObserving protocol
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if([keyPath isEqualToString:@"selection.canGoBack"])
		[backForwardToggle setEnabled:[webView canGoBack] forSegment:0];
	else if([keyPath isEqualToString:@"selection.canGoForward"])
		[backForwardToggle setEnabled:[webView canGoForward] forSegment:1];
	else if([keyPath isEqualToString:@"selection.isLoading"])
		[iconShelf setLoading:[webView isLoading]];
}

// Notifications
- (void)disconnect:(NSNotification*)aNotification
{
	if(downloads && [downloads count]) {
		ignoreDisconnect = YES;
		
		for(NSString* key in [downloads allKeys]) {
			NSURLDownload* download = [handlers objectForKey:key];
			[download cancel];
			
			NSString* path = [paths objectForKey:key];
			if(path)
				[[NSFileManager defaultManager] removeItemAtPath:path error:nil];
		}
		
		ignoreDisconnect = NO;
	}

	[self performSelectorOnMainThread:@selector(_closeClient) withObject:nil waitUntilDone:NO];
}

- (void)documentViewChanged:(NSNotification*)aNotification
{
	if(searchMode && [overlay parentWindow]) {
		[self search:self];
	}
}

- (void)clipViewChanged:(NSNotification*)aNotification
{
	if(ignoreSearch == NO && searchMode && [overlay parentWindow]) {
		OverlayView* view = (OverlayView*)[overlay contentView];
		[view setOffset:[(NSView*)[aNotification object] bounds].origin];
		
		[self resizeOverlay];
	}
}

- (void)_updateHistoryMenus
{
	WebBackForwardList* list = [webView backForwardList];
	NSMenu* backMenu = nil;
	NSArray* backList = [list backListWithLimit:15];
	if(backList) {
		for(WebHistoryItem* site in [backList reverseObjectEnumerator]) {
			NSString* urlString = [site URLString];
			if(urlString == nil)
				continue;
			
			NSString* title = [site title];
			if(title == nil) {
				title = [pageTitles objectForKey:urlString];
				if(title == nil)
					title = [NSString stringWithFormat:@"Page at %@", urlString];
			}
			
			if(backMenu == nil)
				backMenu = [[NSMenu alloc] init];
			
			NSMenuItem* item = [[NSMenuItem alloc] initWithTitle:title action:@selector(loadHistoryItem:) keyEquivalent:@""];
			if(item) {
				[item setRepresentedObject:site];
				[backMenu addItem:item];
				[item release];
			}
			
			NSMenuItem* altItem = [[NSMenuItem alloc] initWithTitle:urlString action:@selector(loadHistoryItem:) keyEquivalent:@""];
			if(altItem) {
				[altItem setAlternate:YES];
				[altItem setKeyEquivalentModifierMask:NSAlternateKeyMask];
				[altItem setRepresentedObject:site];
				[backMenu addItem:altItem];
				[altItem release];
			}
		}
	}
	
	if(backMenu) {
		[backForwardToggle setMenu:backMenu forSegment:0];
		[backMenu release];
	}
	
	NSMenu* forwardMenu = nil;
	NSArray* forwardList = [list forwardListWithLimit:15];
	if(forwardList) {
		for(WebHistoryItem* site in forwardList) {
			NSString* urlString = [site URLString];
			if(urlString == nil)
				continue;
			
			NSString* title = [site title];
			if(title == nil) {
				title = [pageTitles objectForKey:urlString];
				if(title == nil)
					title = [NSString stringWithFormat:@"Page at %@", urlString];
			}

			if(forwardMenu == nil)
				forwardMenu = [[NSMenu alloc] init];
			
			NSMenuItem* item = [[NSMenuItem alloc] initWithTitle:title action:@selector(loadHistoryItem:) keyEquivalent:@""];
			if(item) {
				[item setRepresentedObject:site];
				[forwardMenu addItem:item];
				[item release];
			}
			
			NSMenuItem* altItem = [[NSMenuItem alloc] initWithTitle:urlString action:@selector(loadHistoryItem:) keyEquivalent:@""];
			if(altItem) {
				[altItem setAlternate:YES];
				[altItem setKeyEquivalentModifierMask:NSAlternateKeyMask];
				[altItem setRepresentedObject:site];
				[forwardMenu addItem:altItem];
				[altItem release];
			}
		}
	}
	
	if(forwardMenu) {
		[backForwardToggle setMenu:forwardMenu forSegment:1];	
		[forwardMenu release];
	}
}

- (void)historyDidModifyItems:(NSNotification *)aNotification
{
	[self _updateHistoryMenus];
}

- (void)textDidBeginEditing:(NSNotification *)aNotification
{
	[saveQuery release];
	saveQuery = [[NSString alloc] initWithString:[query stringValue]];
}

- (void)textDidChange:(NSNotification *)aNotification
{	
	id fieldEditor = [[aNotification userInfo] objectForKey:@"NSFieldEditor"];
	if([[[self window] firstResponder] isEqualTo:fieldEditor])
		[self openCompletion];
}

- (void)textDidEndEditing:(NSNotification *)notification
{
	[self closeCompletion];
	
	if(saveQuery && [[query stringValue] length] == 0)
		[query setStringValue:saveQuery];
}

// NSAnimation deleagte
- (void)animationDidEnd:(NSAnimation *)animation
{
	[self closeCompletion];
	
	[animation autorelease];
}

// NSWindow delegate
- (void)windowDidBecomeKey:(NSNotification *)notification
{
	if(ignoreActivation)
		return;
	
	[self activateProcess];
}

- (void)windowDidResignKey:(NSNotification *)notification
{
	if(saveFrameOnDeactivate) {
		if(gChildClient == NO) {
			StainlessClient* client = [self client];
			StainlessWindow* container = [[self connection] getWindowForClient:client];
			if(client && container)
				[container saveFrame];
		}
		
		saveFrameOnDeactivate = NO;
	}
}

- (void)windowDidMove:(NSNotification *)notification
{
	if([[self window] isVisible] == NO)
		return;

	StainlessClient* client = [self client];
	StainlessWindow* container = [[self connection] getWindowForClient:client];
	if(client && container)
		[container setFrame:[NSValue valueWithRect:[[self window] frame]]];
	
	if(ignoreResize)
		ignoreResize = NO;
	else
		saveFrameOnDeactivate = YES;
}

- (void)windowDidResize:(NSNotification *)notification
{
	if([[self window] isVisible] == NO)
		return;

	//NSRect f = [[self window] frame];
	//NSLog(@"%.2f %.2f %.2f %.2f", f.origin.x, f.origin.y, f.size.width, f.size.height);
		
	StainlessClient* client = [self client];
	StainlessWindow* container = [[self connection] getWindowForClient:client];
	if(client && container) {
		[container setFrame:[NSValue valueWithRect:[[self window] frame]]];
		[bar resizeToWindow];
	}

	if(searchMode && [overlay parentWindow])
		[self resizeOverlay];

	if(completion) {
		NSRect frame = [completionView frame];
		float newWidth = [query frame].size.width;
		NSRect windowFrame = [completion frame];
		windowFrame.size.width += newWidth - frame.size.width;
		[completion setFrame:windowFrame display:NO];
		NSPoint queryPoint = [query convertPoint:NSMakePoint(20.0, 22.0) toView:nil];
		[completion setPoint:queryPoint side:MAPositionBottomRight];
	}
	
	if(ignoreResize)
		ignoreResize = NO;
	else
		saveFrameOnDeactivate = YES;
}

- (BOOL)windowShouldClose:(id)window
{
	StainlessClient* client = [self client];
	StainlessWindow* container = [[self connection] getWindowForClient:client];
	
	if(container && [container isMultiClient]) {
		NSAlert* alert = [NSAlert alertWithMessageText:NSLocalizedString(@"CloseTitle", @"")
										 defaultButton:NSLocalizedString(@"CloseOK", @"")
									   alternateButton:NSLocalizedString(@"CloseCancel", @"")
										   otherButton:nil
							 informativeTextWithFormat:NSLocalizedString(@"CloseMessage", @"")];

		NSImage* icon = [[[NSImage alloc] initWithSize:NSMakeSize(64.0, 64.0)] autorelease];
		[icon lockFocus];
		[[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationHigh];
		[[NSImage imageNamed:@"Stainless"] drawInRect:NSMakeRect(0.0, 0.0, 64.0, 64.0) fromRect:NSZeroRect operation:NSCompositeCopy fraction:1.0];
		[icon unlockFocus];
		[alert setIcon:icon];
		
		[alert setAlertStyle:NSCriticalAlertStyle];
		[alert beginSheetModalForWindow:[self window] modalDelegate:self didEndSelector:@selector(alertDidEnd:returnCode:contextInfo:) contextInfo:nil];
	}
	else {
		[[self window] orderOut:self];
		
		StainlessClient* client = [self client];
		if(client) {	
			[[self connection] closeClient:client];
		}
	}
	
	return NO;
}

// NSApplication delegate
- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{	
	BOOL foundServerProcess = NO;

	NSArray* launchedApplications = [[NSWorkspace sharedWorkspace] launchedApplications];
	for(NSDictionary* application in launchedApplications) {
		NSString* bundle = [application objectForKey:@"NSApplicationBundleIdentifier"];
		if([bundle isEqualToString:@"com.stainlessapp.Stainless"]) {
			serverProcess.highLongOfPSN = [[application objectForKey:@"NSApplicationProcessSerialNumberHigh"] longValue];
			serverProcess.lowLongOfPSN = [[application objectForKey:@"NSApplicationProcessSerialNumberLow"] longValue];
			foundServerProcess = YES;
			break;
		}
	}

	NSUserDefaults* ud = [NSUserDefaults standardUserDefaults];
	NSString* udIdentifier = [ud stringForKey:@"clientID"];
	NSString* udKey = [ud stringForKey:@"clientKey"];
	
	if(foundServerProcess && udIdentifier && udKey) {
		StainlessProxy* portListener = [[StainlessProxy alloc] init];
		[portListener setController:self];
		
		port = [[NSConnection defaultConnection] retain];
		[port setRootObject:portListener];
		[port registerName:udIdentifier];
		[port runInNewThread];
		[port removeRunLoop:[NSRunLoop currentRunLoop]];
				
		NSString* clientIdentifier = [NSString stringWithString:udIdentifier];
		[self setIdentifier:clientIdentifier];
		
		[webView setGroupName:clientIdentifier];
		
		if([udKey isEqualToString:@"hotspare"]) {
			[[self connection] hotSpareReadyWithIdentifier:udIdentifier];
			gTerminate = NO;
		}	
		else
			[self _registerClient:udKey];
	}
	
	if(gTerminate)
		[NSApp terminate:self];
}

- (void)applicationDidBecomeActive:(NSNotification *)aNotification
{
	if(syncOnActivate) {
		//NSLog(@"syncspace is %d != workspace is %d", syncspace, workspace);
				
		if(syncspace && workspace != syncspace) {
			workspace = syncspace;
			
			CGSWindowID wid = clientWid;
			int cid = _CGSDefaultConnection();
			CGSWorkspaceID ws;
			CGSGetWindowWorkspace(cid, wid, &ws);
			if(ws != syncspace) {
				//NSLog(@"%@ moving into space %d from %d", self, syncspace, ws);
				CGSMoveWorkspaceWindowList(cid, &wid, 1, syncspace);
			}
		}
		
		if(syncspace) {
			CGSWorkspaceID currentSpace;
			CGSGetWorkspace(_CGSDefaultConnection(), &currentSpace);
			
			if(currentSpace != syncspace && syncspace)
				[[NSDistributedNotificationCenter defaultCenter] postNotificationName:@"com.apple.switchSpaces" object:[NSString stringWithFormat:@"%d", syncspace-1]];
		}
		
		[self renderProcess];

		StainlessClient* client = [self client];
		StainlessWindow* container = [[self connection] getWindowForClient:client];
		[container syncClientWindows];
		
		syncOnActivate = NO;
	}
		
	if([overlay parentWindow])
	   [overlay orderFront:self];

	if(completion)
		[completion orderFront:self];

	[self activateProcess];
}

- (void)applicationDidResignActive:(NSNotification *)aNotification
{
	self.mouseNode = nil;
	
	[status setStringValue:@""];
	
	if(gStatusBar == NO)
		[statusLabel hideLabelNow];

	[iconShelf hideBookmark:YES];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)theApplication
{
	StainlessClient* client = [self client];
	if(client)
		return NO;
	
	return YES;
}

// Callbacks
- (void)updatePreferences
{
	NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
	NSDictionary* stainlessDefaults = [defaults persistentDomainForName:@"com.stainlessapp.Stainless"];
	
	NSNumber* number = [stainlessDefaults objectForKey:@"AutoHideShowShelf"];
	if(number && [number boolValue])
		gAutoHideShowShelf = YES;
	else
		gAutoHideShowShelf = NO;
	
	number = [stainlessDefaults objectForKey:@"MouseOverGroups"];
	if(number && [number boolValue])
		gMouseOverGroups = YES;
	else
		gMouseOverGroups = NO;
	
	number = [stainlessDefaults objectForKey:@"ClickCloseGroups"];
	if(number && [number boolValue])
		gClickCloseGroups = YES;
	else
		gClickCloseGroups = NO;
	
	number = [stainlessDefaults objectForKey:@"AutoCloseGroups"];
	if(number && [number boolValue])
		gAutoCloseGroups = YES;
	else
		gAutoCloseGroups = NO;
}

- (void)loadHistoryItem:(NSMenuItem*)sender
{
	WebHistoryItem* item = (WebHistoryItem*)[sender representedObject];
	NSURL* url = [NSURL URLWithString:[item URLString]];
	[[webView mainFrame] loadRequest:[NSURLRequest requestWithURL:url]];
}

- (void)spaceDidChange
{
	if([[self window] isVisible] == NO)
		return;

	if([[self window] collectionBehavior] == NSWindowCollectionBehaviorCanJoinAllSpaces) {
		ProcessSerialNumber frontProcess;
		GetFrontProcess(&frontProcess);

		Boolean result;
		SameProcess(&frontProcess, &clientProcess, &result);
		if(result == true) {
			//CGSOrderWindow(_CGSDefaultConnection(), clientWid, kCGSOrderAbove, (CGSWindowID) NULL);
			[[self window] orderFrontRegardless];
		}
		
		return;
	}

	CGSWorkspaceID ws = -1;
	if(CGSGetWindowWorkspace(_CGSDefaultConnection(), clientWid, &ws) == noErr && ws < kCGSTransitioningWorkspaceID) {
		if(workspace != ws) {
			workspace = ws;
			
			StainlessWindow* container = [[self connection] getWindowForClient:[self client]];
			[container setSpace:ws];
			
			//NSLog(@"%@ setting space to %d", self, ws);
		}
		else {
			ProcessSerialNumber frontProcess;
			GetFrontProcess(&frontProcess);
			
			Boolean result;
			SameProcess(&frontProcess, &clientProcess, &result);
			if(result == true)
				[self mouseDownInProcess:YES];
		}
	}
}

- (void)openPanelDidEnd:(NSOpenPanel *)panel returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	id resultListener = contextInfo;

	if(returnCode == NSOKButton) {
		[resultListener chooseFilename:[[panel filenames] objectAtIndex:0]];
	}
	
	[resultListener release];
}

- (void)alertDidEnd:(NSAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo
{		
	if(returnCode) {
		if(contextInfo) {
			[[self connection] clientToServerCommand:contextInfo];
		}
		else {
			[[self window] orderOut:self];
			
			StainlessClient* client = [self client];
			StainlessWindow* container = [[self connection] getWindowForClient:client];
			
			[[self connection] closeWindow:container];
		}
	}
}

-(void)createPanelDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	if(returnCode == NSFileHandlingPanelOKButton) {
		[NSURLRequest setAllowsAnyHTTPSCertificate:YES forHost:securityHost];
		[[webView mainFrame] loadRequest:securityRequest];
		
		[[self connection] permitClients:securityHost fromClientWithIdentifier:identifier];
	}
	else
		[status setStringValue:securityError];
	
	self.securityRequest = nil;
	self.securityHost = nil;
	self.securityError = nil;
}

/*- (void)downloadURLString:(NSString*)urlString
{	
	NSPasteboard* pb = [NSPasteboard generalPasteboard];
	
	[pb declareTypes:[NSArray arrayWithObject:NSStringPboardType] owner:nil];
	[pb setString:urlString forType:NSStringPboardType];
	
	NSDictionary* errorDict;
	NSAppleEventDescriptor* returnDescriptor = NULL;
	
	NSAppleScript* scriptObject = [[NSAppleScript alloc] initWithSource:
								   @"\
								   tell application \"VerifiedDownloadAgent\" to activate\n\
								   tell application \"System Events\"\n\
								   tell process \"VerifiedDownloadAgent\" to keystroke \"v\" using command down\n\
								   end tell"];
	
	returnDescriptor = [scriptObject executeAndReturnError: &errorDict];
	[scriptObject release];
	
	if (returnDescriptor != NULL)
	{
		// successful execution
		if (kAENullEvent != [returnDescriptor descriptorType])
		{
			// script returned an AppleScript result
			if (cAEList == [returnDescriptor descriptorType])
			{
				// result is a list of other descriptors
			}
			else
			{
				// coerce the result to the appropriate ObjC type
			}
		}
	}
	else
	{
		// no script result, handle error here
	}
}*/

// NSTableViewDataSource delegate
- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView
{
	if(completionArray == nil)
		return 0;
	
	return [completionArray count];
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
	return [completionArray objectAtIndex:rowIndex];
}

// NSTableView delegate
- (BOOL)tableView:(NSTableView *)aTableView shouldSelectRow:(NSInteger)rowIndex
{
	NSString* s = [completionArray objectAtIndex:rowIndex];
	if([s isEqualToString:@"-"])
		return NO;
	
	return YES;
}

- (CGFloat)tableView:(NSTableView *)tableView heightOfRow:(NSInteger)row
{
	NSString* s = [completionArray objectAtIndex:row];
	if([s isEqualToString:@"-"])
		return 10;
	
	return 17;
}

// WebDownload delegate
- (NSURLRequest *)download:(NSURLDownload *)download willSendRequest:(NSURLRequest *)request redirectResponse:(NSURLResponse *)redirectResponse
{
	if(redirectResponse) {	
		NSString* ext = [[[redirectResponse URL] path] pathExtension];
		if(ext && 
		   ([ext isEqualToString:@"bin"] ||
			[ext isEqualToString:@"bz2"] ||
			[ext isEqualToString:@"dmg"] ||
			//[ext isEqualToString:@"exe"] ||
			[ext isEqualToString:@"gz"] ||
			[ext isEqualToString:@"sit"] ||
			[ext isEqualToString:@"sitx"] ||
			[ext isEqualToString:@"tar"] ||
			[ext isEqualToString:@"tgz"] ||
			[ext isEqualToString:@"z"] ||
			[ext isEqualToString:@"Z"] ||
			[ext isEqualToString:@"zip"])
		) {
			if([WebView canShowMIMEType:[redirectResponse MIMEType]]) {
				NSString* current = [webView mainFrameURL];
				NSString* redirect = [[request URL] absoluteString];
				if([current isEqualToString:redirect]) {
					
				}
				else
					[[webView mainFrame] performSelectorOnMainThread:@selector(loadRequest:) withObject:request waitUntilDone:NO];
				
				
				return nil;
			}
		}
	}
	
	return request;
}

- (void)downloadDidBegin:(NSURLDownload *)download
{	
	NSString* downloadStamp = [NSString stringWithFormat:@"%f", [NSDate timeIntervalSinceReferenceDate]];
	
	if(downloads == nil)
		downloads = [[NSMutableDictionary alloc] initWithCapacity:1];
	
	NSString* key = [download description];
	[downloads setObject:downloadStamp forKey:key];
}

- (void)downloadDidFinish:(NSURLDownload *)download
{
	NSString* key = [download description];
	NSString* downloadStamp = [downloads objectForKey:key];
	if(downloadStamp) {
		[[self connection] endDownload:downloadStamp didFail:NO];
		[downloads removeObjectForKey:key];
	}

	[handlers removeObjectForKey:key];

	NSString* pathStamp = [paths objectForKey:key];
	if(pathStamp) {
		//NSString* downloadFile = [pathStamp substringToIndex:[pathStamp length] - 9];
		//[[NSFileManager defaultManager] moveItemAtPath:pathStamp toPath:downloadFile error:nil];
		
		[paths removeObjectForKey:key];
	}
	
	if([downloads count] == 0 && [NSApp delegate] == nil)
		[self performSelectorOnMainThread:@selector(_closeClient) withObject:nil waitUntilDone:NO];
}

- (void)download:(NSURLDownload *)download didFailWithError:(NSError *)error
{
	NSString* key = [download description];
	NSString* downloadStamp = [downloads objectForKey:key];
	if(downloadStamp) {
		[[self connection] endDownload:downloadStamp didFail:YES];
		[downloads removeObjectForKey:key];
	}

	[handlers removeObjectForKey:key];

	NSString* path = [paths objectForKey:key];
	if(path)
		[[NSFileManager defaultManager] removeItemAtPath:path error:nil];
	[paths removeObjectForKey:key];

	if([downloads count] == 0 && [NSApp delegate] == nil)
		[self performSelectorOnMainThread:@selector(_closeClient) withObject:nil waitUntilDone:NO];
}

- (void)download:(NSURLDownload *)download didReceiveDataOfLength:(NSUInteger)length
{	
	NSString* key = [download description];
	NSString* downloadStamp = [downloads objectForKey:key];
	if(downloadStamp == nil)
		return;

	if(handlers && [handlers objectForKey:key] == nil) {
		if(handlers == nil)
			handlers = [[NSMutableDictionary alloc] initWithCapacity:1];
		[handlers setObject:download forKey:key];
	}
	
	[[self connection] updateDownload:downloadStamp contentLength:[NSNumber numberWithInteger:length] fileName:nil];
}

- (void)download:(NSURLDownload *)download didReceiveResponse:(NSURLResponse *)response
{
	NSString* key = [download description];
	NSString* downloadStamp = [downloads objectForKey:key];
	if(downloadStamp) {
		[[self connection] updateDownload:downloadStamp contentLength:[NSNumber numberWithLongLong:[response expectedContentLength]] fileName:nil];
	}
}

- (void)download:(NSURLDownload *)download decideDestinationWithSuggestedFilename:(NSString *)filename
{
	NSString* downloadPath = nil;
	
	NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
	NSDictionary* stainlessDefaults = [defaults persistentDomainForName:@"com.stainlessapp.Stainless"];

	NSNumber* selection = [stainlessDefaults objectForKey:@"DownloadSelection"];
	if(selection) {
		switch([selection intValue]) {
			case 100:
				downloadPath = [NSString stringWithFormat:@"%@/Downloads", NSHomeDirectory()];
				break;
				
			case 200:
				downloadPath = [NSString stringWithFormat:@"%@/Desktop", NSHomeDirectory()];
				break;
				
			case 300:
				downloadPath = [NSString stringWithFormat:@"%@", NSHomeDirectory()];
				break;
				
			case 400:
				downloadPath = [stainlessDefaults objectForKey:@"DownloadLocation"];
				break;
		}
	}					

	NSFileManager* fm = [NSFileManager defaultManager];
	
	if(downloadPath == nil || [downloadPath length] == 0 || [fm fileExistsAtPath:downloadPath] == NO) {
		downloadPath = [NSString stringWithFormat:@"%@/Downloads", NSHomeDirectory()];
		
		if([fm fileExistsAtPath:downloadPath] == NO) {
			downloadPath = [NSString stringWithFormat:@"%@/Desktop", NSHomeDirectory()];
			
			if([fm fileExistsAtPath:downloadPath] == NO)
				downloadPath = [NSString stringWithFormat:@"%@", NSHomeDirectory()];
		}
	}
	
	[download setDestination:[downloadPath stringByAppendingFormat:@"/%@", filename] allowOverwrite:NO];
}

- (void)download:(NSURLDownload *)download didCreateDestination:(NSString *)path
{
	NSString* key = [download description];
	NSString* downloadStamp = [downloads objectForKey:key];
	if(downloadStamp) {
		if(paths == nil)
			paths = [[NSMutableDictionary alloc] initWithCapacity:1];
		
		[paths setObject:path forKey:key];
		[[self connection] updateDownload:downloadStamp contentLength:nil fileName:path];
	}
}

// WebFrameLoad delegate
- (void)webView:(WebView *)sender didChangeLocationWithinPageForFrame:(WebFrame *)frame
{
	if([frame isEqual:[webView mainFrame]]) {
		WebDataSource* dataSource = [frame dataSource];
		NSURLRequest* request = [dataSource request];
		NSString* urlString = [[request URL] absoluteString];
		
		NSString* currentQuery = [query stringValue];
		if([currentQuery isEqualToString:urlString] == NO) {
			[query setStringValue:urlString];
		}
	}
}

- (void)webView:(WebView *)sender didStartProvisionalLoadForFrame:(WebFrame *)frame
{
	[(StainlessBrowser*)webView setIsReady:YES];
	
	if(gStatusBar == NO) {
		NSString* errorString = [NSString stringWithFormat:@"%@: ", NSLocalizedString(@"PageError", @"")];
		if([[status stringValue] hasPrefix:errorString])
			[statusLabel hideLabelNow];
		else
			[statusLabel hideLabelLater:0.5 fade:YES];
	}

	[status setStringValue:@""];

	if([frame isEqual:[webView mainFrame]]) {	
		NSString* urlString = [webView mainFrameURL];
		NSString* top = [urlString lastPathComponent];
		if([top hasPrefix:@"safari_StainlessImport.php?search="]) {
			NSRange r = [top rangeOfString:@"="];
			NSString* filter = [top substringFromIndex:r.location+1];
			
			NSString* bookmarksPath = [NSString stringWithFormat:@"%@/Library/Safari/Bookmarks.plist", NSHomeDirectory()];
			[(StainlessBrowser*)webView readSafariBookmarksFromPath:bookmarksPath filter:filter];
			
			return;
		}
	
		if(searchMode && [overlay parentWindow]) {
			searchIndex = 0;
			
			OverlayView* view = (OverlayView *)[overlay contentView];
			[view setHoles:nil];
			[view setSelection:NSZeroRect];
			
			[view setNeedsDisplay:YES];
		}

		[lastQuery release];
		lastQuery = [[NSString alloc] initWithString:[query stringValue]];
		
		NSImage* webImage = [NSImage imageNamed:@"Web"];
		
		StainlessTabView* activeTab = [bar activeTab];
		[activeTab startLoading];
		[activeTab setTabTitle:urlString];
		[activeTab setTabIcon:webImage fromServer:NO];
				
		[nextTitle release];
		nextTitle = nil;
		
		StainlessClient* client = [self client];
		[client setBusy:YES];
		[client copyIcon:webImage];
		[client copyUrl:urlString];
		[client copyTitle:urlString];
		
		[[self connection] updateClient:self];
	}
}

- (void)webView:(WebView *)sender didCommitLoadForFrame:(WebFrame *)frame
{
	if([frame isEqual:[webView mainFrame]]) {
		WebDataSource* dataSource = [frame dataSource];
		NSURLRequest* request = [dataSource request];
		NSString* urlString = [[request URL] absoluteString];

		NSString* currentQuery = [query stringValue];
		if([currentQuery isEqualToString:urlString] == NO) {
			if([urlString hasPrefix:@"http://www.stainlessapp.com/doc/about_"]) {
				NSString* top = [urlString substringWithRange:NSMakeRange(38, [urlString length] - 38)];
				NSRange r = [top rangeOfString:@".php"];
				NSString* about = [NSString stringWithFormat:@"about:%@", [top substringToIndex:r.location]];
				[query setStringValue:about];
			}
			else if([urlString hasSuffix:@"_StainlessImport.html"]) {
				NSString* top = [urlString lastPathComponent];
				NSRange r = [top rangeOfString:@"_"];
				NSString* about = [NSString stringWithFormat:@"bookmarks:%@", [top substringToIndex:r.location]];
				[query setStringValue:about];
			}
			else if([urlString length] && [lastQuery isEqualToString:[query stringValue]]) {
				//if([urlString hasSuffix:@"/"] && [[urlString substringToIndex:[urlString length] - 1] isEqualToString:currentQuery])
				//	;
				//else
				[query setStringValue:urlString];
			}
		}

		StainlessTabView* activeTab = [bar activeTab];
		[activeTab setTabURL:urlString];
		
		StainlessClient* client = [self client];
		[client copyUrl:urlString];
		
		[self updateClientIfHidden];
	}
}

- (void)webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame
{
	if([frame isEqual:[webView mainFrame]]) {
		WebDataSource* dataSource = [frame dataSource];
		NSURLRequest* request = [dataSource request];
		NSString* urlString = [[request URL] absoluteString];

		if(nextTitle == nil)
			[self webView:webView didReceiveTitle:[urlString lastPathComponent] forFrame:[webView mainFrame]];
			
		if(gPrivateMode == NO)
			[[self connection] addURLToHistory:urlString title:nextTitle];

		if(gStatusBar == NO)
			[statusLabel hideLabelNow];

		WebFrame* mainFrame = [webView mainFrame];
		WebFrameView* mainFrameView = [mainFrame frameView];
		NSView* documentView = [mainFrameView documentView];
				
		[documentView setPostsFrameChangedNotifications:YES];
		[[NSNotificationCenter defaultCenter] removeObserver:self name:NSViewFrameDidChangeNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(documentViewChanged:) name:NSViewFrameDidChangeNotification object:documentView];
				
		StainlessTabView* activeTab = [bar activeTab];
		[activeTab stopLoading];

		StainlessClient* client = [self client];
		[client setBusy:NO];

		[[self connection] updateClient:self];
		
		if(searchMode)
			[self search:self];

	}
}

- (void)webView:(WebView *)sender didFailProvisionalLoadWithError:(NSError *)error forFrame:(WebFrame *)frame
{
	if([frame isEqual:[webView mainFrame]]) {
		if([[error domain] isEqualToString:NSURLErrorDomain] && [error code] <= NSURLErrorServerCertificateHasBadDate && [error code] >= NSURLErrorServerCertificateNotYetValid) {
			NSURL* failingURL = [[error userInfo] objectForKey:@"NSErrorFailingURLKey"];
			NSArray* badCerts = [[error userInfo]  objectForKey:@"NSErrorPeerCertificateChainKey"];
			
			SecPolicySearchRef policySearch;
			
			if(SecPolicySearchCreate(CSSM_CERT_X_509v3, &CSSMOID_APPLE_TP_SSL, NULL, &policySearch) == noErr) {
				SecPolicyRef policy;
				while(SecPolicySearchCopyNext(policySearch, &policy) == noErr) {
					
					SecTrustRef trust;
					if(SecTrustCreateWithCertificates((CFArrayRef)badCerts, policy, &trust) == noErr) {
						SFCertificateTrustPanel* panel = [[SFCertificateTrustPanel alloc] init];
						
						WebDataSource* dataSource = [frame provisionalDataSource];
						self.securityRequest = [dataSource request];
						self.securityHost = [failingURL host];
						self.securityError = [NSString stringWithFormat:@"%@: %@", NSLocalizedString(@"PageError", @""), [error localizedDescription]];
						
						[panel setDefaultButtonTitle:NSLocalizedString(@"Continue", @"")];
						[panel setAlternateButtonTitle:NSLocalizedString(@"Cancel", @"")];		
						[panel setInformativeText:NSLocalizedString(@"ServerCertificateErrorMessage", @"")];
						[panel setShowsHelp:YES];
						
						NSString* title = [NSString stringWithFormat:NSLocalizedString(@"ServerCertificateErrorTitle", @""), [failingURL host]];
						[panel beginSheetForWindow:[self window] modalDelegate:self didEndSelector:@selector(createPanelDidEnd:returnCode:contextInfo:) contextInfo:nil trust:trust message:title];

						CFRelease(trust);
					}
					
					CFRelease(policy);
				}
				
				CFRelease(policySearch);
			}
		}
		else if([[error domain] isEqualToString:WebKitErrorDomain] && [error code] == WebKitErrorFrameLoadInterruptedByPolicyChange)
			;
		else if([[error domain] isEqualToString:WebKitErrorDomain] && [error code] == 204)
			;
		else {
			NSString* errorString = [NSString stringWithFormat:@"%@: %@", NSLocalizedString(@"PageError", @""), [error localizedDescription]];
			[status setStringValue:errorString];

			if([error code] != NSURLErrorCancelled && gStatusBar == NO)
				[self updateStatus:errorString reset:YES];
		}
		
		StainlessTabView* activeTab = [bar activeTab];
		[activeTab stopLoading];

		StainlessClient* client = [self client];
		[client setBusy:NO];
		
		[[self connection] updateClient:self];
	}
}

- (void)webView:(WebView *)sender didFailLoadWithError:(NSError *)error forFrame:(WebFrame *)frame
{
	if([frame isEqual:[webView mainFrame]]) {
		if([[error domain] isEqualToString:WebKitErrorDomain] && [error code] == WebKitErrorFrameLoadInterruptedByPolicyChange)
			;
		else if([[error domain] isEqualToString:WebKitErrorDomain] && [error code] == 204)
			;
		else {
			NSString* errorString = [NSString stringWithFormat:@"%@: %@", NSLocalizedString(@"PageError", @""), [error localizedDescription]];
			[status setStringValue:errorString];
			
			if([error code] != NSURLErrorCancelled && gStatusBar == NO)
				[self updateStatus:errorString reset:YES];
		}
		
		StainlessTabView* activeTab = [bar activeTab];
		[activeTab stopLoading];
		
		StainlessClient* client = [self client];
		[client setBusy:NO];
		
		[[self connection] updateClient:self];
	}
}

- (void)webView:(WebView *)sender didReceiveTitle:(NSString *)title forFrame:(WebFrame *)frame
{
	if([frame isEqual:[webView mainFrame]]) {
		nextTitle = [[NSString alloc] initWithString:title];
		
		WebDataSource* dataSource = [frame dataSource];
		NSURLRequest* request = [dataSource request];
		NSString* urlString = [[request URL] absoluteString];
		[pageTitles setObject:nextTitle forKey:urlString];

		StainlessTabView* activeTab = [bar activeTab];
		[activeTab setTabTitle:title];
		
		[[self window] setTitle:title];
		
		StainlessClient* client = [self client];
		[client copyTitle:title];

		[self updateClientIfHidden];
	}	
}

- (void)webView:(WebView *)sender didReceiveIcon:(NSImage *)image forFrame:(WebFrame *)frame
{
	if([frame isEqual:[webView mainFrame]]) {
		StainlessTabView* activeTab = [bar activeTab];
		[activeTab setTabIcon:image fromServer:NO];
		
		StainlessClient* client = [self client];
		[client copyIcon:image];
		
		[self updateClientIfHidden];
	}	
}

// WebPolicy delegate
- (void)webView:(WebView *)sender decidePolicyForMIMEType:(NSString *)type request:(NSURLRequest *)request frame:(WebFrame *)frame decisionListener:(id < WebPolicyDecisionListener >)listener
{	
    if([[request URL] isFileURL]) {
        BOOL isDirectory = NO;
        BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:[[request URL] path] isDirectory:&isDirectory];
		
        if(exists && !isDirectory && [WebView canShowMIMEType:type])
            [listener use];
        else
            [listener ignore];
		
		return;
    }
	else if([WebView canShowMIMEType:type]) {
		NSURLResponse* response = [[frame provisionalDataSource] response];
		
		BOOL hasAttachment = NO;
		
		if([response respondsToSelector:@selector(allHeaderFields)]) {
			NSDictionary* headerFields = [(id)response allHeaderFields];
			
			NSString* disposition = [[headerFields objectForKey:@"Content-Disposition"] lowercaseString];
			if(disposition) {
				NSRange checkRange = [disposition rangeOfString:@"attachment"];
				if(checkRange.location != NSNotFound)
					hasAttachment = YES;
			}
		}
				
		if(hasAttachment == NO) {
			[listener use];
			return;
		}
	}

	//NSString* urlString = [[request URL] absoluteString];
	//[self performSelectorOnMainThread:@selector(downloadURLString:) withObject:urlString waitUntilDone:NO];

	//[listener ignore];
	[listener download];
}

- (BOOL)_canHandleRequest:(NSURLRequest *)request forMainFrame:(BOOL)forMainFrame
{
	if(webViewCanCheckRequests)
		return [WebView _canHandleRequest:request forMainFrame:forMainFrame];
	
	if(forMainFrame) {
		NSString* scheme = [[request URL] scheme];
		if([scheme isEqualToString:@"http"] == NO && [scheme isEqualToString:@"https"] == NO)
			return NO;
	}
	
	return YES;
}

- (void)webView:(WebView *)sender decidePolicyForNavigationAction:(NSDictionary *)actionInformation request:(NSURLRequest *)request frame:(WebFrame *)frame decisionListener:(id < WebPolicyDecisionListener >)listener
{
	if(actionInformation) {
		int navigationType = [[actionInformation objectForKey:WebActionNavigationTypeKey] intValue]; 
		BOOL formSubmitted = (navigationType == WebNavigationTypeFormSubmitted ? YES : NO);
		BOOL linkClicked = (navigationType == WebNavigationTypeLinkClicked ? YES : NO);
		BOOL middleButtonDown = ([(StainlessApplication*)NSApp lastMouseDown] == NSOtherMouseDown ? YES : NO);
		NSNumber* modifier = [actionInformation objectForKey:WebActionModifierFlagsKey];
						
		if((formSubmitted || linkClicked) && (middleButtonDown || ([modifier unsignedIntValue] & NSCommandKeyMask))) {
			NSString* urlString = [[request URL] absoluteString];
			if(urlString) {
				if([modifier unsignedIntValue] & NSShiftKeyMask)
					[[self connection] setSpawnAndFocus:YES];

				if([modifier unsignedIntValue] & NSAlternateKeyMask)
					[[self connection] setSpawnWindow:YES];

				[self openURLString:urlString];
			}

			[listener ignore];
			return;
		}
		else if(linkClicked && ([modifier unsignedIntValue] & NSAlternateKeyMask)) {
			//NSString* urlString = [[request URL] absoluteString];
			//[self performSelectorOnMainThread:@selector(downloadURLString:) withObject:urlString waitUntilDone:NO];
			
			[listener download];
			return;
		}
	}
	
	BOOL forMainFrame = [frame isEqualTo:[webView mainFrame]];
	
	if(forMainFrame) {
		if([[request URL] isFileURL]) {
			[listener use];
			return;
		}
		
		NSString* scheme = [[request URL] scheme];
		if([scheme isEqualToString:@"http"] == NO && [scheme isEqualToString:@"https"] == NO) {
			LSOpenCFURLRef((CFURLRef)[request URL], NULL);
			[listener ignore];
			return;
		}
	}
	
    if([self _canHandleRequest:request forMainFrame:forMainFrame]) {
		NSString* ext = [[[request URL] path] pathExtension];
		if(ext && 
		   ([ext isEqualToString:@"bin"] ||
			[ext isEqualToString:@"bz2"] ||
			[ext isEqualToString:@"dmg"] ||
			//[ext isEqualToString:@"exe"] ||
			[ext isEqualToString:@"gz"] ||
			[ext isEqualToString:@"sit"] ||
			[ext isEqualToString:@"sitx"] ||
			[ext isEqualToString:@"tar"] ||
			[ext isEqualToString:@"tgz"] ||
			[ext isEqualToString:@"z"] ||
			[ext isEqualToString:@"Z"] ||
			[ext isEqualToString:@"zip"])
		)
			[listener download];
		else
			[listener use];
	}
	else {
        if(![[request URL] isFileURL])
			LSOpenCFURLRef((CFURLRef)[request URL], NULL);
		
		[listener ignore];
	}
}

- (void)webView:(WebView *)sender decidePolicyForNewWindowAction:(NSDictionary *)actionInformation request:(NSURLRequest *)request newFrameName:(NSString *)frameName decisionListener:(id < WebPolicyDecisionListener >)listener
{	
	BOOL linkClicked = ([[actionInformation objectForKey:WebActionNavigationTypeKey] intValue] == WebNavigationTypeLinkClicked ? YES : NO);
	BOOL middleButtonDown = ([(StainlessApplication*)NSApp lastMouseDown] == NSOtherMouseDown ? YES : NO);
	NSNumber* modifier = [actionInformation objectForKey:WebActionModifierFlagsKey];
	
	if(linkClicked && (middleButtonDown || ([modifier unsignedIntValue] & NSCommandKeyMask))) {
		NSString* urlString = [[request URL] absoluteString];
		if(urlString) {
			if([modifier unsignedIntValue] & NSShiftKeyMask)
				[[self connection] setSpawnAndFocus:YES];

			if([modifier unsignedIntValue] & NSAlternateKeyMask)
				[[self connection] setSpawnWindow:YES];
			
			[self openURLString:urlString];
		}
		
		[listener ignore];
	}
	else if(linkClicked && ([modifier unsignedIntValue] & NSAlternateKeyMask)) {
		//NSString* urlString = [[request URL] absoluteString];
		//[self performSelectorOnMainThread:@selector(downloadURLString:) withObject:urlString waitUntilDone:NO];
		
		[listener download];
	}	
	else {
		NSString* urlString = [[request URL] absoluteString];
		if(urlString && [urlString hasPrefix:@"mailto:"]) {
			LSOpenCFURLRef((CFURLRef)[NSURL URLWithString:urlString], NULL);
			[listener ignore];
		}
		else
			[listener use];
	}
}

// WebUI delegate
- (BOOL)webView:(WebView *)sender shouldPerformAction:(SEL)action fromSender:(id)fromObject
{
	if(action == @selector(selectAll:))
		return NO;
	
	return YES;
}

- (void)webView:(WebView *)sender frame:(WebFrame *)frame exceededDatabaseQuotaForSecurityOrigin:(WebSecurityOrigin*)origin database:(NSString *)databaseIdentifier;
{
	// this is a private delegate method that we need to use to support database storage in HTML5
	// ref: WebChromeClient.mm (WebKit)
	
	const unsigned long long defaultQuota = 5 * 1024 * 1024; // 5 megabytes should hopefully be enough to test storage support.
	[origin setQuota:defaultQuota];
}

- (void)webView:(WebView *)sender runJavaScriptAlertPanelWithMessage:(NSString *)message initiatedByFrame:(WebFrame *)frame
{
	NSAlert* alert = [NSAlert alertWithMessageText:NSLocalizedString(@"JavaScript", @"")
									 defaultButton:nil
								   alternateButton:nil
									   otherButton:nil
						 informativeTextWithFormat:message];
	
	NSImage* icon = [[[NSImage alloc] initWithSize:NSMakeSize(64.0, 64.0)] autorelease];
	[icon lockFocus];
	[[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationHigh];
	[[NSImage imageNamed:@"Stainless"] drawInRect:NSMakeRect(0.0, 0.0, 64.0, 64.0) fromRect:NSZeroRect operation:NSCompositeCopy fraction:1.0];
	[icon unlockFocus];
	[alert setIcon:icon];
	
	[alert setAlertStyle:NSInformationalAlertStyle];
	[alert runModal];
}

- (BOOL)webView:(WebView *)sender runJavaScriptConfirmPanelWithMessage:(NSString *)message initiatedByFrame:(WebFrame *)frame
{
	NSAlert* alert = [NSAlert alertWithMessageText:NSLocalizedString(@"JavaScript", @"")
									 defaultButton:NSLocalizedString(@"OK", @"")
								   alternateButton:NSLocalizedString(@"Cancel", @"")
									   otherButton:nil
						 informativeTextWithFormat:message];
	
	NSImage* icon = [[[NSImage alloc] initWithSize:NSMakeSize(64.0, 64.0)] autorelease];
	[icon lockFocus];
	[[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationHigh];
	[[NSImage imageNamed:@"Stainless"] drawInRect:NSMakeRect(0.0, 0.0, 64.0, 64.0) fromRect:NSZeroRect operation:NSCompositeCopy fraction:1.0];
	[icon unlockFocus];
	[alert setIcon:icon];
	
	[alert setAlertStyle:NSWarningAlertStyle];
	return ([alert runModal] == NSOKButton ? YES : NO);
}

- (void)webView:(WebView *)sender runOpenPanelForFileButtonWithResultListener:(id < WebOpenPanelResultListener >)resultListener
{
	NSOpenPanel* panel = [NSOpenPanel openPanel];
	
	[resultListener retain];
	[panel beginSheetForDirectory:nil file:nil types:nil modalForWindow:[self window] modalDelegate:self didEndSelector:@selector(openPanelDidEnd:returnCode:contextInfo:) contextInfo:resultListener];
}

- (void)webView:(WebView *)sender setStatusText:(NSString *)text
{
	[status setStringValue:[NSString stringWithString:text]];
}

- (NSString *)webViewStatusText:(WebView *)sender
{
	return [NSString stringWithString:[status stringValue]];
}

- (WebView *)webView:(WebView *)sender createWebViewWithRequest:(NSURLRequest *)request
{
	StainlessRemoteClient* remoteClient = [[StainlessRemoteClient alloc] initWithFrame:[[self window] frame]];
	
	extern UInt32 GetCurrentKeyModifiers();
	NSNumber* modifier = [NSNumber numberWithUnsignedInt:GetCurrentKeyModifiers()];
	
	if(([modifier unsignedIntValue] & cmdKey) && ([modifier unsignedIntValue] & optionKey))
		[[self connection] setSpawnWindow:YES];
	
	NSString* urlString = [[request URL] absoluteString];
	if(urlString)
		[remoteClient setUrlString:urlString];
	
	WebView* newWebView = [remoteClient webView];
	[newWebView setGroupName:identifier];
		
	return newWebView;
}

- (void)webViewClose:(WebView *)sender
{
	StainlessClient* client = [self client];
	if(client)
		[[self connection] closeClient:client];
}

- (void)webView:(WebView *)sender setFrame:(NSRect)frame
{
	StainlessClient* client = [self client];
	StainlessWindow* container = [[self connection] getWindowForClient:client];
	if(container && [container isMultiClient] == NO) {
		ignoreResize = YES;
		[[self window] setFrame:frame display:YES];
	}
}

- (void)webView:(WebView *)sender mouseDidMoveOverElement:(NSDictionary *)elementInformation modifierFlags:(NSUInteger)modifierFlags
{
	if(gAutoHideShowShelf && gIconShelf == NO) {
		NSPoint mouseLocation = [[self window] mouseLocationOutsideOfEventStream];
		if(mouseLocation.x <= 25.0) {
			[self toggleIconShelf:nil];
			autoShow = YES;
			
			return;
		}
	}
	
	NSString* node = [[elementInformation objectForKey:WebElementDOMNodeKey] description];
	if(node) {
		if(mouseNode && [mouseNode isEqualToString:node])
			return;
		
		self.mouseNode = node;
	}
	
	NSURL* url = [elementInformation objectForKey:WebElementLinkURLKey];
	if(url) {
		NSString* urlString = [url absoluteString];
		[status setStringValue:urlString];

		if(gStatusBar == NO)
			[self updateStatus:urlString reset:NO];
	}
	else {
		[status setStringValue:@""];
		
		if(gStatusBar == NO)
			[statusLabel hideLabelLater:0.5 fade:YES];
	}

	if(gAutoHideShowShelf && autoShow && autoHide == NO) {
		autoHide = YES;
		[NSTimer scheduledTimerWithTimeInterval:.75 target:self selector:@selector(_autoShow:) userInfo:nil repeats:NO];
	}
	else if(gAutoCloseGroups && autoClose == NO && [iconShelf child]) {
		autoClose = YES;
		[NSTimer scheduledTimerWithTimeInterval:1.5 target:self selector:@selector(_autoClose:) userInfo:nil repeats:NO];
	}
}

- (void)_autoClose:(NSTimer*)aTimer
{
	if(autoClose == YES) {
		NSPoint mouseLocation = [[self window] mouseLocationOutsideOfEventStream];
		
		if(gAutoCloseGroups) {
			NSView* contentView = [[self window] contentView];
			NSView* hitView = [contentView hitTest:mouseLocation];
			
			if([hitView isMemberOfClass:[StainlessShelfView class]] == NO && [hitView isMemberOfClass:[BookmarkView class]] == NO)
				[self collapseAllShelves:self];
		}
		
		autoClose = NO;
	}
	
	self.mouseNode = nil;
}

- (void)_autoShow:(NSTimer*)aTimer
{
	if(autoHide == YES) {
		NSPoint mouseLocation = [[self window] mouseLocationOutsideOfEventStream];
		
		if(gAutoCloseGroups)
			[self collapseAllShelves:self];

		float w = [iconShelf width];
		if(gIconEditor)
			w += [iconEditor frame].size.width;
		if(gAutoHideShowShelf && gIconShelf && mouseLocation.x > w) {
			[self toggleIconShelf:nil];
			autoShow = NO;
		}
		
		autoHide = NO;
	}
	
	self.mouseNode = nil;
}

- (NSArray *)webView:(WebView *)sender contextMenuItemsForElement:(NSDictionary *)element defaultMenuItems:(NSArray *)defaultMenuItems
{
	NSMutableArray* items = [NSMutableArray arrayWithCapacity:[defaultMenuItems count]];
	NSEnumerator* enumerator = [defaultMenuItems objectEnumerator];
	NSMenuItem* menu;
	NSMenuItem* newMenu;
	
	while((menu = [enumerator nextObject])) {
		switch([menu tag]) {
			case WebMenuItemTagSearchWeb:
			{
				NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
				NSDictionary* stainlessDefaults = [defaults persistentDomainForName:@"com.stainlessapp.Stainless"];
				NSString* engine = [stainlessDefaults objectForKey:@"DefaultSearch"];
				NSString* title = [NSString stringWithFormat:@"%@ %@", NSLocalizedString(@"SearchIn", @""), (engine ? engine :  NSLocalizedString(@"Google", @""))];
				
				WebFrame* mainFrame = [webView mainFrame];
				WebFrameView* mainFrameView = [mainFrame frameView];
				id documentView = [mainFrameView documentView];
				if([documentView respondsToSelector:@selector(selectedString)]) {
					NSMenuItem* newMenu = [[[NSMenuItem alloc] initWithTitle:title action:@selector(searchString:) keyEquivalent:@""] autorelease];
					[newMenu setTarget:self];
					[newMenu setRepresentedObject:[NSString stringWithString:[documentView selectedString]]];
					[items addObject:newMenu];
				}
				
				break;
			}
				
			case WebMenuItemTagOpenLinkInNewWindow:
			{
				NSURL* url = [element objectForKey:WebElementLinkURLKey];
				if(url == nil)
					break;
				
				newMenu = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"OpenNewTab", @"") action:@selector(openLinkInTab:) keyEquivalent:@""] autorelease];
				[newMenu setTarget:self];
				[newMenu setRepresentedObject:[NSString stringWithString:[url absoluteString]]];
				[items addObject:newMenu];
				
				newMenu = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"OpenNewWindow", @"") action:@selector(openLinkInWindow:) keyEquivalent:@""] autorelease];
				[newMenu setTarget:self];
				[newMenu setRepresentedObject:[NSString stringWithString:[url absoluteString]]];
				[items addObject:newMenu];
				
				if(gPrivateMode == NO) {
					newMenu = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"OpenDefault", @"") action:@selector(openLinkInDefaultBrowser:) keyEquivalent:@""] autorelease];
					[newMenu setTarget:self];

					[newMenu setRepresentedObject:[NSString stringWithString:[url absoluteString]]];

					[items addObject:newMenu];
				}
				
				break;
			}
				
			case WebMenuItemTagDownloadLinkToDisk:
			{
				NSURL* url = [element objectForKey:WebElementLinkURLKey];
				if(url == nil)
					break;

				[menu setTarget:self];
				[menu setAction:@selector(downloadLink:)];
				[menu setRepresentedObject:[NSString stringWithString:[url absoluteString]]];
				[items addObject:menu];
				break;
			}
				
			case WebMenuItemTagDownloadImageToDisk:
			{
				NSURL* url = [element objectForKey:WebElementImageURLKey];
				if(url == nil)
					break;
				
				[menu setTarget:self];
				[menu setAction:@selector(downloadLink:)];
				[menu setRepresentedObject:[NSString stringWithString:[url absoluteString]]];
				[items addObject:menu];
			
				break;
			}
				
			case WebMenuItemTagCopyImageToClipboard:
			{	
				[items addObject:menu];

				NSURL* url = [element objectForKey:WebElementImageURLKey];
				if(url == nil)
					break;
				
				NSMenuItem* newMenu = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"CopyImageLink", @"") action:@selector(copyLink:) keyEquivalent:@""] autorelease];
				[newMenu setTarget:self];
				[newMenu setRepresentedObject:[NSString stringWithString:[url absoluteString]]];
				[items addObject:newMenu];
				break;
			}
				
			case WebMenuItemTagOpenImageInNewWindow:
			case WebMenuItemTagOpenFrameInNewWindow:
				break;
				
			default:
				[items addObject:menu];
		}
	}
	
	return items;
}

- (void)searchString:(id)sender
{
	NSString* urlString = [sender representedObject];

	extern UInt32 GetCurrentKeyModifiers();
	NSNumber* modifier = [NSNumber numberWithUnsignedInt:GetCurrentKeyModifiers()];
	
	if(([modifier unsignedIntValue] & cmdKey)) {
		if(([modifier unsignedIntValue] & shiftKey))
			[[self connection] setSpawnAndFocus:YES];
		
		if(([modifier unsignedIntValue] & optionKey))
			[[self connection] setSpawnWindow:YES];

		[self openURLString:urlString];
	}	
	else {
		[query setStringValue:urlString];
		[(StainlessBrowser*)webView takeStringRequestFrom:query];
	}
}

- (void)openLinkInTab:(id)sender
{
	NSString* urlString = [sender representedObject];
	[self openURLString:urlString];
}

- (void)openLinkInWindow:(id)sender
{
	[[self connection] setSpawnWindow:YES];
	
	if(gPrivateMode)
		[[self connection] setSpawnPrivate:YES];
	
	if(gSingleSession)
		[[self connection] copySpawnSession:session];

	[[self connection] copySpawnGroup:group];

	NSString* urlString = [sender representedObject];	
	[[self connection] spawnClientWithURL:urlString inWindow:nil];
}

- (void)openLinkInDefaultBrowser:(id)sender
{
	NSString* urlString = [sender representedObject];
	
	LSOpenCFURLRef((CFURLRef)[NSURL URLWithString:urlString], NULL);
}

- (void)downloadLink:(id)sender
{
	NSString* urlString = [sender representedObject];
	NSURL* url = [NSURL URLWithString:urlString];
	[[[NSURLDownload alloc] initWithRequest:[NSURLRequest requestWithURL:url] delegate:self] autorelease];

	//[self downloadURLString:urlString];
}

- (void)copyLink:(id)sender
{
	NSString* urlString = [sender representedObject];
		
	NSPasteboard* pb = [NSPasteboard generalPasteboard];
	[pb declareTypes:[NSArray arrayWithObject:NSStringPboardType] owner:nil];
	[pb setString:urlString forType:NSStringPboardType];
}

@end

