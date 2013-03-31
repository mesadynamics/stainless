//
//  StainlessServer.m
//  Stainless
//
//  Created by Danny Espinoza on 9/3/08.
//  Copyright 2008 Mesa Dynamics, LLC. All rights reserved.
//

#import "StainlessServer.h"
#import "StainlessController.h"
#import "StainlessBridge.h"
#import "StainlessPanel.h"
#import "CGSInternal.h"
// ref: PasteboardMac.mm (WebKit)
NSString* WebURLPboardType = @"public.url";
NSString* WebURLNamePboardType = @"public.url-name";
//

extern SInt32 gOSVersion;

static
void processNotificationCallback(CGSNotificationType type, void* data, unsigned int dataLength, void* inUserData)
{	
	if(type == kCGSNotificationAppUnresponsive && dataLength >= sizeof(CGSProcessNotificationData)) {		
		CGSProcessNotificationData* processData = (CGSProcessNotificationData*) data;
		[(StainlessServer*)inUserData shutdownClientWithPid:processData->pid];
	}
}


@implementation StainlessServer

@synthesize ignoreHistory;
@synthesize searchString;
@synthesize searchToken;
@synthesize selectedTask;

@synthesize focus;
@synthesize forcePrivate;
@synthesize forceSingle;
@synthesize spawnWindow;
@synthesize spawnAndFocus;
@synthesize spawnPrivate;
@synthesize spawnGroup;
@synthesize spawnSession;
@synthesize spawnChild;
@synthesize spawnFrame;
@synthesize spawnCount;
@synthesize spawnIndex;

- (id)init
{
	if(self = [super init]) {
		//provisionalClients = nil;
		//provisionalWindows = nil;
		//provisionalLayers = nil;
		
		clientHistory = nil;
		
		clients = [[NSMutableDictionary alloc] init];
		windows = [[NSMutableDictionary alloc] init];
		layers = [[NSMutableArray alloc] init];
		hosts = nil;
		
		ignoreHistory = nil;
		historyList = nil;
		filteredHistoryList = nil;
		
		downloadInfo = nil;
		urlComplete = [[StainlessAutoComplete alloc] init];
		searchComplete = [[StainlessAutoComplete alloc] init];
		searchString = nil;
		searchToken = nil;
		selectedTask = nil;		
		focus = nil;
		
		hotSpare = nil;
		hotSpareCached = nil;
		hotSpareBusy = NO;
		
		forcePrivate = NO;
		forceSingle = NO;
		
		spawnWindow = NO;
		spawnAndFocus = NO;
		spawnPrivate = NO;
		spawnGroup = nil;
		spawnSession = nil;
		spawnChild = NO;
		spawnFrame = NSZeroRect;
		spawnCount = 0;
		spawnIndex = 0;
		
		focusFirst = NO;
		ignoreLayer = NO;
		
		defaultSpace = 0;
		CFDictionaryRef workspaceBindings = CFPreferencesCopyAppValue(CFSTR("workspaces-app-bindings"), CFSTR("com.apple.dock"));
		if(workspaceBindings) {
			NSNumber* stainlessSpace = [(NSDictionary*)workspaceBindings objectForKey:@"com.stainlessapp.stainless"];
			if(stainlessSpace)
				defaultSpace = [stainlessSpace intValue];
			
			CFRelease(workspaceBindings);
		}
	}
	
	return self;
}

- (void)dealloc
{
	[downloadInfo release];
	
	[filteredHistoryList release];
	[historyList release];
	
	[ignoreHistory release];
	[urlComplete release];
	[searchComplete release];
	[selectedTask release];
	
	[focus release];
	
	[clients release];
	[windows release];
	[layers release];
	[hosts release];
	
	[spawnGroup release];
	[spawnSession release];

	[clientHistory release];

	[super dealloc];
}

- (void)awakeFromNib
{
	CGSRegisterNotifyProc(&processNotificationCallback, kCGSNotificationAppUnresponsive, (void*)self);
		
	//[NSTimer scheduledTimerWithTimeInterval:60.0 target:self selector:@selector(saveCookies:) userInfo:nil repeats:YES];
	[NSTimer scheduledTimerWithTimeInterval:3.0 target:self selector:@selector(refreshTaskManager:) userInfo:nil repeats:YES];
	
	clientHistory = [[WebHistory alloc] init];

	NSFileManager* fm = [NSFileManager defaultManager];
	NSString* libraryPath = [NSString stringWithFormat:@"%@/Library/Preferences/Stainless", NSHomeDirectory()];
	if([fm fileExistsAtPath:libraryPath] == NO)
		[fm createDirectoryAtPath:libraryPath attributes:nil];
	
	NSString* historyPath = [NSString stringWithFormat:@"%@/History.plist", libraryPath];
	
	if([fm fileExistsAtPath:historyPath]) {
		NSError* error = nil;
		[clientHistory loadFromURL:[NSURL fileURLWithPath:historyPath] error:&error];
		
		if(error) {
			NSLog(@"Error reading history %@: %@", historyPath, error);
			[error release];
		}
		else {
			NSMutableArray* allHistory = [NSMutableArray array];
			NSArray* days = [clientHistory orderedLastVisitedDays];
			for(NSCalendarDate* day in days) {
				[allHistory addObjectsFromArray:[clientHistory orderedItemsLastVisitedOnDay:day]];
			}
			
			for(WebHistoryItem* item in allHistory) {
				[self addURLToAutoComplete:[item URLString] withItem:item];
			}
		}
	}
		
	[WebHistory setOptionalSharedHistory:clientHistory];
	
	[history setTarget:self];
	[history setDoubleAction:@selector(openHistoryItem:)];

	[downloads setTarget:self];
	[downloads setDoubleAction:@selector(openDownloadsItem:)];

	webHistoryCanRecordVisits = NO;
	webHistoryCanControlVisitCount = NO;
	
	WebHistoryItem* entry = [[WebHistoryItem alloc] initWithURLString:@"" title:@"" lastVisitedTimeInterval:[NSDate timeIntervalSinceReferenceDate]];
	if([entry respondsToSelector:@selector(_recordInitialVisit)]) {
		if([entry respondsToSelector:@selector(_visitedWithTitle:increaseVisitCount:)]) {
			webHistoryCanRecordVisits = YES;
			webHistoryCanControlVisitCount = YES;
		}
		else if([entry respondsToSelector:@selector(_visitedWithTitle:)])
			webHistoryCanRecordVisits = YES;
	}
	[entry release];
		
	[self refreshHistory];
}

- (IBAction)handleCloseTask:(id)sender
{
	if(selectedTask == nil)
		return;
	
	StainlessClient* client = [clients objectForKey:selectedTask];
	
	if(client == nil)
		return;
	
	[tasks deselectAll:self];
	
	NSMutableDictionary* processInfo = [NSMutableDictionary dictionaryWithCapacity:2];
	[processInfo setObject:[NSNumber numberWithLong:[client hiPSN]] forKey:@"highLongOfPSN"];
	[processInfo setObject:[NSNumber numberWithLong:[client loPSN]] forKey:@"lowLongOfPSN"];
	[NSThread detachNewThreadSelector:@selector(killProcess:) toTarget:self withObject:processInfo];
}

- (IBAction)handleHistoryAction:(id)sender
{
	int tag = [sender tag];
	
	int rowIndex = [history selectedRow];
	if(rowIndex ==  -1)
		rowIndex = [history clickedRow];
	
	if(rowIndex ==  -1)
		return;
	
	NSArray* list = (filteredHistoryList ? filteredHistoryList : historyList);

	switch(tag) {
		case historyOpen:
		case historyOpenTab:
		case historyOpenWindow:
		{
			[history deselectAll:self];
			[history selectRowIndexes:[NSIndexSet indexSetWithIndex:rowIndex] byExtendingSelection:NO];
			
			self.ignoreHistory = [[list objectAtIndex:rowIndex] URLString];
			
			if(tag != historyOpenWindow && focus) {
				NSString* container = [focus container];
				StainlessWindow* focusWindow = [windows objectForKey:container];
								
				if(tag == historyOpenTab)
					[self spawnClientWithURL:ignoreHistory inWindow:focusWindow];
				else
					[self redirectClient:focus toURL:ignoreHistory];
			}
			else
				[self spawnClientWithURL:ignoreHistory];
			
			break;
		}
			
		case historyCopy:
		{
			NSPasteboard* pboard = [NSPasteboard pasteboardWithName:NSGeneralPboard];

			if([history numberOfSelectedRows] == 1) {
				WebHistoryItem* item = [list objectAtIndex:rowIndex];
				NSString* urlString = [item URLString];
				if(urlString) {
					NSString* title = [item title];

					[pboard declareTypes:[NSArray arrayWithObjects:NSURLPboardType, WebURLPboardType, WebURLNamePboardType, NSStringPboardType, nil] owner:self];
					
					NSURL* url = [NSURL URLWithString:urlString];
					[url writeToPasteboard:pboard];
					[pboard setString:urlString forType:WebURLPboardType];
					if(title)
						[pboard setString:title forType:WebURLNamePboardType];
					[pboard setString:urlString forType:NSStringPboardType];
				}
			}
			else {
			}
			
			break;
		}
			
		case historyDelete:
		{
			NSIndexSet* selectedRowIndexes = [history selectedRowIndexes];
			NSMutableArray* removeHistory = [NSMutableArray arrayWithCapacity:[selectedRowIndexes count]];
			
			NSUInteger index = [selectedRowIndexes firstIndex];
			while(index != NSNotFound) {
				WebHistoryItem* item = [list objectAtIndex:index];
				[removeHistory addObject:item];
				
				index = [selectedRowIndexes indexGreaterThanIndex:index];
			}
			
			if([removeHistory count])
				[[WebHistory optionalSharedHistory] removeItems:removeHistory];
			
			[history deselectAll:self];
			[self refreshHistoryList:self];
			
			break;
		}
	}
}

