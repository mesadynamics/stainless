//
//  StainlessController.m
//  Stainless
//
//  Created by Danny Espinoza on 9/3/08.
//  Copyright 2008 Mesa Dynamics, LLC. All rights reserved.
//

#import <Carbon/Carbon.h>
#import "StainlessController.h"
#import "StainlessBridge.h"
#import "StainlessPanel.h"
#import "Transformers.h"
//#import "CGSInternal.h"

extern SInt32 gOSVersion;

ProcessSerialNumber gServerProcess;
ProcessSerialNumber gTransportProcess;
bool gTransporting = false;
bool gQuitting = false;

static
OSStatus handleAppFrontSwitched(EventHandlerCallRef inHandlerCallRef, EventRef inEvent, void* inUserData)
{
	StainlessController* controller = (StainlessController*) inUserData;
	[controller frontAppChanged];
	
	return 0;
}


@implementation StainlessController

@synthesize ignoreActivation;
@synthesize activeBundle;

- (id)init
{
	if(self = [super init]) {
		NSMutableDictionary* defaults = [NSMutableDictionary dictionary];
		
		NSRect windowFrame  = NSMakeRect(0.0, 0.0, 1000.0, 1000.0);
		NSScreen* mainScreen = [NSScreen mainScreen];
		NSRect screenFrame = [mainScreen visibleFrame];
		if(windowFrame.size.width > screenFrame.size.width)
			windowFrame.size.width = screenFrame.size.width - 24.0;
		if(windowFrame.size.height > screenFrame.size.height)
			windowFrame.size.height = screenFrame.size.height - 24.0;
		
		CGFloat menuBarHeight;
#ifdef __LP64__ 
		menuBarHeight = [[NSApp mainMenu] menuBarHeight]; 
#else
		menuBarHeight = [NSMenuView menuBarHeight]; 
#endif
		
		windowFrame.origin.x += (screenFrame.size.width - windowFrame.size.width) * .5;
		windowFrame.origin.y = (screenFrame.origin.y + screenFrame.size.height) - (menuBarHeight + windowFrame.size.height + 4);
		
		// (Environment)
		[defaults setObject:[NSNumber numberWithFloat:windowFrame.origin.x] forKey:@"WindowOriginX"];
		[defaults setObject:[NSNumber numberWithFloat:windowFrame.origin.y] forKey:@"WindowOriginY"];
		[defaults setObject:[NSNumber numberWithFloat:windowFrame.size.width] forKey:@"WindowSizeWidth"];
		[defaults setObject:[NSNumber numberWithFloat:windowFrame.size.height] forKey:@"WindowSizeHeight"];

		[defaults setObject:[NSNumber numberWithBool:YES] forKey:@"ShowIconShelf"];
		[defaults setObject:[NSNumber numberWithBool:NO] forKey:@"ShowStatusBar"];

		[defaults setObject:[NSNumber numberWithBool:NO] forKey:@"DisablePopupBlock"];

		// General
		[defaults setObject:[NSNumber numberWithInt:100] forKey:@"StartupAction"];
		[defaults setObject:@"" forKey:@"HomePage"];
		[defaults setObject:[NSNumber numberWithBool:YES] forKey:@"NewWindowsHome"];
		[defaults setObject:[NSNumber numberWithBool:YES] forKey:@"NewTabsHome"];
		[defaults setObject:@"Google" forKey:@"DefaultSearch"];
		[defaults setObject:[NSNumber numberWithInt:100] forKey:@"DownloadSelection"];
		[defaults setObject:@"" forKey:@"DownloadLocation"];
		
		// Bookmarks
		[defaults setObject:[NSNumber numberWithBool:NO] forKey:@"AutoHideShowShelf"];
		[defaults setObject:[NSNumber numberWithBool:NO] forKey:@"MouseOverGroups"];
		[defaults setObject:[NSNumber numberWithBool:NO] forKey:@"ClickCloseGroups"];
		[defaults setObject:[NSNumber numberWithBool:NO] forKey:@"AutoCloseGroups"];
		[defaults setObject:[NSNumber numberWithBool:NO] forKey:@"ClosePropertiesOnChanges"];
				
		// Tabs
		[defaults setObject:[NSNumber numberWithBool:NO] forKey:@"SingleWindowMode"];
		[defaults setObject:[NSNumber numberWithBool:NO] forKey:@"SpawnAdjacentTabs"];
		[defaults setObject:[NSNumber numberWithBool:NO] forKey:@"ConfirmKeyboardQuit"];
		
		// Security
		[defaults setObject:[NSNumber numberWithBool:NO] forKey:@"ClearHistoryOnQuit"];
		[defaults setObject:[NSNumber numberWithBool:NO] forKey:@"DeleteCookiesOnQuit"];
		[defaults setObject:[NSNumber numberWithBool:NO] forKey:@"DisablePlugins"];
		[defaults setObject:[NSNumber numberWithBool:NO] forKey:@"DisableJava"];
		[defaults setObject:[NSNumber numberWithBool:NO] forKey:@"DisableJavaScript"];
		[defaults setObject:[NSNumber numberWithBool:NO] forKey:@"DefaultPrivateWindows"];
		[defaults setObject:[NSNumber numberWithBool:NO] forKey:@"DefaultSingleSessions"];
		
		// Advanced
		[defaults setObject:[NSNumber numberWithBool:NO] forKey:@"DisableSearching"];
		[defaults setObject:[NSNumber numberWithBool:YES] forKey:@"EnableHotSpare"];
		[defaults setObject:[NSNumber numberWithBool:NO] forKey:@"ShutdownUnresponsiveTabs"];
		[defaults setObject:[NSNumber numberWithBool:NO] forKey:@"EnableDeveloperExtras"];
		[defaults setObject:[NSNumber numberWithBool:NO] forKey:@"LoadWebKit"];
		[defaults setObject:[NSNumber numberWithBool:NO] forKey:@"EnableGears"];
		
 		[[NSUserDefaults standardUserDefaults] registerDefaults:defaults];
		[[NSUserDefaultsController sharedUserDefaultsController] setInitialValues:defaults];
		[[NSUserDefaultsController sharedUserDefaultsController] setAppliesImmediately:NO];

		NSValueTransformer* transformer = [[[SelectionIsNotOther alloc] init] autorelease];
		[NSValueTransformer setValueTransformer:transformer forName:@"SelectionIsNotOther"];

		serverPort = nil;
		cookiePort = nil;
		
		ignoreActivation = YES;
		ignoreSwitch = NO;
		ignoreSessionSave = NO;
		forceSessionSave = NO;
		//focusAllWindows = NO;
		
		prefLocationSet = YES;
		
		quitConfirm = nil;
		ignoreQuitConfirm = NO;
		
		activeBundle = nil;
		transportCoda = nil;
	}

	return self;
}

