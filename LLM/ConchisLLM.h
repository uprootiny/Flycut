//
//  ConchisLLM.h
//  Conchis
//
//  LLM integration for clipboard classification and prompt library.
//  Uses OpenRouter API for model access.
//

#import <Foundation/Foundation.h>

@class FlycutClipping;

// Classification categories for clipboard content
typedef NS_ENUM(NSInteger, ClippingCategory) {
    ClippingCategoryUnknown = 0,
    ClippingCategoryCode,
    ClippingCategoryURL,
    ClippingCategoryEmail,
    ClippingCategoryPath,
    ClippingCategoryJSON,
    ClippingCategoryMarkdown,
    ClippingCategoryProseShort,
    ClippingCategoryProseLong,
    ClippingCategoryList,
    ClippingCategoryNumber,
    ClippingCategoryDate,
    ClippingCategoryAddress,
    ClippingCategoryCommand,
    ClippingCategoryPrompt,
    ClippingCategoryOther
};

// Delegate for async classification results
@protocol ConchisLLMDelegate <NSObject>
@optional
- (void)llmDidClassifyClipping:(FlycutClipping *)clipping withCategory:(ClippingCategory)category confidence:(float)confidence;
- (void)llmDidFailWithError:(NSError *)error;
- (void)llmDidIdentifyReusablePrompt:(NSString *)prompt withTags:(NSArray<NSString *> *)tags;
@end

@interface ConchisLLM : NSObject

@property (nonatomic, weak) id<ConchisLLMDelegate> delegate;
@property (nonatomic, readonly) BOOL isConfigured;

+ (instancetype)shared;

// API Key management (stored in Keychain)
- (void)setAPIKey:(NSString *)apiKey;
- (NSString *)apiKey;
- (void)clearAPIKey;

// Classification
- (void)classifyClipping:(FlycutClipping *)clipping;
- (ClippingCategory)quickClassify:(NSString *)content; // Local heuristics, no API call

// Prompt library
- (void)analyzeForReusablePrompts:(NSString *)content;
- (NSArray<NSDictionary *> *)promptLibrary;
- (void)addPromptToLibrary:(NSString *)prompt withTags:(NSArray<NSString *> *)tags;
- (void)removePromptAtIndex:(NSUInteger)index;
- (NSArray<NSDictionary *> *)promptsMatchingTags:(NSArray<NSString *> *)tags;

// Grouping
- (void)suggestGroupsForClippings:(NSArray<FlycutClipping *> *)clippings
                       completion:(void (^)(NSArray<NSDictionary *> *groups, NSError *error))completion;

// Utility
+ (NSString *)categoryName:(ClippingCategory)category;
+ (NSString *)categoryEmoji:(ClippingCategory)category;

@end
