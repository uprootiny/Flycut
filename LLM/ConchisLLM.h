//
//  ConchisLLM.h
//  Conchis
//
//  REVISED DESIGN: Simple, bounded, fail-visible LLM integration.
//
//  Principles:
//  - User-initiated only (no automatic API calls)
//  - All errors visible in UI
//  - Hard rate limits enforced client-side
//  - Cost tracked and displayed
//  - No singletons, explicit instantiation
//

#import <Foundation/Foundation.h>

// Simplified categories - only 5, not 15
typedef NS_ENUM(NSInteger, ClipCategory) {
    ClipCategoryUnknown = 0,
    ClipCategoryCode,      // Programming code, scripts, config
    ClipCategoryLink,      // URLs, file paths, email addresses
    ClipCategoryData,      // JSON, numbers, structured data
    ClipCategoryText,      // Prose, notes, natural language
};

// Result object - not a delegate callback
@interface LLMResult : NSObject
@property (nonatomic, assign) BOOL success;
@property (nonatomic, copy) NSString *error;         // nil if success
@property (nonatomic, assign) ClipCategory category; // if classification
@property (nonatomic, copy) NSString *summary;       // if summarization
@property (nonatomic, assign) NSTimeInterval latency;
@property (nonatomic, assign) float estimatedCost;   // in USD
@end

// Usage stats - for display in preferences
@interface LLMUsageStats : NSObject
@property (nonatomic, assign) NSInteger requestsToday;
@property (nonatomic, assign) NSInteger requestsThisMonth;
@property (nonatomic, assign) float costThisMonth;   // estimated USD
@property (nonatomic, assign) NSInteger errorsToday;
@property (nonatomic, strong) NSDate *lastRequestTime;
@property (nonatomic, copy) NSString *lastError;
@end

@interface ConchisLLM : NSObject

// Explicit init - no singleton
- (instancetype)initWithAPIKey:(NSString *)apiKey;

// Check if ready (has valid-looking key)
@property (nonatomic, readonly) BOOL isConfigured;

// Rate limit status
@property (nonatomic, readonly) BOOL isRateLimited;
@property (nonatomic, readonly) NSTimeInterval secondsUntilNextRequest;

// Usage stats
@property (nonatomic, readonly) LLMUsageStats *stats;

// Local classification - instant, free, no network
// Returns ClipCategoryUnknown if ambiguous
- (ClipCategory)classifyLocally:(NSString *)content;

// LLM classification - BLOCKING, call from background thread
// Returns nil if rate limited or not configured
- (LLMResult *)classifyWithLLM:(NSString *)content;

// Test API key - BLOCKING
- (LLMResult *)testConnection;

// Category utilities
+ (NSString *)categoryName:(ClipCategory)category;
+ (NSString *)categoryShortCode:(ClipCategory)category; // For bezel display

// Reset stats (for testing)
- (void)resetStats;

@end

// Keychain helper - separate concern
@interface ConchisKeychain : NSObject
+ (void)setAPIKey:(NSString *)key;
+ (NSString *)apiKey;
+ (void)clearAPIKey;
@end
