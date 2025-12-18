# ConchisLLM Design Document

## Summary

LLM integration for clipboard classification. User-initiated, rate-limited, fail-visible.

## Design Principles

1. **Local-first**: Classification works without network. LLM is optional enhancement.
2. **User-initiated**: No automatic API calls. User explicitly requests LLM help.
3. **Fail-visible**: All errors returned as values, never swallowed silently.
4. **Bounded**: Hard limits on rate (10/min), cost tracking, timeout (10s).
5. **Testable**: No singletons. Explicit instantiation with dependency injection.

## What Was Removed (and Why)

| Feature | Reason for Removal |
|---------|-------------------|
| Singleton pattern | Untestable, hidden global state, concurrent access issues |
| Automatic classification | Too slow, expensive, blocks UI, value unproven |
| Prompt library auto-detection | Magic behavior users can't predict or control |
| Grouping suggestions | Adds complexity without demonstrated user need |
| 15 categories | Arbitrary, overlapping, unmaintainable |
| Delegate pattern | Error-prone, callbacks can be silently dropped |

## What Was Simplified

### Categories: 15 → 5

**Before:**
```
Code, URL, Email, Path, JSON, Markdown, ProseShort, ProseLong,
List, Number, Date, Address, Command, Prompt, Other
```

**After:**
```
Code, Link, Data, Text, Unknown
```

Rationale: Users can't remember 15 categories. Overlap between categories caused confusion. Four categories plus "unknown" covers 95% of cases.

### API: Async Delegate → Synchronous Return

**Before:**
```objc
- (void)classifyClipping:(FlycutClipping *)clipping;
// Result delivered via delegate callback (maybe)
```

**After:**
```objc
- (LLMResult *)classifyWithLLM:(NSString *)content;
// Result returned directly, caller controls threading
```

Rationale: Synchronous API makes error handling explicit. Caller decides threading policy. No risk of dropped callbacks.

## Explicit Tradeoffs

### Tradeoff 1: Latency vs Correctness

**Choice:** LLM classification is user-initiated, not automatic.

**Cost:** User must explicitly request classification for ambiguous content.

**Benefit:** No unexpected latency on paste operations. No surprise API costs.

### Tradeoff 2: Coverage vs Confidence

**Choice:** Local classifier returns `Unknown` for ambiguous content rather than guessing.

**Cost:** ~40% of content will be "Unknown" without LLM.

**Benefit:** No misleading classifications. User knows when local heuristics aren't sure.

### Tradeoff 3: Features vs Simplicity

**Choice:** Removed prompt library, grouping, auto-detection.

**Cost:** Less "smart" behavior.

**Benefit:** Predictable system. Fewer edge cases. Smaller attack surface.

## Invariants

1. **Rate limit is always enforced**: Client-side, before network call. Cannot be bypassed.
2. **Errors are always returned**: No code path swallows errors silently.
3. **Cost is always tracked**: Every API call increments the cost counter.
4. **API key never in code**: Keychain only. Not in preferences, not in logs.

## Failure Modes (Now Visible)

| Failure | User Sees |
|---------|-----------|
| No API key | "API key not configured" |
| Invalid API key | "Invalid API key" (HTTP 401) |
| Rate limited | "Rate limited. Try again in N seconds." |
| Network error | "Network error: [description]" |
| Timeout | "Request timed out" |
| Server error | "HTTP [status code]" |
| Malformed response | "Invalid JSON response" or "No content in response" |

## Usage Stats (Visible in Preferences)

```
Requests today: 12
Requests this month: 347
Estimated cost this month: $0.10
Errors today: 2
Last error: "Request timed out"
```

## Testing Strategy

```objc
// Create instance with test API key
ConchisLLM *llm = [[ConchisLLM alloc] initWithAPIKey:@"test-key"];

// Test local classification (no network)
XCTAssertEqual([llm classifyLocally:@"https://example.com"], ClipCategoryLink);
XCTAssertEqual([llm classifyLocally:@"Hello world"], ClipCategoryUnknown);

// Test rate limiting
for (int i = 0; i < 10; i++) {
    [llm recordRequest];
}
XCTAssertTrue(llm.isRateLimited);

// Test error handling
ConchisLLM *unconfigured = [[ConchisLLM alloc] initWithAPIKey:nil];
LLMResult *result = [unconfigured classifyWithLLM:@"test"];
XCTAssertFalse(result.success);
XCTAssertEqualObjects(result.error, @"API key not configured");
```

## Integration Point

In bezel, user presses 'i' (info) on a clipping:

```objc
// On background thread
dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    ConchisLLM *llm = [[ConchisLLM alloc] init];

    // Try local first
    ClipCategory category = [llm classifyLocally:content];

    if (category == ClipCategoryUnknown && llm.isConfigured && !llm.isRateLimited) {
        // Offer LLM classification
        LLMResult *result = [llm classifyWithLLM:content];
        if (result.success) {
            category = result.category;
        } else {
            // Show error in UI
            dispatch_async(dispatch_get_main_queue(), ^{
                [self showError:result.error];
            });
        }
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        [self showCategory:category];
    });
});
```

## Future Considerations

1. **Batch classification**: If proven valuable, could batch multiple items in one request.
2. **Model selection**: Could let user choose model (trade cost vs accuracy).
3. **Custom categories**: Could let user define their own categories.
4. **Offline cache**: Could cache LLM results for repeated content.

All of these are deferred until the basic system proves valuable in practice.
