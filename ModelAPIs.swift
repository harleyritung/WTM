//
//  ModelAPIs.swift
//  WTM
//
//  Created by Riley Hartung on 8/9/25.
//

import Foundation
import CoreLocation
import GooglePlaces
import SwiftUI

struct modelInput: Codable {
	let maxBudget: Int
	let vibe: String
	let moves: [MoveFilterData]
}
	

class ModelAPIs {
	private static let openAIEndpoint = URL(string: "https://api.openai.com/v1/chat/completions")
	private static let bggEndpoint = URL(string: "https://boardgamegeek.com/xmlapi2/collection?username=harleyritung")
	
	
	// given an array of businesses and user preferences, return business IDs that match the preferences
	static func smartFilterLocations(moves: [MoveFilterData], maxBudget: GMSPlacesPriceLevel, vibe: Vibe, completion: @escaping (Result<[LocationConfidence], Error>) -> Void) {
		let request = buildRequest(moves: moves, maxBudget: maxBudget, vibe: vibe)
		
		URLSession.shared.dataTask(with: request) { data, response, error in
			if let error = error {
				DispatchQueue.main.async {
					completion(.failure(error))
				}
				return
			}
			
			guard let data = data else {
				DispatchQueue.main.async {
					completion(.failure(NSError(domain: "No data received", code: -1, userInfo: nil)))
				}
				return
			}
			
			do {
				if let IDsString = String(data: data, encoding: .utf8) {
					print("JSON Response: \(IDsString)")
				}
				// Parse the OpenAI response
				let apiResponse = try JSONDecoder().decode(OpenAIResponse.self, from: data)
				
				if let jsonString = apiResponse.choices.first?.message.content {
					print("coded locationArray: \(jsonString)")
					// Extract the businesses array from the JSON response
					if let jsonData = jsonString.data(using: .utf8) {
						let locationArray = try JSONDecoder().decode([LocationConfidence].self, from: jsonData)
						print("decoded locationArray: \(locationArray)")
						DispatchQueue.main.async {
							completion(.success(locationArray))
						}
					} else {
						DispatchQueue.main.async {
							completion(.failure(NSError(domain: "Failed to extract Move data", code: -1, userInfo: nil)))
						}
					}
				} else {
					DispatchQueue.main.async {
						completion(.failure(NSError(domain: "No content in OpenAI response", code: -1, userInfo: nil)))
					}
				}
			} catch {
				DispatchQueue.main.async {
					completion(.failure(error))
				}
			}
		}.resume()
	}
	
	// Define a Codable struct for the request body
	struct OpenAIRequestBody: Codable {
		struct Message: Codable {
			let role: String
			let content: String
		}

		let model: String
		let messages: [Message]
	}

	// Update the buildRequest function
	static func buildRequest(moves: [MoveFilterData], maxBudget: GMSPlacesPriceLevel, vibe: Vibe) -> URLRequest {
		var request = URLRequest(url: openAIEndpoint!)
		request.httpMethod = "POST"
		request.addValue("Bearer \(chatGPTAPIKey)", forHTTPHeaderField: "Authorization")
		request.addValue("application/json", forHTTPHeaderField: "Content-Type")

		let role = """
  Given a list of locations and user preferences, use what you know about the locations to return a comma-separated list of IDs that best match the preferences. 
  maxPriceLevel is the place, as integers from 0 to 4. e.g. A value of 4 means this place is “$$$$” (expensive). A value of 0 means free (such as a museum with free admission). where 0 is free, 1 is $10, 2 is $25, 3 is $50, and 4 is any price. Only filter out locations that are more expensive than maxPriceLevel, but show any that are cheaper.
  These are the possible vibes for reference: romantic, casual, upscale, outdoorsy, and cozy.
  Return the IDs of the locations that best match the preferences and your confidence score (0-1) for the preference match in a JSON array like this: [{"id": "1", "confidence": 0.9}, {"id": "2", "confidence": 0.8}]. Do not return anything but the JSON output.
  """

		let input = modelInput(maxBudget: maxBudget.rawValue, vibe: vibe.rawValue, moves: moves)

		do {
			let inputData = try JSONEncoder().encode(input)
			if let inputJSONString = String(data: inputData, encoding: .utf8) {
				print("Input JSON: \(inputJSONString)")

				let requestBody = OpenAIRequestBody(
					model: "gpt-4-turbo",
					messages: [
						.init(role: "system", content: role),
						.init(role: "user", content: inputJSONString)
					]
				)

				request.httpBody = try JSONEncoder().encode(requestBody)
			}
		} catch {
			print("Error encoding input: \(error)")
		}
		return request
	}
}
	

// Structure to decode OpenAI API response
struct OpenAIResponse: Codable {
	struct Choice: Codable {
		struct Message: Codable {
			let content: String
		}
		let message: Message
	}
	
	let choices: [Choice]
}

// Define a struct to represent the content objects
struct LocationConfidence: Codable {
	let id: String
	let confidence: Double
}
