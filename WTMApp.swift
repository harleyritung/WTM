//
//  WTMApp.swift
//  WTM
//
//  Created by Riley Hartung on 7/31/25.
//

import SwiftUI
import GooglePlaces

@main
struct WTMApp: App {
	init() {
		GMSPlacesClient.provideAPIKey(googlePlacesAPIKey)
	}
	
	var body: some Scene {
		WindowGroup {
			ContentView()
		}
	}
}