- (void)awakeFromNib
{
	//id manager = [NSConnection rootProxyForConnectionWithRegisteredName:@"StainlessServer" host:nil];
	//if(manager)
	//	exit(0);

	GetCurrentProcess(&gServerProcess);
	
	NSFileManager* fm = [NSFileManager defaultManager];
	NSString* libraryPath = [NSString stringWithFormat:@"%@/Library/Preferences/Stainless", NSHomeDirectory()];
	if([fm fileExistsAtPath:libraryPath] == NO)
		[fm createDirectoryAtPath:libraryPath attributes:nil];
	
	NSString* cookiePath = [NSString stringWithFormat:@"%@/Cookies.plist", libraryPath];
	[[StainlessCookieJar sharedCookieJar] readCookiesFromPath:cookiePath];
	
	cookiePort = [[NSConnection serviceConnectionWithName:@"StainlessCookieServer" rootObject:[[StainlessCookieServer alloc] init]] retain];
	[cookiePort runInNewThread];
	[cookiePort removeRunLoop:[NSRunLoop currentRunLoop]];

	serverPort = [[NSConnection defaultConnection] retain];
    [serverPort setRootObject:server];
    [serverPort registerName:@"StainlessServer"];
		
	if(gOSVersion < 0x1060)
		[server launchManager];
	
	NSUserDefaults* stainlessDefaults = [NSUserDefaults standardUserDefaults];
	
	if([stainlessDefaults stringForKey:@"NSWindow Frame ProcessWindow"] == nil) {
		[taskManager center];
	}
	
	if([stainlessDefaults stringForKey:@"NSWindow Frame DownloadsWindow"] == nil) {
		[downloads center];
	}
	
	if([stainlessDefaults stringForKey:@"NSWindow Frame HistoryWindow"] == nil) {
		NSScreen* screen = [NSScreen mainScreen];
		NSRect screenFrame = [screen visibleFrame];
		NSRect windowFrame = [historyList frame];
		windowFrame.origin.x = (screenFrame.origin.x + screenFrame.size.width) - windowFrame.size.width;
		windowFrame.origin.y = screenFrame.origin.y + screenFrame.size.height;
		windowFrame.size.height = screenFrame.size.height;
		[historyList setFrame:windowFrame display:NO];
	}
	
	if([stainlessDefaults stringForKey:@"NSWindow Frame PreferencesWindow"] == nil) {
		[preferences center];
	}
	
	[taskManager setLevel:NSNormalWindowLevel];
	[downloads setLevel:NSNormalWindowLevel];
	[historyList setLevel:NSNormalWindowLevel];
	[preferences setLevel:NSNormalWindowLevel];
	
	//[taskManager setBecomesKeyOnlyIfNeeded:YES];
	//[downloads setBecomesKeyOnlyIfNeeded:YES];
	//[historyList setBecomesKeyOnlyIfNeeded:YES];
	//[preferences setBecomesKeyOnlyIfNeeded:YES];

	NSNumber* popupBlock = [stainlessDefaults objectForKey:@"DisablePopupBlock"];
	[menuBlockPopups setState:([popupBlock boolValue] ? NSOffState : NSOnState)];
	
	if([[stainlessDefaults objectForKey:@"DefaultPrivateWindows"] boolValue]) {
		[server setForcePrivate:YES];
		
		NSMenu* targetMenu = [[[NSApp mainMenu] itemAtIndex:1] submenu];
		NSMenuItem* i1 = [targetMenu itemWithTitle:@"New Window"];
		NSString* t1 = [i1 title];
		NSMenuItem* i2 = [targetMenu itemWithTitle:@"New Private Browsing Window"];
		NSString* t2 = [i2 title];
		[i1 setTitle:t2];
		[i2 setTitle:t1];
	}
	
	if([[stainlessDefaults objectForKey:@"DefaultSingleSessions"] boolValue]) {
		[server setForceSingle:YES];
		
		NSMenu* targetMenu = [[[NSApp mainMenu] itemAtIndex:1] submenu];
		NSMenuItem* i1 = [targetMenu itemWithTitle:@"New Tab"];
		NSString* t1 = [i1 title];
		NSMenuItem* i2 = [targetMenu itemWithTitle:@"New Single Session Tab"];
		NSString* t2 = [i2 title];
		[i1 setTitle:t2];
		[i2 setTitle:t1];
	}
	
	NSArray* toolbarItems = [toolbar items];
	NSToolbarItem* toolbarItem = [toolbarItems objectAtIndex:0];
	[toolbar setSelectedItemIdentifier:[toolbarItem itemIdentifier]];
	toolbarItem = [toolbarItems objectAtIndex:1];
	NSImage* icon = [[NSWorkspace sharedWorkspace] iconForFileType:NSFileTypeForHFSTypeCode(kToolbarFavoritesIcon)];
	[toolbarItem setImage:icon];
	toolbarItem = [toolbarItems objectAtIndex:2];
	icon = [[NSWorkspace sharedWorkspace] iconForFileType:NSFileTypeForHFSTypeCode(kToolbarCustomizeIcon)];
	[toolbarItem setImage:icon];
	toolbarItem = [toolbarItems objectAtIndex:3];
	icon = [[NSWorkspace sharedWorkspace] iconForFileType:NSFileTypeForHFSTypeCode(kAlertCautionIcon)];
	[toolbarItem setImage:icon];
	
	[[NSAppleEventManager sharedAppleEventManager] setEventHandler:self andSelector:@selector(getUrl:withReplyEvent:) forEventClass:kInternetEventClass andEventID:kAEGetURL];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(trackMenuEnd:) name:@"NSMenuDidEndTrackingNotification" object:[NSApp mainMenu]];
}

