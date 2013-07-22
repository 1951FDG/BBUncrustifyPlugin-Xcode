//
//  BBXcode.m
//  BBUncrustifyPlugin
//
//  Created by Benoît on 16/03/13.
//
//

#import "BBXcode.h"
#import "BBUncrustify.h"

NSArray * BBMergeContinuousRanges(NSArray *ranges)
{
	if (ranges.count == 0)
	{
		return nil;
	}

	NSMutableIndexSet *mIndexes = [NSMutableIndexSet indexSet];

	for (NSValue *rangeValue in ranges)
	{
		NSRange range = [rangeValue rangeValue];
		[mIndexes addIndexesInRange:range];
	}

	NSMutableArray *mergedRanges = [NSMutableArray array];
	__block NSUInteger rangeStartIndex = NSNotFound;
	__block NSUInteger currentIndex = NSNotFound;

	[mIndexes enumerateIndexesUsingBlock: ^(NSUInteger idx, BOOL *stop) {
		if (currentIndex == NSNotFound)
		{
			rangeStartIndex = idx;
			currentIndex = idx;
			return;
		}

		NSRange range = NSMakeRange(rangeStartIndex, (currentIndex - rangeStartIndex) + 1);

		[mergedRanges addObject:[NSValue valueWithRange:range]];

		currentIndex = idx;
		rangeStartIndex = idx;
	}];
	return [NSArray arrayWithArray:mergedRanges];
}

NSString * BBStringByTrimmingTrailingCharactersFromString(NSString *string, NSCharacterSet *characterSet)
{
	NSRange rangeOfLastWantedCharacter = [string rangeOfCharacterFromSet:[characterSet invertedSet] options:NSBackwardsSearch];

	if (rangeOfLastWantedCharacter.location == NSNotFound)
	{
		return @"";
	}

	return [string substringToIndex:rangeOfLastWantedCharacter.location + 1];
}

@implementation BBXcode {}

#pragma mark - Helpers

+ (PBXSourceFileEditor *)currentEditor
{
	PBXWindowController *currentWindowController = [[NSApp keyWindow] windowController];

	if ([currentWindowController isKindOfClass:NSClassFromString(@"PBXWindowController")])
	{
		id module = [currentWindowController activeModule];

		if ([module isKindOfClass:NSClassFromString(@"PBXFileNavigator")])
		{
			PBXSourceFileEditor *editor = [module fileEditor];

			if ([editor isKindOfClass:NSClassFromString(@"PBXSourceFileEditor")])
			{
				return editor;
			}
		}
	}

	return nil;
}

+ (IDEWorkspaceDocument *)currentWorkspaceDocument
{
	NSWindowController *currentWindowController = [[NSApp keyWindow] windowController];
	id document = [currentWindowController document];

	if (currentWindowController && [document isKindOfClass:NSClassFromString(@"IDEWorkspaceDocument")])
	{
		return (IDEWorkspaceDocument *)document;
	}

	return nil;
}

+ (PBXSourceFileDocument *)currentSourceCodeDocumentForEditor:(PBXSourceFileEditor *)editor
{
	PBXSourceFileDocument *document = [editor _sourceFileDocument];

	if ([document isKindOfClass:NSClassFromString(@"PBXSourceFileDocument")])
	{
		return document;
	}

	return nil;
}

+ (NSTextView *)currentSourceCodeTextViewForEditor:(PBXSourceFileEditor *)editor
{
	NSTextView *textView = [editor textView];

	if ([textView isKindOfClass:NSClassFromString(@"NSTextView")])
	{
		return textView;
	}

	return nil;
}

