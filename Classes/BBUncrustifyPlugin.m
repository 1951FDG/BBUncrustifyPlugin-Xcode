//
//  BBUncrustifyPlugin.m
//  BBUncrustifyPlugin
//
//  Created by Benoît on 16/03/13.
//
//

#import "BBUncrustifyPlugin.h"
#import "BBUncrustify.h"
#import "BBXcode.h"
#import "BBPluginUpdater.h"

@implementation BBUncrustifyPlugin {}

#pragma mark - Setup and Teardown

+ (void)pluginDidLoad:(NSBundle *)plugin
{
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		[[self alloc] init];
	});
}

- (id)init
{
	self  = [super init];

	if (self)
	{
		NSMenuItem *editMenuItem = [[NSApp mainMenu] itemWithTitle:@"Edit"];

		if (editMenuItem)
		{
			[[editMenuItem submenu] addItem:[NSMenuItem separatorItem]];

			NSMenuItem *menuItem;
			menuItem = [[NSMenuItem alloc] initWithTitle:@"Uncrustify Selection" action:@selector(uncrustifySelection:) keyEquivalent:@""];
			[menuItem setTarget:self];
			[[editMenuItem submenu] addItem:menuItem];

			menuItem = [[NSMenuItem alloc] initWithTitle:@"Uncrustify Selected Files" action:@selector(uncrustifySelectedFiles:) keyEquivalent:@""];
			[menuItem setTarget:self];
			[[editMenuItem submenu] addItem:menuItem];

			menuItem = [[NSMenuItem alloc] initWithTitle:@"Uncrustify Active File" action:@selector(uncrustifyActiveFile:) keyEquivalent:@""];
			[menuItem setTarget:self];
			[[editMenuItem submenu] addItem:menuItem];

			menuItem = [[NSMenuItem alloc] initWithTitle:@"Uncrustify Selected Lines" action:@selector(uncrustifySelectedLines:) keyEquivalent:@""];
			[menuItem setTarget:self];
			[[editMenuItem submenu] addItem:menuItem];

			menuItem = [[NSMenuItem alloc] initWithTitle:@"Open with UncrustifyX" action:@selector(openWithUncrustifyX:) keyEquivalent:@""];
			[menuItem setTarget:self];
			[[editMenuItem submenu] addItem:menuItem];

			[[BBPluginUpdater sharedUpdater] setDelegate:self];

			NSLog(@"BBUncrustifyPlugin loaded (%@)", [[[NSBundle bundleForClass:[self class]] infoDictionary] objectForKey:@"CFBundleVersion"]);
		}
	}

	return self;
}

#pragma mark - Actions

- (IBAction)uncrustifySelection:(id)sender
{
	PBXSourceFileEditor *editor = [BBXcode currentEditor];
	PBXSourceFileDocument *document = [BBXcode currentSourceCodeDocumentForEditor:editor];
	NSTextView *textView = [BBXcode currentSourceCodeTextViewForEditor:editor];

	if (!document || !textView)
	{
		return;
	}

	IDEWorkspace *currentWorkspace = [BBXcode currentWorkspaceDocument].workspace;
	[BBXcode uncrustifySelectionOfDocument:document inTextView:textView inWorkspace:currentWorkspace];

	//[[BBPluginUpdater sharedUpdater] checkForUpdatesIfNeeded];
}

- (IBAction)uncrustifySelectedFiles:(id)sender
{
	NSArray *fileNavigableItems = [BBXcode selectedObjCFileNavigableItems];
	IDEWorkspace *currentWorkspace = [BBXcode currentWorkspaceDocument].workspace;

	for (id fileNavigableItem in fileNavigableItems)
	{
		PBXSourceFileDocument *document = [NSClassFromString(@"PBXSourceFileDocument") fileDocumentForFileReference:fileNavigableItem loadIfNeeded:YES];

		if (document)
		{
			BOOL uncrustified = [BBXcode uncrustifyCodeOfDocument:document inWorkspace:currentWorkspace];

			if (uncrustified)
			{
				//[document saveDocument:nil];
			}
		}
	}

	//[[BBPluginUpdater sharedUpdater] checkForUpdatesIfNeeded];
}

- (IBAction)uncrustifyActiveFile:(id)sender
{
	PBXSourceFileEditor *editor = [BBXcode currentEditor];
	PBXSourceFileDocument *document = [BBXcode currentSourceCodeDocumentForEditor:editor];

	if (!document)
	{
		return;
	}

	IDEWorkspace *currentWorkspace = [BBXcode currentWorkspaceDocument].workspace;
	[BBXcode uncrustifyCodeOfDocument:document inWorkspace:currentWorkspace];

	//[[BBPluginUpdater sharedUpdater] checkForUpdatesIfNeeded];
}