- (IBAction)newDocument:(id)sender
{
	if(sender && [server forcePrivate])
		[server setSpawnPrivate:YES];
	
	[server setSpawnAndFocus:YES];
	[server setSpawnWindow:YES];
	[server spawnClientWithURL:nil];
}

- (IBAction)createNewTab:(id)sender
{
	if(sender && [server forceSingle]) {
		CFUUIDRef uuidObj = CFUUIDCreate(NULL);
		CFStringRef uuidString = CFUUIDCreateString(NULL, uuidObj);
		NSString* sessionStamp = [NSString stringWithString:(NSString*)uuidString];
		CFRelease(uuidString);
		CFRelease(uuidObj);
		
		[server setSpawnAndFocus:YES];
		[server setSpawnSession:sessionStamp];
		[server createNewTab:nil];
	}
	else
		[server createNewTab];
}

- (IBAction)createIsolatedTab:(id)sender
{
	if([server forceSingle]) {
		[self createNewTab:nil];
		return;
	}

	CFUUIDRef uuidObj = CFUUIDCreate(NULL);
	CFStringRef uuidString = CFUUIDCreateString(NULL, uuidObj);
	NSString* sessionStamp = [NSString stringWithString:(NSString*)uuidString];
	CFRelease(uuidString);
	CFRelease(uuidObj);
 	
	[server setSpawnAndFocus:YES];
	[server setSpawnSession:sessionStamp];
	[server createNewTab:@"about:sessions"];
}