- (IBAction)handleDownloadAction:(id)sender
{
	if(downloadInfo == nil)
		return;

	int tag = [sender tag];
	
	if(tag == downloadDeleteAll) {
		NSMutableArray* clear = [NSMutableArray arrayWithCapacity:[downloadInfo count]];
		for(NSString* key in [downloadInfo allKeys]) {
			NSMutableDictionary* info = [downloadInfo objectForKey:key];
			if([info objectForKey:@"Fail"])
				[clear addObject:key];
		}
		
		for(NSString* key in [clear reverseObjectEnumerator]) {
			[downloadInfo removeObjectForKey:key];
		}
		
		[clearDownloads setEnabled:NO];
		[downloads reloadData];

		return;
	}
	
	
	int rowIndex = [downloads selectedRow];
	if(rowIndex ==  -1)
		rowIndex = [downloads clickedRow];
	
	if(rowIndex ==  -1)
		return;
		
	NSArray* list = [[downloadInfo allValues] sortedArrayUsingSelector:@selector(indexKeyCompare:)];
	NSMutableDictionary* info = [list objectAtIndex:rowIndex];

	switch(tag) {
		case downloadOpen:
		{
			if([info objectForKey:@"Icon"]) {
				NSString* fileName = [info objectForKey:@"FileName"];
				if(fileName) {
					[[NSWorkspace sharedWorkspace] openFile:fileName];
				}
			}
			
			break;
		}
			
		case downloadReveal:
		{
			if([info objectForKey:@"Icon"]) {
				NSString* fileName = [info objectForKey:@"FileName"];
				if(fileName) {
					[[NSWorkspace sharedWorkspace] selectFile:fileName inFileViewerRootedAtPath:nil];
				}
			}
			
			break;
		}

		case downloadCopy:
		{
			NSPasteboard* pboard = [NSPasteboard pasteboardWithName:NSGeneralPboard];
			
			if([downloads numberOfSelectedRows] == 1) {
				NSString* urlString = [info objectForKey:@"URL"];
				if(urlString) {
					NSString* fileName = [info objectForKey:@"FileName"];
					NSString* title = [fileName lastPathComponent];
					
					[pboard declareTypes:[NSArray arrayWithObjects:NSURLPboardType, WebURLPboardType, WebURLNamePboardType, NSStringPboardType, nil] owner:self];
					
					NSURL* url = [NSURL URLWithString:urlString];
					[url writeToPasteboard:pboard];
					[pboard setString:urlString forType:WebURLPboardType];
					if(title)
						[pboard setString:title forType:WebURLNamePboardType];
					[pboard setString:urlString forType:NSStringPboardType];
				}
			}
			else {
			}
			
			break;
		}
		
		case downloadDelete:
		{
			NSIndexSet* selectedRowIndexes = [downloads selectedRowIndexes];
			NSMutableArray* clear = [NSMutableArray arrayWithCapacity:[selectedRowIndexes count]];
			
			NSUInteger index = [selectedRowIndexes firstIndex];
			while(index != NSNotFound) {
				info = [list objectAtIndex:index];
				
				if([info objectForKey:@"Fail"]) {
					NSString* key = [[downloadInfo allKeysForObject:info] objectAtIndex:0];
					[clear addObject:key];
				}
				
				index = [selectedRowIndexes indexGreaterThanIndex:index];
			}
			
			for(NSString* key in [clear reverseObjectEnumerator]) {
				[downloadInfo removeObjectForKey:key];
			}
			
			[downloads deselectAll:self];
			[downloads reloadData];

			[clearDownloads setEnabled:[self hasDownloads]];

			break;
		}
			
		case downloadStop:
		{
			NSString* downloadStamp = nil;
			for(NSString* key in [downloadInfo allKeys]) {
				NSMutableDictionary* keyInfo = [downloadInfo objectForKey:key];
				if([info isEqualToDictionary:keyInfo]) {
					downloadStamp = key;
					break;
				}
			}
			
			if(downloadStamp) {
				NSNumber* fail = [info objectForKey:@"Fail"];
				if([fail boolValue] == NO) {
					[info setObject:NSLocalizedString(@"Stop", @"") forKey:@"Status"];
					[info setObject:[NSNumber numberWithBool:YES] forKey:@"Fail"];		
					
					NSEnumerator* enumerator = [[clients allValues] objectEnumerator];
					for(StainlessClient* notifyClient in enumerator)
						[[notifyClient connection] cancelDownloadForClient:downloadStamp];
				}
			}
			break;
		}
	}
}

- (void)createNewTab:(NSString*)urlString
{
	StainlessWindow* focusWindow = nil;
	
	if(focus) {
		NSString* container = [focus container];
		focusWindow = [windows objectForKey:container];
	}
	
	[self spawnClientWithURL:urlString inWindow:focusWindow];
}

- (void)createNewTab
{
	[self createNewTab:nil];
}

- (void)refreshTaskManager:(NSTimer*)timer
{	
	if(timer == nil || [[tasks window] isVisible])
		[tasks reloadData];
	
	if(timer && [[downloads window] isVisible]) {
		[self purgeDownloads];
	}
}

- (void)refreshHistory
{
	[self refreshHistoryDays];
	[self refreshHistoryList:nil];	
}

- (void)refreshHistoryDays
{	
	NSCalendarDate* today = [NSCalendarDate calendarDate];
	NSCalendarDate* firstDay = (NSCalendarDate*) [[historyDate itemAtIndex:0] representedObject];
	if(firstDay == nil || [firstDay isEqualToDate:today] == NO) {
		NSCalendarDate* selectedDay = nil;
		if(firstDay)
			selectedDay = (NSCalendarDate*) [[[historyDate selectedItem] representedObject] retain];
		
		[historyDate removeAllItems];

		NSMenuItem* todayItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Today", @"") action:@selector(refreshHistoryList:) keyEquivalent:@"0"];
		[todayItem setTarget:self];
		[todayItem setRepresentedObject:today];
		[todayItem setEnabled:YES];
		[[historyDate menu] addItem:todayItem];
		[todayItem release];
		
		int index = 1;
		NSArray* days = [[WebHistory optionalSharedHistory] orderedLastVisitedDays];
		for(NSCalendarDate* day in days) {
			NSInteger elapsedDays;
			[day years:nil months:nil days:&elapsedDays hours:nil minutes:nil seconds:nil sinceDate:today];
			
			if(elapsedDays == 0)
				continue;
			
			NSString* dayDescription = nil;
			if(elapsedDays == -1)
				dayDescription = NSLocalizedString(@"Yesterday", @"");
			else
				dayDescription = [NSString stringWithFormat:@"%d %@", -elapsedDays, NSLocalizedString(@"DaysAgo", @"")];
				
			NSString* key = @"";
			if(index < 10)
				key = [NSString stringWithFormat:@"%d", index++];
			
			NSMenuItem* dayItem = [[NSMenuItem alloc] initWithTitle:dayDescription action:@selector(refreshHistoryList:) keyEquivalent:key];
			[dayItem setTarget:self];
			[dayItem setRepresentedObject:day];
			[dayItem setEnabled:YES];
			[[historyDate menu] addItem:dayItem];
			[dayItem release];
			
			if(selectedDay && [day isEqualToDate:selectedDay])
				[historyDate selectItem:dayItem];
		}
		
		if(index > 1) {
			[[historyDate menu] addItem:[NSMenuItem separatorItem]];

			NSMenuItem* allItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"AllDays", @"") action:@selector(refreshHistoryList:) keyEquivalent:@"="];
			[allItem setTag:-1];
			[allItem setTarget:self];
			[allItem setRepresentedObject:nil];
			[allItem setEnabled:YES];
			[[historyDate menu] addItem:allItem];
			[allItem release];
		}
		
		if(selectedDay)
			[selectedDay release];
	}
}

- (IBAction)refreshHistoryList:(id)sender
{
	NSMenuItem* item = (NSMenuItem*) [historyDate selectedItem];
	if([item tag] == -1) {
		NSMutableArray* allHistory = [[NSMutableArray alloc] init];
		NSArray* days = [[WebHistory optionalSharedHistory] orderedLastVisitedDays];
		for(NSCalendarDate* day in days) {
			[allHistory addObjectsFromArray:[[WebHistory optionalSharedHistory] orderedItemsLastVisitedOnDay:day]];
		}
		
		[historyList release];
		historyList = allHistory;
	}
	else {
		NSCalendarDate* day = (NSCalendarDate*) [item representedObject];
		
		if(day == nil)
			day = [NSCalendarDate calendarDate];
			
		[historyList release];
		historyList = [[NSArray alloc] initWithArray:[[WebHistory optionalSharedHistory] orderedItemsLastVisitedOnDay:day]];
	}
	
	[self filterHistoryList:self];
	
	if(sender == nil || [[history window] isVisible]) {
		[history reloadData];
		
		if(sender != nil && [item tag] != -1)
			[self refreshHistoryDays];
	}
}

- (IBAction)filterHistoryList:(id)sender
{
	[filteredHistoryList release];
	filteredHistoryList = nil;
	
	NSString* filter = [historySearch stringValue];
	if([historyList count] && [filter length]) {
		filteredHistoryList = [[NSMutableArray alloc] initWithCapacity:[historyList count]];
		
		for(WebHistoryItem* item in historyList) {
			NSRange r = [[item title] rangeOfString:filter options:NSCaseInsensitiveSearch];
			if(r.location != NSNotFound)
				[filteredHistoryList addObject:item];
			else {
				r = [[item URLString] rangeOfString:filter options:NSCaseInsensitiveSearch];
				if(r.location != NSNotFound)
					[filteredHistoryList addObject:item];
			}
		}
	}
	
	[history reloadData];
}

- (void)saveCookies:(NSTimer*)timer
{
	NSFileManager* fm = [NSFileManager defaultManager];
	NSString* libraryPath = [NSString stringWithFormat:@"%@/Library/Preferences/Stainless", NSHomeDirectory()];
	if([fm fileExistsAtPath:libraryPath] == NO)
		[fm createDirectoryAtPath:libraryPath attributes:nil];
	
	NSString* cookiePath = [NSString stringWithFormat:@"%@/Cookies.plist", libraryPath];
	[[StainlessCookieJar sharedCookieJar] writeCookiesToPath:cookiePath purge:NO];
}

- (void)saveFocusWindow
{
	StainlessWindow* focusWindow = nil;
	NSString* windowIdentifier = nil;
	
	if(focus) {
		if([focus isChild])
			return;
		
		windowIdentifier = [focus container];
		
		if(windowIdentifier)
			focusWindow = [windows objectForKey:windowIdentifier];
	}
	
	if(focusWindow == nil)
		return;
	
	StainlessWindow* window = [windows objectForKey:windowIdentifier];
	
	if(window == nil)
		return;
	
	NSRect windowFrame = [[window frame] rectValue];
	
	NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
	[defaults setObject:[NSNumber numberWithFloat:windowFrame.origin.x] forKey:@"WindowOriginX"];
	[defaults setObject:[NSNumber numberWithFloat:windowFrame.origin.y] forKey:@"WindowOriginY"];
	[defaults setObject:[NSNumber numberWithFloat:windowFrame.size.width] forKey:@"WindowSizeWidth"];
	[defaults setObject:[NSNumber numberWithFloat:windowFrame.size.height] forKey:@"WindowSizeHeight"];
}

- (void)saveSessions:(BOOL)persist
{
	NSFileManager* fm = [NSFileManager defaultManager];
	NSString* libraryPath = [NSString stringWithFormat:@"%@/Library/Preferences/Stainless", NSHomeDirectory()];
	if([fm fileExistsAtPath:libraryPath] == NO)
		[fm createDirectoryAtPath:libraryPath attributes:nil];
	
	NSString* path = [NSString stringWithFormat:@"%@/Sessions", libraryPath];

	if([fm fileExistsAtPath:path])
		[fm removeItemAtPath:path error:nil];

	if(persist == NO)
		return;
	
	NSMutableArray* allWindows = [NSMutableArray arrayWithCapacity:[layers count]];
	
	for(StainlessWindow* window in layers) {
		if([window privateMode] == NO)
			[allWindows addObject:window];
	}
	
	if([allWindows count] == 0)
		return;
	
	@try {
		[NSArchiver archiveRootObject:allWindows toFile:path];
	}
	
	@catch (NSException* anException) {
		NSLog(@"%@ exception writing %@: %@", [anException name], path, [anException reason]);
	}
}

