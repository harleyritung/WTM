//
//  FindMovesView.swift
//  WTM
//
//  Created by Riley Hartung on 7/31/25.
//

import SwiftUI
import GooglePlaces
import CoreLocation

struct FindMovesView: View {
	var locationManager = LocationManager()
	@State private var nearbyPlaces: [GMSPlace] = []
	@State private var isLoading = false
	@State private var selectedFilter: PlaceType = .all
	
	// Filter states
	@State private var showBudgetFilter = false
	@State private var showDistanceFilter = false
	@State private var showActivityFilter = false
	@State private var showVibeFilter = false
	
	// Current filter values
	@State private var useSmartFilter = false
	@State private var currentMaxBudget = GMSPlacesPriceLevel.medium
	@State private var currentMaxDistance = 5.0
	@State private var currentVibe = Vibe.any
	
	// Constants for filters
	private let priceTitles = ["Free", "$", "$$", "$$$", "$$$$"]
	private let distanceOptions = [1, 5, 10, 15, 20]
	
	var body: some View {
		VStack(spacing: 0) {
			filterToolbar
				.padding()
				.background(Color(.systemGray6))
			
			if isLoading {
				Spacer()
				ProgressView()
				Spacer()
			} else if filteredPlaces.isEmpty {
				Spacer()
				Text("No places found")
					.foregroundColor(.secondary)
					.padding()
				Spacer()
			} else {
				ScrollView {
					LazyVStack(spacing: 12) {
						ForEach(filteredPlaces.indices, id: \.self) { placeIndex in
							let place = filteredPlaces[placeIndex]
							locationCard(for: place)
								.background(Color(.systemGray6))
								.cornerRadius(10)
								.shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
						}
						.padding(.bottom, 4)
					}
					.padding(.vertical, 8)
				}
			}
		}
		.navigationTitle("Find Moves")
		.onAppear {
			// Auto-search when the view appears
			if nearbyPlaces.isEmpty {
				isLoading = true
				locationManager.getCurrentLocation { places in
					nearbyPlaces = places
					isLoading = false
				}
			}
		}
	}
	
	func locationCard(for move: Move) -> some View {
		VStack(alignment: .leading, spacing: 0) {
			PlaceImageView(place: move.gmsPlace)
			
			VStack(alignment: .leading, spacing: 8) {
				
				HStack {
					Text(move.gmsPlace.name ?? "Unknown Place")
						.font(.headline)
					
					Spacer()
					
					Text("\(move.distance) mi")
				}
				
				HStack {
					StarRatingView(rating: Double(move.gmsPlace.rating))
					
					Spacer()
					
					if move.gmsPlace.priceLevel.rawValue > 0 {
						Text(String(repeating: "$", count: Int(move.gmsPlace.priceLevel.rawValue)))
							.foregroundColor(.secondary)
					} else {
						Text("Free")
							.foregroundColor(.green)
							.font(.caption)
					}
				}
			}
			.padding()
		}
	}
	