- (IBAction)createPrivateWindow:(id)sender
{
	if([server forcePrivate]) {
		[self newDocument:nil];
		return;
	}
		
	[server setSpawnPrivate:YES];
	[server setSpawnAndFocus:YES];
	[server setSpawnWindow:YES];
	[server spawnClientWithURL:@"about:private"];
}

- (IBAction)performCommand:(id)sender
{
	[server performCommand:[sender title]];
}

- (IBAction)bringAllToFront:(id)sender
{
	transportCoda = @"stainless:bringAllToFront";
}

- (IBAction)showAboutPage:(id)sender
{
	if(gTransporting) 
		transportCoda = @"about:stainless";
	else
		[server spawnClientWithURL:@"about:stainless"];
}

- (IBAction)showHelpPage:(id)sender
{
	if(gTransporting) 
		transportCoda = @"about:help";
	else
		[server spawnClientWithURL:@"about:help"];
}

- (IBAction)showShortcutsPage:(id)sender
{
	if(gTransporting) 
		transportCoda = @"about:shortcuts";
	else
		[server spawnClientWithURL:@"about:shortcuts"];
}

- (IBAction)checkForUpdates:(id)sender
{
	if(gTransporting) 
		transportCoda = @"about:updates";
	else
		[server spawnClientWithURL:@"about:updates"];
}

- (IBAction)updatePopupBlock:(id)sender
{
	NSMenuItem* item = (NSMenuItem*)sender;
	NSInteger state = ([sender state] == NSOnState ? NSOffState : NSOnState);
	[item setState:state];
		
	if(state == NSOnState) {
		[server refreshAllClients:SMHidePopups];
	}
	else {
		[server refreshAllClients:SMShowPopups];
	}
}

- (IBAction)chooseDownloadLocation:(id)sender
{
	NSUserDefaultsController* sharedDefaults = [NSUserDefaultsController sharedUserDefaultsController];
	NSUserDefaults* stainlessDefaults = [sharedDefaults defaults];
	NSString* path = [stainlessDefaults objectForKey:@"DownloadLocation"];
	
	NSOpenPanel* openPanel = [NSOpenPanel openPanel];
	[openPanel setCanChooseFiles:NO];
	[openPanel setCanChooseDirectories:YES];
	if([openPanel runModalForDirectory:path file:nil types:nil] == NSOKButton) {
		NSString* location = (NSString*) [[openPanel filenames] objectAtIndex:0];
		[prefLocation setStringValue:location];
		prefLocationSet = YES;
	}
}

- (IBAction)terminateLater:(id)sender
{
	if([sender tag] == 100)
		forceSessionSave = YES;
	
	[NSApp performSelectorOnMainThread:@selector(terminate:) withObject:sender waitUntilDone:NO];
}