- (BOOL)restoreSessions
{
	NSFileManager* fm = [NSFileManager defaultManager];
	NSString* libraryPath = [NSString stringWithFormat:@"%@/Library/Preferences/Stainless", NSHomeDirectory()];
	NSString* path = [NSString stringWithFormat:@"%@/Sessions", libraryPath];
	
	if([fm fileExistsAtPath:path] == NO)
		return NO;

	NSMutableArray* allWindows = nil;
	
	@try {
		allWindows = (NSMutableArray*) [NSUnarchiver unarchiveObjectWithFile:path];
	}
	
	@catch (NSException* anException) {
		NSLog(@"%@ exception reading %@: %@", [anException name], path, [anException reason]);
	}
	
	if(allWindows) {
		for(StainlessWindow* window in allWindows) {
			[windows setObject:window forKey:[NSString stringWithString:[window identifier]]];
			[layers addObject:window];
			
			for(StainlessClient* client in [window clients]) {
				[clients setObject:client forKey:[NSString stringWithString:[client identifier]]];
			}
		}
		
		focusFirst = YES;
		
		NSString* clientKey = nil;
		NSString* clientIdentifier = nil;
		
		for(StainlessWindow* window in layers) {
			StainlessClient* client = [window focus];
			if(client) {
				clientIdentifier = [client identifier];
				clientKey = [NSString stringWithFormat:@"%X", [clientIdentifier globalHash]];
				
				[self launchClientWithIdentifier:clientIdentifier andKey:clientKey];
			}
		}
		
		for(StainlessWindow* window in layers) {
			for(StainlessClient* client in [window clients]) {
				if([client isEqualTo:[window focus]] == NO) {
					clientIdentifier = [client identifier];
					clientKey = [NSString stringWithFormat:@"%X", [clientIdentifier globalHash]];
					
					[self launchClientWithIdentifier:clientIdentifier andKey:clientKey];
				}
			}
		}
		
		return YES;
	}
	
	return NO;
}

- (void)computeSearchString
{
	NSString* urlString = @"http://www.google.com/search?";
	NSString* urlToken = @"q=";
	
	NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
	NSString* engine = [defaults objectForKey:@"DefaultSearch"];
	if(engine) {
		NSString* search = [NSString stringWithString:engine];
		if([search isEqualToString:@"Yahoo!"]) {
			urlString = @"http://search.yahoo.com/search?";			
			urlToken = @"p=";
		}
		else if([search isEqualToString:@"Live Search"] || [search isEqualToString:@"Bing"])
			urlString = @"http://www.bing.com/search?";				
		else if([search isEqualToString:@"AOL"]) {
			urlString = @"http://search.aol.com/aol/search?";
			urlToken = @"query=";
		}
		else if([search isEqualToString:@"Ask"])
			urlString = @"http://www.ask.com/web?";
	}

	self.searchString = urlString;
	self.searchToken = urlToken;
}

- (void)addURLToAutoComplete:(NSString*)urlString withItem:(WebHistoryItem*)item
{
	if(searchString == nil)
		[self computeSearchString];
	
	NSString* alternateTitle = [item alternateTitle];
	if(alternateTitle == nil) {
		if([urlString hasPrefix:searchString]) {
			NSRange r = [urlString rangeOfString:searchToken];
			if(r.location != NSNotFound) {
				r.location += [searchToken length];
				
				NSUInteger len = [urlString length];
				NSRange r2 = [urlString rangeOfString:@"&" options:0 range:NSMakeRange(r.location, len - r.location)];
				if(r2.location == NSNotFound)
					r2.location = len;
				
				NSString* query = [urlString substringWithRange:NSMakeRange(r.location, r2.location - r.location)];
				NSMutableString* mutableQuery = [[query mutableCopy] autorelease];
				[mutableQuery replaceOccurrencesOfString:@"+" withString:@" " options:0 range:NSMakeRange(0, [mutableQuery length])];

				CFStringRef escaped = CFURLCreateStringByReplacingPercentEscapesUsingEncoding(NULL, (CFStringRef)mutableQuery, CFSTR(""), kCFStringEncodingUTF8);
				if(CFStringGetLength(escaped) > 3) {
					alternateTitle = [NSString stringWithString:(NSString*)escaped];
					[item setAlternateTitle:alternateTitle];
				}
				CFRelease(escaped);
			}
		}
	}
	
	if(alternateTitle) {
		[searchComplete swap];
		
		NSMutableString* mutableAlternateTitle = [[alternateTitle mutableCopy] autorelease];
		[mutableAlternateTitle replaceOccurrencesOfString:@"\"" withString:@" " options:0 range:NSMakeRange(0, [mutableAlternateTitle length])];

		NSArray* components = [mutableAlternateTitle componentsSeparatedByString:@" "];
		BOOL skip = YES;
		for(NSString* s in components) {
			if(skip) {
				skip = NO;
				continue;
			}
			
			if([s length] > 3)
				[searchComplete addString:s withObject:item];
		}
		[searchComplete addString:alternateTitle withObject:item];
		[searchComplete swap];
		
		return;
	}
	
	if([urlString hasPrefix:@"http://"] || [urlString hasPrefix:@"file://"] || [urlString hasPrefix:@"feed://"])
		urlString = [urlString substringFromIndex:7];
	else if([urlString hasPrefix:@"https://"])
		urlString = [urlString substringFromIndex:8];
	
	NSRange r = [urlString rangeOfString:@"/"];
	if(r.location != NSNotFound) {
		NSString* domain = [urlString substringToIndex:r.location];
		r = [domain rangeOfString:@"."];
		if (r.location != NSNotFound) {
			NSString* suffix = [domain substringFromIndex:r.location + 1];
			if([suffix length] > 3)
				[urlComplete addString:[urlString substringFromIndex:r.location+1] withObject:item];
		}
	}
	
	
	NSString* userQuery = nil;
	r = [urlString rangeOfString:@"?q="];
	if(r.location == NSNotFound)
		r = [urlString rangeOfString:@"&q="];
	
	if(r.location != NSNotFound) {
		r.location += 3;
		
		NSUInteger len = [urlString length];
		NSRange r2 = [urlString rangeOfString:@"&" options:0 range:NSMakeRange(r.location, len - r.location)];
		if(r2.location == NSNotFound)
			r2.location = len;
		
		NSString* query = [urlString substringWithRange:NSMakeRange(r.location, r2.location - r.location)];
		NSMutableString* mutableQuery = [[query mutableCopy] autorelease];
		[mutableQuery replaceOccurrencesOfString:@"+" withString:@" " options:0 range:NSMakeRange(0, [mutableQuery length])];
		
		CFStringRef escaped = CFURLCreateStringByReplacingPercentEscapesUsingEncoding(NULL, (CFStringRef)mutableQuery, CFSTR(""), kCFStringEncodingUTF8);
		if(CFStringGetLength(escaped) > 3) {
			userQuery = [NSString stringWithString:(NSString*)escaped];
		}
		CFRelease(escaped);
	}
	
	if(userQuery) {
		[urlComplete addString:userQuery withObject:item];
	}
	else {
		NSArray* components = [urlString componentsSeparatedByString:@"/"];
		BOOL skip = YES;
		for(NSString* s in components) {
			if(skip) {
				skip = NO;
				continue;
			}
			
			if([s length] > 3)
				[urlComplete addString:s withObject:item];
		}
	}
	
	[urlComplete addString:urlString withObject:item];
}

- (void)launchHotSpareWithIdentifier:(NSString*)clientIdentifier
{
	if([self launchClientWithIdentifier:clientIdentifier andKey:@"hotspare"]) {
		@synchronized(hotSpareCached) {
			hotSpareCached = [clientIdentifier retain];
		}
	}
}

- (BOOL)launchClientWithIdentifier:(NSString*)clientIdentifier andKey:(NSString*)clientKey
{
	NSString* clientPath = [NSString stringWithFormat:@"%@/Contents/Helpers/StainlessClient.app/Contents/MacOS/StainlessClient", [[NSBundle mainBundle] bundlePath]];
	NSArray* clientArgs = [NSArray arrayWithObjects:@"-clientID", [NSString stringWithFormat:@"\"%@\"", clientIdentifier], @"-clientKey", [NSString stringWithFormat:@"\"%@\"", clientKey], nil];

	NSMutableDictionary* environment = nil;
	
	NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
	if([[defaults objectForKey:@"LoadWebKit"] boolValue] == YES) {
		NSString* webKit = [[NSWorkspace sharedWorkspace] absolutePathForAppBundleWithIdentifier:@"org.webkit.nightly.WebKit"];
		NSString* frameworks = [NSString stringWithFormat:@"%@/Contents/Frameworks/10.5", webKit]; 
		
		if([[NSFileManager defaultManager] fileExistsAtPath:frameworks]) {
			NSProcessInfo* processInfo = [NSProcessInfo processInfo];
			environment = [[[processInfo environment] mutableCopy] autorelease];
			[environment setObject:frameworks forKey:@"DYLD_FRAMEWORK_PATH"];
			[environment setObject:@"YES" forKey:@"WEBKIT_UNSET_DYLD_FRAMEWORK_PATH"];
			
		}
	}
	
#if CHECK_FOR_LEAKS
	NSProcessInfo* processInfo = [NSProcessInfo processInfo];
	NSMutableDictionary* environment = [[processInfo environment] mutableCopy];
	[environment setObject:@"1" forKey:@"MallocStackLogging"];
#endif

	FSRef appRef;
	CFURLGetFSRef((CFURLRef) [NSURL fileURLWithPath:clientPath], &appRef);
	
	LSApplicationParameters appParams;
	memset(&appParams, 0, sizeof(appParams));
	
	if(environment)
		appParams.environment = (CFDictionaryRef) environment;
	
	appParams.version = 0;
	appParams.flags = kLSLaunchNewInstance + kLSLaunchAsync;
	appParams.application = &appRef;
	appParams.argv = (CFArrayRef) clientArgs;
	
	OSStatus err = LSOpenApplication(&appParams, NULL);
	if(err != noErr) {
		NSLog(@"LSOpenApplication error launching %@: %d", clientIdentifier, err);
		
		NSTask* task = [[[NSTask alloc] init] autorelease];
		 [task setLaunchPath:clientPath];
		 [task setArguments:clientArgs];
		
		if(environment)
			[task setEnvironment:environment];
		
		@try {
			[task launch];
		}
		
		@catch (NSException* anException) {
			NSLog(@"%@ exception launching %@: %@", [anException name], clientIdentifier, [anException reason]);
			return NO;
		}
	}

	return YES;
}

- (void)launchManager
{
	NSString* clientPath = [NSString stringWithFormat:@"%@/Contents/Helpers/StainlessManager", [[NSBundle mainBundle] bundlePath]];
	NSArray* clientArgs = [NSArray arrayWithObject:[NSString stringWithFormat:@"%.0f", [[NSApp menu] menuBarHeight]]];

	FSRef appRef;
	CFURLGetFSRef((CFURLRef) [NSURL fileURLWithPath:clientPath], &appRef);
	
	LSApplicationParameters appParams;
	memset(&appParams, 0, sizeof(appParams));
	
	appParams.version = 0;
	appParams.flags = kLSLaunchAsync;
	appParams.application = &appRef;
	appParams.argv = (CFArrayRef) clientArgs;
	
	OSStatus err = LSOpenApplication(&appParams, NULL);
	if(err != noErr) {
		NSLog(@"LSOpenApplication error launching StainlessManager: %d", err);

		NSTask* task = [[[NSTask alloc] init] autorelease];
		[task setLaunchPath:clientPath];
		[task setArguments:clientArgs];
		
		@try {
			[task launch];
		}
		
		@catch (NSException* anException) {
			NSLog(@"%@ exception launching StainlessManager: %@", [anException name], [anException reason]);
		}
	}
}

- (void)refreshAllClients:(NSString*)message
{
	NSEnumerator* enumerator = [[clients allValues] objectEnumerator];
	for(StainlessClient* client in enumerator)
		[[client connection] refreshClient:message];
}

- (void)closeAllClients
{
	NSEnumerator* enumerator = [[clients allValues] objectEnumerator];
	for(StainlessClient* client in enumerator) {
		[[NSNotificationCenter defaultCenter] removeObserver:client];
		[[client connection] closeClient];
	}	
	
	[self removeCacheForClientWithPid:0];
}

