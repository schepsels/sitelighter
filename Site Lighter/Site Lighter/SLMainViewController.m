//
//  SLMainViewController.m
//  Site Lighter
//
//  Created by Pim Snel on 04-05-12.
//  Copyright (c) 2012 Lingewoud b.v. All rights reserved.
//

#import "SLMainViewController.h"
#import "SLSite.h"
#import "WebToPng.h"
#import "AppDelegate.h"

@interface SLMainViewController ()

@end

@implementation SLMainViewController

@synthesize sitesTable;
@synthesize sitesArrayController;
@synthesize showDebugMessages;
@synthesize screenshotView;
@synthesize pdfView;
@synthesize pdfWindow;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        showDebugMessages = NO;

        if([[NSUserDefaults standardUserDefaults] boolForKey:@"showDebugMessages"])
        {
            showDebugMessages = YES;
        }
    }
    
    return self;
}

- (void) loadView{
    [super loadView];
  
    [SLSite defaultSite];
    self.sitesTable.delegate = self;
    //showDebugMessages = NO;
    

}

-(IBAction)openTutor:(id)sender{
    [pdfWindow makeKeyAndOrderFront:sender];
    
    NSBundle* myBundle = [NSBundle mainBundle];
    NSString* myPdfPath = [myBundle pathForResource:@"creating-a-lightbox-effect" ofType:@"pdf"];
    NSURL * mydocUrl = [NSURL fileURLWithPath:myPdfPath];

    
    [pdfView setDocument:[[PDFDocument alloc] initWithURL:mydocUrl]];   
}



- (void)controlTextDidEndEditing:(NSNotification *)aNotification
{
  
    NSTextField* textField = [aNotification object];
    NSString* newValue = [textField stringValue];
    
    SLSite * site = sitesArrayController.selectedObjects.lastObject;
    [site setValue: newValue forKey:@"url"];

    [self setSiteSceenShot];

}


#pragma mark IBActions

-(IBAction)testSettings:(id)sender{
    [[NSApp delegate] overlay1:sender];
    [self testFTPSettings];
    [[NSApp delegate] overlay1:sender];
 }

-(void)setSiteSceenShot {
    SLSite * site = sitesArrayController.selectedObjects.lastObject;
    
    NSString * filename = [self genRandStringLength:5];
    NSString * path = [[[NSApp delegate] applicationFilesDirectory] path];
       
    NSLog(@"fil:%@",filename);
    NSLog(@"path:%@",path);
    
    NSURL * url = [NSURL URLWithString:[site valueForKey:@"url"]];
    
    [[[WebToPng alloc] init] takeSnapshotOfURL:url
                           toPath:path
                             name:filename
                    viewToUpdate:screenshotView
                         original:YES
                            thumb:YES
                          clipped:YES
                            scale:0.25
                            width:200
                           height:150];
    

    NSString * completePath = [NSString stringWithFormat:@"%@/%@-thumb.png",path,filename];
    [site setValue: completePath forKey:@"screenshot"];
    NSLog(@"completepath:%@",completePath);
}




- (void) doAfterOptimize:(NSAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
   	if(returnCode == 0)
	{
		[self visitSite:self];
	}
}

- (void) doAfterAlert:(NSAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	if(returnCode == 0)
	{
		[self visitSite:self];
	}
}


-(NSString *) genRandStringLength: (int) len {
    NSString *letters = @"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";

    NSMutableString *randomString = [NSMutableString stringWithCapacity: len];
    
    for (int i=0; i<len; i++) {
        [randomString appendFormat: @"%C", [letters characterAtIndex: arc4random() % [letters length]]];
    }
    
    return randomString;
}