- (IBAction)newDocumentFromDock:(id)sender
{
	ignoreActivation = YES;
	[NSApp activateIgnoringOtherApps:YES];
	
	[self newDocument:sender];
}

- (IBAction)getGears:(id)sender
{
	[server spawnClientWithURL:@"http://gears.google.com/"];
}

- (IBAction)getWebkit:(id)sender
{
	[server spawnClientWithURL:@"http://nightly.webkit.org/"];
}

- (IBAction)showSafariBookmarks:(id)sender
{
	[server spawnClientWithURL:@"bookmarks:safari"];
}

- (IBAction)showHistoryList:(id)sender
{
	[server refreshHistory];
	[historyList makeKeyAndOrderFront:self];
	[historyList orderFrontRegardless];
	
	ignoreActivation = YES;
	[NSApp activateIgnoringOtherApps:YES];
}

- (IBAction)showTaskManager:(id)sender
{
	[server refreshTaskManager:nil];
	[taskManager makeKeyAndOrderFront:self];
	[taskManager orderFrontRegardless];
	
	ignoreActivation = YES;
	[NSApp activateIgnoringOtherApps:YES];
}

- (IBAction)showDownloads:(id)sender
{
	[downloads makeKeyAndOrderFront:self];
	[downloads orderFrontRegardless];
	
	if(sender) {
		ignoreActivation = YES;
		[NSApp activateIgnoringOtherApps:YES];
	}
}

- (IBAction)showPreferences:(id)sender
{
	NSFileManager* fm = [NSFileManager defaultManager];
	NSString* gearsPath = @"/Library/InputManagers/GearsEnabler/GearsEnabler.bundle";
	[prefGears setEnabled:[fm fileExistsAtPath:gearsPath]];

	if(gOSVersion >= 0x1060) {
		[prefGears setHidden:YES];
		[prefGearsInfo setHidden:YES];
	}
	
	NSWorkspace* ws = [NSWorkspace sharedWorkspace];	
	[prefWebKit setEnabled:([ws absolutePathForAppBundleWithIdentifier:@"org.webkit.nightly.WebKit"] ? YES : NO)];
	
	saveGears = [prefGears state];
	saveWebKit = [prefWebKit state];
	
	[preferences makeKeyAndOrderFront:self];
	[preferences orderFrontRegardless];
	
	ignoreActivation = YES;
	[NSApp activateIgnoringOtherApps:YES];
}

- (IBAction)cancelPreferences:(id)sender
{
	[preferences orderOut:self];
	
	NSUserDefaultsController* sharedDefaults = [NSUserDefaultsController sharedUserDefaultsController];
	[sharedDefaults revert:self];
	
	[server focusAllWindows];
}

- (IBAction)savePreferences:(id)sender
{
	[preferences orderOut:self];
		
	NSUserDefaultsController* sharedDefaults = [NSUserDefaultsController sharedUserDefaultsController];
	[sharedDefaults save:self];

	if(saveGears != [prefGears state] || saveWebKit != [prefWebKit state])
		[server resetHotSpare];
	
	NSString* home = [prefHome stringValue];
	[server refreshAllClients:(home && [home length] ? SMShowHomeButton : SMHideHomeButton)];
	
	[server focusAllWindows];

	[server computeSearchString];	
}

- (IBAction)noopAction:(id)sender
{
	[server performCommand:[sender title]];
}

- (void)handleClientDisconnect:(id)sender
{	
	[server performSelectorOnMainThread:@selector(forgetClientWithIdentifier:) withObject:sender waitUntilDone:NO];
}

// Callbacks

- (void)getUrl:(NSAppleEventDescriptor *)event withReplyEvent:(NSAppleEventDescriptor *)replyEvent
{
	NSString* urlString = [[event paramDescriptorForKeyword:keyDirectObject] stringValue];
	[server spawnClientWithURL:urlString];
}

- (void)trackMenuEnd:(NSNotification*)aNotification
{	
	if(gTransporting) {
		gTransporting = false;

		NSArray* serverWindows = [NSApp windows];
		for(NSWindow* window in serverWindows) {
			if([window isFlushWindowDisabled])
				[window enableFlushWindow];
		}
		
		SetFrontProcess(&gTransportProcess);
		[server freezeAllWindows:NO];
	}	

	//if(focusAllWindows) {
	//	[server focusAllWindows];
	//	focusAllWindows = NO;
	//}
}