+ (NSArray *)selectedObjCFileNavigableItems
{
	NSMutableArray *mutableArray = [NSMutableArray array];

	PBXWindowController *currentWindowController = [[NSApp keyWindow] windowController];

	if ([currentWindowController isKindOfClass:NSClassFromString(@"PBXWindowController")])
	{
		id module = [currentWindowController rootModule];

		if ([module isKindOfClass:NSClassFromString(@"PBXProjectModule")])
		{
			id modules = [module keyModules];

			if ([modules isKindOfClass:[NSArray class]])
			{
				for (id anObject in modules)
				{
					if ([anObject isKindOfClass:NSClassFromString(@"PBXSmartGroupTreeModule")])
					{
						id currentNavigator = [anObject selectedProjectItems];

						if ([currentNavigator isKindOfClass:[NSArray class]])
						{
							for (id selectedObject in currentNavigator)
							{
								if ([selectedObject isKindOfClass:NSClassFromString(@"PBXFileReference")])
								{
									id uti = [selectedObject fileType];

									if ([uti isSourceCode])
									{
										id language = [uti languageSpecificationIdentifier];

										if ([language isEqualToString:@"c.objcpp"] || [language isEqualToString:@"c.objc"] || [language isEqualToString:@"c"])
										{
											[mutableArray addObject:selectedObject];
										}
									}
								}
							}
						}

						break;
					}
				}
			}
		}
	}

	if (mutableArray.count)
	{
		return [NSArray arrayWithArray:mutableArray];
	}

	return nil;
}

+ (NSArray *)containerFolderURLsForNavigableItem:(IDENavigableItem *)navigableItem
{
	NSMutableArray *mArray = [NSMutableArray array];

	do
	{
		NSURL *folderURL = nil;
		id representedObject = navigableItem.representedObject;

		if ([navigableItem isKindOfClass:NSClassFromString(@"IDEGroupNavigableItem")])
		{
			// IDE-GROUP (a folder in the navigator)
			IDEGroup *group = (IDEGroup *)representedObject;
			folderURL = group.resolvedFilePath.fileURL;
		}
		else if ([navigableItem isKindOfClass:NSClassFromString(@"IDEContainerFileReferenceNavigableItem")])
		{
			// CONTAINER (an Xcode project)
			IDEFileReference *fileReference = representedObject;
			folderURL = [fileReference.resolvedFilePath.fileURL URLByDeletingLastPathComponent];
		}
		else if ([navigableItem isKindOfClass:NSClassFromString(@"IDEKeyDrivenNavigableItem")])
		{
			// WORKSPACE (root: Xcode project or workspace)
			IDEWorkspace *workspace = representedObject;
			folderURL = [workspace.representingFilePath.fileURL URLByDeletingLastPathComponent];
		}

		if (folderURL && ![mArray containsObject:folderURL])
		{
			[mArray addObject:folderURL];
		}

		navigableItem = [navigableItem parentItem];
	} while (navigableItem != nil);

	if (mArray.count > 0)
	{
		return [NSArray arrayWithArray:mArray];
	}

	return nil;
}

#pragma mark - Uncrustify

+ (BOOL)uncrustifySelectionOfDocument:(PBXSourceFileDocument *)document inTextView:(NSTextView *)textView inWorkspace:(IDEWorkspace *)workspace
{
	PBXTextStorage *textStorage = [document textStorage];
	NSString *originalString = [textStorage.string substringWithRange:[[[textView selectedRanges] objectAtIndex:0] rangeValue]];

	if (originalString.length > 0)
	{
		NSArray *additionalConfigurationFolderURLs = nil;

		if (workspace)
		{
			IDENavigableItemCoordinator *coordinator = [[NSClassFromString(@"IDENavigableItemCoordinator") alloc] init];
			IDENavigableItem *navigableItem = [coordinator structureNavigableItemForDocumentURL:document.fileURL inWorkspace:workspace error:nil];
			[coordinator release];

			if (navigableItem)
			{
				additionalConfigurationFolderURLs = [BBXcode containerFolderURLsForNavigableItem:navigableItem];
			}
		}

		NSMutableDictionary *options = [NSMutableDictionary dictionaryWithObject:document.fileURL.lastPathComponent forKey:BBUncrustifyOptionSourceFilename];

		if (additionalConfigurationFolderURLs.count > 0)
		{
			[options setObject:additionalConfigurationFolderURLs forKey:BBUncrustifyOptionSupplementalConfigurationFolders];
		}

		NSString *uncrustifiedCode = [BBUncrustify uncrustifyCodeFragment:originalString options:options];

		if (![uncrustifiedCode isEqualToString:originalString])
		{
			[textView replaceCurrentSelectionWithString:uncrustifiedCode];
		}

		NSUserDefaults *preferences = [NSUserDefaults standardUserDefaults];

		if ([[preferences stringForKey:@"PBXUsesSyntaxAwareIndenting"] boolValue])
		{
			[textStorage indentCharacterRange:[[[textView selectedRanges] objectAtIndex:0] rangeValue] undoManager:[document undoManager]];
		}
	}

	BOOL codeHasChanged = (originalString && ![originalString isEqualToString:textStorage.string]);
	return codeHasChanged;
}

