//
//  BezelSearchTests.m
//  ConchisTests
//
//  Unit tests for bezel search filtering functionality.
//  Tests the FlycutOperator search methods used by bezel filtering.
//

#import <XCTest/XCTest.h>
#import "FlycutOperator.h"
#import "FlycutClipping.h"

@interface BezelSearchTests : XCTestCase
@property (nonatomic, retain) FlycutOperator *operator;
@end

@implementation BezelSearchTests

- (void)setUp {
    [super setUp];

    [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithInt:100] forKey:@"rememberNum"];
    [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithInt:40] forKey:@"favoritesRememberNum"];
    [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithBool:NO] forKey:@"removeDuplicates"];
    [[NSUserDefaults standardUserDefaults] synchronize];

    self.operator = [[FlycutOperator alloc] init];
    [self.operator awakeFromNibDisplaying:10 withDisplayLength:40 withSaveSelector:nil forTarget:nil];
}

- (void)tearDown {
    [self.operator release];
    self.operator = nil;
    [super tearDown];
}

#pragma mark - Helper Methods

- (void)addTestClippings {
    [self.operator addClipping:@"Apple pie recipe"
                        ofType:@"public.utf8-plain-text"
                       fromApp:@"Notes"
                withAppBundleURL:nil
                        target:nil
          clippingAddedSelector:nil];

    [self.operator addClipping:@"Banana bread instructions"
                        ofType:@"public.utf8-plain-text"
                       fromApp:@"Safari"
                withAppBundleURL:nil
                        target:nil
          clippingAddedSelector:nil];

    [self.operator addClipping:@"Cherry cobbler tips"
                        ofType:@"public.utf8-plain-text"
                       fromApp:@"Notes"
                withAppBundleURL:nil
                        target:nil
          clippingAddedSelector:nil];

    [self.operator addClipping:@"Apple cider vinegar"
                        ofType:@"public.utf8-plain-text"
                       fromApp:@"Chrome"
                withAppBundleURL:nil
                        target:nil
          clippingAddedSelector:nil];

    [self.operator addClipping:@"Date night ideas"
                        ofType:@"public.utf8-plain-text"
                       fromApp:@"Safari"
                withAppBundleURL:nil
                        target:nil
          clippingAddedSelector:nil];
}

#pragma mark - Search Filtering Tests

- (void)testPreviousIndexesContaining_FindsMatches {
    [self addTestClippings];

    NSArray *indexes = [self.operator previousIndexes:100 containing:@"Apple"];

    XCTAssertEqual([indexes count], 2, @"Should find 2 items containing 'Apple'");
}

- (void)testPreviousIndexesContaining_CaseInsensitive {
    [self addTestClippings];

    NSArray *indexes = [self.operator previousIndexes:100 containing:@"apple"];

    XCTAssertEqual([indexes count], 2, @"Search should be case-insensitive");
}

- (void)testPreviousIndexesContaining_EmptyQuery {
    [self addTestClippings];

    NSArray *indexes = [self.operator previousIndexes:100 containing:@""];

    XCTAssertEqual([indexes count], 5, @"Empty search should return all items");
}

- (void)testPreviousIndexesContaining_NoMatches {
    [self addTestClippings];

    NSArray *indexes = [self.operator previousIndexes:100 containing:@"xyz123"];

    XCTAssertEqual([indexes count], 0, @"Should find 0 items for non-matching query");
}

- (void)testPreviousIndexesContaining_PartialMatch {
    [self addTestClippings];

    NSArray *indexes = [self.operator previousIndexes:100 containing:@"pie"];

    XCTAssertEqual([indexes count], 1, @"Should find 1 item containing 'pie'");
}

- (void)testPreviousDisplayStrings_Filtering {
    [self addTestClippings];

    NSArray *strings = [self.operator previousDisplayStrings:100 containing:@"bread"];

    XCTAssertEqual([strings count], 1, @"Should find 1 item containing 'bread'");
    XCTAssertTrue([[strings firstObject] containsString:@"Banana"],
                  @"Result should contain 'Banana bread'");
}

#pragma mark - Navigation State Tests

