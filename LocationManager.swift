import CoreLocation
import GooglePlaces
import SwiftUI

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
	private var manager = CLLocationManager()
	private var placesClient: GMSPlacesClient
	
	@Published var currentLocation: CLLocation?
	@Published var authorizationStatus: CLAuthorizationStatus
	
	// 10 miles in meters
	private let maxDistance: CLLocationDistance = 16093.4
	
	override init() {
		placesClient = GMSPlacesClient.shared()
		authorizationStatus = manager.authorizationStatus
		
		super.init()
		manager.delegate = self
		manager.desiredAccuracy = kCLLocationAccuracyKilometer
	}
	
	func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
		if let location = locations.first {
			currentLocation = location
			manager.stopUpdatingLocation()
		}
	}
	
	func getCurrentLocation(completion: @escaping ([GMSPlace]) -> Void) {
		if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
			manager.startUpdatingLocation()
			
			// Only fetch places if we have location permission
			// Add a small delay to ensure we have the current location first
			DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
				self?.fetchNearbyPlaces { places in
					completion(places)
				}
			}
		} else {
			manager.requestWhenInUseAuthorization()
			completion([]) // Return empty array if no authorization
		}
	}
	
	private func fetchNearbyPlaces(completion: @escaping ([GMSPlace]) -> Void) {
		let fields: GMSPlaceField = GMSPlaceField(rawValue: UInt64(
			UInt(GMSPlaceField.name.rawValue) |
			UInt(GMSPlaceField.placeID.rawValue) |
			UInt(GMSPlaceField.types.rawValue) |
			UInt(GMSPlaceField.rating.rawValue) |
			UInt(GMSPlaceField.priceLevel.rawValue) |
			UInt(GMSPlaceField.photos.rawValue) |
			UInt(GMSPlaceField.coordinate.rawValue)
		))
		
		guard let userLocation = currentLocation else {
			completion([])
			return
		}
		
		placesClient.findPlaceLikelihoodsFromCurrentLocation(withPlaceFields: fields) { (placeLikelihoodList, error) in
			if let error = error {
				print("Places error: \(error.localizedDescription)")
				completion([])
				return
			}
			
			if let placeLikelihoodList = placeLikelihoodList {
				var places: [GMSPlace] = []
				
				for likelihood in placeLikelihoodList {
					let place = likelihood.place
					
					let placeLocation = CLLocation(latitude: place.coordinate.latitude, longitude: place.coordinate.longitude)
					let distance = userLocation.distance(from: placeLocation)
					
					if distance <= self.maxDistance, let types = place.types, !types.isEmpty {
						places.append(place)
						print("Found place: \(place.name ?? "Unknown") at likelihood \(likelihood.likelihood) with types \(types), distance: \(distance/1609.34) miles")
					}
				}
				
				completion(places)
			} else {
				completion([])
			}
		}
	}
}
