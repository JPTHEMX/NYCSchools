import XCTest
@testable import YourAppModuleName // Replace!

// ... (Existing MockURLProtocol, ActorIsolated, createHttpResponse, etc.) ...
// ... (Existing DataLoaderTests class setup and other tests) ...

class DataLoaderTests: XCTestCase {

    // ... (Existing setup, teardown, helpers, other tests) ...

    // MARK: - Cache Only Tests

    func testLoadImageFromCacheOnly_CacheHit_ReturnsDataValue() async throws {
        // Arrange
        let expectedData = try XCTUnwrap(createDummyImageData(color: .magenta))
        let response = createHttpResponse(url: testURL, statusCode: 200)
        // Pre-populate cache via actor helper
        await dataLoader.storeDataInCacheForTest(data: expectedData, for: testURL, response: response)

        // Act: Call the cache-only method
        let result = await dataLoader.loadImageFromCacheOnly(for: testURL)

        // Assert
        XCTAssertNotNil(result, "Result should not be nil for cache hit")
        XCTAssertEqual(result?.url, testURL)
        XCTAssertEqual(result?.data, expectedData)
    }

    func testLoadImageFromCacheOnly_CacheMiss_ReturnsNil() async throws {
        // Arrange: Ensure cache is empty (done in setUp usually, but double-check)
        let isInitiallyCached = await dataLoader.isDataCached(for: testURL)
        XCTAssertFalse(isInitiallyCached, "Precondition failed: Cache should be empty")

        // Act: Call the cache-only method
        let result = await dataLoader.loadImageFromCacheOnly(for: testURL)

        // Assert
        XCTAssertNil(result, "Result should be nil for cache miss")
    }

    func testLoadImageFromCacheOnly_LoadsCorrectDataForDifferentURLs() async throws {
        // Arrange
        let data1 = try XCTUnwrap(createDummyImageData(color: .orange))
        let data2 = try XCTUnwrap(createDummyImageData(color: .purple))
        let response1 = createHttpResponse(url: testURL, statusCode: 200)
        let response2 = createHttpResponse(url: testURL2, statusCode: 200)
        await dataLoader.storeDataInCacheForTest(data: data1, for: testURL, response: response1)
        await dataLoader.storeDataInCacheForTest(data: data2, for: testURL2, response: response2)

        // Act
        let result1 = await dataLoader.loadImageFromCacheOnly(for: testURL)
        let result2 = await dataLoader.loadImageFromCacheOnly(for: testURL2)
        let resultNil = await dataLoader.loadImageFromCacheOnly(for: URL(string: "https://test.com/notcached")!)

        // Assert
        XCTAssertNotNil(result1); XCTAssertEqual(result1?.data, data1); XCTAssertEqual(result1?.url, testURL)
        XCTAssertNotNil(result2); XCTAssertEqual(result2?.data, data2); XCTAssertEqual(result2?.url, testURL2)
        XCTAssertNil(resultNil)
    }
}