- (void)freezeAllWindows:(BOOL)freeze
{
	NSEnumerator* enumerator = [[windows allValues] objectEnumerator];
	for(StainlessWindow* window in enumerator)
		[window freezeClientWindows:freeze];
}

- (void)hideAllWindows:(BOOL)hide
{
	NSEnumerator* enumerator = [[windows allValues] objectEnumerator];
	for(StainlessWindow* window in enumerator)
		[window hideClientWindows:hide];
}

- (void)focusAllWindows
{
	ignoreLayer = YES;
		
	NSEnumerator* enumerator = [layers reverseObjectEnumerator];
	for(StainlessWindow* window in enumerator) {
		[window refocusClientWindows];
	}
	
	ignoreLayer = NO;
	
	[self focusMainWindow];
}

- (void)focusMainWindow
{
	StainlessWindow* focusWindow = nil;

	if(focus) {
		NSString* container = [focus container];
		focusWindow = [windows objectForKey:container];
	}
	
	if(focusWindow) {
		CGSWorkspaceID space;
		CGSGetWorkspace(_CGSDefaultConnection(), &space);
		
		if(space && [focusWindow space] != space) {
			NSEnumerator* enumerator = [layers objectEnumerator];
			for(StainlessWindow* window in enumerator) {
				if([window space] == space) {
					focusWindow = window;
					break;
				}
			}
		}
		
		[focusWindow relayerClientWindows:YES];
	}
}

- (NSMutableDictionary*)windowsInCurrentSpace
{
	CGSWorkspaceID space;
	CGSGetWorkspace(_CGSDefaultConnection(), &space);
	
	if(space) {
		NSMutableDictionary* spaceWindows = [NSMutableDictionary dictionaryWithCapacity:[windows count]];
		
		NSEnumerator* enumerator = [layers objectEnumerator];
		for(StainlessWindow* window in enumerator) {
			if([window space] == space) {
				[spaceWindows setObject:window forKey:[window identifier]];
			}
		}
		
		return spaceWindows;
	}
	
	return windows;
}

- (void)resetHotSpare
{
	if(hotSpare) {
		StainlessClient* newClient = [[[StainlessClient alloc] init] autorelease];
		NSString* clientIdentifier = [NSString stringWithString:hotSpare];
		[newClient setIdentifier:clientIdentifier];
		id connection = [newClient connection];
		[newClient setIdentifier:nil];
		
		[connection closeClient];
		
		[hotSpare release];
		hotSpare = nil;		
	}
}

// StainlessWorkspaceServer protocol
- (void)beginTransportForPid:(pid_t)pid
{
	extern ProcessSerialNumber gServerProcess;
	extern ProcessSerialNumber gTransportProcess;
	extern bool gTransporting;
	extern bool gQuitting;
	
	if(gQuitting == false && gTransporting == false) {		
		gTransporting = true;

		[self freezeAllWindows:YES];
		
		NSArray* serverWindows = [NSApp windows];
		for(NSWindow* window in serverWindows) {
			if([window isFlushWindowDisabled] == NO)
				[window disableFlushWindow];
		}
		
		GetProcessForPID(pid, &gTransportProcess);
		SetFrontProcess(&gServerProcess);
	}
}

// StainlessServerProtocol
- (StainlessClient*)spawnClientWithURL:(NSString*)urlString
{
	return [self spawnClientWithURL:urlString inWindow:nil];
}

- (StainlessClient*)spawnClientWithURL:(NSString*)urlString inWindow:(StainlessWindow*)window // remote entry
{
	NSString* windowIdentifier = [window identifier];
	return [self spawnClientWithURL:urlString inWindowWithIdentifier:windowIdentifier];
}

- (StainlessClient*)spawnClientWithURL:(NSString*)urlString inWindowWithIdentifier:(NSString*)windowIdentifier
{	
	if(windowIdentifier && spawnIndex) {
		StainlessWindow* insertWindow = [windows objectForKey:windowIdentifier];
		StainlessClient* pushClient = [insertWindow clientAtIndex:spawnIndex-1];
		if(pushClient) {
			spawnIndex = 0;
			
			[self redirectClient:pushClient toURL:urlString];
			return pushClient;
		}
	}
	
	spawnCount++;
	
	NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
	
	if(urlString == nil) {
		if(spawnCount == 1) {
			NSNumber* action = [defaults objectForKey:@"StartupAction"];
			
			switch([action intValue]) {
				case 100:
					urlString = @"about:welcome";
					break;
					
				case 200:
					if(windowIdentifier == nil)
						urlString = [defaults objectForKey:@"HomePage"];
					break;
					
				case 300:
					urlString = @"";
					break;
			}
		}
		
		if(urlString == nil) {
			if(windowIdentifier == nil && [[defaults objectForKey:@"NewWindowsHome"] boolValue] == YES)
				urlString = [defaults objectForKey:@"HomePage"];
			else if(windowIdentifier && [[defaults objectForKey:@"NewTabsHome"] boolValue] == YES)
				urlString = [defaults objectForKey:@"HomePage"];
		}
			
		if(urlString == nil)
			urlString = @"";
		
		spawnAndFocus = YES;
	}
	
	StainlessClient* newClient = [[[StainlessClient alloc] init] autorelease];
	NSString* clientIdentifier = nil;
	
	if(hotSpare)
		clientIdentifier = [NSString stringWithString:hotSpare];
	else
		clientIdentifier = [NSString stringWithFormat:@"StainlessClient[%f]", [NSDate timeIntervalSinceReferenceDate]];
				
	[newClient setIdentifier:clientIdentifier];
	[newClient copyUrl:urlString]; // will be used by client at launch
	
	if(newClient) {
		[clients setObject:newClient forKey:clientIdentifier];
		
		/*@synchronized(provisionalClients) {
			if(provisionalClients == nil)
				provisionalClients = [[NSMutableDictionary alloc] init];
		
			[provisionalClients setObject:newClient forKey:clientIdentifier];

			[self performSelectorOnMainThread:@selector(syncClients:) withObject:self waitUntilDone:NO];
		}*/
		
		if(spawnWindow)
			windowIdentifier = nil;
		else if(windowIdentifier == nil && [[defaults objectForKey:@"SingleWindowMode"] boolValue] == YES) {
			StainlessWindow* focusWindow = nil;
			
			if(focus) {
				NSString* container = [focus container];
				focusWindow = [windows objectForKey:container];
			}
			
			if(focusWindow)
				windowIdentifier = [focusWindow identifier];
			
			spawnAndFocus = YES;
		}
		
		StainlessWindow* insertWindow = nil;
		if(windowIdentifier) {
			insertWindow = [windows objectForKey:windowIdentifier];
			[insertWindow alertClientWindows];
		}
				
		[self moveClient:newClient intoWindow:insertWindow insertBefore:nil];
	}
	
	NSString* clientKey = [NSString stringWithFormat:@"%X", [clientIdentifier globalHash]];

	if(hotSpare)
		[[newClient connection] registerClient:clientKey];
	else
		[self launchClientWithIdentifier:clientIdentifier andKey:clientKey];
	
	if(hotSpare) {
		[hotSpare release];
		hotSpare = nil;		
	}

	return newClient;
}

- (BOOL)redirectClient:(StainlessClient*)client toURL:(NSString*)urlString
{
	NSString* clientIdentifier = [client identifier];
	return [self redirectClientWithIdentifier:clientIdentifier toURL:urlString];
}

- (BOOL)redirectClientWithIdentifier:(NSString*)clientIdentifier toURL:(NSString*)urlString // remote entry
{
	if(clientIdentifier == nil)
		return NO;
	
	StainlessClient* client = [clients objectForKey:clientIdentifier];
	
	if(client == nil)
		return NO;
	
	[[client connection] redirectClient:[NSString stringWithString:urlString]];
	
	return YES;
}

- (void)performCommand:(NSString*)command
{
	[[focus connection] serverToClientCommand:command];
}

- (void)clientToServerCommand:(NSString*)command // remote entry
{
	NSMenu* targetMenu = nil;
	
	@try {
		if(
		   [command isEqualToString:@"Preferences..."] ||
		   [command isEqualToString:@"Hide Stainless"] ||
		   [command isEqualToString:@"Hide Others"] ||
		   [command isEqualToString:@"Quit Stainless"]
		)
			targetMenu = [[[NSApp mainMenu] itemAtIndex:0] submenu];
		else if(
			[command isEqualToString:@"New Single Session Tab"] ||
			[command isEqualToString:@"New Window"] ||
			[command isEqualToString:@"New Private Browsing Window"] ||
			[command isEqualToString:@"New Tab"] ||
			[command isEqualToString:@"Print..."]
		) {
			if(forcePrivate) {
				if([command isEqualToString:@"New Window"])
					command = @"New Private Browsing Window";
				else if([command isEqualToString:@"New Private Browsing Window"])
					command = @"New Window";
			}
			
			if(forceSingle) {
				if([command isEqualToString:@"New Tab"])
					command = @"New Single Session Tab";
				else if([command isEqualToString:@"New Single Session Tab"])
					command = @"New Tab";
			}
			
			targetMenu = [[[NSApp mainMenu] itemAtIndex:1] submenu];
		}
		else if([command isEqualToString:@"Select Previous Window"]) {
			NSDictionary* spaceWindows = [self windowsInCurrentSpace];
			
			if([spaceWindows count] > 1) {
				NSString* container = [focus container];
				StainlessWindow* focusWindow = [spaceWindows objectForKey:container];
				NSArray* windowList = [[spaceWindows allValues] sortedArrayUsingSelector:@selector(identifierCompare:)];
				NSUInteger index = [windowList indexOfObjectIdenticalTo:focusWindow];
				if(index != NSNotFound) {
					if(index == 0)
						index = [windowList count] - 1;
					else
						index--;
					
					StainlessWindow* window = [windowList objectAtIndex:index];
					[self setFocus:[window focus]];
					[self focusWindow:window];
				}
			}
		}
		else if([command isEqualToString:@"Select Next Window"]) {
			NSDictionary* spaceWindows = [self windowsInCurrentSpace];
			
			if([spaceWindows count] > 1) {
				NSString* container = [focus container];
				StainlessWindow* focusWindow = [spaceWindows objectForKey:container];
				NSArray* windowList = [[spaceWindows allValues] sortedArrayUsingSelector:@selector(identifierCompare:)];

				NSUInteger index = [windowList indexOfObjectIdenticalTo:focusWindow];
				if(index != NSNotFound) {
					if(index == [windowList count] - 1)
						index = 0;
					else
						index++;
					
					StainlessWindow* window = [windowList objectAtIndex:index];
					[self setFocus:[window focus]];
					[self focusWindow:window];
				}
			}
		}
		else if([command isEqualToString:@"History"] || [command isEqualToString:@"Downloads"] || [command isEqualToString:@"Process Manager"]) {
			targetMenu = [[[NSApp mainMenu] itemAtIndex:4] submenu];
		}
		
		if(targetMenu)
			[targetMenu performActionForItemAtIndex:[targetMenu indexOfItemWithTitle:command]];
	}

	@catch (NSException* anException) {
	}
}

- (oneway void)closeWindow:(StainlessWindow*)window // remote entry
{
	NSString* windowIdentifier = [window identifier];
	[self closeWindowWithIdentifier:windowIdentifier];
}