-(IBAction)optimize:(id)sender{

    
    [[NSApp delegate] overlay1:sender];

    SLSite * site = sitesArrayController.selectedObjects.lastObject;

    //[self getLastPathSegmentFromIndexWithFTP];
    //return;
    
    if([[NSUserDefaults standardUserDefaults] boolForKey:@"doDownload"])
    {
        [self refreshAndDownloadTree];
    }
    
    if([[site valueForKey:@"applyLightifyPlugin"] boolValue])
    {
        [self applyLightify];    
    }
    
    if([[NSUserDefaults standardUserDefaults] boolForKey:@"doFilter"])
    {
        [self textReplaceAllHTMLFiles];
    }
    if([[NSUserDefaults standardUserDefaults] boolForKey:@"doUpload"])
    {
        [self uploadTree];
    }
    [[NSApp delegate] overlay1:sender];
    [self setSiteSceenShot];
    
    NSAlert *alert =
    [NSAlert
     alertWithMessageText:@"Site optimization finished"
     defaultButton:@"Close"
     alternateButton:@"Visit website"
     otherButton:nil
     informativeTextWithFormat:@"Your site optimization has finished."];
    
    [alert beginSheetModalForWindow:[[NSApp delegate] window] modalDelegate:self didEndSelector:@selector(doAfterOptimize:returnCode:contextInfo:) contextInfo:nil];
}

-(IBAction)visitSite:(id)sender{
    SLSite * site = sitesArrayController.selectedObjects.lastObject;    
    NSURL * url = [NSURL URLWithString:[site valueForKey:@"url"]];
    
    [[NSWorkspace sharedWorkspace] openURL:url];
}

#pragma mark ruby wrapper stuff

-(void)testFTPSettings{
    if(showDebugMessages) NSLog(@"test ftp:");
    
    SLSite * site = sitesArrayController.selectedObjects.lastObject;
    NSString * wrapperPath = [NSString stringWithFormat:@"%@/Contents/Resources",[[NSBundle mainBundle] bundlePath]];
    NSString * rubyExec = @"/usr/bin/ruby";
    NSString * rubyScriptPath = [NSString stringWithFormat:@"%@/sitelighterlibwrapper.rb",wrapperPath];
    
    NSTask *rubyProcess = [[NSTask alloc] init];
    [rubyProcess setCurrentDirectoryPath:wrapperPath];
    [rubyProcess setLaunchPath: rubyExec];
    [rubyProcess setArguments: [NSArray arrayWithObjects:
                                rubyScriptPath,
                                @"--action",@"test",
                                @"--localdir",[self getLocalDir],
                                @"--server",[site valueForKey:@"ftpServer"],
                                @"--user",[site valueForKey:@"ftpUser"],
                                @"--pass",[site valueForKey:@"ftpPass"],
                                @"--path",[site valueForKey:@"ftpPath"],
                                nil]];
    [rubyProcess launch];
    
    [rubyProcess waitUntilExit];
    int status = [rubyProcess terminationStatus];
    
    if (status == 0){
        
        NSAlert *alert =
        [NSAlert
         alertWithMessageText:@"Site test"
         defaultButton:NSLocalizedStringFromTable(@"OK", @"Errors", @"Standard dialog dismiss button.")
         alternateButton:nil
         otherButton:nil
         informativeTextWithFormat:@"Connection was succesfull."];
        
        [alert beginSheetModalForWindow:[[NSApp delegate] window] modalDelegate:self didEndSelector:@selector(doAfterAlert:returnCode:contextInfo:) contextInfo:nil];

//        NSLog(@"Task test succeeded.");
    }
    else if (status == 1) {
        
        
        NSAlert *alert =
        [NSAlert
         alertWithMessageText:@"Site test"
         defaultButton:NSLocalizedStringFromTable(@"OK", @"Errors", @"Standard dialog dismiss button.")
         alternateButton:nil
         otherButton:nil
         informativeTextWithFormat:@"Connection failed."];
        
        [alert beginSheetModalForWindow:[[NSApp delegate] window] modalDelegate:self didEndSelector:@selector(doAfterAlert:returnCode:contextInfo:) contextInfo:nil];

    }
    else if (status == 2) {

        NSAlert *alert =
        [NSAlert
         alertWithMessageText:@"Site test"
         defaultButton:NSLocalizedStringFromTable(@"OK", @"Errors", @"Standard dialog dismiss button.")
         alternateButton:nil
         otherButton:nil
         informativeTextWithFormat:@"Path is incorrect."];
        
        [alert beginSheetModalForWindow:[[NSApp delegate] window] modalDelegate:self didEndSelector:@selector(doAfterAlert:returnCode:contextInfo:) contextInfo:nil];

       // NSLog(@"Task failed path error. %i",status);
    }
    
    [rubyProcess release];
}