	var filterToolbar: some View {
		HStack {
			Spacer()
			
			// Distance filter chip
			Menu {
				ForEach(distanceOptions, id: \ .self) { distance in
					Button {
						currentMaxDistance = Double(distance)
					} label: {
						HStack {
							Text("\(distance) mi")
							if Int(currentMaxDistance) == distance {
								Image(systemName: "checkmark")
							}
						}
					}
				}
			} label: {
				Text("\(Int(currentMaxDistance)) mi")
			}
			.buttonStyle(.bordered)
			.background(Color.blue.opacity(0.1))
			
			Spacer()
			
			// Budget filter chip
			Menu {
				ForEach(priceTitles.indices) { index in
					Button(action: {
						currentMaxBudget = GMSPlacesPriceLevel(rawValue: index) ?? .medium
					}) {
						HStack {
							Text(priceTitles[index])
							if currentMaxBudget.rawValue == index {
								Image(systemName: "checkmark")
							}
						}
					}
				}
			} label: {
				Text(priceTitles[currentMaxBudget.rawValue])
			}
			.buttonStyle(.bordered)
			.background(Color.blue.opacity(0.1))
			
			Spacer()
			
			// Vibe filter chip
			Menu {
				ForEach(Vibe.allCases) { vibe in
					Button(action: {
						currentVibe = vibe
					}) {
						HStack {
							Text(vibe.rawValue.capitalized)
							if currentVibe == vibe {
								Image(systemName: "checkmark")
							}
						}
					}
				}
			} label: {
				Text(currentVibe.rawValue.capitalized)
			}
			.buttonStyle(.bordered)
			.background(Color.blue.opacity(0.1))
			
			// Smart filter switch
			Toggle("Smart Filter", isOn: $useSmartFilter)
			
			Spacer()
		}
	}
	
//	func filterMenu(type:, labelStr: String) -> some View {
//		Menu {
//
//			ForEach(distanceOptions, id: \ .self) { distance in
//				Button {
//					currentMaxDistance = Double(distance)
//				} label: {
//					HStack {
//						Text("\(distance) mi")
//						if Int(currentMaxDistance) == distance {
//							Image(systemName: "checkmark")
//						}
//					}
//				}
//			}
//		} label: {
//			Text(labelStr)
//		}
//		.buttonStyle(.bordered)
//		.background(Color.blue.opacity(0.1))
//	}
	
	var filteredPlaces: [Move] {
		var places = nearbyPlaces
		
		var distanceInMiles = 0.0
		
		// Apply distance filter if location manager has a current location
		if let userLocation = locationManager.currentLocation {
			places = places.filter { place in
				let placeLocation = CLLocation(latitude: place.coordinate.latitude, longitude: place.coordinate.longitude)
				let distanceInMeters = userLocation.distance(from: placeLocation)
				distanceInMiles = distanceInMeters / 1609.34
				return distanceInMiles <= currentMaxDistance
			}
		}
		
		if useSmartFilter {
			do {
				var moves: [MoveFilterData] = []
				for place in places {
					moves.append(MoveFilterData(id: place.placeID ?? UUID().uuidString, name: place.name ?? "n/a", address: place.formattedAddress))
				}

				ModelAPIs.smartFilterLocations(moves: moves, maxBudget: currentMaxBudget, vibe: currentVibe) { result in
					switch result {
					case .success(let locationConfidences):
						places = places.filter { place in
							locationConfidences.contains { confidence in
								place.placeID == confidence.id
							}
						}
					case .failure(let error):
						print("Error smart filtering locations: \(error)")
					}
				}
			}
		} else {
			if selectedFilter != .all {
				places = places.filter { place in
					guard let types = place.types else { return false }
					return types.contains { placeType in
						selectedFilter.apiTypes.contains(placeType.lowercased())
					}
				}
			}
			
			// Show places at this price level and below
			places = places.filter { place in
				if currentMaxBudget == .free {
					// necessary to filter out unknown (-1) price levels
					return place.priceLevel == .free
				} else {
					return place.priceLevel.rawValue <= currentMaxBudget.rawValue
				}
			}
			
			// Apply vibe filter
			places = places.filter { place in
				guard let types = place.types else { return true }
				
				switch currentVibe {
				case .romantic:
					// Places that might be romantic
					return types.contains { $0.lowercased().contains("restaurant") } && place.priceLevel.rawValue >= 2
				case .casual:
					// Casual places tend to be lower priced
					return place.priceLevel.rawValue <= 2
				case .upscale:
					// Upscale places tend to be higher priced
					return place.priceLevel.rawValue >= 3
				case .outdoorsy:
					// Places that are typically outdoors
					return types.contains { $0.lowercased().contains("park") || $0.lowercased().contains("outdoor") }
				case .cozy:
					// Cozy places might be cafes or certain restaurants
					return types.contains { $0.lowercased().contains("cafe") || $0.lowercased().contains("bakery") }
				default:
					return true
				}
			}
		}
		
		var moves: [Move] = []
		for place in places {
			moves.append(Move(gmsPlace: place, distance: distanceInMiles))
		}
		return moves
	}
}

