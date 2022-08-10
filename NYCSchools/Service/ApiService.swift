//
//  Service.swift
//  NYCSchools
//
//  Created by Juan Pablo Granados Garcia on 8/9/22.
//

import UIKit

// MARK: - APIService
class ApiService: NSObject {
    
    static let shared = ApiService()
    
    /// Get Schools list
    /// - Parameter completion: return a result type with data on success and error on failure
    func getHighSchools(_ completion: @escaping (Result<[School], Error>) -> Void) {
        request(for: Constants.schoolListAPI) { result in
            switch result {
            case let .success(data):
                do {
                    completion(.success(try JSONDecoder().decode([School].self, from: data)))
                } catch {
                    completion(.failure(ServiceError.jsonParse))
                }
            case let .failure(error):
                completion(.failure(error))
            }
        }
    }
    
    /// Get School SAT details
    /// - Parameters:
    ///   - dbn: dbn assigned to school
    ///   - completion: return a result type with data on success and error on failure
    func getSATScores(dbn: String, _ completion: @escaping (Result<[SATScore], Error>) -> Void) {
        let queryItems = [URLQueryItem(name: Constants.dbn, value: dbn)]
        request(for: Constants.schoolDetailAPI, queryItems: queryItems) { result in
            switch result {
            case let .success(data):
                do {
                    completion(.success(try JSONDecoder().decode([SATScore].self, from: data)))
                } catch {
                    completion(.failure(error))
                }
            case let .failure(error):
                completion(.failure(error))
            }
        }
    }
    
    
    /// Fetch the data
    /// - Parameters:
    ///   - url: url api
    ///   - queryItems: An array of query items for the URL
    ///   - completion: return a result type with data on success and error on failure
    func request(for url: String, queryItems: [URLQueryItem] = [], _ completion: @escaping (Result<Data, Error>) -> Void) {
        guard var urlComponents = URLComponents(string: url) else {
            completion(.failure(ServiceError.components))
            return
        }
        urlComponents.queryItems = queryItems
        guard let url = urlComponents.url else {
            completion(.failure(ServiceError.urlCreation))
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        let config = URLSessionConfiguration.ephemeral
        let session = URLSession(configuration: config)
        session.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let data = data else {
                completion(.failure(ServiceError.urlResponseData))
                return
            }
            guard let response = response as? HTTPURLResponse, (200 ..< 300) ~= response.statusCode else {
                completion(.failure(ServiceError.urlResponseData))
                return
            }
            completion(.success(data))
        }.resume()
    }
}