- (void)closeWindowWithIdentifier:(NSString*)windowIdentifier
{
	if(windowIdentifier == nil)
		return;
	
	StainlessWindow* window = [windows objectForKey:windowIdentifier];
	
	if(window == nil)
		return;

	[window setIdentifier:nil];

	NSArray* clientList = [[window clientIdentifiers] retain];
	for(NSString* clientIdentifier in clientList) {
		StainlessClient* client = [clients objectForKey:clientIdentifier];
		[[client connection] closeClient];
		
		[clients removeObjectForKey:clientIdentifier];
	}

	[self reconcileWid:[window wid]];
	
	if([layers count] == 1) {
		NSRect windowFrame = [[window frame] rectValue];
		
		NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
		[defaults setObject:[NSNumber numberWithFloat:windowFrame.origin.x] forKey:@"WindowOriginX"];
		[defaults setObject:[NSNumber numberWithFloat:windowFrame.origin.y] forKey:@"WindowOriginY"];
		[defaults setObject:[NSNumber numberWithFloat:windowFrame.size.width] forKey:@"WindowSizeWidth"];
		[defaults setObject:[NSNumber numberWithFloat:windowFrame.size.height] forKey:@"WindowSizeHeight"];
	}
	
	[layers removeObject:window];
	[windows removeObjectForKey:windowIdentifier];
	
	NSDictionary* spaceWindows = [self windowsInCurrentSpace];
	
	if([spaceWindows count] == 0) {
		focus = nil;
		[NSApp activateIgnoringOtherApps:YES];
	}
	else {
		StainlessWindow* switchWindow = [[spaceWindows allValues] objectAtIndex:0];
		[self setFocus:[switchWindow focus]];
		[self focusWindow:switchWindow];
	}

	[clientList release];
	
	if([[tasks window] isVisible])
		[tasks reloadData];
}

- (void)layerWindow:(StainlessWindow*)window // remote entry
{
	NSString* windowIdentifier = [window identifier];
	[self layerWindowWithIdentifier:windowIdentifier];
}
		
- (void)layerWindowWithIdentifier:(NSString*)windowIdentifier
{	
	if(ignoreLayer)
		return;
	
	if(windowIdentifier == nil)
		return;
	
	StainlessWindow* window = [windows objectForKey:windowIdentifier];
	
	if(window == nil)
		return;
	
	for(StainlessPanel* panel in [NSApp windows]) {
		if([panel isVisible] && [panel focusWid] == [window wid]) {
			[panel setFocusMode:NSWindowBelow];}
	}
		
	BOOL didAddWindow = YES;

	if([layers containsObject:window]) {
		if([window isEqualTo:[layers objectAtIndex:0]])
			return;
		
		[window retain];
		[layers removeObject:window];
		
		didAddWindow = NO;
	}
	
	//crash[layers insertObject:window atIndex:0];
	[layers insertObject:window atIndex:0];
	
	if(didAddWindow == NO)
		[window release];
	
	[self setFocus:[window focus]];
}
	
- (void)alignWindow:(StainlessWindow*)window // remote entry
{
	NSString* windowIdentifier = [window identifier];
	[self alignWindowWithIdentifier:windowIdentifier];
}

- (void)alignWindowWithIdentifier:(NSString*)windowIdentifier
{	
	if(ignoreLayer)
		return;
	
	if(windowIdentifier == nil)
		return;
	
	StainlessWindow* window = [windows objectForKey:windowIdentifier];
	
	if(window == nil)
		return;
}

- (void)focusWindow:(StainlessWindow*)window // remote entry
{
	NSString* windowIdentifier = [window identifier];
	[self focusWindowWithIdentifier:windowIdentifier];
}

- (void)focusWindowWithIdentifier:(NSString*)windowIdentifier
{	
 	if(ignoreLayer)
		return;
	
	if(windowIdentifier == nil)
		return;
	
	StainlessWindow* window = [windows objectForKey:windowIdentifier];
	
	if(window == nil)
		return;

	StainlessWindow* focusWindow = nil;
	
	if(focus) {
		NSString* container = [focus container];
		focusWindow = [windows objectForKey:container];
	}
	
	if(focusWindow && [window isEqualTo:focusWindow])
		[focusWindow relayerClientWindows:YES];
	else
		[window relayerClientWindows:NO];
	
	if([[tasks window] isVisible])
		[tasks reloadData];	
}

- (void)focusClient:(StainlessClient*)client
{
	NSString* clientIdentifier = [client identifier];
	[self focusClientWithIdentifier:clientIdentifier];
}

- (void)focusClientWithIdentifier:(NSString*)clientIdentifier // remote entry
{
	if(clientIdentifier == nil)
		return;
	
	StainlessClient* client = [clients objectForKey:clientIdentifier];
	
	if(client == nil)
		return;
	
	if(focus && [focus isEqualTo:client])
		return;

	StainlessWindow* focusWindow = nil;
	
	if(focus) {
		NSString* container = [focus container];
		focusWindow = [windows objectForKey:container];
	}
	
	[self setFocus:client];
	
	NSString* container = [client container];
	StainlessWindow* clientWindow = [windows objectForKey:container];
	if(clientWindow) {
		if(focusWindow && [focusWindow isEqualTo:clientWindow])
			[clientWindow switchFocusToClient:client];
		else {
			[clientWindow setFocus:client];
			[self focusWindow:clientWindow];
		}
	}
}

- (void)undockClient:(StainlessClient*)client
{
	NSString* clientIdentifier = [client identifier];

	StainlessClient* localClient = [clients objectForKey:clientIdentifier];
	[self moveClient:localClient intoWindow:nil insertBefore:nil];
}

- (void)dockClientWithIdentifier:(NSString*)clientIdentifier intoWindow:(StainlessWindow*)window beforeClientWithIdentifier:(NSString*)beforeIdentifier
{
	StainlessClient* localDock = [clients objectForKey:clientIdentifier];
	StainlessClient* localInsert = (beforeIdentifier == nil ? nil : [clients objectForKey:beforeIdentifier]);

	NSString* windowIdentifier = [window identifier];
	StainlessWindow* localWindow = [windows objectForKey:windowIdentifier];
		
	[self moveClient:localDock intoWindow:localWindow insertBefore:localInsert];
}

- (void)moveClient:(StainlessClient*)client intoWindow:(StainlessWindow*)window insertBefore:(StainlessClient*)nextClient
{
	if(client == nil)
		return;
	
	BOOL didCreateWindow = NO;
	NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];	
	
	if(window == nil) {
		StainlessWindow* newWindow = [[StainlessWindow alloc] init];
		if(defaultSpace)
			[newWindow setSpace:defaultSpace];
		else {
			CGSWorkspaceID space;
			CGSGetWorkspace(_CGSDefaultConnection(), &space);
						
			if(space < kCGSTransitioningWorkspaceID)
				[newWindow setSpace:space];
		}
		
		NSString* windowIdentifier = [NSString stringWithFormat:@"StainlessWindow[%f]", [NSDate timeIntervalSinceReferenceDate]];
		[newWindow setIdentifier:windowIdentifier];

		BOOL didSetWindow = NO;
		NSRect windowFrame;
		
		if(NSIsEmptyRect(spawnFrame) == NO) {
			windowFrame = spawnFrame;
			didSetWindow = YES;
		}
		
		if(didSetWindow == NO) {
			if(focus) {
				NSString* container = [focus container];
				if(container) {
					StainlessWindow* clientWindow = [windows objectForKey:container];
					if(clientWindow) {
						windowFrame = [[clientWindow frame] rectValue];
						windowFrame = NSOffsetRect(windowFrame, 10.0, -10.0);
						didSetWindow = YES;
					}
				}
			}
		}
		
		if(didSetWindow == NO) {
			windowFrame.origin.x = [[defaults objectForKey:@"WindowOriginX"] floatValue];
			windowFrame.origin.y = [[defaults objectForKey:@"WindowOriginY"] floatValue];
			windowFrame.size.width = [[defaults objectForKey:@"WindowSizeWidth"] floatValue];
			windowFrame.size.height = [[defaults objectForKey:@"WindowSizeHeight"] floatValue];
		}
		
		BOOL iconShelf = [[defaults objectForKey:@"ShowIconShelf"] boolValue];
		[newWindow setIconShelf:iconShelf];
		
		BOOL statusBar = [[defaults objectForKey:@"ShowStatusBar"] boolValue];
		[newWindow setStatusBar:statusBar];
		
		if(spawnPrivate)
			[newWindow setPrivateMode:YES];
		
		[newWindow setFrame:[NSValue valueWithRect:windowFrame]];
		
		[windows setObject:newWindow forKey:windowIdentifier];
		
		/*@synchronized(provisionalWindows) {
			if((provisionalWindows) == nil)
				(provisionalWindows) = [[NSMutableDictionary alloc] init];
			
			[(provisionalWindows) setObject:newWindow forKey:windowIdentifier];
			
			[self performSelectorOnMainThread:@selector(syncWindows:) withObject:self waitUntilDone:NO];
		}*/
		
		window = [newWindow autorelease];
		
		[self setFocus:client];
		didCreateWindow = YES;
	}
	else {
		if(spawnAndFocus)
			[self setFocus:client];
	}
	
	if(spawnChild)
		[client setIsChild:YES];
	
	StainlessClient* spawnParent = nil;

	if(spawnGroup) {
		if(nextClient == nil && [[defaults objectForKey:@"SpawnAdjacentTabs"] boolValue] == YES) {
			spawnParent = [clients objectForKey:spawnGroup];
			if(spawnParent) {
				NSUInteger index = [window indexOfClient:spawnParent];
				nextClient = [window clientAtIndex:index + 1];
			}
		}
		
		[client setGroup:spawnGroup];
		self.spawnGroup = nil;
	}
	
	if(spawnSession) {
		[client setSession:spawnSession];
		self.spawnSession = nil;
	}
	
	spawnWindow = NO;
	spawnAndFocus = NO;
	spawnPrivate = NO;
	spawnChild = NO;
	spawnFrame = NSZeroRect;
	spawnIndex = 0;
		
	if([window addClient:client beforeClient:nextClient] == YES) {
		NSString* container = [client container];
		if(container) {
			StainlessWindow* clientWindow = [windows objectForKey:container];
			if(clientWindow) {
				StainlessClient* newFocus = [clientWindow moveClient:client];
				
				if(newFocus == nil) {
					[layers removeObject:clientWindow];
					[windows removeObjectForKey:[clientWindow identifier]];
				}
				else {
					[clientWindow setFocus:newFocus];
					[clientWindow relayerClientWindows:NO];
				}
			}
		}
	}
		
	if([[client identifier] isEqualToString:[[self focus] identifier]])
		[window setFocus:client];
	
	[client setContainer:[window identifier]];
	
	if([client key] || didCreateWindow)
		[self focusWindow:window];
}

- (void)hotSpareReadyWithIdentifier:(NSString*)clientIdentifier // remote entry
{
	hotSpareBusy = YES;
	
	if(hotSpareCached && [hotSpareCached isEqualToString:clientIdentifier]) {
		@synchronized(hotSpareCached) {
			hotSpare = hotSpareCached;
			hotSpareCached = nil;
		}
	}
	
	hotSpareBusy = NO;
}

- (StainlessClient*)registerClientWithIdentifier:(NSString*)clientIdentifier key:(NSString*)key // remote entry
{
	StainlessClient* client = [clients objectForKey:clientIdentifier];
		
	if(client) {
		if([client key]) {
			if(focusFirst) {
				focusFirst = NO;
				[self focusClientWithIdentifier:clientIdentifier];
			}
		}
		else {
			NSString* clientKey = [NSString stringWithFormat:@"%X", [[client identifier] globalHash]];
			if([key isEqualToString:clientKey] == NO)
				return nil;
			
			[client copyKey:key];

			[self layerWindowWithIdentifier:[client container]];

			//[NSThread sleepForTimeInterval:2.0];

			//NSString* container = [client container];
			//StainlessWindow* clientWindow = [windows objectForKey:container];
			//if(clientWindow)
			//	[self focusWindow:clientWindow];
		}
	}
	
	return client;
}