-(NSString *)getLastPathSegmentFromIndexWithFTP{
    if(showDebugMessages) NSLog(@"get index ftp:");    

    SLSite * site = sitesArrayController.selectedObjects.lastObject;
    NSString * wrapperPath = [NSString stringWithFormat:@"%@/Contents/Resources",[[NSBundle mainBundle] bundlePath]];
    NSString * rubyExec = @"/usr/bin/ruby";
    NSString * rubyScriptPath = [NSString stringWithFormat:@"%@/sitelighterlibwrapper.rb",wrapperPath];
    
    NSTask *rubyProcess = [[NSTask alloc] init];    
    [rubyProcess setCurrentDirectoryPath:wrapperPath];
    [rubyProcess setLaunchPath: rubyExec];
    [rubyProcess setArguments: [NSArray arrayWithObjects:
                                rubyScriptPath,
                                @"--action",@"download",
                                @"--localdir",[self getLocalDir2],
                                @"--server",[site valueForKey:@"ftpServer"],
                                @"--user",[site valueForKey:@"ftpUser"],
                                @"--pass",[site valueForKey:@"ftpPass"],
                                @"--path",[site valueForKey:@"ftpPath"],                                
                                nil]];    
    [rubyProcess launch];        
    
    [rubyProcess waitUntilExit];
    int status = [rubyProcess terminationStatus];
    

    if (status == 0){
        NSLog(@"Task get Index succeeded.");

        NSLog(@"nw checking:%@",[NSString stringWithFormat:@"%@/%@",[self getLocalDir2],@"index.html"]);

        //Now get path segment
        if([[NSFileManager defaultManager] fileExistsAtPath: [NSString stringWithFormat:@"%@/%@",[self getLocalDir2],@"index.html"] isDirectory: NO])
        {
            
            NSString *filePath = [[self getLocalDir2] stringByAppendingPathComponent:@"index.html"];
            NSError *anError;
            NSString *fileText = [NSString stringWithContentsOfFile:filePath encoding:NSUTF8StringEncoding error:&anError];
            if (!fileText) {
                NSLog(@"Error: %@", [anError localizedDescription]);
            }
            else
            {
                //NSString * search = @"<meta http-equiv=\"refresh\" content=\"";
                
                NSString * search = @"<meta http-equiv=\"refresh\" content=\"0;url= ";
                if([fileText rangeOfString:search].location == NSNotFound)
                {
                    NSLog(@"http-equiv not found:%@",fileText);
                    
                }
                else {
                    NSString *sub1 = [fileText substringFromIndex:[fileText rangeOfString:search].location+43];
                    NSString *sub2 = [sub1 substringToIndex:[sub1 rangeOfString:@"/"].location];
                    
                    NSLog(@"redirect:%@",sub1);
                    NSLog(@"redirect:%@",sub2);
                    return sub2;
                }
            }
        }
        
        
    }
    else if (status == 1) {
        NSLog(@"Task failed connection error. %i",status);
    }
    else if (status == 2) {
        NSLog(@"Task failed path error. %i",status);
    }
    return @"";
    


    [rubyProcess release];
}

-(void)refreshAndDownloadTree{
    
    NSString *extraPathSegment = [self getLastPathSegmentFromIndexWithFTP];
    
    if(showDebugMessages) NSLog(@"refresh and download:");

    SLSite * site = sitesArrayController.selectedObjects.lastObject;
    
    NSString * wrapperPath = [NSString stringWithFormat:@"%@/Contents/Resources",[[NSBundle mainBundle] bundlePath]];
    NSString * rubyExec = @"/usr/bin/ruby";
    NSString * rubyScriptPath = [NSString stringWithFormat:@"%@/sitelighterlibwrapper.rb",wrapperPath];
    
    
    NSTask *rubyProcess = [[NSTask alloc] init];    
    [rubyProcess setCurrentDirectoryPath:wrapperPath];
    [rubyProcess setLaunchPath: rubyExec];
    [rubyProcess setArguments: [NSArray arrayWithObjects:
                                rubyScriptPath,
                                @"--action",@"download",
                                @"--localdir",[self getLocalDir],                                
                                @"--server",[site valueForKey:@"ftpServer"],
                                @"--user",[site valueForKey:@"ftpUser"],
                                @"--pass",[site valueForKey:@"ftpPass"],
                                @"--path",[NSString stringWithFormat:@"%@/%@",[site valueForKey:@"ftpPath"],extraPathSegment],
                                nil]];    
    [rubyProcess launch];        
    
    [rubyProcess waitUntilExit];
    int status = [rubyProcess terminationStatus];
    
    if (status == 0){
        NSLog(@"Task download and refresh localsite succeeded.");
    }
    else if (status == 1) {
        NSLog(@"Task failed refresh local site error. %i",status);
    }
    else if (status == 2) {
        NSLog(@"Task failed download error. %i",status);
    }
    
    [rubyProcess release];
}

