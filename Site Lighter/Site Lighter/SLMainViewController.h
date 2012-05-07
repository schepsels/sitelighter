//
//  SLMainViewController.h
//  Site Lighter
//
//  Created by Pim Snel on 04-05-12.
//  Copyright (c) 2012 Lingewoud b.v. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface SLMainViewController : NSViewController <NSTableViewDelegate>

@property (retain) IBOutlet NSTableView* sitesTable;
@property (retain) IBOutlet NSArrayController* sitesArrayController;
@property BOOL showDebugMessages;


//@property (retain) IBOutlet NSView* mainView;

-(IBAction)testSettings:(id)sender;
-(IBAction)optimize:(id)sender;
-(IBAction)visitSite:(id)sender;
@end