- (StainlessClient*)clientWithIdentifier:(NSString*)clientIdentifier // remote entry
{
	return [clients objectForKey:clientIdentifier];
}

- (NSArray*)getPermittedHosts
{
	if(hosts == nil)
		return nil;
	
	NSMutableArray* permittedHosts = [NSMutableArray arrayWithCapacity:[hosts count]];
	
	for(NSString* host in hosts)
		[permittedHosts addObject:[NSString stringWithString:host]];

	return permittedHosts;
}

- (StainlessWindow*)getWindowForClient:(StainlessClient*)client // remote entry
{
	NSString* clientIdentifier = [client identifier];
	return [self getWindowForClientWithIdentifier:clientIdentifier];
}

- (StainlessWindow*)getWindowForClientWithIdentifier:(NSString*)clientIdentifier
{
	if(clientIdentifier == nil)
		return nil;
	
	StainlessClient* client = [clients objectForKey:clientIdentifier];
	
	if(client == nil)
		return nil;
	
	NSString* container = [client container];
	return [windows objectForKey:container];
}

- (void)resetFocus
{
	NSString* container = [focus container];
	StainlessWindow* focusWindow = [windows objectForKey:container];
	StainlessClient* firstTab = [focusWindow clientAtIndex:0];
	[self focusClientWithIdentifier:[firstTab identifier]];
}

- (oneway void)trimFocus:(long)count
{
	NSString* container = [focus container];
	StainlessWindow* focusWindow = [windows objectForKey:container];

	NSArray* clientList = [[focusWindow clientIdentifiers] retain];
	int excess = [clientList count] -  (count - 1);
	if(excess > 0) {
		int i = 1;
		
		for(NSString* clientIdentifier in [clientList reverseObjectEnumerator]) {
			[self closeClientWithIdentifier:clientIdentifier];
			
			if(++i > excess)
				break;
		}
	}
	
	[clientList release];
}

- (oneway void)closeClient:(StainlessClient*)client // remote entry
{
	NSString* clientIdentifier = [client identifier];
	[self closeClientWithIdentifier:clientIdentifier];
}

- (oneway void)closeClientWithIdentifier:(NSString*)clientIdentifier // remote entry
{
	if(clientIdentifier == nil)
		return;
	
	StainlessClient* client = [clients objectForKey:clientIdentifier];
	
	if(client == nil)
		return;

	[self removeCacheForClientWithPid:[client pid]];
	
	NSEnumerator* enumerator = [[clients allValues] objectEnumerator];
	for(StainlessClient* notifyClient in enumerator)
		[[notifyClient connection] notifyClientWithIdentifier:clientIdentifier];
	
	NSString* container = [client container];
	StainlessWindow* clientWindow = [windows objectForKey:container];
	if(clientWindow) {		
		[clients removeObjectForKey:clientIdentifier];
		StainlessClient* newFocus = [clientWindow removeClient:client];
			
		if([clientWindow identifier] == nil)
			return;
		
		if(newFocus == nil) {
			[self reconcileWid:[clientWindow wid]];

			if([layers count] == 1) {
				NSRect windowFrame = [[clientWindow frame] rectValue];
				
				NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
				[defaults setObject:[NSNumber numberWithFloat:windowFrame.origin.x] forKey:@"WindowOriginX"];
				[defaults setObject:[NSNumber numberWithFloat:windowFrame.origin.y] forKey:@"WindowOriginY"];
				[defaults setObject:[NSNumber numberWithFloat:windowFrame.size.width] forKey:@"WindowSizeWidth"];
				[defaults setObject:[NSNumber numberWithFloat:windowFrame.size.height] forKey:@"WindowSizeHeight"];
			}
			
			[layers removeObject:clientWindow];
			[windows removeObjectForKey:[clientWindow identifier]];
			
			NSDictionary* spaceWindows = [self windowsInCurrentSpace];

			if([spaceWindows count] == 0) {
				focus = nil;
				[NSApp activateIgnoringOtherApps:YES];
			}
			else {
				StainlessWindow* switchWindow = [[spaceWindows allValues] objectAtIndex:0];
				[self setFocus:[switchWindow focus]];
				[self focusWindow:switchWindow];
			}
		}
		else {
			if([newFocus isEqualTo:[clientWindow focus]]) {
				[self focusWindow:clientWindow];
			}
			else {
				[self setFocus:newFocus];
				//[clientWindow switchFocusToClient:newFocus];
				[clientWindow performSelectorOnMainThread:@selector(switchFocusToClient:) withObject:newFocus waitUntilDone:NO];
			}
		}
	}
	else
		[clients removeObjectForKey:clientIdentifier];

	if([[tasks window] isVisible])
		[tasks reloadData];
}	

- (oneway void)resizeClientWithIdentifier:(NSString*)clientIdentifier toFrame:(NSRect)frame // remote entry
{
	StainlessClient* client = [clients objectForKey:clientIdentifier];
	
	if(client == nil)
		return;
	
	[[client connection] resizeClient:frame];
}

- (oneway void)updateClient:(StainlessClient*)client // remote entry
{
	NSString* clientIdentifier = [client identifier];
	[self updateClientWithIdentifier:clientIdentifier];
}

- (void)updateClientWithIdentifier:(NSString*)clientIdentifier
{
	if(clientIdentifier == nil)
		return;
	
	StainlessClient* client = [clients objectForKey:clientIdentifier];
	
	if(client == nil)
		return;

	NSString* container = [client container];
	StainlessWindow* clientWindow = [windows objectForKey:container];
	if(clientWindow)
		[clientWindow updateClientWindows:clientIdentifier];

	if([[tasks window] isVisible])
		[tasks reloadData];
}

- (oneway void)updateClientWindow:(StainlessClient*)client // remote entry
{
	NSString* clientIdentifier = [client identifier];
	[self updateClientWindowWithIdentifier:clientIdentifier];
}

- (void)updateClientWindowWithIdentifier:(NSString*)clientIdentifier
{
	if(clientIdentifier == nil)
		return;
	
	StainlessClient* client = [clients objectForKey:clientIdentifier];
	
	if(client == nil)
		return;
	
	NSString* container = [client container];
	StainlessWindow* clientWindow = [windows objectForKey:container];
	if(clientWindow) {
		NSEnumerator* enumerator = [layers reverseObjectEnumerator];
		for(StainlessWindow* window in enumerator) {
			if([container isEqualToString:[window identifier]] == NO) {
				StainlessClient* windowFocus = [window focus];
				[[windowFocus connection] refreshClient:SMUpdateIconShelf];
			}
		}
	}
}

- (oneway void)permitClients:(NSString*)host fromClientWithIdentifier:(NSString*)clientIdentifier // remote entry
{
	NSString* localHost = [NSString stringWithString:host];
	
	NSEnumerator* enumerator = [[clients allValues] objectEnumerator];
	for(StainlessClient* client in enumerator) {
		if([[client identifier] isEqualToString:clientIdentifier] == NO)
			[[client connection] permitClient:localHost];
	}

	if(hosts == nil)
		hosts = [[NSMutableArray alloc] initWithCapacity:1];
	
	if([hosts containsObject:localHost] == NO)
		[hosts addObject:localHost];
}

- (void)purgeDownloads
{
	if(downloadInfo == nil)
		return;
	
	BOOL refresh = NO;
	
	for(NSMutableDictionary* info in [downloadInfo allValues]) {
		if([info objectForKey:@"Fail"] == nil) {
			NSNumber* lastUpdate = [info objectForKey:@"LastUpdate"];
			if(lastUpdate) {
				double then = [lastUpdate doubleValue];
				double now = [NSDate timeIntervalSinceReferenceDate];
				
				if(now > then + 60.0) {
					NSString* url = [info objectForKey:@"URL"];
					[info setObject:url forKey:@"FileName"];
					[info setObject:NSLocalizedString(@"Fail", @"") forKey:@"Status"];
				
					[info setObject:[NSNumber numberWithBool:YES] forKey:@"Fail"];		
				
					refresh = YES;
				}
			}
		}
	}
	
	if(refresh) {
		[clearDownloads setEnabled:YES];
		[downloads reloadData];
	}
}

- (BOOL)hasDownloads
{
	if(downloadInfo == nil)
		return NO;

	[self purgeDownloads];

	for(NSMutableDictionary* info in [downloadInfo allValues]) {
		if([info objectForKey:@"Fail"] == nil)
			return YES;
	}
	
	return NO;
}

- (BOOL)hasClients
{
	return ([clients count] > 0 ? YES : NO);
}

- (BOOL)isMultiClient // remote entry
{
	return ([clients count] > 1 ? YES : NO);
}

- (BOOL)isActiveClient // remote entry
{
	if([clients count] == 0)
		return NO;
	
	for(StainlessClient* client in [clients allValues]) {
		NSString* url = [client url];
		if(url == nil ||[url length] == 0)
			return NO;
	}
	
	return YES;
}

- (void)hold // remote entry
{
	StainlessController* controller = (StainlessController*)[NSApp delegate];
	[controller setIgnoreActivation:YES];
}

- (oneway void)copySpawnGroup:(bycopy NSString*)copy // remote entry
{
	self.spawnGroup = [NSString stringWithString:copy];
}

- (oneway void)copySpawnSession:(bycopy NSString*)copy // remote entry
{
	self.spawnSession = [NSString stringWithString:copy];
}

- (oneway void)addURLToHistory:(bycopy NSString *)URLString title:(bycopy NSString *)title // remote entry
{
	if(ignoreHistory && [ignoreHistory isEqualToString:URLString]) {
		self.ignoreHistory = nil;
		return;
	}
	
	WebHistoryItem* entry = [clientHistory _itemForURLString:URLString];
	
	if(entry) {
		if(webHistoryCanRecordVisits) {
			if(webHistoryCanControlVisitCount)
				[entry _visitedWithTitle:title increaseVisitCount:YES];
			else
				[entry _visitedWithTitle:title];
		
			[clientHistory addItems:[NSArray arrayWithObject:entry]];
		}
		else {
			entry = [[WebHistoryItem alloc] initWithURLString:URLString title:title lastVisitedTimeInterval:[NSDate timeIntervalSinceReferenceDate]];
			[clientHistory addItems:[NSArray arrayWithObject:entry]];
			[entry release];
		}
	}
	else {
		entry = [[WebHistoryItem alloc] initWithURLString:URLString title:title lastVisitedTimeInterval:[NSDate timeIntervalSinceReferenceDate]];
		
		if(webHistoryCanRecordVisits)
			[entry _recordInitialVisit];
		else
			[entry setVisitCount:1];
			
		[clientHistory addItems:[NSArray arrayWithObject:entry]];
		[entry release];

		[self addURLToAutoComplete:URLString withItem:entry];
	}
	
	[self refreshHistoryList:self];
}