- (void)frontAppChanged
{
	if(gTransporting == false) {		 
		NSDictionary* activeApplication = [[NSWorkspace sharedWorkspace] activeApplication];
		NSString* newActiveBundle = [activeApplication objectForKey:@"NSApplicationBundleIdentifier"];
				
		BOOL shuffle = NO;
		if([newActiveBundle isEqualToString:@"com.stainlessapp.StainlessClient"]) {
			if(activeBundle && [activeBundle isEqualToString:@"com.stainlessapp.Stainless"] == NO && [activeBundle isEqualToString:@"com.stainlessapp.StainlessClient"] == NO)
				shuffle = YES;
			else {
				for(StainlessPanel* panel in [NSApp windows]) {
					if([panel focusOnAppChange]) {
						[panel setFocusOnAppChange:NO];
						
						NSInteger wid = [panel focusWid];
						NSInteger mode = [panel focusMode];
											
						if(wid == 0) {
							wid = [server widForBottom];
							
							if(wid == 0)
								[panel orderFront:self];
							else
								mode = NSWindowBelow;
						}
						
						if(wid) {
							@try {
								[panel orderWindow:mode relativeTo:wid];
							}
							
							@catch (NSException* anException) {
								[panel orderFront:self];
							}
						}
					}	
				}
			}
		}
		
		self.activeBundle = newActiveBundle;
		
		if(ignoreSwitch == NO && shuffle)
			[self performSelectorOnMainThread:@selector(shuffleProcesses:) withObject:activeApplication waitUntilDone:NO];
	}
}

- (void)shuffleProcesses:(NSDictionary*)activeApplication
{
	ignoreActivation = YES;
	ignoreSwitch = YES;
	
	for(StainlessPanel* panel in [NSApp windows]) {
		if([panel isVisible]) {
			[panel orderOut:self];
			[panel setFocusOnAppChange:YES];
		}
	}
	
	ProcessSerialNumber clientProcess;
	clientProcess.highLongOfPSN = [[activeApplication objectForKey:@"NSApplicationProcessSerialNumberHigh"] longValue];
	clientProcess.lowLongOfPSN = [[activeApplication objectForKey:@"NSApplicationProcessSerialNumberLow"] longValue];
	
	SetFrontProcess(&gServerProcess);
	SetFrontProcess(&clientProcess);
	
	ignoreSwitch = NO;
}

// NSMenu delegate
- (void)menuWillOpen:(NSMenu *)menu
{
}

- (void)menuDidClose:(NSMenu *)menu
{
}

// NSWindow delegate
- (void)windowWillClose:(NSNotification *)notification
{
	ignoreActivation = YES;
	[NSApp activateIgnoringOtherApps:YES];

	StainlessPanel* window = (StainlessPanel*)[notification object];
	[window setFocusOnAppChange:NO];
	[window orderOut:self];
		
	[server focusAllWindows];
}

- (void)windowDidBecomeKey:(NSNotification *)notification
{
	NSInteger wid = [server widForTop];
	StainlessPanel* window = (StainlessPanel*)[notification object];
	[window setFocusWid:wid];
	[window setFocusMode:NSWindowAbove];
}

/*- (void)windowDidUpdate:(NSNotification *)notification
{
	NSWindow* window = (NSWindow*)[notification object];
	if([window isEqualTo:taskManager])
		[server refreshTaskManager:nil];
}*/
	
// NSApplication delegate
- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	/*NSString* dbPath = [NSString stringWithFormat:@"%@/Library/Preferences/Stainless/Databases/Databases.db", NSHomeDirectory()];
	if([fm fileExistsAtPath:dbPath] == NO) {
		NSManagedObjectModel* mom = [NSManagedObjectModel mergedModelFromBundles:nil];
		NSPersistentStoreCoordinator* psc = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:mom];
		NSError* error = nil;
		[psc addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:[NSURL fileURLWithPath:dbPath] options:nil error:&error];
		[error release];
	}*/
		
	EventTypeSpec spec = { kEventClassApplication, kEventAppFrontSwitched };
	InstallApplicationEventHandler(NewEventHandlerUPP(handleAppFrontSwitched), 1, &spec, (void*)self, NULL);
	
	[NSThread detachNewThreadSelector:@selector(processMonitor:) toTarget:server withObject:nil];
}

