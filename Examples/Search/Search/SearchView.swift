import ComposableArchitecture
import SwiftUI

private let readMe = """
  This application demonstrates live-searching with the Composable Architecture. As you type the \
  events are debounced for 300ms, and when you stop typing an API request is made to load \
  locations. Then tapping on a location will load weather.
  """

// MARK: - Search feature view

struct SearchView: View {
  let store: Store<SearchState, SearchAction>

  var body: some View {
    WithViewStore(self.store) { viewStore in
      NavigationView {
        VStack(alignment: .leading) {
          Text(readMe)
            .padding()

          HStack {
            Image(systemName: "magnifyingglass")
            TextField(
              "New York, San Francisco, ...",
              text: viewStore.binding(
                get: \.searchQuery, send: SearchAction.searchQueryChanged
              )
            )
            .textFieldStyle(.roundedBorder)
            .autocapitalization(.none)
            .disableAutocorrection(true)
          }
          .padding(.horizontal, 16)

          List {
            ForEach(viewStore.locations, id: \.id) { location in
              VStack(alignment: .leading) {
                Button(action: {
                  viewStore.send(.locationTapped(location))
                })
                {
                  HStack {
                    Text(location.title)

                    if viewStore.locationWeatherRequestInFlight?.id == location.id {
                      ProgressView()
                    }
                  }
                }

                if location.id == viewStore.locationWeather?.id {
                  self.weatherView(locationWeather: viewStore.locationWeather)
                }
              }
            }
          }

          Button("Weather API provided by MetaWeather.com") {
            UIApplication.shared.open(URL(string: "http://www.MetaWeather.com")!)
          }
          .foregroundColor(.gray)
          .padding(.all, 16)
        }
        .navigationBarTitle("Search")
      }
      .navigationViewStyle(.stack)
    }
  }

  func weatherView(locationWeather: LocationWeather?) -> some View {
    guard let locationWeather = locationWeather else {
      return AnyView(EmptyView())
    }

    let days = locationWeather.consolidatedWeather
      .enumerated()
      .map { idx, weather in formattedWeatherDay(weather, isToday: idx == 0) }

    return AnyView(
      VStack(alignment: .leading) {
        ForEach(days, id: \.self) { day in
          Text(day)
        }
      }
      .padding(.leading, 16)
    )
  }
}

// MARK: - Private helpers

private func formattedWeatherDay(_ data: LocationWeather.ConsolidatedWeather, isToday: Bool)
  -> String
{
  let date =
    isToday
    ? "Today"
    : dateFormatter.string(from: data.applicableDate).capitalized

  return [
    date,
    "\(Int(round(data.theTemp)))℃",
    data.weatherStateName,
  ]
  .compactMap { $0 }
  .joined(separator: ", ")
}

private let dateFormatter: DateFormatter = {
  let formatter = DateFormatter()
  formatter.dateFormat = "EEEE"
  return formatter
}()

// MARK: - SwiftUI previews

struct SearchView_Previews: PreviewProvider {
  static var previews: some View {
    let store = Store(
      initialState: SearchState(),
      reducer: searchReducer,
      environment: SearchEnvironment(
        weatherClient: WeatherClient(
          searchLocation: { _ in
            Effect(value: [
              Location(id: 1, title: "Brooklyn"),
              Location(id: 2, title: "Los Angeles"),
              Location(id: 3, title: "San Francisco"),
            ])
          },
          weather: { id in
            Effect(
              value: LocationWeather(
                consolidatedWeather: [
                  .init(
                    applicableDate: Date(timeIntervalSince1970: 0),
                    maxTemp: 90,
                    minTemp: 70,
                    theTemp: 80,
                    weatherStateName: "Clear"
                  ),
                  .init(
                    applicableDate: Date(timeIntervalSince1970: 86_400),
                    maxTemp: 70,
                    minTemp: 50,
                    theTemp: 60,
                    weatherStateName: "Rain"
                  ),
                  .init(
                    applicableDate: Date(timeIntervalSince1970: 172_800),
                    maxTemp: 100,
                    minTemp: 80,
                    theTemp: 90,
                    weatherStateName: "Cloudy"
                  ),
                ],
                id: id
              )
            )
          }
        ),
        mainQueue: .main
      )
    )

    return Group {
      SearchView(store: store)

      SearchView(store: store)
        .environment(\.colorScheme, .dark)
    }
  }
}
