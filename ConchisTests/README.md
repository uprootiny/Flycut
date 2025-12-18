# Conchis Tests

Unit tests for the Conchis clipboard manager (Flycut fork).

## Test Files

- `FlycutClippingTests.m` - Tests for the `FlycutClipping` data model class (~25 tests)
- `FlycutStoreTests.m` - Tests for the `FlycutStore` clipboard history storage engine (~30 tests)
- `FlycutOperatorTests.m` - Tests for the `FlycutOperator` coordinator class (~45 tests)
- `BezelSearchTests.m` - Tests for bezel search filtering functionality (~15 tests)

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

### FlycutOperator Tests
- Initialization and configuration
- Add clipping operations (valid, empty, multiple)
- Stack position management (bounds checking, navigation)
- Directional navigation (one more/less recent, ten more/less, first/last)
- Get paste operations (from stack position, from index, empty store)
- Clear operations (single item, clear all)
- Favorites store (switch, restore, toggle, save to favorites)
- Disable store functionality
- Search operations (display strings, indexes)
- Index lookup (existing, nonexistent clippings)
- Clipping retrieval (at stack position, valid numbers)
- Merge list functionality
- Edge cases (empty store operations, position after clear)

### BezelSearchTests
- Search filtering (finding matches, case insensitivity)
- Empty and no-match queries
- Partial matching
- Correct index mapping
- Navigation within filtered results
- Edge cases (empty store, special characters, whitespace, newlines, unicode, emoji)
- Limit parameter handling
- Display strings and indexes consistency

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
