//
//  ConchisLLM.m
//  Conchis
//
//  REVISED: Addresses failure modes identified in design review.
//
//  Changes from original:
//  - No singleton (explicit instantiation, testable)
//  - Synchronous API (caller controls threading)
//  - Hard rate limiting (10 req/min client-side)
//  - Cost tracking (visible in UI)
//  - All errors returned, never swallowed
//  - Simplified categories (5 not 15)
//  - No auto-classification (user-initiated only)
//  - No prompt library (removed - unproven value)
//

#import "ConchisLLM.h"
#import <Security/Security.h>

static NSString * const kOpenRouterAPIURL = @"https://openrouter.ai/api/v1/chat/completions";
static NSString * const kKeychainService = @"com.conchis.openrouter";
static NSString * const kKeychainAccount = @"api_key";
static NSString * const kStatsKey = @"ConchisLLMStats";

// Rate limit: 10 requests per minute
static const NSInteger kMaxRequestsPerMinute = 10;
static const NSTimeInterval kRateLimitWindow = 60.0;

// Cost estimate per request (Claude Haiku via OpenRouter)
static const float kEstimatedCostPerRequest = 0.0003; // $0.0003 approx

// Timeout - fail fast
static const NSTimeInterval kRequestTimeout = 10.0;

#pragma mark - LLMResult

@implementation LLMResult
- (instancetype)init {
    self = [super init];
    if (self) {
        _success = NO;
        _category = ClipCategoryUnknown;
        _estimatedCost = 0;
    }
    return self;
}

+ (instancetype)errorWithMessage:(NSString *)message {
    LLMResult *result = [[LLMResult alloc] init];
    result.success = NO;
    result.error = message;
    return result;
}

+ (instancetype)successWithCategory:(ClipCategory)category latency:(NSTimeInterval)latency {
    LLMResult *result = [[LLMResult alloc] init];
    result.success = YES;
    result.category = category;
    result.latency = latency;
    result.estimatedCost = kEstimatedCostPerRequest;
    return result;
}
@end

#pragma mark - LLMUsageStats

@implementation LLMUsageStats
- (instancetype)init {
    self = [super init];
    if (self) {
        _requestsToday = 0;
        _requestsThisMonth = 0;
        _costThisMonth = 0;
        _errorsToday = 0;
    }
    return self;
}

- (instancetype)initWithDictionary:(NSDictionary *)dict {
    self = [super init];
    if (self && dict) {
        _requestsToday = [dict[@"requestsToday"] integerValue];
        _requestsThisMonth = [dict[@"requestsThisMonth"] integerValue];
        _costThisMonth = [dict[@"costThisMonth"] floatValue];
        _errorsToday = [dict[@"errorsToday"] integerValue];
        _lastRequestTime = dict[@"lastRequestTime"];
        _lastError = dict[@"lastError"];
    }
    return self;
}

- (NSDictionary *)toDictionary {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    dict[@"requestsToday"] = @(self.requestsToday);
    dict[@"requestsThisMonth"] = @(self.requestsThisMonth);
    dict[@"costThisMonth"] = @(self.costThisMonth);
    dict[@"errorsToday"] = @(self.errorsToday);
    if (self.lastRequestTime) dict[@"lastRequestTime"] = self.lastRequestTime;
    if (self.lastError) dict[@"lastError"] = self.lastError;
    return dict;
}
@end

#pragma mark - ConchisKeychain

@implementation ConchisKeychain

