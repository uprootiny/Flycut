//
//  ConchisLLM.m
//  Conchis
//
//  LLM integration for clipboard classification and prompt library.
//

#import "ConchisLLM.h"
#import "FlycutClipping.h"
#import <Security/Security.h>

static NSString * const kOpenRouterAPIURL = @"https://openrouter.ai/api/v1/chat/completions";
static NSString * const kKeychainService = @"com.conchis.openrouter";
static NSString * const kKeychainAccount = @"api_key";
static NSString * const kPromptLibraryKey = @"ConchisPromptLibrary";

@interface ConchisLLM ()
@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *prompts;
@end

@implementation ConchisLLM

+ (instancetype)shared {
    static ConchisLLM *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[ConchisLLM alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
        config.timeoutIntervalForRequest = 30.0;
        _session = [NSURLSession sessionWithConfiguration:config];
        [self loadPromptLibrary];
    }
    return self;
}

#pragma mark - API Key Management (Keychain)

- (void)setAPIKey:(NSString *)apiKey {
    if (!apiKey || apiKey.length == 0) {
        [self clearAPIKey];
        return;
    }

    NSData *keyData = [apiKey dataUsingEncoding:NSUTF8StringEncoding];

    // Delete existing key first
    [self clearAPIKey];

    // Add new key
    NSDictionary *query = @{
        (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService: kKeychainService,
        (__bridge id)kSecAttrAccount: kKeychainAccount,
        (__bridge id)kSecValueData: keyData,
        (__bridge id)kSecAttrAccessible: (__bridge id)kSecAttrAccessibleWhenUnlocked
    };

    OSStatus status = SecItemAdd((__bridge CFDictionaryRef)query, NULL);
    if (status != errSecSuccess) {
        NSLog(@"ConchisLLM: Failed to store API key in Keychain: %d", (int)status);
    }
}

- (NSString *)apiKey {
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

- (void)clearAPIKey {
    NSDictionary *query = @{
        (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService: kKeychainService,
        (__bridge id)kSecAttrAccount: kKeychainAccount
    };

    SecItemDelete((__bridge CFDictionaryRef)query);
}

- (BOOL)isConfigured {
    NSString *key = [self apiKey];
    return key != nil && key.length > 0;
}

#pragma mark - Quick Classification (Local Heuristics)

- (ClippingCategory)quickClassify:(NSString *)content {
    if (!content || content.length == 0) {
        return ClippingCategoryUnknown;
    }

    NSString *trimmed = [content stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

    // URL detection
    if ([trimmed hasPrefix:@"http://"] || [trimmed hasPrefix:@"https://"] || [trimmed hasPrefix:@"ftp://"]) {
        return ClippingCategoryURL;
    }

    // Email detection
    NSRegularExpression *emailRegex = [NSRegularExpression regularExpressionWithPattern:@"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$" options:0 error:nil];
    if ([emailRegex numberOfMatchesInString:trimmed options:0 range:NSMakeRange(0, trimmed.length)] > 0) {
        return ClippingCategoryEmail;
    }

    // Path detection (Unix or Windows)
    if ([trimmed hasPrefix:@"/"] || [trimmed hasPrefix:@"~/"] || [trimmed hasPrefix:@"C:\\"] || [trimmed hasPrefix:@"."]) {
        if ([trimmed rangeOfString:@"/"].location != NSNotFound || [trimmed rangeOfString:@"\\"].location != NSNotFound) {
            return ClippingCategoryPath;
        }
    }

    // JSON detection
    if (([trimmed hasPrefix:@"{"] && [trimmed hasSuffix:@"}"]) ||
        ([trimmed hasPrefix:@"["] && [trimmed hasSuffix:@"]"])) {
        NSData *data = [trimmed dataUsingEncoding:NSUTF8StringEncoding];
        if ([NSJSONSerialization JSONObjectWithData:data options:0 error:nil]) {
            return ClippingCategoryJSON;
        }
    }

    // Number detection
    NSCharacterSet *nonNumeric = [[NSCharacterSet characterSetWithCharactersInString:@"0123456789.,+-eE "] invertedSet];
    if ([trimmed rangeOfCharacterFromSet:nonNumeric].location == NSNotFound && trimmed.length < 50) {
        return ClippingCategoryNumber;
    }

    // Command detection (shell commands)
    NSArray *commandPrefixes = @[@"cd ", @"ls ", @"cat ", @"grep ", @"git ", @"npm ", @"yarn ", @"brew ", @"sudo ", @"chmod ", @"mkdir ", @"rm ", @"cp ", @"mv "];
    for (NSString *prefix in commandPrefixes) {
        if ([trimmed hasPrefix:prefix] || [trimmed hasPrefix:[@"$" stringByAppendingString:prefix]]) {
            return ClippingCategoryCommand;
        }
    }

    // Code detection (heuristics)
    NSArray *codeIndicators = @[@"function ", @"def ", @"class ", @"import ", @"#include", @"var ", @"let ", @"const ", @"return ", @"if (", @"for (", @"while (", @"->", @"=>", @"public ", @"private ", @"@interface", @"@implementation"];
    for (NSString *indicator in codeIndicators) {
        if ([trimmed rangeOfString:indicator].location != NSNotFound) {
            return ClippingCategoryCode;
        }
    }

    // Markdown detection
    if ([trimmed hasPrefix:@"# "] || [trimmed hasPrefix:@"## "] || [trimmed hasPrefix:@"- "] || [trimmed hasPrefix:@"* "] ||
        [trimmed rangeOfString:@"```"].location != NSNotFound || [trimmed rangeOfString:@"**"].location != NSNotFound) {
        return ClippingCategoryMarkdown;
    }

    // List detection
    NSArray *lines = [trimmed componentsSeparatedByString:@"\n"];
    if (lines.count >= 3) {
        BOOL isList = YES;
        for (NSString *line in lines) {
            NSString *trimmedLine = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            if (trimmedLine.length > 0 &&
                !([trimmedLine hasPrefix:@"- "] || [trimmedLine hasPrefix:@"* "] ||
                  [trimmedLine hasPrefix:@"• "] || [[trimmedLine substringToIndex:MIN(3, trimmedLine.length)] rangeOfCharacterFromSet:[NSCharacterSet decimalDigitCharacterSet]].location != NSNotFound)) {
                isList = NO;
                break;
            }
        }
        if (isList) {
            return ClippingCategoryList;
        }
    }

    // Prompt detection (questions or instructions to AI)
    NSArray *promptIndicators = @[@"Please ", @"Can you ", @"Could you ", @"Write ", @"Generate ", @"Create ", @"Explain ", @"Help me ", @"I want ", @"I need "];
    for (NSString *indicator in promptIndicators) {
        if ([trimmed hasPrefix:indicator]) {
            return ClippingCategoryPrompt;
        }
    }

    // Prose detection by length
    if (trimmed.length < 100) {
        return ClippingCategoryProseShort;
    } else {
        return ClippingCategoryProseLong;
    }
}

#pragma mark - LLM Classification

- (void)classifyClipping:(FlycutClipping *)clipping {
    if (!self.isConfigured) {
        if ([self.delegate respondsToSelector:@selector(llmDidFailWithError:)]) {
            NSError *error = [NSError errorWithDomain:@"ConchisLLM" code:1 userInfo:@{NSLocalizedDescriptionKey: @"API key not configured"}];
            [self.delegate llmDidFailWithError:error];
        }
        return;
    }

    NSString *content = [clipping contents];
    if (content.length > 2000) {
        content = [content substringToIndex:2000];
    }

    NSString *prompt = [NSString stringWithFormat:@"Classify this clipboard content into exactly one category. Respond with only the category name.\n\nCategories: code, url, email, path, json, markdown, prose_short, prose_long, list, number, date, address, command, prompt, other\n\nContent:\n%@", content];

    [self sendPrompt:prompt completion:^(NSString *response, NSError *error) {
        if (error) {
            if ([self.delegate respondsToSelector:@selector(llmDidFailWithError:)]) {
                [self.delegate llmDidFailWithError:error];
            }
            return;
        }

        ClippingCategory category = [self categoryFromString:[response lowercaseString]];
        if ([self.delegate respondsToSelector:@selector(llmDidClassifyClipping:withCategory:confidence:)]) {
            [self.delegate llmDidClassifyClipping:clipping withCategory:category confidence:0.8];
        }
    }];
}

- (ClippingCategory)categoryFromString:(NSString *)string {
    string = [string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

    NSDictionary *mapping = @{
        @"code": @(ClippingCategoryCode),
        @"url": @(ClippingCategoryURL),
        @"email": @(ClippingCategoryEmail),
        @"path": @(ClippingCategoryPath),
        @"json": @(ClippingCategoryJSON),
        @"markdown": @(ClippingCategoryMarkdown),
        @"prose_short": @(ClippingCategoryProseShort),
        @"prose_long": @(ClippingCategoryProseLong),
        @"list": @(ClippingCategoryList),
        @"number": @(ClippingCategoryNumber),
        @"date": @(ClippingCategoryDate),
        @"address": @(ClippingCategoryAddress),
        @"command": @(ClippingCategoryCommand),
        @"prompt": @(ClippingCategoryPrompt),
        @"other": @(ClippingCategoryOther)
    };

    NSNumber *value = mapping[string];
    return value ? [value integerValue] : ClippingCategoryUnknown;
}

#pragma mark - Prompt Library

- (void)loadPromptLibrary {
    NSArray *saved = [[NSUserDefaults standardUserDefaults] arrayForKey:kPromptLibraryKey];
    if (saved) {
        _prompts = [saved mutableCopy];
    } else {
        _prompts = [NSMutableArray array];
    }
}

- (void)savePromptLibrary {
    [[NSUserDefaults standardUserDefaults] setObject:_prompts forKey:kPromptLibraryKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (NSArray<NSDictionary *> *)promptLibrary {
    return [_prompts copy];
}

- (void)addPromptToLibrary:(NSString *)prompt withTags:(NSArray<NSString *> *)tags {
    NSDictionary *entry = @{
        @"prompt": prompt,
        @"tags": tags ?: @[],
        @"created": [NSDate date],
        @"useCount": @0
    };
    [_prompts insertObject:entry atIndex:0];
    [self savePromptLibrary];
}

- (void)removePromptAtIndex:(NSUInteger)index {
    if (index < _prompts.count) {
        [_prompts removeObjectAtIndex:index];
        [self savePromptLibrary];
    }
}

- (NSArray<NSDictionary *> *)promptsMatchingTags:(NSArray<NSString *> *)tags {
    NSMutableArray *matches = [NSMutableArray array];
    for (NSDictionary *entry in _prompts) {
        NSArray *entryTags = entry[@"tags"];
        for (NSString *tag in tags) {
            if ([entryTags containsObject:tag]) {
                [matches addObject:entry];
                break;
            }
        }
    }
    return matches;
}

- (void)analyzeForReusablePrompts:(NSString *)content {
    if (!self.isConfigured || content.length < 20) {
        return;
    }

    // Only analyze content that looks like a prompt
    if ([self quickClassify:content] != ClippingCategoryPrompt) {
        return;
    }

    NSString *analysisPrompt = [NSString stringWithFormat:@"Analyze this text. If it's a reusable prompt template (something that could be used again with different inputs), respond with:\nREUSABLE: [2-3 word description]\nTAGS: [comma-separated tags]\n\nIf it's not reusable, respond with: NOT_REUSABLE\n\nText:\n%@", content];

    [self sendPrompt:analysisPrompt completion:^(NSString *response, NSError *error) {
        if (error || !response) return;

        if ([response hasPrefix:@"REUSABLE:"]) {
            NSArray *lines = [response componentsSeparatedByString:@"\n"];
            NSMutableArray *tags = [NSMutableArray array];

            for (NSString *line in lines) {
                if ([line hasPrefix:@"TAGS:"]) {
                    NSString *tagString = [[line substringFromIndex:5] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
                    tags = [[tagString componentsSeparatedByString:@","] mutableCopy];
                    for (NSUInteger i = 0; i < tags.count; i++) {
                        tags[i] = [tags[i] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
                    }
                }
            }

            [self addPromptToLibrary:content withTags:tags];

            if ([self.delegate respondsToSelector:@selector(llmDidIdentifyReusablePrompt:withTags:)]) {
                [self.delegate llmDidIdentifyReusablePrompt:content withTags:tags];
            }
        }
    }];
}

#pragma mark - Grouping

- (void)suggestGroupsForClippings:(NSArray<FlycutClipping *> *)clippings
                       completion:(void (^)(NSArray<NSDictionary *> *groups, NSError *error))completion {
    if (!self.isConfigured) {
        NSError *error = [NSError errorWithDomain:@"ConchisLLM" code:1 userInfo:@{NSLocalizedDescriptionKey: @"API key not configured"}];
        completion(nil, error);
        return;
    }

    NSMutableString *contentList = [NSMutableString string];
    for (NSUInteger i = 0; i < MIN(clippings.count, 20); i++) {
        FlycutClipping *clip = clippings[i];
        NSString *preview = [clip contents];
        if (preview.length > 100) {
            preview = [[preview substringToIndex:100] stringByAppendingString:@"..."];
        }
        [contentList appendFormat:@"%lu. %@\n", (unsigned long)i, preview];
    }

    NSString *prompt = [NSString stringWithFormat:@"Group these clipboard items by topic/type. Respond in format:\nGROUP: [name]\nITEMS: [comma-separated indices]\n\nItems:\n%@", contentList];

    [self sendPrompt:prompt completion:^(NSString *response, NSError *error) {
        if (error) {
            completion(nil, error);
            return;
        }

        NSMutableArray *groups = [NSMutableArray array];
        NSArray *lines = [response componentsSeparatedByString:@"\n"];
        NSString *currentGroup = nil;

        for (NSString *line in lines) {
            if ([line hasPrefix:@"GROUP:"]) {
                currentGroup = [[line substringFromIndex:6] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            } else if ([line hasPrefix:@"ITEMS:"] && currentGroup) {
                NSString *itemsStr = [[line substringFromIndex:6] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
                NSArray *indexStrings = [itemsStr componentsSeparatedByString:@","];
                NSMutableArray *indices = [NSMutableArray array];
                for (NSString *idx in indexStrings) {
                    [indices addObject:@([[idx stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] integerValue])];
                }
                [groups addObject:@{@"name": currentGroup, @"indices": indices}];
                currentGroup = nil;
            }
        }

        completion(groups, nil);
    }];
}

#pragma mark - API Communication

- (void)sendPrompt:(NSString *)prompt completion:(void (^)(NSString *response, NSError *error))completion {
    NSString *apiKey = [self apiKey];
    if (!apiKey) {
        NSError *error = [NSError errorWithDomain:@"ConchisLLM" code:1 userInfo:@{NSLocalizedDescriptionKey: @"API key not configured"}];
        completion(nil, error);
        return;
    }

    NSURL *url = [NSURL URLWithString:kOpenRouterAPIURL];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = @"POST";
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:[NSString stringWithFormat:@"Bearer %@", apiKey] forHTTPHeaderField:@"Authorization"];
    [request setValue:@"Conchis Clipboard Manager" forHTTPHeaderField:@"HTTP-Referer"];
    [request setValue:@"Conchis" forHTTPHeaderField:@"X-Title"];

    NSDictionary *body = @{
        @"model": @"anthropic/claude-3-haiku",
        @"messages": @[@{@"role": @"user", @"content": prompt}],
        @"max_tokens": @500,
        @"temperature": @0.3
    };

    NSError *jsonError;
    request.HTTPBody = [NSJSONSerialization dataWithJSONObject:body options:0 error:&jsonError];
    if (jsonError) {
        completion(nil, jsonError);
        return;
    }

    NSURLSessionDataTask *task = [self.session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil, error);
            });
            return;
        }

        NSError *parseError;
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&parseError];
        if (parseError) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil, parseError);
            });
            return;
        }

        NSString *content = json[@"choices"][0][@"message"][@"content"];
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(content, nil);
        });
    }];
    [task resume];
}