- (oneway void)updateDownload:(bycopy NSString*)downloadStamp contentLength:(bycopy NSNumber*)length fileName:(bycopy NSString*)name // remote entry
{
	static int downloadCount = 0;
	
	if(downloadInfo == nil)
		downloadInfo = [[NSMutableDictionary alloc] initWithCapacity:1];
	
	BOOL refresh = NO;
	
	NSMutableDictionary* info = [downloadInfo objectForKey:downloadStamp];
	if(info == nil) {
		StainlessController* controller = (StainlessController*)[NSApp delegate];
		[controller showDownloads:nil];

		info = [NSMutableDictionary dictionary];
		[info setObject:[NSNumber numberWithInt:downloadCount++] forKey:@"Index"];
		
		[downloadInfo setObject:info forKey:downloadStamp];
		
		refresh = YES;
	}
	
	if(length) {
		NSNumber* currentLength = [info objectForKey:@"ContentLength"];
		if(currentLength == nil) {
			[info setObject:length forKey:@"ContentLength"];
			[info setObject:[NSNumber numberWithLongLong:0] forKey:@"Bytes"];
			
			NSString* size = nil;
			
			long long bytes = [length longLongValue];
			if(bytes != NSURLResponseUnknownLength) {
				if(bytes < 1024)
					size = [NSString stringWithFormat:@"%dB", bytes];
				else if(bytes < 1024 * 1024) {
					double b = (double) bytes / 1024.0;
					size = [NSString stringWithFormat:@"%.0fK", b];
				}
				else if(bytes < 1024 * 1024 * 1024) {
					bytes /= 1024;
					double b = (double) bytes / 1024.0;
					size = [NSString stringWithFormat:@"%.1fM", b];
				}
				else {
					bytes /= (1024 * 1024);
					double b = (double) bytes / 1024.0;
					size = [NSString stringWithFormat:@"%.2fG", b];
				}
			}
			
			if(size)
				[info setObject:size forKey:@"Status"];
		}
		else {
			NSNumber* currentBytes = [info objectForKey:@"Bytes"];
			long long newBytes = [currentBytes longLongValue] + [length longLongValue];
			
			[info setObject:[NSNumber numberWithLongLong:newBytes] forKey:@"Bytes"];
		}
		
		refresh = YES;
	}
	
	if(name) {
		if([info objectForKey:@"URL"] == nil)
			[info setObject:name forKey:@"URL"];
			
		[info setObject:name forKey:@"FileName"];
		refresh = YES;
	}
	
	[info setObject:[NSNumber numberWithDouble:[NSDate timeIntervalSinceReferenceDate]] forKey:@"LastUpdate"];
	
	if(refresh)
		[downloads reloadData];
}

- (oneway void)endDownload:(bycopy NSString*)downloadStamp didFail:(BOOL)fail // remote entry
{
	NSMutableDictionary* info = [downloadInfo objectForKey:downloadStamp];
	if(info == nil)
		return;

	if(fail == NO) {
		NSNumber* currentLength = [info objectForKey:@"ContentLength"];
		if(currentLength)
			[info setObject:currentLength forKey:@"Bytes"];
		
		NSImage* icon = [[NSWorkspace sharedWorkspace] iconForFile:[info objectForKey:@"FileName"]];
		[icon setScalesWhenResized:YES];
		[icon setSize:NSMakeSize(16.0, 16.0)];
		[info setObject:icon forKey:@"Icon"];

		[info removeObjectForKey:@"Status"];

		//NSString* fileName = [info objectForKey:@"FileName"];
		//if([fileName hasSuffix:@".download"]) {
		//	fileName = [fileName substringToIndex:[fileName length] - 9];
		//	[info setObject:fileName forKey:@"FileName"];
		//}
	}
	else {
		NSString* url = [info objectForKey:@"URL"];
		[info setObject:url forKey:@"FileName"];
		[info setObject:NSLocalizedString(@"Fail", @"") forKey:@"Status"];
	}
	
	[info setObject:[NSNumber numberWithBool:fail] forKey:@"Fail"];		

	[clearDownloads setEnabled:YES];
	[downloads reloadData];
}

- (NSArray*)completionForURLString:(bycopy NSString*)urlString includeSearch:(BOOL)search // remote entry
{
	NSMutableArray* completion = nil;
	BOOL didAddSearch = NO;

	if(search) {
		long maxCount = 3;

		completion = [NSMutableArray arrayWithCapacity:10];
		
		[searchComplete swap];
		
		NSMutableArray* matches = [searchComplete arrayOfDataMatchingString:urlString];
		[matches sortUsingSelector:@selector(visitCountCompare:)];
		for(WebHistoryItem* item in matches) {
			NSString* alternateTitle = [item alternateTitle];
			if(alternateTitle) {
				didAddSearch = YES;

				if([completion containsObject:alternateTitle] == NO)
					[completion addObject:alternateTitle];
				
				if(--maxCount == 0)
					break;
				
			}
		}
				
		[searchComplete swap];
	}
	
	{
		long maxCount = 7;

		if(completion == nil)
			completion = [NSMutableArray arrayWithCapacity:maxCount];
		
		NSMutableArray* matches = [urlComplete arrayOfDataMatchingString:urlString];
		[matches sortUsingSelector:@selector(visitCountCompare:)];
		for(WebHistoryItem* item in matches) {
			NSString* itemURLString = [item URLString];
			
			{
				BOOL include = YES;
				for(NSString* i in completion) {
					if([itemURLString hasPrefix:i]) {
						include = NO;
						break;
					}
				}
				
				if(include) {
					if(didAddSearch) {
						[completion addObject:@"-"];
						didAddSearch = NO;
					}
					
					[completion addObject:itemURLString];
					
					if(--maxCount == 0)
						break;
				}
			}
		}
	}
		
	return completion;
}

// Callbacks
- (void)shutdownClientWithPid:(pid_t)pid
{
	NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
	if([[defaults objectForKey:@"ShutdownUnresponsiveTabs"] boolValue] == NO)
		return;

	for(NSString* clientIdentifier in clients) {
		StainlessClient* client = [clients objectForKey:clientIdentifier];

		if([client pid] == pid) {
			NSLog(@"shutting down unresponsive process with tab titled \"%@\"", [client title]);
			
			NSMutableDictionary* processInfo = [NSMutableDictionary dictionaryWithCapacity:2];
			[processInfo setObject:[NSNumber numberWithLong:[client hiPSN]] forKey:@"highLongOfPSN"];
			[processInfo setObject:[NSNumber numberWithLong:[client loPSN]] forKey:@"lowLongOfPSN"];
			[NSThread detachNewThreadSelector:@selector(killProcess:) toTarget:self withObject:processInfo];
			
			return;
		}
	}
}

- (void)openHistoryItem:(id)sender
{
	int rowIndex = [history clickedRow];
	if(rowIndex ==  -1)
		return;

	NSArray* list = (filteredHistoryList ? filteredHistoryList : historyList);

	self.ignoreHistory = [[list objectAtIndex:rowIndex] URLString];
	
	if(focus) {
		NSString* container = [focus container];
		StainlessWindow* focusWindow = [windows objectForKey:container];

		extern UInt32 GetCurrentKeyModifiers();
		NSNumber* modifier = [NSNumber numberWithUnsignedInt:GetCurrentKeyModifiers()];

		if(([modifier unsignedIntValue] & cmdKey)) {
			if(([modifier unsignedIntValue] & shiftKey))
				[self setSpawnAndFocus:YES];
			
			if(([modifier unsignedIntValue] & optionKey))
				[self spawnClientWithURL:ignoreHistory];
			else
				[self spawnClientWithURL:ignoreHistory inWindow:focusWindow];
		}	
		else
			[self redirectClient:focus toURL:ignoreHistory];
	}
	else
		[self spawnClientWithURL:ignoreHistory];
}

- (void)openDownloadsItem:(id)sender
{
	int rowIndex = [downloads clickedRow];
	if(rowIndex ==  -1)
		return;
	
	NSArray* list = [[downloadInfo allValues] sortedArrayUsingSelector:@selector(indexKeyCompare:)];
	NSMutableDictionary* info = [list objectAtIndex:rowIndex];
	
	if([info objectForKey:@"Icon"]) {
		NSString* fileName = [info objectForKey:@"FileName"];
		if(fileName) {
			[[NSWorkspace sharedWorkspace] selectFile:fileName inFileViewerRootedAtPath:nil];
		}
	}
}

/*
 - (void)syncClients:(id)sender
{
	@synchronized(provisionalClients) {
		if(provisionalClients) {		
			NSUInteger capacity = [provisionalClients count] + [clients count];
			NSMutableDictionary* newClients = [[NSMutableDictionary alloc] initWithCapacity:capacity];
			[newClients addEntriesFromDictionary:provisionalClients];
			[newClients addEntriesFromDictionary:clients];
			
			[provisionalClients release];
			provisionalClients = nil;
			
			NSMutableDictionary* oldClients = clients;
			clients = newClients;
			[oldClients release];
		}
	}
}

- (void)syncWindows:(id)sender
{
	@synchronized(provisionalWindows) {
		if(provisionalWindows) {		
			NSUInteger capacity = [provisionalWindows count] + [windows count];
			NSMutableDictionary* newWindows = [[NSMutableDictionary alloc] initWithCapacity:capacity];
			[newWindows addEntriesFromDictionary:provisionalWindows];
			[newWindows addEntriesFromDictionary:windows];
			
			[provisionalWindows release];
			provisionalWindows = nil;
			
			NSMutableDictionary* oldWindows = windows;
			windows = newWindows;
			[oldWindows release];
		}
	}
}
*/

- (void)switchWindow:(id)sender
{
	NSString* windowIdentifier = [(NSMenuItem*)sender representedObject];

	StainlessWindow* window = [windows objectForKey:windowIdentifier];
	
	if(window == nil)
		return;

	[self setFocus:[window focus]];
	[self focusWindow:window];
}

/*- (void)launchClient:(id)sender
{
	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	
	NSString* clientIdentifier = [NSString stringWithString:sender];
	NSString* clientKey = [NSString stringWithFormat:@"%X", [clientIdentifier globalHash]];
	
	@try {
		NSTask* task = [[[NSTask alloc] init] autorelease];
		
		NSString* clientPath = [NSString stringWithFormat:@"%@/Contents/Helpers/StainlessClient.app/Contents/MacOS/StainlessClient", [[NSBundle mainBundle] bundlePath]];
		[task setLaunchPath:clientPath];
		
		[task setArguments:[NSArray arrayWithObjects:@"-clientID", [NSString stringWithFormat:@"\"%@\"", clientIdentifier], @"-clientKey", [NSString stringWithFormat:@"\"%@\"", clientKey], nil]];
		
		[task launch];
	}
	
	@catch (NSException* anException) {
	}
	
	[pool release];
}*/

- (void)processMonitor:(id)sender
{
	NSAutoreleasePool* pool = nil;
	
	BOOL needsManager = (gOSVersion < 0x1060 ? YES : NO);
		
	do {
		[pool release];
		pool = [[NSAutoreleasePool alloc] init];

		[NSThread sleepForTimeInterval:3.0];
		
		if(needsManager) {
			id manager = [NSConnection connectionWithRegisteredName:@"StainlessManager" host:nil];
			if(manager == nil)
				[self performSelectorOnMainThread:@selector(launchManager) withObject:nil waitUntilDone:YES];
		}
		
		NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
		if([[defaults objectForKey:@"EnableHotSpare"] boolValue] == NO)
			continue;
		
		if(hotSpareBusy || hotSpareCached || hotSpare)
			continue;
			
		NSString* hotSpareIdentifier = [[NSString alloc] initWithFormat:@"StainlessClient[%f]", [NSDate timeIntervalSinceReferenceDate]];
		[self performSelectorOnMainThread:@selector(launchHotSpareWithIdentifier:) withObject:hotSpareIdentifier waitUntilDone:YES];
		[hotSpareIdentifier release];
	} while(1);
}