-(void)applyLightify{
    if(showDebugMessages) NSLog(@"applyLightify:");    

    SLSite * site = sitesArrayController.selectedObjects.lastObject;
    
    NSString * wrapperPath = [NSString stringWithFormat:@"%@/Contents/Resources",[[NSBundle mainBundle] bundlePath]];
    NSString * rubyExec = @"/usr/bin/ruby";
    NSString * rubyScriptPath = [NSString stringWithFormat:@"%@/sitelighterlibwrapper.rb",wrapperPath];
    NSTask *rubyProcess = [[NSTask alloc] init];    
    [rubyProcess setCurrentDirectoryPath:wrapperPath];
    [rubyProcess setLaunchPath: rubyExec];
    [rubyProcess setArguments: [NSArray arrayWithObjects:
                                rubyScriptPath,
                                @"--action",@"applylightify",
                                @"--localdir",[self getLocalDir],                                
                                @"--server",[site valueForKey:@"ftpServer"],
                                @"--user",[site valueForKey:@"ftpUser"],
                                @"--pass",[site valueForKey:@"ftpPass"],
                                @"--path",[site valueForKey:@"ftpPath"],                                
                                nil]];    
    [rubyProcess launch];        
    
    [rubyProcess waitUntilExit];
    int status = [rubyProcess terminationStatus];
    
    if (status == 0){
        NSLog(@"Task applylightify succeeded.");
    }
    else if (status == 1) {
        NSLog(@"Task failed applylightify error. %i",status);
    }
    
    [rubyProcess release];
}

-(void)uploadTree{
    if(showDebugMessages) NSLog(@"uploadTree:");    

    NSString *extraPathSegment = [self getLastPathSegmentFromIndexWithFTP];

    SLSite * site = sitesArrayController.selectedObjects.lastObject;
    
    NSString * wrapperPath = [NSString stringWithFormat:@"%@/Contents/Resources",[[NSBundle mainBundle] bundlePath]];
    NSString * rubyExec = @"/usr/bin/ruby";
    NSString * rubyScriptPath = [NSString stringWithFormat:@"%@/sitelighterlibwrapper.rb",wrapperPath];
    
    
    NSTask *rubyProcess = [[NSTask alloc] init];    
    [rubyProcess setCurrentDirectoryPath:wrapperPath];
    [rubyProcess setLaunchPath: rubyExec];
    [rubyProcess setArguments: [NSArray arrayWithObjects:
                                rubyScriptPath,
                                @"--action",@"upload",
                                @"--localdir",[self getLocalDir],                                
                                @"--server",[site valueForKey:@"ftpServer"],
                                @"--user",[site valueForKey:@"ftpUser"],
                                @"--pass",[site valueForKey:@"ftpPass"],
                                @"--path",[NSString stringWithFormat:@"%@/%@",[site valueForKey:@"ftpPath"],extraPathSegment],
                                nil]];
    [rubyProcess launch];        
    
    [rubyProcess waitUntilExit];
    int status = [rubyProcess terminationStatus];
    
    if (status == 0){
        NSLog(@"Task upload succeeded.");
    }
    else if (status == 1) {
        NSLog(@"Task failed upload error. %i",status);
    }
    
    [rubyProcess release];
}


#pragma mark main filter loop

-(NSString *)getLocalDir{
    NSString * localDir = @"/tmp/sitelighter";
    return localDir;
}

-(NSString *)getLocalDir2{
    NSString * localDir = @"/tmp/sitelighter2";
    return localDir;
}

