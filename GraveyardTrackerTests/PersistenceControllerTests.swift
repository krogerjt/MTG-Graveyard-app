import Combine
import CoreData
import XCTest
@testable import GraveyardTracker

final class PersistenceControllerTests: XCTestCase {
    @MainActor
    func testInitialLoadTransitionsFromLoadingToReady() {
        var completions: [(Error?) -> Void] = []
        let persistence = PersistenceController(inMemory: true) { _, completion in
            completions.append(completion)
        }

        XCTAssertFalse(persistence.isReady)
        XCTAssertNil(persistence.storeError)
        XCTAssertEqual(completions.count, 1)

        let ready = expectation(description: "store becomes ready")
        let cancellable = persistence.$isReady
            .dropFirst()
            .filter { $0 }
            .sink { _ in ready.fulfill() }
        completions[0](nil)
        wait(for: [ready], timeout: 1)
        cancellable.cancel()

        XCTAssertTrue(persistence.isReady)
        XCTAssertNil(persistence.storeError)
    }

    @MainActor
    func testFailedLoadCanRetryWithFreshContainerAndClearError() {
        var completions: [(Error?) -> Void] = []
        var containers: [NSPersistentContainer] = []
        let persistence = PersistenceController(inMemory: true) { container, completion in
            containers.append(container)
            completions.append(completion)
        }

        let failure = NSError(domain: "PersistenceControllerTests", code: 7,
                              userInfo: [NSLocalizedDescriptionKey: "Store unavailable"])
        let failed = expectation(description: "store failure is published")
        let failureCancellable = persistence.$storeError
            .compactMap { $0 }
            .sink { _ in failed.fulfill() }
        completions[0](failure)
        wait(for: [failed], timeout: 1)
        failureCancellable.cancel()

        XCTAssertFalse(persistence.isReady)
        XCTAssertEqual(persistence.storeError, "Store unavailable")

        let ready = expectation(description: "retry becomes ready")
        let readyCancellable = persistence.$isReady
            .dropFirst()
            .filter { $0 }
            .sink { _ in ready.fulfill() }
        persistence.loadStore()

        XCTAssertFalse(persistence.isReady)
        XCTAssertNil(persistence.storeError)
        XCTAssertEqual(completions.count, 2)
        XCTAssertFalse(containers[0] === containers[1])

        // A second request while retrying must not start another load.
        persistence.loadStore()
        XCTAssertEqual(completions.count, 2)

        completions[1](nil)
        wait(for: [ready], timeout: 1)
        readyCancellable.cancel()
        XCTAssertTrue(persistence.isReady)
        XCTAssertNil(persistence.storeError)
    }

    @MainActor
    func testLateCallbackFromPriorAttemptCannotOverwriteRetryState() {
        var completions: [(Error?) -> Void] = []
        let persistence = PersistenceController(inMemory: true) { _, completion in
            completions.append(completion)
        }

        let firstReady = expectation(description: "first load becomes ready")
        let firstCancellable = persistence.$isReady
            .dropFirst()
            .filter { $0 }
            .sink { _ in firstReady.fulfill() }
        completions[0](nil)
        wait(for: [firstReady], timeout: 1)
        firstCancellable.cancel()

        persistence.loadStore()
        XCTAssertFalse(persistence.isReady)
        XCTAssertEqual(completions.count, 2)

        // The prior callback is deliberately invoked again after the retry starts.
        completions[0](NSError(domain: "stale", code: 1))
        let retryReady = expectation(description: "retry becomes ready")
        let retryCancellable = persistence.$isReady
            .filter { $0 }
            .sink { _ in retryReady.fulfill() }
        completions[1](nil)
        wait(for: [retryReady], timeout: 1)
        retryCancellable.cancel()

        XCTAssertTrue(persistence.isReady)
        XCTAssertNil(persistence.storeError)
    }
}
