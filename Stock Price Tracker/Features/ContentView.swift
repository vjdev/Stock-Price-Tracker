import SwiftUI

struct ContentView: View {
    @ObservedObject var container: AppContainer

    var body: some View {
        NavigationStack {
            StockListView(viewModel: container.stockListViewModel)
                .navigationDestination(for: String.self) { symbol in
                    StockDetailView(symbol: symbol, stockListViewModel: container.stockListViewModel)
                }
        }
        .tint(AppTheme.Colors.accent)
    }
}

#Preview {
    ContentView(container: AppContainer())
}