-(void)textReplaceAllHTMLFiles{
    SLSite * site = sitesArrayController.selectedObjects.lastObject;
    
    NSString* file;
    NSDirectoryEnumerator* enumerator = [[NSFileManager defaultManager] enumeratorAtPath:[self getLocalDir]];
    while (file = [enumerator nextObject])
    {
        BOOL isDirectory = NO;
        [[NSFileManager defaultManager] fileExistsAtPath: [NSString stringWithFormat:@"%@/%@",[self getLocalDir],file]
                                             isDirectory: &isDirectory];
        if (!isDirectory)
        {
            if ([file rangeOfString:@"/"].location == NSNotFound) {
                //THESE ARE THE ONES
                NSLog(@"file: %@",file);            
                NSString *filePath = [[self getLocalDir] stringByAppendingPathComponent:file];
                NSError *anError;
                NSString *fileContents = [NSString stringWithContentsOfFile:filePath
                                                                   encoding:NSUTF8StringEncoding
                                                                      error:&anError];
                if (!fileContents) {
                    NSLog(@"%@", [anError localizedDescription]);
                } else {
    
                    NSString *replacedString = [self replaceHeader:fileContents 
                                                                  :[site valueForKey:@"codeHeader"] 
                                                                  :[site valueForKey:@"metaKeywords"] 
                                                                  :[site valueForKey:@"metaDescription"]];
                    
                    replacedString = [self replaceFooter:replacedString 
                                                        :[site valueForKey:@"codeFooter"] 
                                                        :[site valueForKey:@"googleAnalyticsCode"]];
                    
                    replacedString = [self replaceTitle:replacedString 
                                                       :[site valueForKey:@"titlePrefix"] 
                                                       :[site valueForKey:@"titlePostfix"]];

                    [replacedString writeToFile:filePath
                                     atomically:YES 
                                       encoding:NSUTF8StringEncoding
                                          error:&anError];                    
                }
            }
            else {
                //NSLog(@"ignored file: %@",file);
            }
        }        
    }
}

#pragma mark string replace magic

-(NSString *)replaceHeader:(NSString*)fileText :(NSString*)headerCode :(NSString*)keywords :(NSString*)description{
    
    if(!headerCode) headerCode=@"";
    if(!keywords) keywords=@"";
    if(!description) description=@"";
    
    if(showDebugMessages) NSLog(@"replaceHeader:");
    
    NSString *metakeywords =@"";
    NSString *metadescription =@"";
 
    if ([[keywords stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]length] > 0){
        metakeywords = [NSString stringWithFormat:@"<meta name=\"keywords\" content=\"%@\" />",keywords];
    }

    if ([[description stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]length] > 0){
        metadescription = [NSString stringWithFormat:@"<meta name=\"description\" content=\"%@\" />",description];    
    }
    
    NSString *replacedString;
    NSString *search = @"<!-- START SiteLighter HeaderCode -->";
    NSString *search2 = @"<!-- END SiteLighter HeaderCode -->";
    
    if([fileText rangeOfString:search].location == NSNotFound)
    {
        NSString *headerBlock = [[NSString alloc] initWithFormat:                                 
                                 @"<!-- START SiteLighter HeaderCode -->%@%@%@<!-- END SiteLighter HeaderCode --></head>", metadescription,metakeywords,headerCode];

        replacedString = [fileText stringByReplacingOccurrencesOfString:@"</head>" withString:headerBlock];
    }
    else {
        NSString *sub1 = [fileText substringToIndex:[fileText rangeOfString:search].location];
        NSString *sub2 = [fileText substringFromIndex:NSMaxRange([fileText rangeOfString:search2])];

        replacedString = [[NSString alloc] initWithFormat:                                 
                                 @"%@<!-- START SiteLighter HeaderCode -->%@%@%@<!-- END SiteLighter HeaderCode -->%@", sub1, metadescription,metakeywords,headerCode,sub2];
    }
    
    return replacedString;
}

