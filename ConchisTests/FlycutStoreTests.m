//
//  FlycutStoreTests.m
//  ConchisTests
//
//  Unit tests for FlycutStore - the clipboard history storage engine.
//  Tests cover initialization, CRUD operations, search, and boundary conditions.
//

#import <XCTest/XCTest.h>
#import "FlycutStore.h"
#import "FlycutClipping.h"

@interface FlycutStoreTests : XCTestCase
@property (nonatomic, retain) FlycutStore *store;
@end

@implementation FlycutStoreTests

- (void)setUp {
    [super setUp];
    self.store = [[FlycutStore alloc] initRemembering:10 displaying:5 withDisplayLength:40];
}

- (void)tearDown {
    [self.store release];
    self.store = nil;
    [super tearDown];
}

#pragma mark - Helper Methods

- (void)addClipping:(NSString *)contents {
    [self.store addClipping:contents ofType:@"public.utf8-plain-text" fromApp:@"TestApp" withAppBundleURL:nil target:nil clippingAddedSelector:nil];
}

#pragma mark - Initialization Tests

- (void)testInitialization {
    XCTAssertNotNil(self.store, @"Store should initialize");
    XCTAssertEqual([self.store jcListCount], 0, @"New store should be empty");
}

- (void)testInitializationWithCustomValues {
    FlycutStore *customStore = [[FlycutStore alloc] initRemembering:50 displaying:10 withDisplayLength:100];
    XCTAssertNotNil(customStore, @"Custom store should initialize");
    [customStore release];
}

- (void)testInitializationWithZeroRememberNum {
    FlycutStore *zeroStore = [[FlycutStore alloc] initRemembering:0 displaying:5 withDisplayLength:40];
    XCTAssertNotNil(zeroStore, @"Store with zero remember should initialize");
    [zeroStore release];
}

#pragma mark - Add Clipping Tests

- (void)testAddClipping {
    [self addClipping:@"Test content"];
    XCTAssertEqual([self.store jcListCount], 1, @"Store should have one clipping");
}

- (void)testAddMultipleClippings {
    [self addClipping:@"First"];
    [self addClipping:@"Second"];
    [self addClipping:@"Third"];
    XCTAssertEqual([self.store jcListCount], 3, @"Store should have three clippings");
}

- (void)testAddClippingOrder {
    [self addClipping:@"First"];
    [self addClipping:@"Second"];
    [self addClipping:@"Third"];

    // Most recent should be at index 0
    XCTAssertEqualObjects([self.store clippingContentsAtPosition:0], @"Third", @"Most recent at position 0");
    XCTAssertEqualObjects([self.store clippingContentsAtPosition:1], @"Second", @"Second most recent at position 1");
    XCTAssertEqualObjects([self.store clippingContentsAtPosition:2], @"First", @"Oldest at position 2");
}

- (void)testAddEmptyClipping {
    bool result = [self.store addClipping:@"" ofType:@"text" fromApp:@"App" withAppBundleURL:nil target:nil clippingAddedSelector:nil];
    XCTAssertFalse(result, @"Adding empty clipping should fail");
    XCTAssertEqual([self.store jcListCount], 0, @"Store should remain empty");
}

#pragma mark - Memory Limit Tests

- (void)testRememberNumEnforcement {
    // Store remembers 10 items
    for (int i = 0; i < 15; i++) {
        [self addClipping:[NSString stringWithFormat:@"Clipping %d", i]];
    }
    XCTAssertEqual([self.store jcListCount], 10, @"Store should not exceed rememberNum");
}

- (void)testOldestClippingRemoved {
    for (int i = 0; i < 12; i++) {
        [self addClipping:[NSString stringWithFormat:@"Clipping %d", i]];
    }
    // Clipping 0 and 1 should have been removed
    NSString *oldest = [self.store clippingContentsAtPosition:9];
    XCTAssertEqualObjects(oldest, @"Clipping 2", @"Oldest remaining should be Clipping 2");
}

#pragma mark - Retrieval Tests

- (void)testClippingContentsAtPosition {
    [self addClipping:@"Test content"];
    NSString *contents = [self.store clippingContentsAtPosition:0];
    XCTAssertEqualObjects(contents, @"Test content", @"Should retrieve correct contents");
}

- (void)testClippingContentsAtInvalidPosition {
    [self addClipping:@"Test"];
    NSString *contents = [self.store clippingContentsAtPosition:99];
    XCTAssertNil(contents, @"Invalid position should return nil");
}

- (void)testClippingAtPosition {
    [self.store addClipping:@"Content" ofType:@"text" fromApp:@"Safari" withAppBundleURL:@"/Apps/Safari" target:nil clippingAddedSelector:nil];

    FlycutClipping *clipping = [self.store clippingAtPosition:0];
    XCTAssertNotNil(clipping, @"Should return clipping");
    XCTAssertEqualObjects([clipping contents], @"Content", @"Contents should match");
    XCTAssertEqualObjects([clipping appLocalizedName], @"Safari", @"App name should match");
}

#pragma mark - Search Tests

- (void)testPreviousContentsContaining {
    [self addClipping:@"Apple pie"];
    [self addClipping:@"Banana bread"];
    [self addClipping:@"Apple cider"];

    NSArray *results = [self.store previousContents:10 containing:@"Apple"];
    XCTAssertEqual([results count], 2, @"Should find 2 matches");
}

- (void)testSearchCaseInsensitive {
    [self addClipping:@"APPLE"];
    [self addClipping:@"apple"];
    [self addClipping:@"Apple"];

    NSArray *results = [self.store previousContents:10 containing:@"apple"];
    XCTAssertEqual([results count], 3, @"Search should be case-insensitive");
}