- (void)testStackPositionNavigationWithFilter {
    [self addTestClippings];

    // Get filtered indexes
    NSArray *filteredIndexes = [self.operator previousIndexes:100 containing:@"Apple"];
    XCTAssertEqual([filteredIndexes count], 2, @"Should have 2 filtered items");

    // Navigate to first filtered item
    int firstFilteredIndex = [[filteredIndexes objectAtIndex:0] intValue];
    [self.operator setStackPositionTo:firstFilteredIndex];

    FlycutClipping *clipping = [self.operator clippingAtStackPosition];
    XCTAssertTrue([[clipping contents] containsString:@"Apple"],
                  @"First filtered item should contain 'Apple'");

    // Navigate to second filtered item
    int secondFilteredIndex = [[filteredIndexes objectAtIndex:1] intValue];
    [self.operator setStackPositionTo:secondFilteredIndex];

    clipping = [self.operator clippingAtStackPosition];
    XCTAssertTrue([[clipping contents] containsString:@"Apple"],
                  @"Second filtered item should contain 'Apple'");
}

- (void)testFilteredIndexesAreValid {
    [self addTestClippings];

    NSArray *indexes = [self.operator previousIndexes:100 containing:@"Apple"];

    for (NSNumber *indexNum in indexes) {
        int index = [indexNum intValue];
        XCTAssertTrue(index >= 0 && index < [self.operator jcListCount],
                      @"Filtered index should be valid");

        [self.operator setStackPositionTo:index];
        FlycutClipping *clipping = [self.operator clippingAtStackPosition];
        XCTAssertNotNil(clipping, @"Should get clipping at filtered index");
    }
}

#pragma mark - Edge Cases

- (void)testSearchOnEmptyStore {
    NSArray *indexes = [self.operator previousIndexes:100 containing:@"test"];
    XCTAssertEqual([indexes count], 0, @"Empty store should return empty results");
}

- (void)testSearchWithSpecialCharacters {
    [self.operator addClipping:@"Price: $100.00"
                        ofType:@"public.utf8-plain-text"
                       fromApp:@"App"
                withAppBundleURL:nil
                        target:nil
          clippingAddedSelector:nil];

    NSArray *indexes = [self.operator previousIndexes:100 containing:@"$100"];
    XCTAssertEqual([indexes count], 1, @"Should find item with special characters");
}

- (void)testSearchWithWhitespace {
    [self.operator addClipping:@"Hello   World"
                        ofType:@"public.utf8-plain-text"
                       fromApp:@"App"
                withAppBundleURL:nil
                        target:nil
          clippingAddedSelector:nil];

    NSArray *indexes = [self.operator previousIndexes:100 containing:@"Hello   World"];
    XCTAssertEqual([indexes count], 1, @"Should find item with whitespace");
}

- (void)testSearchWithNewlines {
    [self.operator addClipping:@"Line1\nLine2\nLine3"
                        ofType:@"public.utf8-plain-text"
                       fromApp:@"App"
                withAppBundleURL:nil
                        target:nil
          clippingAddedSelector:nil];

    NSArray *indexes = [self.operator previousIndexes:100 containing:@"Line2"];
    XCTAssertEqual([indexes count], 1, @"Should find item by searching within lines");
}

- (void)testSearchWithUnicode {
    [self.operator addClipping:@"Café résumé naïve"
                        ofType:@"public.utf8-plain-text"
                       fromApp:@"App"
                withAppBundleURL:nil
                        target:nil
          clippingAddedSelector:nil];

    NSArray *indexes = [self.operator previousIndexes:100 containing:@"résumé"];
    XCTAssertEqual([indexes count], 1, @"Should find item with unicode characters");
}

- (void)testSearchWithEmoji {
    [self.operator addClipping:@"Hello 🎉 World"
                        ofType:@"public.utf8-plain-text"
                       fromApp:@"App"
                withAppBundleURL:nil
                        target:nil
          clippingAddedSelector:nil];

    NSArray *indexes = [self.operator previousIndexes:100 containing:@"🎉"];
    XCTAssertEqual([indexes count], 1, @"Should find item with emoji");
}

- (void)testSearchLimitParameter {
    [self addTestClippings];

    // Request only 2 results
    NSArray *indexes = [self.operator previousIndexes:2 containing:@""];
    XCTAssertEqual([indexes count], 2, @"Should respect limit parameter");
}

- (void)testDisplayStringsMatchIndexes {
    [self addTestClippings];

    NSArray *strings = [self.operator previousDisplayStrings:100 containing:@"Apple"];
    NSArray *indexes = [self.operator previousIndexes:100 containing:@"Apple"];

    XCTAssertEqual([strings count], [indexes count],
                   @"Display strings and indexes should have same count");
}

@end