- (void)forgetClientWithIdentifier:(id)sender
{
	NSString* clientIdentifier = (NSString*)sender;
	
	if(clientIdentifier == nil)
		return;
	
	StainlessClient* client = [clients objectForKey:clientIdentifier];
	
	if(client == nil)
		return;

	[self removeCacheForClientWithPid:[client pid]];
	
	[client setKey:nil];
	[client retain];
	
	NSString* container = [client container];
	StainlessWindow* clientWindow = [windows objectForKey:container];
	if(clientWindow) {
		[clients removeObjectForKey:clientIdentifier];
		StainlessClient* newFocus = [clientWindow removeClient:client];

		if(newFocus == nil) {
			[self reconcileWid:[clientWindow wid]];

			if([layers count] == 1) {
				NSRect windowFrame = [[clientWindow frame] rectValue];
				
				NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
				[defaults setObject:[NSNumber numberWithFloat:windowFrame.origin.x] forKey:@"WindowOriginX"];
				[defaults setObject:[NSNumber numberWithFloat:windowFrame.origin.y] forKey:@"WindowOriginY"];
				[defaults setObject:[NSNumber numberWithFloat:windowFrame.size.width] forKey:@"WindowSizeWidth"];
				[defaults setObject:[NSNumber numberWithFloat:windowFrame.size.height] forKey:@"WindowSizeHeight"];
			}

			[layers removeObject:clientWindow];
			[windows removeObjectForKey:[clientWindow identifier]];
			
			NSDictionary* spaceWindows = [self windowsInCurrentSpace];
			
			if([spaceWindows count] == 0) {
				focus = nil;
				[NSApp activateIgnoringOtherApps:YES];
			}
			else {
				StainlessWindow* switchWindow = [[spaceWindows allValues] objectAtIndex:0];
				[self setFocus:[switchWindow focus]];
				[self focusWindow:switchWindow];
			}
		}
		else {
			if([newFocus isEqualTo:[clientWindow focus]])
				[self focusWindow:clientWindow];
			else {
				[self setFocus:newFocus];
				[clientWindow switchFocusToClient:newFocus];
			}
		}
	}
	else
		[clients removeObjectForKey:clientIdentifier];

	[client release];
	
	if([[tasks window] isVisible])
		[tasks reloadData];
}

- (void)killProcess:(id)sender
{	
	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	
	NSDictionary* processInfo = (NSDictionary*)sender;
	
	ProcessSerialNumber psn;
	psn.highLongOfPSN = [[processInfo objectForKey:@"highLongOfPSN"] longValue];
	psn.lowLongOfPSN = [[processInfo objectForKey:@"lowLongOfPSN"] longValue];
	KillProcess(&psn);	
	
	[pool release];
}

- (void)removeCacheForClientWithPid:(pid_t)pid
{
	@try {
		NSFileManager* fm = [NSFileManager defaultManager];
		NSString* libraryPath = [NSString stringWithFormat:@"%@/Library/Caches/Stainless", NSHomeDirectory()];
		if([fm fileExistsAtPath:libraryPath]) {
			if(pid == 0)
				[fm removeItemAtPath:libraryPath error:nil];
			else {
				NSString* cachePath = [NSString stringWithFormat:@"%@/%d", libraryPath, pid];
				[fm removeItemAtPath:cachePath error:nil];
			}
		}
	}
	
	@catch (NSException* anException) {
		NSLog(@"%@ exception removing cache for %d: %@", [anException name], pid, [anException reason]);
	}
}

- (NSInteger)widForTop
{
	StainlessWindow* topWindow = nil;
	
	if(topWindow == nil && focus) {
		NSString* container = [focus container];
		topWindow = [windows objectForKey:container];
	}

	if(topWindow)
		return [topWindow wid];
	
	return 0;
}

- (NSInteger)widForBottom
{
	StainlessWindow* bottomWindow = [layers lastObject];
	
	if(bottomWindow)
		return [bottomWindow wid];
	
	return 0;
}

- (void)reconcileWid:(NSInteger)wid
{
	for(StainlessPanel* panel in [NSApp windows]) {
		if([panel isVisible] && [panel focusWid] == wid)
			[panel setFocusWid:0];
	}
}

// NSTableView delegate
- (void)tableViewSelectionDidChange:(NSNotification *)aNotification
{
	if([[aNotification object] isEqualTo:tasks]) {
		self.selectedTask = nil;
		
		if([tasks selectedRow] == -1) {
			[closeTask setEnabled:NO];
			return;
		}
		
		NSInteger rowIndex = [tasks selectedRow];
		NSArray* sortedClients = [[clients allValues] sortedArrayUsingSelector:@selector(pidCompare:)];

		if([sortedClients count] <= rowIndex) {
			[closeTask setEnabled:NO];
			return;
		}

		StainlessClient* client = [sortedClients objectAtIndex:rowIndex];
		NSString* clientIdentifier = [client identifier];
		if(clientIdentifier) {
			self.selectedTask = [NSString stringWithString:clientIdentifier];
			[closeTask setEnabled:YES];
		}
		else
			[closeTask setEnabled:NO];
	}
}

- (NSString *)tableView:(NSTableView *)aTableView toolTipForCell:(NSCell *)aCell rect:(NSRectPointer)rect tableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)row mouseLocation:(NSPoint)mouseLocation
{
	if([aTableView isEqualTo:downloads]) {
		if([[aTableColumn identifier] isEqualToString:@"fileIconColumn"]) {
			NSArray* list = [[downloadInfo allValues] sortedArrayUsingSelector:@selector(indexKeyCompare:)];
			NSMutableDictionary* info = [list objectAtIndex:row];
			return [info objectForKey:@"FileName"];
		}
	}
	
	return nil;
}

- (void)tableView:(NSTableView *)aTableView willDisplayCell:(id)aCell forTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
	if([aTableView isEqualTo:downloads]) {
		if([[aTableColumn identifier] isEqualToString:@"fileProgressColumn"]) {
			NSArray* list = [[downloadInfo allValues] sortedArrayUsingSelector:@selector(indexKeyCompare:)];
			NSMutableDictionary* info = [list objectAtIndex:rowIndex];
			if([info objectForKey:@"Fail"]) {
				[aCell setLevelIndicatorStyle:NSRatingLevelIndicatorStyle];
				[aCell setMaxValue:0.0];
			}
			else {
				[aCell setLevelIndicatorStyle:NSContinuousCapacityLevelIndicatorStyle];
				[aCell setMaxValue:100.0];
			}
		}
	}
}

// NSTableDataSource protocol
- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView
{
	if([aTableView isEqualTo:tasks])
		return [clients count];

	if([aTableView isEqualTo:downloads])
		return [downloadInfo count];

	if(filteredHistoryList)
		return [filteredHistoryList count];
	
	return [historyList count];
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
	if([aTableView isEqualTo:tasks]) {
		NSArray* sortedClients = [[clients allValues] sortedArrayUsingSelector:@selector(pidCompare:)];
		if([sortedClients count] <= rowIndex)
			return nil;
		
		StainlessClient* client = [sortedClients objectAtIndex:rowIndex];

		if([client pid] == 0)
			return nil;

		if([[aTableColumn identifier] isEqualToString:@"clientIconColumn"])
			return [client icon];
		else if([[aTableColumn identifier] isEqualToString:@"clientNameColumn"])
			return [client title];
		else if([[aTableColumn identifier] isEqualToString:@"clientProcessColumn"])
			return [NSString stringWithFormat:@"%d", [client pid]];
	}
	else if([aTableView isEqualTo:downloads]) {
		NSArray* list = [[downloadInfo allValues] sortedArrayUsingSelector:@selector(indexKeyCompare:)];
		NSMutableDictionary* info = [list objectAtIndex:rowIndex];
		
		if([[aTableColumn identifier] isEqualToString:@"fileIconColumn"])
			return [info objectForKey:@"Icon"];
		
		if([[aTableColumn identifier] isEqualToString:@"fileNameColumn"]) {
			NSString* fileName = [[info objectForKey:@"FileName"] lastPathComponent];
			//if([fileName hasSuffix:@".download"])
			//	fileName = [fileName substringToIndex:[fileName length] - 9];
			
			return fileName;
		}

		if([[aTableColumn identifier] isEqualToString:@"fileSizeColumn"])
			return [info objectForKey:@"Status"];
		
		if([[aTableColumn identifier] isEqualToString:@"fileProgressColumn"]) {
			long long ratio = 0;
			
			NSNumber* currentLength = [info objectForKey:@"ContentLength"];
			if(currentLength) {				
				
				long long length = [currentLength longLongValue];
				if(length != NSURLResponseUnknownLength && length != 0) {
					NSNumber* currentBytes = [info objectForKey:@"Bytes"];
					
					long long bytes = [currentBytes longLongValue];
					ratio = ((long long) 100 * bytes) / length;
				}
			}
			
			return [NSNumber numberWithLongLong:ratio]; 
		}	
	}
	else {
		NSArray* list = (filteredHistoryList ? filteredHistoryList : historyList);
		/*if([[aTableColumn identifier] isEqualToString:@"historyIconColumn"]) {
			Class webIconDatabaseClass = NSClassFromString(@"WebIconDatabase");
			if(webIconDatabaseClass) {
				id iconDB = [webIconDatabaseClass performSelector:@selector(sharedIconDatabase)];
				NSSize WebIconSmallSize = {16, 16};
				return [iconDB iconForURL:[[items objectAtIndex:rowIndex] URLString] withSize:WebIconSmallSize];
			}
		}*/

		if([[aTableColumn identifier] isEqualToString:@"historyTitleColumn"])
			return [[list objectAtIndex:rowIndex] title];
		
		if([[aTableColumn identifier] isEqualToString:@"historyURLColumn"])
			return [[list objectAtIndex:rowIndex] URLString];
	}
	
	return nil;
}

// NSMenu delegate
- (NSInteger)numberOfItemsInMenu:(NSMenu *)menu
{
	NSInteger itemCount = 8;
	if([windows count])
		itemCount += [windows count] + 1;
	
	return itemCount;
}

- (void)menuNeedsUpdate:(NSMenu *)menu
{
	while([menu numberOfItems] > 8)
		[menu removeItemAtIndex:8];

	if([windows count])
		[menu addItem:[NSMenuItem separatorItem]];
	
	NSArray* windowList = [[windows allValues] sortedArrayUsingSelector:@selector(identifierCompare:)];
	for(StainlessWindow* container in windowList) {
		StainlessClient* client = [container focus];
		NSString* clientTitle = [client title];
		if(clientTitle) {
			NSMenuItem* item = [menu addItemWithTitle:[NSString stringWithString:clientTitle] action:@selector(switchWindow:) keyEquivalent:@""];
			[item setTarget:self];
			[item setRepresentedObject:[NSString stringWithString:[container identifier]]];
			[item setEnabled:YES];

			if([client isEqualTo:focus])
				[item setState:NSOnState];
		}
	}
}

@end


@implementation WebHistoryItem (CountCompare)
- (NSComparisonResult)visitCountCompare:(WebHistoryItem*)item
{
	int k1 = [self visitCount];
	int k2 = [item visitCount];
	
	if(k1 == k2)
		return NSOrderedSame;
	
	if(k1 > k2)
		return NSOrderedAscending;
	
	return NSOrderedDescending;
}
@end


@implementation NSMutableDictionary (KeyCompare)
- (NSComparisonResult)indexKeyCompare:(NSMutableDictionary*)dict
{
	int k1 = [[self objectForKey:@"Index"] intValue];
	int k2 = [[dict objectForKey:@"Index"] intValue];
	
	if(k1 > k2)
		return NSOrderedAscending;
	
	return NSOrderedDescending;
}
@end

