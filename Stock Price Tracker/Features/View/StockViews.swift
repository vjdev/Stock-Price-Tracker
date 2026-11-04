import SwiftUI

struct StockListView: View {
    @ObservedObject var viewModel: StockListViewModel

    var body: some View {
        List {
            Section {
                if viewModel.stocks.isEmpty {
                    ContentUnavailableView(
                        "market.empty.title",
                        systemImage: "chart.xyaxis.line",
                        description: Text("market.empty.message")
                    )
                    .listRowBackground(AppTheme.Colors.surface)
                } else if viewModel.sortedStocks.isEmpty {
                    ContentUnavailableView.search(text: viewModel.searchQuery)
                        .listRowBackground(AppTheme.Colors.surface)
                } else {
                    ForEach(viewModel.sortedStocks) { stock in
                        NavigationLink(value: stock.symbol) {
                            StockRow(stock: stock)
                        }
                        .simultaneousGesture(TapGesture().onEnded {
                            viewModel.selectStock(symbol: stock.symbol)
                        })
                        .listRowBackground(AppTheme.Colors.surface)
                    }
                }
            } header: {
                HStack(spacing: AppTheme.Spacing.compact) {
                    Text(viewModel.stocks.count, format: .number.locale(.current))
                    Text("market.trackedSymbols")
                }
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.Colors.secondaryText)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(AppTheme.Colors.background)
        .navigationTitle("market.title")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $viewModel.searchQuery, prompt: "stock.search")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { sortMenu }
            ToolbarItem(placement: .bottomBar) { FeedControl(viewModel: viewModel) }
        }
    }

    private var sortMenu: some View {
        Menu {
            Picker("sort.title", selection: $viewModel.sortOption) {
                ForEach(StockSortOption.allCases) { option in
                    Text(option.localizedTitle).tag(option)
                }
            }
        } label: {
            Label("sort.title", systemImage: "arrow.up.arrow.down")
        }
    }
}

private struct StockRow: View {
    let stock: Stock

    var body: some View {
        HStack(spacing: AppTheme.Spacing.item) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.compact) {
                Text(stock.symbol)
                    .font(AppTheme.Typography.body.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.primaryText)
                Text(stock.name)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .lineLimit(1)
            }
            Spacer(minLength: AppTheme.Spacing.item)
            VStack(alignment: .trailing, spacing: AppTheme.Spacing.compact) {
                Text(LocaleFormatting.currency(stock.price))
                    .font(AppTheme.Typography.body.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.primaryText)
                ChangeLabel(change: stock.change)
            }
        }
        .padding(.vertical, AppTheme.Spacing.row)
        .accessibilityElement(children: .combine)
    }
}

struct FeedControl: View {
    @ObservedObject var viewModel: StockListViewModel

    var body: some View {
        HStack(spacing: AppTheme.Spacing.item) {
            Circle()
                .fill(viewModel.connectionState == .connected ? AppTheme.Colors.positive : AppTheme.Colors.secondaryText)
                .frame(width: 8, height: 8)
            Text(viewModel.connectionState.localizedTitle)
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.Colors.secondaryText)
            Spacer()
            Button(action: toggleFeed) {
                Text(viewModel.connectionState.isRunning ? "feed.stop" : "feed.start")
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.borderedProminent)
            .tint(viewModel.connectionState.isRunning ? AppTheme.Colors.negative : AppTheme.Colors.accent)
        }
        .padding(.vertical, AppTheme.Spacing.compact)
    }

    private func toggleFeed() {
        if viewModel.connectionState.isRunning {
            viewModel.stopFeed()
        } else {
            viewModel.startFeed()
        }
    }
}

struct ChangeLabel: View {
    let change: Double

    var body: some View {
        Label {
            Text(LocaleFormatting.percentage(change))
        } icon: {
            Image(systemName: change >= 0 ? "arrow.up.right" : "arrow.down.right")
        }
        .font(AppTheme.Typography.caption.weight(.semibold))
        .foregroundStyle(change >= 0 ? AppTheme.Colors.positive : AppTheme.Colors.negative)
        .labelStyle(.titleAndIcon)
    }
}