struct StarRatingView: View {
	let rating: Double?
	let maxRating: Int = 5
	
	var body: some View {
		HStack(spacing: 4) {
			ForEach(1...maxRating, id: \.self) { star in
				Image(systemName: starType(for: star))
					.foregroundColor(.yellow)
			}
			
			if let rating = rating {
				Text(String(format: "%.1f", rating))
					.foregroundColor(.secondary)
					.font(.caption)
					.padding(.leading, 4)
			} else {
				Text("No rating")
					.foregroundColor(.secondary)
					.font(.caption)
					.padding(.leading, 4)
			}
		}
	}
	
	private func starType(for position: Int) -> String {
		guard let rating = rating else {
			return "star"
		}
		
		if Double(position) <= rating {
			return "star.fill"
		} else if Double(position) - rating < 1 && Double(position) - rating > 0 {
			return "star.leadinghalf.fill"
		} else {
			return "star"
		}
	}
}

struct FilterButton: View {
	let type: PlaceType
	let isSelected: Bool
	let action: () -> Void
	
	var body: some View {
		Button(action: action) {
			Text(type.rawValue)
				.padding(.horizontal, 12)
				.padding(.vertical, 8)
				.background(isSelected ? Color.blue : Color.gray.opacity(0.2))
				.foregroundColor(isSelected ? .white : .primary)
				.cornerRadius(16)
		}
		.buttonStyle(.plain)
	}
}

struct Move {
	let gmsPlace: GMSPlace
	let distance: Double
}

struct MoveFilterData: Codable, Identifiable {
	let id: String
	let name: String
	let address: String?
}

enum Budget: String, CaseIterable {
	case free = "Free"
	case cheap = "$"
	case medium = "$$"
	case expensive = "$$$"
	case all = "$$$+"
}

func budgetDescription(budget: Budget) -> Int {
	if budget == .all {
		return 4
	} else if budget == .expensive {
		return 3
	} else if budget == .medium {
		return 2
	} else if budget == .cheap {
		return 1
	} else {
		return 0
	}
}

func distanceDescription(distance: Int) -> String {
	return distance == 1 ? "1 mile" : "\(distance) miles"
}

struct PreferenceFilter : Codable {
	var maxPriceLevel: Int
	var vibe: String
	
	init(maxPriceLevel: Int, vibe: Vibe) {
		self.maxPriceLevel = maxPriceLevel
		self.vibe = vibe.rawValue
	}
}

enum Vibe: String, CaseIterable, Codable, Identifiable {
	case any = "Any vibe"
	case casual = "Casual"
	case outdoorsy = "Outdoors"
	case cozy = "Cozy"
	case romantic = "Romantic"
	case upscale = "Upscale"
	
	var id: String { self.rawValue }
}

enum MoveType: String, CaseIterable {
	case location = "Location"
	case steam = "Steam"
}

enum PlaceType: String, CaseIterable, Identifiable {
	case all = "All"
	case restaurant = "Restaurant"
	case bar = "Bar"
	case cafe = "Cafe"
	case park = "Park"
	case store = "Store"
	case entertainment = "Entertainment"
	
	var id: String { self.rawValue }
	
	// Google Places API type mappings
	var apiTypes: [String] {
		switch self {
		case .all:
			return []
		case .restaurant:
			return ["restaurant", "food"]
		case .bar:
			return ["bar", "night_club"]
		case .cafe:
			return ["cafe", "bakery"]
		case .park:
			return ["park", "tourist_attraction"]
		case .store:
			return ["store", "shopping_mall", "clothing_store"]
		case .entertainment:
			return ["movie_theater", "amusement_park", "bowling_alley", "museum"]
		}
	}
}

#Preview {
	NavigationView {
		FindMovesView()
	}
}
