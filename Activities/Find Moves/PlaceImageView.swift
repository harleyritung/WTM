//
//  PlaceImageView.swift
//  WTM
//
//  Created by Riley Hartung on 8/3/25.
//

import SwiftUI
import GooglePlaces

struct PlaceImageView: View {
	let place: GMSPlace
	@State private var placeImage: UIImage?
	@State private var isLoading = false
	
	var body: some View {
		Group {
			if let image = placeImage {
				Image(uiImage: image)
					.resizable()
					.aspectRatio(contentMode: .fill)
					.frame(height: 180)
					.clipped()
					.cornerRadius(8)
			} else {
				Rectangle()
					.fill(Color.gray.opacity(0.3))
					.frame(height: 180)
					.cornerRadius(8)
					.overlay(
						Group {
							if isLoading {
								ProgressView()
							} else {
								Image(systemName: "photo")
									.font(.largeTitle)
									.foregroundColor(.gray)
							}
						}
					)
			}
		}
		.onAppear {
			loadPlaceImage()
		}
	}
	
	private func loadPlaceImage() {
		guard placeImage == nil, !isLoading else { return }
		
		isLoading = true
		
		// Check if place has metadata photos
		if let photos = place.photos, !photos.isEmpty {
			let photo = photos[0]
			
			// TODO: use photos when done (reduce tokens until then)
			// Load the photo using the Google Places API
//			photo.loadImage(callback: { image, error in
//				DispatchQueue.main.async {
//					self.isLoading = false
//					
//					if let error = error {
//						print("Error loading place image: \(error.localizedDescription)")
//						return
//					}
//					
//					self.placeImage = image
//				}
//			})
		} else {
			// No photos available
			isLoading = false
		}
	}
}