- (void)applicationDidBecomeActive:(NSNotification *)aNotification
{
	if(gTransporting == false) {
		if(ignoreActivation)
			ignoreActivation = NO;
		else {
			if([server hasClients])
				[server focusMainWindow];
		}
	}
}

- (void)applicationWillResignActive:(NSNotification *)aNotification
{
	activeTimerCount = 0;
	
	if(gTransporting) {
		gTransporting = false;
		
		NSArray* serverWindows = [NSApp windows];
		for(NSWindow* window in serverWindows) {
			if([window isFlushWindowDisabled])
				[window enableFlushWindow];
		}
		
		[server freezeAllWindows:NO];
	}
}

- (void)applicationDidResignActive:(NSNotification *)aNotification
{
	if(transportCoda) {
		if([transportCoda isEqualToString:@"stainless:bringAllToFront"])
			[server focusAllWindows];
		else
			[server spawnClientWithURL:transportCoda];
		
		[transportCoda release];
		transportCoda = nil;
	}
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender
{
	if(ignoreQuitConfirm == NO && [server hasDownloads]) {
		[self showDownloads:self];
		
		if(quitConfirm == nil) {
			quitConfirm = [NSAlert alertWithMessageText:NSLocalizedString(@"QuitTitle", @"")
											 defaultButton:NSLocalizedString(@"QuitOK", @"")
										   alternateButton:NSLocalizedString(@"QuitCancel", @"")
											   otherButton:nil
								 informativeTextWithFormat:NSLocalizedString(@"QuitMessage", @"")];
			
			[quitConfirm retain];
			
			[quitConfirm setAlertStyle:NSCriticalAlertStyle];
			[quitConfirm beginSheetModalForWindow:downloads modalDelegate:self didEndSelector:@selector(alertDidEnd:returnCode:contextInfo:) contextInfo:nil];
		}
		
		return NSTerminateCancel;
	}
	
	return NSTerminateNow;
}

- (void)alertDidEnd:(NSAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo
{		
	if(returnCode) {
		ignoreQuitConfirm = YES;
		[NSApp terminate:self];
	}
	
	[quitConfirm release];
	quitConfirm = nil;
}

- (void)applicationWillTerminate:(NSNotification *)aNotification
{
	gQuitting = true;

	[taskManager orderOut:nil];
	[historyList orderOut:nil];
	[downloads orderOut:nil];
	[preferences orderOut:nil];
	
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[cookiePort registerName:nil];
	[cookiePort invalidate];
	[cookiePort release];
	
	[serverPort registerName:nil];
	[serverPort invalidate];
	[serverPort release];
	
	[server closeAllClients];
			
	NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
	BOOL popupBlock = ([menuBlockPopups state] == NSOnState ? NO : YES);
	[defaults setObject:[NSNumber numberWithBool:popupBlock] forKey:@"DisablePopupBlock"];
	
	if(prefLocationSet)
		[defaults setObject:[prefLocation stringValue] forKey:@"DownloadLocation"];

	NSNumber* action = [defaults objectForKey:@"StartupAction"];	
	if([action intValue] == 400) {
		if(ignoreSessionSave == NO)
			[server saveSessions:YES];
	}
	else
		[server saveSessions:forceSessionSave];

	[server saveFocusWindow];

	NSFileManager* fm = [NSFileManager defaultManager];
	NSString* libraryPath = [NSString stringWithFormat:@"%@/Library/Preferences/Stainless", NSHomeDirectory()];
	if([fm fileExistsAtPath:libraryPath] == NO)
		[fm createDirectoryAtPath:libraryPath attributes:nil];

	NSString* killPath = [NSString stringWithFormat:@"%@/safari_StainlessImport.html", NSTemporaryDirectory()];
	[fm removeItemAtPath:killPath error:nil];
	killPath = [NSString stringWithFormat:@"%@/firefox_StainlessImport.html", NSTemporaryDirectory()];
	[fm removeItemAtPath:killPath error:nil];

	BOOL purge = NO;
	NSString* cookiePath = [NSString stringWithFormat:@"%@/Cookies.plist", libraryPath];
	NSNumber* cookies = [defaults objectForKey:@"DeleteCookiesOnQuit"];
	if(cookies && [cookies boolValue])
		purge = YES;
	[[StainlessCookieJar sharedCookieJar] writeCookiesToPath:cookiePath purge:purge];
	
	NSString* historyPath = [NSString stringWithFormat:@"%@/History.plist", libraryPath];
	NSError* error = nil;
	
	NSNumber* history = [defaults objectForKey:@"ClearHistoryOnQuit"];
	if(history && [history boolValue])
		[fm removeItemAtPath:historyPath error:nil];
	else
		[[WebHistory optionalSharedHistory] saveToURL:[NSURL fileURLWithPath:historyPath] error:&error];
	
	if(error) {
		NSLog(@"Error writing history %@: %@", historyPath, error);
		[error release];
	}
}

- (BOOL)application:(NSApplication *)theApplication openFile:(NSString *)filename
{
	NSString* urlString = nil;
	
	if([server spawnCount] == 0)
		ignoreSessionSave = YES;
	
	if([filename hasSuffix:@".webloc"]) {
		NSString* err = nil;
		NSData* data = [NSData dataWithContentsOfFile:filename];
		id plist = [NSPropertyListSerialization propertyListFromData:data
													mutabilityOption:NSPropertyListImmutable
															  format:nil
													errorDescription:&err];
		
		if(plist)
			urlString = [plist objectForKey:@"URL"];
		else {
			char* urlBytes = NULL;
			
			NSURL* url = [NSURL fileURLWithPath:filename];
			FSRef ref;
			if(CFURLGetFSRef((CFURLRef)url, &ref) == false)
				return NO;
			
			HFSUniStr255 rfName;
			if(FSGetResourceForkName(&rfName) != noErr)
				return NO;

			FSIORefNum refNum;
			if(FSOpenFork(&ref, rfName.length, rfName.unicode, fsRdPerm, &refNum) != noErr)
				return NO;
			
			char lengthByte;
			if(FSReadFork(refNum, fsFromStart, 327, 1, &lengthByte, NULL) == noErr && lengthByte) {
				urlBytes = (char*) calloc(1, lengthByte + 1);
				if(urlBytes) {
					if(FSReadFork(refNum, fsAtMark, 327, lengthByte, urlBytes, NULL) != noErr) {
						free(urlBytes);
						urlBytes = NULL;
					}
				}
			}
				
			FSCloseFork(refNum);
						
			if(urlBytes) {
				urlString = [NSString stringWithCString:urlBytes encoding:NSMacOSRomanStringEncoding];
				free(urlBytes);
			}
		}
	}
	else {
		NSURL* url = [NSURL fileURLWithPath:filename];
		urlString = [url absoluteString];
	}
	
	if(urlString) {
		[server spawnClientWithURL:urlString];
		return YES;
	}
	
	return NO;
}

- (void)applicationWillHide:(NSNotification *)aNotification
{
	[server hideAllWindows:YES];
}

- (void)applicationDidUnhide:(NSNotification *)aNotification
{
	[server hideAllWindows:NO];
}

- (BOOL)applicationOpenUntitledFile:(NSApplication *)theApplication
{
	static BOOL firstLaunch = YES;
	
	if([server hasClients] == NO) {
		if(firstLaunch == YES) {
			if([server restoreSessions]) {
				firstLaunch = NO;
				return YES;
			}			
		}
		
		[self newDocument:self];
		
		firstLaunch = NO;
		return YES;
	}
	
	firstLaunch = NO;
	return NO;
}

// NSToolbar delegate
- (NSArray *)toolbarSelectableItemIdentifiers:(NSToolbar *)tb
{
	return [[tb items] valueForKey:@"itemIdentifier"];
}

@end


@implementation NSWindow (Stainless)

- (BOOL)_hasActiveControls
{
	return YES;
}

@end


@implementation NSPanel (Stainless)

- (void)sendEvent:(NSEvent *)event
{
	[super sendEvent:event];
}

@end


@implementation NSToolbarItem (Stainless)

- (NSInteger)indexOfSelectedItem
{
	return [self tag];
}

@end