+ (BOOL)uncrustifyCodeOfDocument:(PBXSourceFileDocument *)document inWorkspace:(IDEWorkspace *)workspace
{
	PBXTextStorage *textStorage = [document textStorage];
	NSString *originalString = [NSString stringWithString:textStorage.string];

	if (originalString.length > 0)
	{
		NSArray *additionalConfigurationFolderURLs = nil;

		if (workspace)
		{
			IDENavigableItemCoordinator *coordinator = [[NSClassFromString(@"IDENavigableItemCoordinator") alloc] init];
			IDENavigableItem *navigableItem = [coordinator structureNavigableItemForDocumentURL:document.fileURL inWorkspace:workspace error:nil];
			[coordinator release];

			if (navigableItem)
			{
				additionalConfigurationFolderURLs = [BBXcode containerFolderURLsForNavigableItem:navigableItem];
			}
		}

		NSMutableDictionary *options = [NSMutableDictionary dictionaryWithObject:document.fileURL.lastPathComponent forKey:BBUncrustifyOptionSourceFilename];

		if (additionalConfigurationFolderURLs.count > 0)
		{
			[options setObject:additionalConfigurationFolderURLs forKey:BBUncrustifyOptionSupplementalConfigurationFolders];
		}

		NSString *uncrustifiedCode = [BBUncrustify uncrustifyCodeFragment:originalString options:options];

		[textStorage beginEditing];

		if (![uncrustifiedCode isEqualToString:originalString])
		{
			[textStorage replaceCharactersInRange:NSMakeRange(0, textStorage.string.length) withString:uncrustifiedCode withUndoManager:[document undoManager]];
		}

		NSUserDefaults *preferences = [NSUserDefaults standardUserDefaults];

		if ([[preferences stringForKey:@"PBXUsesSyntaxAwareIndenting"] boolValue])
		{
			[textStorage indentCharacterRange:NSMakeRange(0, textStorage.string.length) undoManager:[document undoManager]];
		}

		if (![preferences boolForKey:@"GTMXcodeCorrectWhiteSpaceOnSave"])
		{
			NSMutableString *text = [NSMutableString stringWithString:textStorage.string];

			NSString *newlineString = @"\n";
			NSCharacterSet *whiteSpace
			= [NSCharacterSet whitespaceCharacterSet];
			NSCharacterSet *nonWhiteSpace = [[NSCharacterSet whitespaceCharacterSet] invertedSet];

			// If the file is missing a newline at the end, add it now.
			if (![text hasSuffix:newlineString])
			{
				[text appendString:newlineString];
			}

			NSRange textRange = NSMakeRange(0, text.length - 1);

			while (textRange.length > 0)
			{
				NSRange lineRange = [text rangeOfString:@"\n"
												options:NSBackwardsSearch
												  range:textRange];

				if (lineRange.location == NSNotFound)
				{
					lineRange.location = 0;
				}
				else
				{
					lineRange.location += 1;
				}

				lineRange.length = textRange.length - lineRange.location;
				textRange.length = lineRange.location;

				if (textRange.length != 0)
				{
					textRange.length -= 1;
				}

				NSRange whiteRange = [text rangeOfCharacterFromSet:whiteSpace
														   options:NSBackwardsSearch
															 range:lineRange];

				if (NSMaxRange(whiteRange) == NSMaxRange(lineRange))
				{
					NSRange nonWhiteRange = [text rangeOfCharacterFromSet:nonWhiteSpace
																  options:NSBackwardsSearch
																	range:lineRange];
					NSRange deleteRange;

					if (nonWhiteRange.location == NSNotFound)
					{
						deleteRange.location = lineRange.location;
					}
					else
					{
						deleteRange.location = NSMaxRange(nonWhiteRange);
					}

					deleteRange.length = NSMaxRange(whiteRange) - deleteRange.location;
					[text deleteCharactersInRange:deleteRange];
				}
			}

			// Replace the text with the new stripped version.
			[textStorage replaceCharactersInRange:NSMakeRange(0, textStorage.string.length) withString:text withUndoManager:[document undoManager]];
		}

		[textStorage endEditing];
	}

	BOOL codeHasChanged = (originalString && ![originalString isEqualToString:textStorage.string]);
	return codeHasChanged;
}