- (void)testSearchEmptyQuery {
    [self addClipping:@"First"];
    [self addClipping:@"Second"];

    NSArray *results = [self.store previousContents:10 containing:@""];
    XCTAssertEqual([results count], 2, @"Empty query should return all");
}

- (void)testSearchNoMatches {
    [self addClipping:@"Apple"];
    [self addClipping:@"Banana"];

    NSArray *results = [self.store previousContents:10 containing:@"xyz"];
    XCTAssertEqual([results count], 0, @"Should find no matches");
}

- (void)testPreviousIndexesContaining {
    [self addClipping:@"First Apple"];
    [self addClipping:@"Banana"];
    [self addClipping:@"Second Apple"];

    NSArray *indexes = [self.store previousIndexes:10 containing:@"Apple"];
    XCTAssertEqual([indexes count], 2, @"Should find 2 matching indexes");
}

#pragma mark - Delete Tests

- (void)testDeleteClippingAtIndex {
    [self addClipping:@"First"];
    [self addClipping:@"Second"];
    [self addClipping:@"Third"];

    [self.store clearItem:1]; // Delete "Second"

    XCTAssertEqual([self.store jcListCount], 2, @"Should have 2 clippings");
    XCTAssertEqualObjects([self.store clippingContentsAtPosition:0], @"Third", @"Third still at 0");
    XCTAssertEqualObjects([self.store clippingContentsAtPosition:1], @"First", @"First now at 1");
}

- (void)testClearAll {
    [self addClipping:@"First"];
    [self addClipping:@"Second"];
    [self addClipping:@"Third"];

    [self.store clearList];

    XCTAssertEqual([self.store jcListCount], 0, @"Store should be empty");
}

#pragma mark - Move Tests

- (void)testMoveToTop {
    [self addClipping:@"First"];
    [self addClipping:@"Second"];
    [self addClipping:@"Third"];

    [self.store moveToTop:2]; // Move "First" to top

    XCTAssertEqualObjects([self.store clippingContentsAtPosition:0], @"First", @"First should now be at top");
    XCTAssertEqualObjects([self.store clippingContentsAtPosition:1], @"Third", @"Third moves down");
    XCTAssertEqualObjects([self.store clippingContentsAtPosition:2], @"Second", @"Second moves down");
}

#pragma mark - Index Lookup Tests

- (void)testIndexOfClipping {
    [self.store addClipping:@"Content1" ofType:@"text" fromApp:@"App1" withAppBundleURL:nil target:nil clippingAddedSelector:nil];
    [self.store addClipping:@"Content2" ofType:@"text" fromApp:@"App2" withAppBundleURL:nil target:nil clippingAddedSelector:nil];

    int index = [self.store indexOfClipping:@"Content1" ofType:@"text" fromApp:@"App1" withAppBundleURL:nil];
    XCTAssertEqual(index, 1, @"Content1 should be at index 1");
}

- (void)testIndexOfNonexistentClipping {
    [self addClipping:@"Existing"];

    int index = [self.store indexOfClipping:@"Nonexistent" ofType:@"text" fromApp:@"App" withAppBundleURL:nil];
    XCTAssertEqual(index, -1, @"Nonexistent clipping should return -1");
}

#pragma mark - Display String Tests

- (void)testPreviousDisplayStrings {
    [self addClipping:@"Short"];
    [self addClipping:@"This is a much longer string that should be truncated"];

    NSArray *strings = [self.store previousDisplayStrings:10 containing:@""];
    XCTAssertEqual([strings count], 2, @"Should return 2 display strings");
}

- (void)testDisplayStringTruncation {
    NSMutableString *longString = [NSMutableString string];
    for (int i = 0; i < 100; i++) {
        [longString appendString:@"word "];
    }
    [self addClipping:longString];

    NSArray *strings = [self.store previousDisplayStrings:10 containing:@""];
    NSString *display = [strings firstObject];
    XCTAssertTrue([display length] <= 43, @"Display string should be truncated (40 + ellipsis)");
}

#pragma mark - Modified State Tests

- (void)testModifiedStateAfterAdd {
    XCTAssertFalse([self.store modifiedSinceLastSave], @"New store not modified");

    [self addClipping:@"Test"];

    XCTAssertTrue([self.store modifiedSinceLastSave], @"Store modified after add");
}

- (void)testModifiedStateAfterDelete {
    [self addClipping:@"Test"];
    [self.store setModifiedSinceLastSave:NO];

    [self.store clearItem:0];

    XCTAssertTrue([self.store modifiedSinceLastSave], @"Store modified after delete");
}

#pragma mark - Edge Cases

- (void)testOperationsOnEmptyStore {
    XCTAssertNil([self.store clippingContentsAtPosition:0], @"Empty store returns nil");
    XCTAssertNil([self.store clippingAtPosition:0], @"Empty store returns nil clipping");

    NSArray *results = [self.store previousContents:10 containing:@"test"];
    XCTAssertEqual([results count], 0, @"Empty store returns empty results");
}

- (void)testUnicodeContent {
    [self addClipping:@"日本語テスト 🎉 émojis"];

    NSString *contents = [self.store clippingContentsAtPosition:0];
    XCTAssertEqualObjects(contents, @"日本語テスト 🎉 émojis", @"Unicode should be preserved");
}

- (void)testNewlineContent {
    [self addClipping:@"Line1\nLine2\nLine3"];

    NSString *contents = [self.store clippingContentsAtPosition:0];
    XCTAssertTrue([contents containsString:@"\n"], @"Newlines should be preserved");
}

- (void)testWhitespaceContent {
    [self addClipping:@"  spaces  "];

    NSString *contents = [self.store clippingContentsAtPosition:0];
    XCTAssertEqualObjects(contents, @"  spaces  ", @"Whitespace should be preserved");
}

@end
