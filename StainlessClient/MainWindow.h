//
//  MainWindow.h
//  StainlessClient
//
//  Created by Danny Espinoza on 3/19/09.
//  Copyright 2009 Mesa Dynamics, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface MainWindow : NSWindow {
	IBOutlet NSTextField* query;
}

@end

@class WebHTMLView;

@interface WebHTMLView
- (Class)class;
#if 0
- (BOOL)validateUserInterfaceItemWithoutDelegate:(id <NSValidatedUserInterfaceItem>)item;
#endif
@end