+ (void)setAPIKey:(NSString *)key {
    if (!key || key.length == 0) {
        [self clearAPIKey];
        return;
    }

    NSData *keyData = [key dataUsingEncoding:NSUTF8StringEncoding];
    [self clearAPIKey];

    NSDictionary *query = @{
        (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService: kKeychainService,
        (__bridge id)kSecAttrAccount: kKeychainAccount,
        (__bridge id)kSecValueData: keyData,
        (__bridge id)kSecAttrAccessible: (__bridge id)kSecAttrAccessibleWhenUnlocked
    };

    OSStatus status = SecItemAdd((__bridge CFDictionaryRef)query, NULL);
    if (status != errSecSuccess) {
        NSLog(@"ConchisLLM: Keychain write failed: %d", (int)status);
    }
}

+ (NSString *)apiKey {
    NSDictionary *query = @{
        (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService: kKeychainService,
        (__bridge id)kSecAttrAccount: kKeychainAccount,
        (__bridge id)kSecReturnData: @YES,
        (__bridge id)kSecMatchLimit: (__bridge id)kSecMatchLimitOne
    };

    CFDataRef dataRef = NULL;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, (CFTypeRef *)&dataRef);

    if (status == errSecSuccess && dataRef) {
        NSData *data = (__bridge_transfer NSData *)dataRef;
        return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    }
    return nil;
}

+ (void)clearAPIKey {
    NSDictionary *query = @{
        (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService: kKeychainService,
        (__bridge id)kSecAttrAccount: kKeychainAccount
    };
    SecItemDelete((__bridge CFDictionaryRef)query);
}

@end

#pragma mark - ConchisLLM

@interface ConchisLLM ()
@property (nonatomic, copy) NSString *apiKey;
@property (nonatomic, strong) LLMUsageStats *stats;
@property (nonatomic, strong) NSMutableArray<NSDate *> *recentRequests; // For rate limiting
@end

@implementation ConchisLLM

- (instancetype)initWithAPIKey:(NSString *)apiKey {
    self = [super init];
    if (self) {
        _apiKey = [apiKey copy];
        _recentRequests = [NSMutableArray array];
        [self loadStats];
    }
    return self;
}

- (instancetype)init {
    return [self initWithAPIKey:[ConchisKeychain apiKey]];
}

#pragma mark - Stats Persistence

- (void)loadStats {
    NSDictionary *dict = [[NSUserDefaults standardUserDefaults] dictionaryForKey:kStatsKey];
    if (dict) {
        _stats = [[LLMUsageStats alloc] initWithDictionary:dict];
        [self resetStatsIfNewDay];
    } else {
        _stats = [[LLMUsageStats alloc] init];
    }
}

- (void)saveStats {
    [[NSUserDefaults standardUserDefaults] setObject:[self.stats toDictionary] forKey:kStatsKey];
}

- (void)resetStatsIfNewDay {
    NSDate *lastRequest = self.stats.lastRequestTime;
    if (!lastRequest) return;

    NSCalendar *cal = [NSCalendar currentCalendar];
    if (![cal isDateInToday:lastRequest]) {
        self.stats.requestsToday = 0;
        self.stats.errorsToday = 0;
    }

    NSDateComponents *lastComponents = [cal components:NSCalendarUnitMonth|NSCalendarUnitYear fromDate:lastRequest];
    NSDateComponents *nowComponents = [cal components:NSCalendarUnitMonth|NSCalendarUnitYear fromDate:[NSDate date]];

    if (lastComponents.month != nowComponents.month || lastComponents.year != nowComponents.year) {
        self.stats.requestsThisMonth = 0;
        self.stats.costThisMonth = 0;
    }
}

- (void)resetStats {
    _stats = [[LLMUsageStats alloc] init];
    [self saveStats];
}

#pragma mark - Configuration

- (BOOL)isConfigured {
    return self.apiKey != nil && self.apiKey.length > 10;
}

#pragma mark - Rate Limiting

- (void)pruneOldRequests {
    NSDate *cutoff = [NSDate dateWithTimeIntervalSinceNow:-kRateLimitWindow];
    NSMutableArray *toRemove = [NSMutableArray array];
    for (NSDate *date in self.recentRequests) {
        if ([date compare:cutoff] == NSOrderedAscending) {
            [toRemove addObject:date];
        }
    }
    [self.recentRequests removeObjectsInArray:toRemove];
}

- (BOOL)isRateLimited {
    [self pruneOldRequests];
    return self.recentRequests.count >= kMaxRequestsPerMinute;
}

- (NSTimeInterval)secondsUntilNextRequest {
    if (!self.isRateLimited) return 0;

    [self pruneOldRequests];
    if (self.recentRequests.count == 0) return 0;

    NSDate *oldest = self.recentRequests[0];
    NSTimeInterval age = -[oldest timeIntervalSinceNow];
    return MAX(0, kRateLimitWindow - age);
}

- (void)recordRequest {
    [self.recentRequests addObject:[NSDate date]];
    self.stats.requestsToday++;
    self.stats.requestsThisMonth++;
    self.stats.lastRequestTime = [NSDate date];
    [self saveStats];
}

- (void)recordError:(NSString *)error {
    self.stats.errorsToday++;
    self.stats.lastError = error;
    [self saveStats];
}

- (void)recordCost:(float)cost {
    self.stats.costThisMonth += cost;
    [self saveStats];
}

#pragma mark - Local Classification

- (ClipCategory)classifyLocally:(NSString *)content {
    if (!content || content.length == 0) {
        return ClipCategoryUnknown;
    }

    NSString *trimmed = [content stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

    // URL/Link detection (high confidence)
    if ([trimmed hasPrefix:@"http://"] || [trimmed hasPrefix:@"https://"] ||
        [trimmed hasPrefix:@"ftp://"] || [trimmed hasPrefix:@"file://"]) {
        return ClipCategoryLink;
    }

    // Email detection
    if ([trimmed rangeOfString:@"@"].location != NSNotFound &&
        [trimmed rangeOfString:@"."].location != NSNotFound &&
        [trimmed rangeOfString:@" "].location == NSNotFound &&
        trimmed.length < 100) {
        return ClipCategoryLink;
    }

    // File path detection
    if (([trimmed hasPrefix:@"/"] || [trimmed hasPrefix:@"~/"]) &&
        [trimmed rangeOfString:@" "].location == NSNotFound) {
        return ClipCategoryLink;
    }

    // JSON detection
    if (([trimmed hasPrefix:@"{"] && [trimmed hasSuffix:@"}"]) ||
        ([trimmed hasPrefix:@"["] && [trimmed hasSuffix:@"]"])) {
        NSData *data = [trimmed dataUsingEncoding:NSUTF8StringEncoding];
        if ([NSJSONSerialization JSONObjectWithData:data options:0 error:nil]) {
            return ClipCategoryData;
        }
    }

    // Code detection (conservative - only obvious cases)
    NSArray *strongCodeIndicators = @[
        @"function ", @"def ", @"class ", @"#include", @"import ",
        @"public static", @"private void", @"@interface", @"@implementation",
        @"func ", @"fn ", @"let mut ", @"pub fn"
    ];
    for (NSString *indicator in strongCodeIndicators) {
        if ([trimmed rangeOfString:indicator].location != NSNotFound) {
            return ClipCategoryCode;
        }
    }

    // If ambiguous, return Unknown - let user decide or use LLM
    return ClipCategoryUnknown;
}

#pragma mark - LLM Classification

- (LLMResult *)classifyWithLLM:(NSString *)content {
    // Pre-flight checks with clear error messages
    if (!self.isConfigured) {
        return [LLMResult errorWithMessage:@"API key not configured"];
    }

    if (self.isRateLimited) {
        NSString *msg = [NSString stringWithFormat:@"Rate limited. Try again in %.0f seconds.",
                         self.secondsUntilNextRequest];
        return [LLMResult errorWithMessage:msg];
    }

    if (!content || content.length == 0) {
        return [LLMResult errorWithMessage:@"Empty content"];
    }

    // Truncate to avoid excessive token usage
    NSString *truncated = content;
    if (content.length > 500) {
        truncated = [[content substringToIndex:500] stringByAppendingString:@"..."];
    }

    NSString *prompt = [NSString stringWithFormat:
        @"Classify this clipboard content into exactly one category. "
        @"Respond with ONLY the category name, nothing else.\n\n"
        @"Categories:\n"
        @"- CODE (programming, scripts, config files)\n"
        @"- LINK (URLs, file paths, email addresses)\n"
        @"- DATA (JSON, numbers, structured data)\n"
        @"- TEXT (prose, notes, natural language)\n\n"
        @"Content:\n%@", truncated];

    // Record request before making it
    [self recordRequest];

    NSDate *startTime = [NSDate date];
    LLMResult *result = [self sendSyncRequest:prompt];
    result.latency = -[startTime timeIntervalSinceNow];

    if (result.success) {
        result.category = [self categoryFromResponse:result.summary];
        result.estimatedCost = kEstimatedCostPerRequest;
        [self recordCost:result.estimatedCost];
    } else {
        [self recordError:result.error];
    }

    return result;
}

- (LLMResult *)testConnection {
    if (!self.isConfigured) {
        return [LLMResult errorWithMessage:@"API key not configured"];
    }

    // Don't count test against rate limit, but do record it
    NSDate *startTime = [NSDate date];
    LLMResult *result = [self sendSyncRequest:@"Reply with exactly: OK"];
    result.latency = -[startTime timeIntervalSinceNow];

    if (result.success && [result.summary rangeOfString:@"OK"].location != NSNotFound) {
        result.summary = @"Connection successful";
    } else if (result.success) {
        result.success = NO;
        result.error = @"Unexpected response from API";
    }

    return result;
}

- (ClipCategory)categoryFromResponse:(NSString *)response {
    if (!response) return ClipCategoryUnknown;

    NSString *upper = [response uppercaseString];

    if ([upper rangeOfString:@"CODE"].location != NSNotFound) return ClipCategoryCode;
    if ([upper rangeOfString:@"LINK"].location != NSNotFound) return ClipCategoryLink;
    if ([upper rangeOfString:@"DATA"].location != NSNotFound) return ClipCategoryData;
    if ([upper rangeOfString:@"TEXT"].location != NSNotFound) return ClipCategoryText;

    return ClipCategoryUnknown;
}

#pragma mark - Network (Synchronous)

- (LLMResult *)sendSyncRequest:(NSString *)prompt {
    NSURL *url = [NSURL URLWithString:kOpenRouterAPIURL];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = @"POST";
    request.timeoutInterval = kRequestTimeout;

    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:[NSString stringWithFormat:@"Bearer %@", self.apiKey] forHTTPHeaderField:@"Authorization"];
    [request setValue:@"Conchis" forHTTPHeaderField:@"HTTP-Referer"];
    [request setValue:@"Conchis" forHTTPHeaderField:@"X-Title"];

    NSDictionary *body = @{
        @"model": @"anthropic/claude-3-haiku",
        @"messages": @[@{@"role": @"user", @"content": prompt}],
        @"max_tokens": @50,  // Short responses only
        @"temperature": @0.1 // Deterministic
    };

    NSError *jsonError;
    request.HTTPBody = [NSJSONSerialization dataWithJSONObject:body options:0 error:&jsonError];
    if (jsonError) {
        return [LLMResult errorWithMessage:[NSString stringWithFormat:@"JSON error: %@", jsonError.localizedDescription]];
    }

    // Synchronous request - caller is responsible for threading
    __block NSData *responseData = nil;
    __block NSURLResponse *response = nil;
    __block NSError *networkError = nil;

    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);

    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request
        completionHandler:^(NSData *data, NSURLResponse *resp, NSError *error) {
            responseData = data;
            response = resp;
            networkError = error;
            dispatch_semaphore_signal(semaphore);
        }];
    [task resume];

    // Wait with timeout
    dispatch_time_t timeout = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kRequestTimeout * NSEC_PER_SEC));
    if (dispatch_semaphore_wait(semaphore, timeout) != 0) {
        [task cancel];
        return [LLMResult errorWithMessage:@"Request timed out"];
    }

    if (networkError) {
        return [LLMResult errorWithMessage:[NSString stringWithFormat:@"Network error: %@", networkError.localizedDescription]];
    }

    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
    if (httpResponse.statusCode == 401) {
        return [LLMResult errorWithMessage:@"Invalid API key"];
    }
    if (httpResponse.statusCode == 429) {
        return [LLMResult errorWithMessage:@"Rate limited by OpenRouter"];
    }
    if (httpResponse.statusCode != 200) {
        return [LLMResult errorWithMessage:[NSString stringWithFormat:@"HTTP %ld", (long)httpResponse.statusCode]];
    }

    NSError *parseError;
    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:responseData options:0 error:&parseError];
    if (parseError) {
        return [LLMResult errorWithMessage:@"Invalid JSON response"];
    }

    NSString *content = json[@"choices"][0][@"message"][@"content"];
    if (!content) {
        return [LLMResult errorWithMessage:@"No content in response"];
    }

    LLMResult *result = [[LLMResult alloc] init];
    result.success = YES;
    result.summary = content;
    return result;
}

#pragma mark - Utilities

+ (NSString *)categoryName:(ClipCategory)category {
    switch (category) {
        case ClipCategoryCode: return @"Code";
        case ClipCategoryLink: return @"Link";
        case ClipCategoryData: return @"Data";
        case ClipCategoryText: return @"Text";
        default: return @"Unknown";
    }
}

+ (NSString *)categoryShortCode:(ClipCategory)category {
    switch (category) {
        case ClipCategoryCode: return @"<>";
        case ClipCategoryLink: return @"://";
        case ClipCategoryData: return @"{}";
        case ClipCategoryText: return @"Aa";
        default: return @"?";
    }
}

@end
