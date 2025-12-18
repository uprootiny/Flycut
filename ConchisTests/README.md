# Conchis Tests

Unit tests for the Conchis clipboard manager (Flycut fork).

## Test Files

- `FlycutClippingTests.m` - Tests for the `FlycutClipping` data model class
- `FlycutStoreTests.m` - Tests for the `FlycutStore` clipboard history storage engine

## Running Tests

### Option 1: Add Test Target to Xcode (Recommended)

1. Open `Flycut.xcodeproj` in Xcode
2. File → New → Target → macOS → Unit Testing Bundle
3. Name it "ConchisTests"
4. Add the test files from this directory to the target
5. Add `FlycutEngine` sources to the test target's Compile Sources
6. Run tests with Cmd+U or Product → Test

### Option 2: Command Line (after target is configured)

```bash
xcodebuild test \
  -project Flycut.xcodeproj \
  -scheme Flycut \
  -destination 'platform=macOS'
```

## Test Coverage

### FlycutClipping Tests
- Initialization (default and custom)
- Display string truncation (short, long, exact length, multiline)
- Whitespace handling (leading whitespace, whitespace-only)
- Setter/getter consistency
- Equality comparison (same contents, different contents, nil, different class)
- Unicode content handling
- Edge cases (empty content, very long content)

### FlycutStore Tests
- Initialization (default, custom, edge cases with zero/negative values)
- Add clipping operations
- Memory limit enforcement (rememberNum)
- Retrieval operations (by position, previous contents)
- Search functionality (case-insensitive, empty queries, no matches)
- Delete operations (single item, clear all)
- Move operations (move to top, move from/to)
- Merge list functionality
- Index lookup
- Display length updates
- Modified state tracking
- Delegate callback verification (using mock delegate)
- Edge cases (empty store, invalid indexes)

## Writing New Tests

Follow these conventions:

1. Use XCTest framework
2. One test class per source file being tested
3. Group related tests with `#pragma mark` sections
4. Test method names should describe what is being tested
5. Use manual memory management (retain/release) to match production code
6. Create mock objects for delegate testing

Example:
```objc
- (void)testMethodName_ExpectedBehavior {
    // Arrange
    FlycutClipping *clipping = [[FlycutClipping alloc] init];

    // Act
    [clipping setContents:@"test"];

    // Assert
    XCTAssertEqualObjects([clipping contents], @"test");

    // Cleanup
    [clipping release];
}
```