- (IBAction)uncrustifySelectedLines:(id)sender
{
	PBXSourceFileEditor *editor = [BBXcode currentEditor];
	PBXSourceFileDocument *document = [BBXcode currentSourceCodeDocumentForEditor:editor];
	NSTextView *textView = [BBXcode currentSourceCodeTextViewForEditor:editor];

	if (!document || !textView)
	{
		return;
	}

	IDEWorkspace *currentWorkspace = [BBXcode currentWorkspaceDocument].workspace;
	NSArray *selectedRanges = [textView selectedRanges];
	[BBXcode uncrustifyCodeAtRanges:selectedRanges document:document inTextView:textView inWorkspace:currentWorkspace];

	//[[BBPluginUpdater sharedUpdater] checkForUpdatesIfNeeded];
}

- (IBAction)openWithUncrustifyX:(id)sender
{
	NSURL *appURL = [BBUncrustify uncrustifyXApplicationURL];

	NSURL *configurationFileURL = [BBUncrustify resolvedConfigurationFileURLWithAdditionalLookupFolderURLs:nil];
	NSURL *builtInConfigurationFileURL = [BBUncrustify builtInConfigurationFileURL];

	if ([configurationFileURL isEqual:builtInConfigurationFileURL])
	{
		configurationFileURL = [[BBUncrustify userConfigurationFileURLs] objectAtIndex:0];
		NSAlert *alert = [NSAlert alertWithMessageText:@"Custom Configuration File Not Found" defaultButton:@"Create Configuration File & Open UncrustifyX" alternateButton:@"Cancel" otherButton:nil informativeTextWithFormat:@"Do you want to create a configuration file at this path \n%@", configurationFileURL.path];

		if ([alert runModal] == NSAlertDefaultReturn)
		{
			[[NSFileManager defaultManager] copyItemAtPath:builtInConfigurationFileURL.path toPath:configurationFileURL.path error:nil];
		}
		else
		{
			configurationFileURL = nil;
		}
	}

	if (configurationFileURL)
	{
		PBXSourceFileEditor *editor = [BBXcode currentEditor];
		PBXSourceFileDocument *document = [BBXcode currentSourceCodeDocumentForEditor:editor];

		if (document)
		{
			PBXTextStorage *textStorage = [document textStorage];
			[[NSPasteboard pasteboardWithName:@"BBUncrustifyPlugin-source-code"] clearContents];

			if (textStorage.string)
			{
				[[NSPasteboard pasteboardWithName:@"BBUncrustifyPlugin-source-code"] writeObjects:[NSArray arrayWithObject:textStorage.string]];
			}
		}

		NSDictionary *configuration = [NSDictionary dictionaryWithObject:[NSArray arrayWithObjects:@"-bbuncrustifyplugin", @"-configpath", configurationFileURL.path, nil] forKey:NSWorkspaceLaunchConfigurationArguments];
		[[NSWorkspace sharedWorkspace] launchApplicationAtURL:appURL options:0 configuration:configuration error:nil];
	}

	//[[BBPluginUpdater sharedUpdater] checkForUpdatesIfNeeded];
}

#pragma mark - NSMenuValidation

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	if ([menuItem action] == @selector(uncrustifySelection:))
	{
		BOOL validated = NO;
		PBXSourceFileEditor *editor = [BBXcode currentEditor];
		PBXSourceFileDocument *document = [BBXcode currentSourceCodeDocumentForEditor:editor];
		NSTextView *textView = [BBXcode currentSourceCodeTextViewForEditor:editor];

		if (document && textView)
		{
			NSArray *selectedRanges = [textView selectedRanges];
			validated = ([[selectedRanges objectAtIndex:0] rangeValue].length > 0);
		}

		return validated;
	}
	else if ([menuItem action] == @selector(uncrustifySelectedFiles:))
	{
		return ([BBXcode selectedObjCFileNavigableItems].count > 0);
	}
	else if ([menuItem action] == @selector(uncrustifyActiveFile:))
	{
		PBXSourceFileEditor *editor = [BBXcode currentEditor];
		PBXSourceFileDocument *document = [BBXcode currentSourceCodeDocumentForEditor:editor];
		return (document != nil);
	}
	else if ([menuItem action] == @selector(uncrustifySelectedLines:))
	{
		BOOL validated = NO;
		PBXSourceFileEditor *editor = [BBXcode currentEditor];
		PBXSourceFileDocument *document = [BBXcode currentSourceCodeDocumentForEditor:editor];
		NSTextView *textView = [BBXcode currentSourceCodeTextViewForEditor:editor];

		if (document && textView)
		{
			NSArray *selectedRanges = [textView selectedRanges];
			validated = ([[selectedRanges objectAtIndex:0] rangeValue].length > 0);
		}

		return validated;
	}
	else if ([menuItem action] == @selector(openWithUncrustifyX:))
	{
		BOOL appExists = NO;
		NSURL *appURL = [BBUncrustify uncrustifyXApplicationURL];

		if (appURL)
		{
			appExists = [[NSFileManager defaultManager] fileExistsAtPath:appURL.path];
		}

		[menuItem setHidden:!appExists];
	}

	return YES;
}

#pragma mark - SUUpdater Delegate

- (NSString *)pathToRelaunchForUpdater:(SUUpdater *)updater
{
	return [[NSBundle mainBundle].bundleURL path];
}

@end
