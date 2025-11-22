//
//  ContentView.swift
//  WTM
//
//  Created by Riley Hartung on 7/31/25.
//

import SwiftUI

struct ContentView: View {
	var body: some View {
		TabView {
			NavigationStack {
				FindMovesView()
					.navigationTitle("Find Moves")
			}
			.tabItem {
				Label("Find Moves", systemImage: "calendar")
			}
			
			NavigationStack {
				Text("Past Moves View")
					.navigationTitle("Past Moves")
			}
			.tabItem {
				Label("Past Moves", systemImage: "clock")
			}
			
			NavigationStack {
				Text("Profile View")
					.navigationTitle("Profile")
			}
			.tabItem {
				Label("Profile", systemImage: "person")
			}
		}
	}
}

#Preview {
	ContentView()
}
