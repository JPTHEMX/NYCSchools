To improve future testability and make the code more reusable, we could abstract the data loading logic. A good way to do this would be to create a DataLoaderManaging protocol and a DataLoaderManager class. This approach would allow us to inject a mock for testing and reuse the manager in other parts of the app

Benefits:
Testability: This allows us to inject a mock implementation during unit tests, removing the need for actual network calls.
Reusability: A generic DataLoaderManager can be used across the entire application, preventing code duplication.