#pragma mark - Utility

+ (NSString *)categoryName:(ClippingCategory)category {
    switch (category) {
        case ClippingCategoryCode: return @"Code";
        case ClippingCategoryURL: return @"URL";
        case ClippingCategoryEmail: return @"Email";
        case ClippingCategoryPath: return @"Path";
        case ClippingCategoryJSON: return @"JSON";
        case ClippingCategoryMarkdown: return @"Markdown";
        case ClippingCategoryProseShort: return @"Short Text";
        case ClippingCategoryProseLong: return @"Long Text";
        case ClippingCategoryList: return @"List";
        case ClippingCategoryNumber: return @"Number";
        case ClippingCategoryDate: return @"Date";
        case ClippingCategoryAddress: return @"Address";
        case ClippingCategoryCommand: return @"Command";
        case ClippingCategoryPrompt: return @"Prompt";
        case ClippingCategoryOther: return @"Other";
        default: return @"Unknown";
    }
}

+ (NSString *)categoryEmoji:(ClippingCategory)category {
    switch (category) {
        case ClippingCategoryCode: return @"</>"; // No emoji, text representation
        case ClippingCategoryURL: return @"link";
        case ClippingCategoryEmail: return @"@";
        case ClippingCategoryPath: return @"/";
        case ClippingCategoryJSON: return @"{}";
        case ClippingCategoryMarkdown: return @"#";
        case ClippingCategoryProseShort: return @"Aa";
        case ClippingCategoryProseLong: return @"Aa+";
        case ClippingCategoryList: return @"-";
        case ClippingCategoryNumber: return @"123";
        case ClippingCategoryDate: return @"cal";
        case ClippingCategoryAddress: return @"loc";
        case ClippingCategoryCommand: return @"$";
        case ClippingCategoryPrompt: return @"?";
        case ClippingCategoryOther: return @"...";
        default: return @"?";
    }
}

@end
