In Swift Testing, the standard way to handle setup and cleanup for each individual test relies on the lifecycle of the struct (or actor) containing the tests:
init (Equivalent to setUp):
The struct's initializer runs before each @Test method.
It's the place for initial setup (creating SUT, mocks, etc.).
It can throw errors to signal setup failures, similar to setUpWithError in XCTest.
deinit (Equivalent to tearDown):
The deinitializer runs after each @Test method when the struct instance is destroyed.
It's the place for cleanup of instance-specific resources.
It cannot throw errors directly.
