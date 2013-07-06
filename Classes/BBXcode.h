//
//  BBXcode.h
//  BBUncrustifyPlugin
//
//  Created by Benoît on 16/03/13.
//
//

#import <Cocoa/Cocoa.h>

@interface NSTextView (PBXTextViewFindExtensions)
- (BOOL)replaceCurrentSelectionWithString:(NSString *)string;
@end

@interface PBXTextStorage : NSTextStorage
- (void)replaceCharactersInRange:(NSRange)range withString:(NSString *)string withUndoManager:(id)undoManager;
- (NSRange)lineRangeForCharacterRange:(NSRange)range;
- (NSRange)characterRangeForLineRange:(NSRange)range;
- (void)indentCharacterRange:(NSRange)range undoManager:(id)undoManager;
@end

@interface DVTFilePath : NSObject
@property (readonly) NSURL *fileURL;
@end

@interface IDEContainerItem : NSObject
@property (readonly) DVTFilePath *resolvedFilePath;
@end

@interface IDEGroup : IDEContainerItem

@end

@interface IDEFileReference : IDEContainerItem

@end

@interface IDENavigableItem : NSObject
@property (readonly) IDENavigableItem *parentItem;
@property (readonly) id representedObject;
@end

@interface PBXFileReference : NSObject
- (id)fileType;
@end

@interface PBXSmartGroupTreeModule : NSObject
- (id)selectedProjectItems;
@end

@interface PBXProjectModule : NSObject
- (id)keyModules;
@end

@interface PBXFileType : NSObject
- (BOOL)isSourceCode;
- (id)languageSpecificationIdentifier;
@end

@interface IDENavigableItemCoordinator : NSObject
- (id)structureNavigableItemForDocumentURL:(id)arg1 inWorkspace:(id)arg2 error:(id *)arg3;
@end

@interface PBXSourceFileDocument : NSDocument
+ (id)fileDocumentForFileReference:(id)fp8 loadIfNeeded:(BOOL)fp12;
- (id)selection;
- (id)textStorage;
@end

@interface PBXSourceFileEditor : NSObject
@property (retain) NSTextView *textView;
- (id)_sourceFileDocument;
@end

@interface PBXFileNavigator : NSObject
- (id)fileEditor;
@end

@interface PBXWindowController : NSWindowController
- (id)rootModule;
- (id)activeModule;
@end

@interface IDEWorkspace : NSObject
@property (readonly) DVTFilePath *representingFilePath;
@end

@interface IDEWorkspaceDocument : NSDocument
@property (readonly) IDEWorkspace *workspace;
@end

@interface BBXcode : NSObject
+ (PBXSourceFileEditor *)currentEditor;
+ (IDEWorkspaceDocument *)currentWorkspaceDocument;
+ (PBXSourceFileDocument *)currentSourceCodeDocumentForEditor:(PBXSourceFileEditor *)editor;
+ (NSTextView *)currentSourceCodeTextViewForEditor:(PBXSourceFileEditor *)editor;
+ (NSArray *)selectedObjCFileNavigableItems;
+ (BOOL)uncrustifySelectionOfDocument:(PBXSourceFileDocument *)document inTextView:(NSTextView *)textView inWorkspace:(IDEWorkspace *)workspace;
+ (BOOL)uncrustifyCodeOfDocument:(PBXSourceFileDocument *)document inWorkspace:(IDEWorkspace *)workspace;
+ (BOOL)uncrustifyCodeAtRanges:(NSArray *)ranges document:(PBXSourceFileDocument *)document inTextView:(NSTextView *)textView inWorkspace:(IDEWorkspace *)workspace;
+ (void)normalizeCodeAtRange:(NSRange)range document:(PBXSourceFileDocument *)document;
+ (NSString *)stringByTrimmingString:(NSString *)string trimWhitespaceOnlyLines:(BOOL)trimWhitespaceOnlyLines trimTrailingWhitespace:(BOOL)trimTrailingWhitespace;
@end
