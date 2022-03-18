//
//  SearchState.swift
//  Search
//
//  Created by jake on 3/18/22.
//  Copyright © 2022 Brandon Williams. All rights reserved.
//

import ComposableArchitecture
import SwiftUI

private let readMe = """
  This application demonstrates live-searching with the Composable Architecture. As you type the \
  events are debounced for 300ms, and when you stop typing an API request is made to load \
  locations. Then tapping on a location will load weather.
  """

// MARK: - Search feature domain

struct SearchState: Equatable {
  var locations: [Location] = []
  var locationWeather: LocationWeather?
  var locationWeatherRequestInFlight: Location?
  var searchQuery = ""
}

enum SearchAction: Equatable {
  case locationsResponse(Result<[Location], WeatherClient.Failure>)
  case locationTapped(Location)
  case locationWeatherResponse(Result<LocationWeather, WeatherClient.Failure>)
  case searchQueryChanged(String)
}

struct SearchEnvironment {
  var weatherClient: WeatherClient
  var mainQueue: AnySchedulerOf<DispatchQueue>
}

// MARK: - Search feature reducer

let searchReducer = Reducer<SearchState, SearchAction, SearchEnvironment> {
  state, action, environment in
  switch action {
  case .locationsResponse(.failure):
    state.locations = []
    return .none

  case let .locationsResponse(.success(response)):
    state.locations = response
    return .none

  case let .locationTapped(location):
    struct SearchWeatherId: Hashable {}

    state.locationWeatherRequestInFlight = location

    return environment.weatherClient
      .weather(location.id)
      .receive(on: environment.mainQueue)
      .catchToEffect(SearchAction.locationWeatherResponse)
      .cancellable(id: SearchWeatherId(), cancelInFlight: true)

  case let .searchQueryChanged(query):
    struct SearchLocationId: Hashable {}

    state.searchQuery = query

    // When the query is cleared we can clear the search results, but we have to make sure to cancel
    // any in-flight search requests too, otherwise we may get data coming in later.
    guard !query.isEmpty else {
      state.locations = []
      state.locationWeather = nil
      return .cancel(id: SearchLocationId())
    }

    return environment.weatherClient
      .searchLocation(query)
      .debounce(id: SearchLocationId(), for: 0.3, scheduler: environment.mainQueue)
      .catchToEffect(SearchAction.locationsResponse)

  case let .locationWeatherResponse(.failure(locationWeather)):
    state.locationWeather = nil
    state.locationWeatherRequestInFlight = nil
    return .none

  case let .locationWeatherResponse(.success(locationWeather)):
    state.locationWeather = locationWeather
    state.locationWeatherRequestInFlight = nil
    return .none
  }
}
