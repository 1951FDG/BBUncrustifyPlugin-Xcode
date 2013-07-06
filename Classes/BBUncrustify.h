//
//  BBUncrustify.h
//  BBUncrustifyPlugin
//
//  Created by Benoît on 16/03/13.
//
//

// Code inspired by https://github.com/ryanmaxwell/UncrustifyX

#import <Foundation/Foundation.h>

extern NSString *const BBUncrustifyOptionEvictCommentInsertion;
extern NSString *const BBUncrustifyOptionSourceFilename;
extern NSString *const BBUncrustifyOptionSupplementalConfigurationFolders; // NSArray of NSURL (array of urls representing folders)

@interface BBUncrustify : NSObject

+ (NSString *)uncrustifyCodeFragment:(NSString *)codeFragment options:(NSDictionary *)options;
+ (NSString *)configurationByRemovingOptions:(NSArray *)options fromConfiguration:(NSString *)originalConfiguration hasChanged:(BOOL *)outHasChanged;
+ (NSURL *)builtInConfigurationFileURL; // returns the default config file URL of the plugin.
+ (NSArray *)userConfigurationFileURLs; // returns suggested custom config file URLs.
+ (NSURL *)resolvedConfigurationFileURLWithAdditionalLookupFolderURLs:(NSArray *)lookupFolderURLs; // returns the config file URL actually used by Uncrustify.
+ (void)uncrustifyFilesAtURLs:(NSArray *)fileURLs configurationFileURL:(NSURL *)configurationFileURL;
+ (NSURL *)uncrustifyXApplicationURL;
@end
