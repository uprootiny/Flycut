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

#pragma mark - Mock Delegate

@interface MockStoreDelegate : NSObject <FlycutStoreDelegate>
@property (nonatomic, assign) int beginUpdatesCalled;
@property (nonatomic, assign) int endUpdatesCalled;
@property (nonatomic, strong) NSMutableArray *insertedIndexes;
@property (nonatomic, strong) NSMutableArray *deletedIndexes;
@property (nonatomic, strong) NSMutableArray *movedFromIndexes;
@property (nonatomic, strong) NSMutableArray *movedToIndexes;
@end

@implementation MockStoreDelegate

- (instancetype)init {
    self = [super init];
    if (self) {
        _insertedIndexes = [[NSMutableArray alloc] init];
        _deletedIndexes = [[NSMutableArray alloc] init];
        _movedFromIndexes = [[NSMutableArray alloc] init];
        _movedToIndexes = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)beginUpdates {
    _beginUpdatesCalled++;
}

- (void)endUpdates {
    _endUpdatesCalled++;
}

- (void)insertClippingAtIndex:(int)index {
    [_insertedIndexes addObject:@(index)];
}

- (void)deleteClippingAtIndex:(int)index {
    [_deletedIndexes addObject:@(index)];
}

- (void)moveClippingAtIndex:(int)index toIndex:(int)newIndex {
    [_movedFromIndexes addObject:@(index)];
    [_movedToIndexes addObject:@(newIndex)];
}

- (void)reset {
    _beginUpdatesCalled = 0;
    _endUpdatesCalled = 0;
    [_insertedIndexes removeAllObjects];
    [_deletedIndexes removeAllObjects];
    [_movedFromIndexes removeAllObjects];
    [_movedToIndexes removeAllObjects];
}

- (void)dealloc {
    [_insertedIndexes release];
    [_deletedIndexes release];
    [_movedFromIndexes release];
    [_movedToIndexes release];
    [super dealloc];
}

@end

#pragma mark - Tests

@interface FlycutStoreTests : XCTestCase
@property (nonatomic, retain) FlycutStore *store;
@property (nonatomic, retain) MockStoreDelegate *mockDelegate;
@end

@implementation FlycutStoreTests

- (void)setUp {
    [super setUp];
    self.store = [[FlycutStore alloc] initRemembering:10 displaying:5 withDisplayLength:40];
    self.mockDelegate = [[MockStoreDelegate alloc] init];
    self.store.delegate = self.mockDelegate;
}

- (void)tearDown {
    self.store.delegate = nil;
    [self.store release];
    self.store = nil;
    [self.mockDelegate release];
    self.mockDelegate = nil;
    [super tearDown];
}

#pragma mark - Initialization Tests

- (void)testDefaultInitialization {
    FlycutStore *defaultStore = [[FlycutStore alloc] init];

    XCTAssertEqual([defaultStore rememberNum], 20, @"Default remember num should be 20");
    XCTAssertEqual([defaultStore displayLen], 40, @"Default display length should be 40");
    XCTAssertEqual([defaultStore jcListCount], 0, @"New store should be empty");

    [defaultStore release];
}

- (void)testCustomInitialization {
    XCTAssertEqual([self.store rememberNum], 10, @"Remember num should match init value");
    XCTAssertEqual([self.store displayLen], 40, @"Display length should match init value");
    XCTAssertEqual([self.store jcListCount], 0, @"New store should be empty");
}

- (void)testInitWithZeroRememberNumDefaultsToForty {
    FlycutStore *zeroStore = [[FlycutStore alloc] initRemembering:0 displaying:5 withDisplayLength:40];

    XCTAssertEqual([zeroStore rememberNum], 40, @"Zero remember num should default to 40");

    [zeroStore release];
}

- (void)testInitWithNegativeRememberNumDefaultsToForty {
    FlycutStore *negStore = [[FlycutStore alloc] initRemembering:-5 displaying:5 withDisplayLength:40];

    XCTAssertEqual([negStore rememberNum], 40, @"Negative remember num should default to 40");

    [negStore release];
}

#pragma mark - Add Clipping Tests

- (void)testAddClipping {
    BOOL result = [self.store addClipping:@"Test content"
                                   ofType:@"public.utf8-plain-text"
                     fromAppLocalizedName:@"TestApp"
                         fromAppBundleURL:nil
                              atTimestamp:100];

    XCTAssertTrue(result, @"Adding valid clipping should return YES");
    XCTAssertEqual([self.store jcListCount], 1, @"Store should have one clipping");
    XCTAssertEqualObjects([self.store clippingContentsAtPosition:0], @"Test content");
}

- (void)testAddEmptyClipping {
    BOOL result = [self.store addClipping:@""
                                   ofType:@"text"
                     fromAppLocalizedName:@"TestApp"
                         fromAppBundleURL:nil
                              atTimestamp:0];

    XCTAssertFalse(result, @"Adding empty clipping should return NO");
    XCTAssertEqual([self.store jcListCount], 0, @"Store should remain empty");
}

- (void)testAddMultipleClippings {
    [self.store addClipping:@"First" ofType:@"text" fromAppLocalizedName:@"" fromAppBundleURL:nil atTimestamp:0];
    [self.store addClipping:@"Second" ofType:@"text" fromAppLocalizedName:@"" fromAppBundleURL:nil atTimestamp:0];
    [self.store addClipping:@"Third" ofType:@"text" fromAppLocalizedName:@"" fromAppBundleURL:nil atTimestamp:0];

    XCTAssertEqual([self.store jcListCount], 3, @"Store should have three clippings");
    // Most recent should be at position 0 (stack behavior)
    XCTAssertEqualObjects([self.store clippingContentsAtPosition:0], @"Third");
    XCTAssertEqualObjects([self.store clippingContentsAtPosition:1], @"Second");
    XCTAssertEqualObjects([self.store clippingContentsAtPosition:2], @"First");
}

- (void)testAddClippingTriggersDelegate {
    [self.mockDelegate reset];

    [self.store addClipping:@"Test" ofType:@"text" fromAppLocalizedName:@"" fromAppBundleURL:nil atTimestamp:0];

    XCTAssertEqual(self.mockDelegate.beginUpdatesCalled, 1, @"beginUpdates should be called");
    XCTAssertEqual(self.mockDelegate.endUpdatesCalled, 1, @"endUpdates should be called");
    XCTAssertEqual([self.mockDelegate.insertedIndexes count], 1, @"One insertion should be recorded");
    XCTAssertEqualObjects(self.mockDelegate.insertedIndexes[0], @0, @"Insertion at index 0");
}

#pragma mark - Memory Limit Tests

- (void)testStoreEnforcesRememberNumLimit {
    // Store remembers 10, add 15 clippings
    for (int i = 0; i < 15; i++) {
        [self.store addClipping:[NSString stringWithFormat:@"Clip %d", i]
                         ofType:@"text"
           fromAppLocalizedName:@""
               fromAppBundleURL:nil
                    atTimestamp:0];
    }

    XCTAssertEqual([self.store jcListCount], 10, @"Store should not exceed remember num");
    // Most recent should be 14, oldest kept should be 5
    XCTAssertEqualObjects([self.store clippingContentsAtPosition:0], @"Clip 14");
    XCTAssertEqualObjects([self.store clippingContentsAtPosition:9], @"Clip 5");
}

- (void)testSetRememberNumPrunesExistingClippings {
    // Add 10 clippings
    for (int i = 0; i < 10; i++) {
        [self.store addClipping:[NSString stringWithFormat:@"Clip %d", i]
                         ofType:@"text"
           fromAppLocalizedName:@""
               fromAppBundleURL:nil
                    atTimestamp:0];
    }

    XCTAssertEqual([self.store jcListCount], 10);

    // Reduce remember num to 5
    [self.store setRememberNum:5];

    XCTAssertEqual([self.store jcListCount], 5, @"Store should prune to new remember num");
    XCTAssertEqual([self.store rememberNum], 5);
    // Most recent (Clip 9) should still be at position 0
    XCTAssertEqualObjects([self.store clippingContentsAtPosition:0], @"Clip 9");
}

#pragma mark - Retrieval Tests

- (void)testClippingAtPositionWithValidIndex {
    [self.store addClipping:@"Test content" ofType:@"text" fromAppLocalizedName:@"App" fromAppBundleURL:nil atTimestamp:0];

    FlycutClipping *clipping = [self.store clippingAtPosition:0];

    XCTAssertNotNil(clipping, @"Should return clipping at valid position");
    XCTAssertEqualObjects([clipping contents], @"Test content");
}

- (void)testClippingAtPositionWithInvalidIndex {
    [self.store addClipping:@"Test" ofType:@"text" fromAppLocalizedName:@"" fromAppBundleURL:nil atTimestamp:0];

    FlycutClipping *clipping = [self.store clippingAtPosition:99];

    XCTAssertNil(clipping, @"Should return nil for invalid position");
}

- (void)testClippingContentsAtPositionWithInvalidIndex {
    NSString *contents = [self.store clippingContentsAtPosition:0];

    XCTAssertNil(contents, @"Should return nil for position in empty store");
}

- (void)testPreviousContents {
    [self.store addClipping:@"First" ofType:@"text" fromAppLocalizedName:@"" fromAppBundleURL:nil atTimestamp:0];
    [self.store addClipping:@"Second" ofType:@"text" fromAppLocalizedName:@"" fromAppBundleURL:nil atTimestamp:0];
    [self.store addClipping:@"Third" ofType:@"text" fromAppLocalizedName:@"" fromAppBundleURL:nil atTimestamp:0];

    NSArray *previous = [self.store previousContents:2];

    XCTAssertEqual([previous count], 2, @"Should return requested number of items");
    // previousContents returns in oldest-first order
    XCTAssertEqualObjects(previous[0], @"Second");
    XCTAssertEqualObjects(previous[1], @"Third");
}

- (void)testPreviousContentsExceedsCount {
    [self.store addClipping:@"Only" ofType:@"text" fromAppLocalizedName:@"" fromAppBundleURL:nil atTimestamp:0];

    NSArray *previous = [self.store previousContents:10];

    XCTAssertEqual([previous count], 1, @"Should return all available when requested exceeds count");
}

#pragma mark - Search Tests

- (void)testSearchFindsMatchingClippings {
    [self.store addClipping:@"Apple pie recipe" ofType:@"text" fromAppLocalizedName:@"" fromAppBundleURL:nil atTimestamp:0];
    [self.store addClipping:@"Banana bread" ofType:@"text" fromAppLocalizedName:@"" fromAppBundleURL:nil atTimestamp:0];
    [self.store addClipping:@"Apple cider" ofType:@"text" fromAppLocalizedName:@"" fromAppBundleURL:nil atTimestamp:0];

    NSArray *results = [self.store previousDisplayStrings:10 containing:@"Apple"];

    XCTAssertEqual([results count], 2, @"Should find two matches for 'Apple'");
}

- (void)testSearchIsCaseInsensitive {
    [self.store addClipping:@"HELLO WORLD" ofType:@"text" fromAppLocalizedName:@"" fromAppBundleURL:nil atTimestamp:0];
    [self.store addClipping:@"hello there" ofType:@"text" fromAppLocalizedName:@"" fromAppBundleURL:nil atTimestamp:0];

    NSArray *results = [self.store previousDisplayStrings:10 containing:@"hello"];

    XCTAssertEqual([results count], 2, @"Search should be case insensitive");
}

- (void)testSearchWithNoMatches {
    [self.store addClipping:@"Test content" ofType:@"text" fromAppLocalizedName:@"" fromAppBundleURL:nil atTimestamp:0];

    NSArray *results = [self.store previousDisplayStrings:10 containing:@"xyz"];

    XCTAssertEqual([results count], 0, @"No matches should return empty array");
}

- (void)testSearchWithNilQuery {
    [self.store addClipping:@"Content" ofType:@"text" fromAppLocalizedName:@"" fromAppBundleURL:nil atTimestamp:0];

    NSArray *results = [self.store previousDisplayStrings:10 containing:nil];

    XCTAssertEqual([results count], 1, @"Nil search should return all clippings");
}

- (void)testSearchWithEmptyQuery {
    [self.store addClipping:@"Content" ofType:@"text" fromAppLocalizedName:@"" fromAppBundleURL:nil atTimestamp:0];

    NSArray *results = [self.store previousDisplayStrings:10 containing:@""];

    XCTAssertEqual([results count], 1, @"Empty search should return all clippings");
}

- (void)testPreviousIndexesWithSearch {
    [self.store addClipping:@"First match" ofType:@"text" fromAppLocalizedName:@"" fromAppBundleURL:nil atTimestamp:0];
    [self.store addClipping:@"No match" ofType:@"text" fromAppLocalizedName:@"" fromAppBundleURL:nil atTimestamp:0];
    [self.store addClipping:@"Second match" ofType:@"text" fromAppLocalizedName:@"" fromAppBundleURL:nil atTimestamp:0];

    NSArray *indexes = [self.store previousIndexes:10 containing:@"match"];

    XCTAssertEqual([indexes count], 2, @"Should find two matching indexes");
    // Most recent match first (newest-first order)
    XCTAssertEqualObjects(indexes[0], @0, @"Index 0 is 'Second match'");
    XCTAssertEqualObjects(indexes[1], @2, @"Index 2 is 'First match'");
}

#pragma mark - Delete Tests

- (void)testClearItem {
    [self.store addClipping:@"First" ofType:@"text" fromAppLocalizedName:@"" fromAppBundleURL:nil atTimestamp:0];
    [self.store addClipping:@"Second" ofType:@"text" fromAppLocalizedName:@"" fromAppBundleURL:nil atTimestamp:0];
    [self.store addClipping:@"Third" ofType:@"text" fromAppLocalizedName:@"" fromAppBundleURL:nil atTimestamp:0];

    [self.mockDelegate reset];
    [self.store clearItem:1]; // Remove "Second"

    XCTAssertEqual([self.store jcListCount], 2, @"Store should have two clippings");
    XCTAssertEqualObjects([self.store clippingContentsAtPosition:0], @"Third");
    XCTAssertEqualObjects([self.store clippingContentsAtPosition:1], @"First");
    XCTAssertEqual([self.mockDelegate.deletedIndexes count], 1, @"One deletion recorded");
}

- (void)testClearList {
    [self.store addClipping:@"First" ofType:@"text" fromAppLocalizedName:@"" fromAppBundleURL:nil atTimestamp:0];
    [self.store addClipping:@"Second" ofType:@"text" fromAppLocalizedName:@"" fromAppBundleURL:nil atTimestamp:0];

    [self.store clearList];

    XCTAssertEqual([self.store jcListCount], 0, @"Store should be empty after clearList");
}

#pragma mark - Move Tests

- (void)testClippingMoveToTop {
    [self.store addClipping:@"First" ofType:@"text" fromAppLocalizedName:@"" fromAppBundleURL:nil atTimestamp:0];
    [self.store addClipping:@"Second" ofType:@"text" fromAppLocalizedName:@"" fromAppBundleURL:nil atTimestamp:0];
    [self.store addClipping:@"Third" ofType:@"text" fromAppLocalizedName:@"" fromAppBundleURL:nil atTimestamp:0];

    // "First" is at index 2, move it to top
    [self.store clippingMoveToTop:2];

    XCTAssertEqualObjects([self.store clippingContentsAtPosition:0], @"First", @"Moved item should be at top");
    XCTAssertEqualObjects([self.store clippingContentsAtPosition:1], @"Third");
    XCTAssertEqualObjects([self.store clippingContentsAtPosition:2], @"Second");
}

- (void)testClippingMoveFromTo {
    [self.store addClipping:@"A" ofType:@"text" fromAppLocalizedName:@"" fromAppBundleURL:nil atTimestamp:0];
    [self.store addClipping:@"B" ofType:@"text" fromAppLocalizedName:@"" fromAppBundleURL:nil atTimestamp:0];
    [self.store addClipping:@"C" ofType:@"text" fromAppLocalizedName:@"" fromAppBundleURL:nil atTimestamp:0];
    [self.store addClipping:@"D" ofType:@"text" fromAppLocalizedName:@"" fromAppBundleURL:nil atTimestamp:0];
    // Order: D, C, B, A

    [self.mockDelegate reset];
    [self.store clippingMoveFrom:0 To:2]; // Move D to position 2

    // New order: C, B, D, A
    XCTAssertEqualObjects([self.store clippingContentsAtPosition:0], @"C");
    XCTAssertEqualObjects([self.store clippingContentsAtPosition:1], @"B");
    XCTAssertEqualObjects([self.store clippingContentsAtPosition:2], @"D");
    XCTAssertEqualObjects([self.store clippingContentsAtPosition:3], @"A");
}

#pragma mark - Merge Tests

- (void)testMergeList {
    [self.store addClipping:@"First" ofType:@"text" fromAppLocalizedName:@"" fromAppBundleURL:nil atTimestamp:0];
    [self.store addClipping:@"Second" ofType:@"text" fromAppLocalizedName:@"" fromAppBundleURL:nil atTimestamp:0];
    [self.store addClipping:@"Third" ofType:@"text" fromAppLocalizedName:@"" fromAppBundleURL:nil atTimestamp:0];

    [self.store mergeList];

    // Merge should add a new clipping with all contents joined
    // Original order (oldest to newest): First, Second, Third
    NSString *merged = [self.store clippingContentsAtPosition:0];
    XCTAssertTrue([merged containsString:@"First"], @"Merged should contain First");
    XCTAssertTrue([merged containsString:@"Second"], @"Merged should contain Second");
    XCTAssertTrue([merged containsString:@"Third"], @"Merged should contain Third");
}

#pragma mark - Index Of Clipping Tests

- (void)testIndexOfClipping {
    [self.store addClipping:@"First" ofType:@"text" fromAppLocalizedName:@"" fromAppBundleURL:nil atTimestamp:0];
    [self.store addClipping:@"Second" ofType:@"text" fromAppLocalizedName:@"" fromAppBundleURL:nil atTimestamp:0];
    [self.store addClipping:@"Third" ofType:@"text" fromAppLocalizedName:@"" fromAppBundleURL:nil atTimestamp:0];

    int index = [self.store indexOfClipping:@"Second" ofType:@"text" fromAppLocalizedName:@"" fromAppBundleURL:nil atTimestamp:0];

    XCTAssertEqual(index, 1, @"Second should be at index 1");
}

- (void)testIndexOfNonexistentClipping {
    [self.store addClipping:@"Content" ofType:@"text" fromAppLocalizedName:@"" fromAppBundleURL:nil atTimestamp:0];

    int index = [self.store indexOfClipping:@"Nonexistent" ofType:@"text" fromAppLocalizedName:@"" fromAppBundleURL:nil atTimestamp:0];

    XCTAssertEqual(index, -1, @"Nonexistent clipping should return -1");
}

- (void)testIndexOfEmptyStringClipping {
    [self.store addClipping:@"Content" ofType:@"text" fromAppLocalizedName:@"" fromAppBundleURL:nil atTimestamp:0];

    int index = [self.store indexOfClipping:@"" ofType:@"text" fromAppLocalizedName:@"" fromAppBundleURL:nil atTimestamp:0];

    XCTAssertEqual(index, -1, @"Empty string should return -1");
}

#pragma mark - Display Length Tests

- (void)testSetDisplayLengthUpdatesAllClippings {
    [self.store addClipping:@"This is a long clipping that will be truncated"
                     ofType:@"text"
       fromAppLocalizedName:@""
           fromAppBundleURL:nil
                atTimestamp:0];

    // Default display length is 40, set it to 10
    [self.store setDisplayLen:10];

    NSString *displayString = [self.store clippingDisplayStringAtPosition:0];

    // Display string should be truncated to 10 chars + ellipsis
    XCTAssertTrue([displayString length] <= 11, @"Display string should be truncated");
    XCTAssertTrue([displayString hasSuffix:@"…"], @"Truncated string should have ellipsis");
}

#pragma mark - Modified State Tests

- (void)testModifiedSinceLastSaveInitiallyNo {
    FlycutStore *freshStore = [[FlycutStore alloc] init];

    XCTAssertFalse([freshStore modifiedSinceLastSaveStore], @"New store should not be modified");

    [freshStore release];
}

- (void)testAddClippingSetsModifiedFlag {
    FlycutStore *freshStore = [[FlycutStore alloc] init];

    [freshStore addClipping:@"Content" ofType:@"text" fromAppLocalizedName:@"" fromAppBundleURL:nil atTimestamp:0];

    XCTAssertTrue([freshStore modifiedSinceLastSaveStore], @"Store should be modified after add");

    [freshStore release];
}

- (void)testClearModifiedSinceLastSaveStore {
    [self.store addClipping:@"Content" ofType:@"text" fromAppLocalizedName:@"" fromAppBundleURL:nil atTimestamp:0];
    XCTAssertTrue([self.store modifiedSinceLastSaveStore]);

    [self.store clearModifiedSinceLastSaveStore];

    XCTAssertFalse([self.store modifiedSinceLastSaveStore], @"Modified flag should be cleared");
}

#pragma mark - Edge Cases

- (void)testOperationsOnEmptyStore {
    // These should not crash
    [self.store clearList];
    XCTAssertEqual([self.store jcListCount], 0);

    NSArray *contents = [self.store previousContents:10];
    XCTAssertEqual([contents count], 0);

    NSArray *displayStrings = [self.store previousDisplayStrings:10];
    XCTAssertEqual([displayStrings count], 0);
}

- (void)testAddClippingObject {
    FlycutClipping *clipping = [[FlycutClipping alloc] initWithContents:@"Direct add"
                                                               withType:@"text"
                                                      withDisplayLength:40
                                                   withAppLocalizedName:@"App"
                                                       withAppBundleURL:nil
                                                          withTimestamp:100];

    [self.store addClipping:clipping];

    XCTAssertEqual([self.store jcListCount], 1);
    XCTAssertEqualObjects([self.store clippingContentsAtPosition:0], @"Direct add");

    [clipping release];
}

@end
