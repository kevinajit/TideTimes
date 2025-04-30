//
//  ContentView.swift
//  TideTimes
//
//  Created by Kevin Ajit on 13/04/2025.
//

import SwiftUI
import MapKit
import Charts
import Portal


struct TideData: Codable {
    let status: Int
    let heights: [TideHeight]
    let extremes: [TideExtreme]
}

struct TideHeight: Codable {
    let dt: Int
    let height: Double
}

struct TideExtreme: Codable {
    let dt: Int
    let height: Double
    let type: String
}

struct Location: Identifiable, Codable {
    let id = UUID()
    let name: String
    let latitude: Double
    let longitude: Double
}

struct TideExtremeRow: View {
    let extreme: TideExtreme
    
    var body: some View {
        HStack {
            Image(systemName: extreme.type == "high" ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                .foregroundColor(extreme.type == "high" ? .red : .green)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(extreme.type == "high" ? "High Tide" : "Low Tide")
                    .font(.headline)
                Text("\(String(format: "%.2f", extreme.height))m")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(Date(timeIntervalSince1970: TimeInterval(extreme.dt)), style: .time)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
    }
}

struct ContentView: View {
    @State private var searchText = ""
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278),
        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
    )
    @State private var selectedLocation: Location?
    @State private var tideData: TideData?
    @State private var showingLocationPicker = false
    @State private var searchResults: [Location] = []
    
    private let apiKey = "986c3e50-ab46-4a33-acff-9366bf4c6c2b"
    
    private func searchLocations() {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = searchText
        request.region = region
        
        let search = MKLocalSearch(request: request)
        search.start { response, error in
            guard let response = response else { return }
            
            searchResults = response.mapItems.map { item in
                Location(
                    name: item.name ?? "Unknown Location",
                    latitude: item.placemark.coordinate.latitude,
                    longitude: item.placemark.coordinate.longitude
                )
            }
        }
    }
    
    private func fetchTideData(for location: Location) {
        let now = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -1, to: now)!
        
        let urlString = "https://www.worldtides.info/api/v3?heights&extremes&lat=\(location.latitude)&lon=\(location.longitude)&start=\(Int(startDate.timeIntervalSince1970))&end=\(Int(now.timeIntervalSince1970))&key=\(apiKey)"
        
        guard let url = URL(string: urlString) else { return }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data else { return }
            
            if let decodedData = try? JSONDecoder().decode(TideData.self, from: data) {
                DispatchQueue.main.async {
                    self.tideData = decodedData
                }
            }
        }.resume()
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Location Search Bar
                    HStack {
                        TextField("Search location", text: $searchText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .onChange(of: searchText) { _ in
                                searchLocations()
                            }
                        
                        Button(action: {
                            showingLocationPicker.toggle()
                        }) {
                            Image(systemName: "location.magnifyingglass")
                                .font(.title2)
                                .foregroundColor(.blue)
                        }
                        .frame(width: 44, height: 44)
                    }
                    .padding(.horizontal)
                    
                    if showingLocationPicker {
                        List(searchResults) { location in
                            Button(action: {
                                selectedLocation = location
                                fetchTideData(for: location)
                                showingLocationPicker = false
                            }) {
                                Text(location.name)
                            }
                        }
                        .frame(height: 200)
                    }
                    
                    if let tideData = tideData {
                        VStack(alignment: .leading, spacing: 16) {
                            // Location Header
                            HStack {
                                Image(systemName: "location.fill")
                                    .foregroundColor(.blue)
                                Text(selectedLocation?.name ?? "Select Location")
                                    .font(.title2)
                                    .fontWeight(.semibold)
                            }
                            .padding(.horizontal)
                            
                            // Tide Graph
                            Chart {
                                ForEach(tideData.heights, id: \.dt) { height in
                                    LineMark(
                                        x: .value("Time", Date(timeIntervalSince1970: TimeInterval(height.dt))),
                                        y: .value("Height", height.height)
                                    )
                                    .foregroundStyle(.blue.opacity(0.8))
                                }
                                
                                ForEach(tideData.extremes, id: \.dt) { extreme in
                                    PointMark(
                                        x: .value("Time", Date(timeIntervalSince1970: TimeInterval(extreme.dt))),
                                        y: .value("Height", extreme.height)
                                    )
                                    .foregroundStyle(extreme.type == "high" ? .red : .green)
                                }
                            }
                            .chartXAxis {
                                AxisMarks(values: .stride(by: .hour, count: 4)) { value in
                                    AxisGridLine()
                                    AxisValueLabel(format: .dateTime.hour())
                                }
                            }
                            .frame(height: 250)
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(16)
                            .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                            
                            // Highs and Lows Table
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Tide Extremes")
                                    .font(.headline)
                                    .padding(.horizontal)
                                
                                ForEach(tideData.extremes, id: \.dt) { extreme in
                                    TideExtremeRow(extreme: extreme)
                                        .padding(.horizontal)
                                }
                            }
                            .padding(.vertical)
                            .background(Color(.systemBackground))
                            .cornerRadius(16)
                            .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                        }
                        .padding(.horizontal)
                    } else {
                        VStack(spacing: 16) {
                            Image(systemName: "figure.pool.swim")
                                .font(.system(size: 60))
                                .foregroundColor(.blue.opacity(0.5))
                            Text("Select a location to view tide data")
                                .font(.headline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding()
                    }
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Tide Times")
        }
    }
}

#Preview {
    ContentView()
}