-(NSString *)replaceFooter:(NSString*)fileText :(NSString*)footerCode :(NSString*)googleCode{
    
    if(!footerCode) footerCode=@"";
    if(!googleCode) googleCode=@"";
    
        if(showDebugMessages) NSLog(@"replaceFooter:");    
    NSString *replacedString;
    NSString *search = @"<!-- START SiteLighter FooterCode -->";
    NSString *search2 = @"<!-- END SiteLighter FooterCode -->";
    NSString * googleCodeBlock =@"";
    if ([[googleCode stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]length] > 0)
    {
        googleCodeBlock= @"<script type=\"text/javascript\">\
        \
        var _gaq = _gaq || [];\
        _gaq.push(['_setAccount', 'GOOGLECODE']);\
        _gaq.push(['_trackPageview']);\
        \
        (function() {\
            var ga = document.createElement('script'); ga.type = 'text/javascript'; ga.async = true;\
            ga.src = ('https:' == document.location.protocol ? 'https://ssl' : 'http://www') + '.google-analytics.com/ga.js';\
            var s = document.getElementsByTagName('script')[0]; s.parentNode.insertBefore(ga, s);\
        })();\
        \
        </script>";
        googleCodeBlock = [googleCodeBlock stringByReplacingOccurrencesOfString:@"GOOGLECODE" withString:googleCode];
        //NSLog(@"googleCode: %@",googleCodeBlock);
    }
    
    if([fileText rangeOfString:search].location == NSNotFound)
    {
        NSString *footerBlock = [[NSString alloc] initWithFormat:                                 
                                 @"<!-- START SiteLighter FooterCode -->%@%@<!-- END SiteLighter FooterCode --></body>", footerCode,googleCodeBlock];
        
        replacedString = [fileText stringByReplacingOccurrencesOfString:@"</body>" withString:footerBlock];
    }
    else {
        NSString *sub1 = [fileText substringToIndex:[fileText rangeOfString:search].location];
        NSString *sub2 = [fileText substringFromIndex:NSMaxRange([fileText rangeOfString:search2])];

        replacedString = [[NSString alloc] initWithFormat:                                 
                          @"%@<!-- START SiteLighter FooterCode -->%@%@<!-- END SiteLighter FooterCode -->%@", sub1,footerCode,googleCodeBlock,sub2];        
    }
    
    return replacedString;
}

-(NSString *)replaceTitle:(NSString*)fileText :(NSString*)prefix :(NSString *)postfix{
    if(showDebugMessages) NSLog(@"replaceTitle:");
    
    if(!prefix) prefix=@"";
    if(!postfix) postfix=@"";
    
    NSString *replacedString;
    NSString *search = @"<!-- START SiteLighter TitleCode -->";
    NSString *search2 = @"<!-- END SiteLighter TitleCode -->";

    if([fileText rangeOfString:search].location == NSNotFound)
    {
        NSString *sub1 = [fileText substringToIndex:[fileText rangeOfString:@"<title>"].location];
        NSString *sub2 = [fileText substringFromIndex:NSMaxRange([fileText rangeOfString:@"</title>"])];    

        NSString *title = nil;
        NSScanner *theScanner = [NSScanner scannerWithString:fileText];
        // find start of IMG tag
        [theScanner scanUpToString:@"<title>" intoString:nil];
        if (![theScanner isAtEnd]) {
            [theScanner scanUpToString:@"</title>" intoString:&title];
            title = [title substringFromIndex:NSMaxRange([title rangeOfString:@"<title>"])];
        }

        
        replacedString = [NSString stringWithFormat:                                 
                          @"%@<!-- START SiteLighter TitleCode --><title>%@%@%@</title><meta origtitle=\"%@\" /><!-- END SiteLighter TitleCode -->%@",sub1,prefix,title,postfix,title,sub2];   
    }
    else {

        NSString *title = nil;
       
        NSScanner *theScanner = [NSScanner scannerWithString:fileText];
        [theScanner scanUpToString:@"<meta origtitle" intoString:nil];
        if (![theScanner isAtEnd]) {
            NSCharacterSet *charset = [NSCharacterSet characterSetWithCharactersInString:@"\"'"];
            [theScanner scanUpToCharactersFromSet:charset intoString:nil];
            [theScanner scanCharactersFromSet:charset intoString:nil];
            [theScanner scanUpToString:@"\" />" intoString:&title];
        }

        
        NSString *sub1 = [fileText substringToIndex:[fileText rangeOfString:search].location];
        NSString *sub2 = [fileText substringFromIndex:NSMaxRange([fileText rangeOfString:search2])];    
        
        replacedString = [[NSString alloc] initWithFormat:                                 
                          @"%@<!-- START SiteLighter TitleCode --><title>%@%@%@</title><meta origtitle=\"%@\" /><!-- END SiteLighter TitleCode -->%@",sub1,prefix,title,postfix,title,sub2];

    }
    
    return replacedString;
    
    
}





@end