+ (BOOL)uncrustifyCodeAtRanges:(NSArray *)ranges document:(PBXSourceFileDocument *)document inTextView:(NSTextView *)textView inWorkspace:(IDEWorkspace *)workspace
{
	PBXTextStorage *textStorage = [document textStorage];

	NSArray *linesRangeValues = nil;
	{
		NSMutableArray *mLinesRangeValues = [NSMutableArray array];

		for (NSValue *rangeValue in ranges)
		{
			NSRange range = [rangeValue rangeValue];
			NSRange lineRange = [textStorage lineRangeForCharacterRange:range];
			[mLinesRangeValues addObject:[NSValue valueWithRange:lineRange]];
		}

		linesRangeValues = BBMergeContinuousRanges(mLinesRangeValues);
	}

	NSMutableArray *textFragments = [NSMutableArray array];

	NSArray *additionalConfigurationFolderURLs = nil;

	if (workspace)
	{
		IDENavigableItemCoordinator *coordinator = [[NSClassFromString(@"IDENavigableItemCoordinator") alloc] init];
		IDENavigableItem *navigableItem = [coordinator structureNavigableItemForDocumentURL:document.fileURL inWorkspace:workspace error:nil];
		[coordinator release];

		if (navigableItem)
		{
			additionalConfigurationFolderURLs = [BBXcode containerFolderURLsForNavigableItem:navigableItem];
		}
	}

	for (NSValue *linesRangeValue in linesRangeValues)
	{
		NSRange linesRange = [linesRangeValue rangeValue];
		NSRange characterRange = [textStorage characterRangeForLineRange:linesRange];

		if (characterRange.location != NSNotFound)
		{
			NSString *string = [textStorage.string substringWithRange:characterRange];

			if (string.length > 0)
			{
				NSMutableDictionary *options = [NSMutableDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], BBUncrustifyOptionEvictCommentInsertion, document.fileURL.lastPathComponent, BBUncrustifyOptionSourceFilename, nil];

				if (additionalConfigurationFolderURLs.count > 0)
				{
					[options setObject:additionalConfigurationFolderURLs forKey:BBUncrustifyOptionSupplementalConfigurationFolders];
				}

				NSString *uncrustifiedString = [BBUncrustify uncrustifyCodeFragment:string options:options];

				if (uncrustifiedString.length > 0)
				{
					[textFragments addObject:[NSDictionary dictionaryWithObjectsAndKeys:uncrustifiedString, @"textFragment", [NSValue valueWithRange:characterRange], @"range", nil]];
				}
			}
		}
	}

	NSString *originalString = [NSString stringWithString:textStorage.string];

	NSMutableArray *newSelectionRanges = [NSMutableArray array];

	[textFragments enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(id textFragment, NSUInteger idx, BOOL *stop) {
		NSRange range = [[textFragment objectForKey:@"range"] rangeValue];
		NSString *newString = [textFragment objectForKey:@"textFragment"];
		[textStorage beginEditing];
		[textStorage replaceCharactersInRange:range withString:newString withUndoManager:[document undoManager]];
		[BBXcode normalizeCodeAtRange:NSMakeRange(range.location, newString.length) document:document];

		// If more than one selection update previous range.locations by adding changeInLength
		if (newSelectionRanges.count > 0)
		{
			NSUInteger i = 0;

			while (i < newSelectionRanges.count)
			{
				range = [[newSelectionRanges objectAtIndex:i] rangeValue];
				range.location = range.location + [textStorage changeInLength];
				[newSelectionRanges replaceObjectAtIndex:i withObject:[NSValue valueWithRange:range]];
				i++;
			}
		}

		NSRange editedRange = [textStorage editedRange];

		if (editedRange.location != NSNotFound)
		{
			[newSelectionRanges addObject:[NSValue valueWithRange:editedRange]];
		}

		[textStorage endEditing];
	}];

	if (newSelectionRanges.count > 0)
	{
		[textView setSelectedRanges:newSelectionRanges];
	}

	BOOL codeHasChanged = (![originalString isEqualToString:textStorage.string]);
	return codeHasChanged;
}

