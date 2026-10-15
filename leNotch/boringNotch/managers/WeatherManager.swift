//
//  WeatherManager.swift
//  boringNotch
//
//  Created for boringNotch Weather Integration.
//

import AppKit
import Combine
import Foundation

struct WeatherInfo: Equatable {
    let temperature: Double
    let unit: String
    let conditionDescription: String
    let symbolName: String
    let city: String

    var formattedTemperature: String {
        "\(Int(round(temperature)))\(unit)"
    }
}

@MainActor
final class WeatherManager: ObservableObject {
    static let shared = WeatherManager()

    @Published var weather: WeatherInfo?
    @Published var isLoading: Bool = false
    private var refreshTimer: AnyCancellable?

    private init() {
        Task {
            await fetchWeather()
        }
        setupTimer()
    }

    private func setupTimer() {
        refreshTimer = Timer.publish(every: 1800, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task {
                    await self?.fetchWeather()
                }
            }
    }

    func fetchWeather() async {
        isLoading = true
        defer { isLoading = false }

        do {
            guard let locationURL = URL(string: "http://ip-api.com/json") else { return }
            let (locData, _) = try await URLSession.shared.data(from: locationURL)
            guard let locJson = try? JSONSerialization.jsonObject(with: locData) as? [String: Any],
                  let lat = locJson["lat"] as? Double,
                  let lon = locJson["lon"] as? Double else {
                return
            }
            let city = (locJson["city"] as? String) ?? "Local"

            let isFahrenheit: Bool = {
                if #available(macOS 13.0, *) {
                    return Locale.current.measurementSystem == .us
                } else {
                    return Locale.current.identifier.hasSuffix("_US")
                }
            }()
            let unitParam = isFahrenheit ? "fahrenheit" : "celsius"
            let unitSymbol = isFahrenheit ? "°F" : "°"

            guard let weatherURL = URL(string: "https://api.open-meteo.com/v1/forecast?latitude=\(lat)&longitude=\(lon)&current=temperature_2m,weather_code&temperature_unit=\(unitParam)") else {
                return
            }
            let (weatherData, _) = try await URLSession.shared.data(from: weatherURL)
            guard let weatherJson = try? JSONSerialization.jsonObject(with: weatherData) as? [String: Any],
                  let current = weatherJson["current"] as? [String: Any],
                  let temp = current["temperature_2m"] as? Double,
                  let code = current["weather_code"] as? Int else {
                return
            }

            let (symbol, desc) = symbolAndDescription(for: code)
            self.weather = WeatherInfo(
                temperature: temp,
                unit: unitSymbol,
                conditionDescription: desc,
                symbolName: symbol,
                city: city
            )
        } catch {
            print("⚠️ [WeatherManager] Error fetching weather: \(error)")
        }
    }

    func openWeatherApp() {
        if let url = URL(string: "weather://") {
            NSWorkspace.shared.open(url)
        }
    }

    private func symbolAndDescription(for code: Int) -> (String, String) {
        switch code {
        case 0:
            return ("sun.max.fill", "Clear")
        case 1, 2:
            return ("cloud.sun.fill", "Partly Cloudy")
        case 3:
            return ("cloud.fill", "Overcast")
        case 45, 48:
            return ("cloud.fog.fill", "Fog")
        case 51, 53, 55:
            return ("cloud.drizzle.fill", "Drizzle")
        case 61, 63, 65:
            return ("cloud.rain.fill", "Rain")
        case 71, 73, 75, 77:
            return ("snowflake", "Snow")
        case 80, 81, 82:
            return ("cloud.heavyrain.fill", "Showers")
        case 85, 86:
            return ("cloud.snow.fill", "Snow Showers")
        case 95, 96, 99:
            return ("cloud.bolt.rain.fill", "Thunderstorm")
        default:
            return ("cloud.sun.fill", "Fair")
        }
    }
}