#pragma mark - Normalizing

+ (void)normalizeCodeAtRange:(NSRange)range document:(PBXSourceFileDocument *)document
{
	PBXTextStorage *textStorage = [document textStorage];

	const NSRange scopeLineRange = [textStorage lineRangeForCharacterRange:range]; // the line range stays unchanged during the normalization

	NSRange characterRange = [textStorage characterRangeForLineRange:scopeLineRange];

	NSUserDefaults *preferences = [NSUserDefaults standardUserDefaults];

	if ([[preferences stringForKey:@"PBXUsesSyntaxAwareIndenting"] boolValue])
	{
		// PS: The method [PBXTextStorage indentCharacterRange:undoManager:] always indents empty lines to the same level as code (ignoring the preferences in Xcode concerning the identation of whitespace only lines).
		[textStorage indentCharacterRange:characterRange undoManager:[document undoManager]];
		characterRange = [textStorage characterRangeForLineRange:scopeLineRange];
	}

	if (![preferences boolForKey:@"GTMXcodeCorrectWhiteSpaceOnSave"])
	{
		NSString *string = [textStorage.string substringWithRange:characterRange];
		NSString *trimString = [BBXcode stringByTrimmingString:string trimWhitespaceOnlyLines:YES trimTrailingWhitespace:YES];
		[textStorage replaceCharactersInRange:characterRange withString:trimString withUndoManager:[document undoManager]];
	}
}

+ (NSString *)stringByTrimmingString:(NSString *)string trimWhitespaceOnlyLines:(BOOL)trimWhitespaceOnlyLines trimTrailingWhitespace:(BOOL)trimTrailingWhitespace
{
	NSMutableString *mResultString = [NSMutableString string];

	// I'm not using [NSString enumerateLinesUsingBlock:] to enumerate the string by lines because the last line of the string is ignored if it's an empty line.
	NSArray *lines = [string componentsSeparatedByString:@"\n"];

	NSCharacterSet *characterSet = [NSCharacterSet whitespaceCharacterSet]; // [NSCharacterSet whitespaceCharacterSet] means tabs or spaces

	[lines enumerateObjectsWithOptions:0 usingBlock:^(id line, NSUInteger idx, BOOL *stop) {
		if (idx > 0)
		{
			[mResultString appendString:@"\n"];
		}

		BOOL acceptedLine = YES;

		NSString *trimSubstring = [line stringByTrimmingCharactersInSet:characterSet];

		if (trimWhitespaceOnlyLines)
		{
			acceptedLine = (trimSubstring.length > 0);
		}

		if (acceptedLine)
		{
			if (trimTrailingWhitespace && trimSubstring.length > 0)
			{
				line = BBStringByTrimmingTrailingCharactersFromString(line, characterSet);
			}

			[mResultString appendString:line];
		}
	}];

	return [NSString stringWithString:mResultString];
}

@end
