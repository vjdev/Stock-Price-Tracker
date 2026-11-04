import SwiftUI

struct StockDetailView: View {
    let symbol: String
    @StateObject private var viewModel: StockDetailViewModel

    init(symbol: String, stockListViewModel: StockListViewModel) {
        self.symbol = symbol
        _viewModel = StateObject(wrappedValue: StockDetailViewModel(symbol: symbol, stockListViewModel: stockListViewModel))
    }

    var body: some View {
        ScrollView {
            if let stock = viewModel.stock {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.section) {
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.item) {
                        Text(stock.symbol)
                            .font(AppTheme.Typography.screenTitle)
                            .foregroundStyle(AppTheme.Colors.primaryText)
                            .accessibilityIdentifier("stockDetailSymbol")
                        Text(stock.name)
                            .font(AppTheme.Typography.body)
                            .foregroundStyle(AppTheme.Colors.secondaryText)
                            .accessibilityIdentifier("stockDetailName")
                    }
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.card) {
                        Text(LocaleFormatting.currency(stock.price))
                            .font(.largeTitle.weight(.bold))
                            .contentTransition(.numericText())
                        ChangeLabel(change: stock.change)
                            .accessibilityIdentifier("stockDetailPercentageChange")
                        HStack(spacing: AppTheme.Spacing.compact) {
                            Text("stock.change.absolute")
                                .accessibilityIdentifier("stockDetailAbsoluteChangeLabel")
                            Text(LocaleFormatting.currency(stock.absoluteChange))
                                .accessibilityIdentifier("stockDetailAbsoluteChange")
                        }
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                        HStack(spacing: AppTheme.Spacing.compact) {
                            Text("stock.lastUpdated")
                            Text(stock.lastUpdated, style: .time)
                        }
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(AppTheme.Colors.surface, in: RoundedRectangle(cornerRadius: AppTheme.Radius.card))
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.item) {
                        HStack(spacing: AppTheme.Spacing.compact) {
                            Text("stock.about")
                            Text(stock.symbol)
                        }
                        .font(AppTheme.Typography.sectionTitle)
                        Text(stock.description)
                            .font(AppTheme.Typography.body)
                            .foregroundStyle(AppTheme.Colors.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .foregroundStyle(AppTheme.Colors.primaryText)
                .appScreenStyle()
                .padding(.vertical, AppTheme.Spacing.screenPadding)
            } else {
                ContentUnavailableView("stock.unavailable.title", systemImage: "chart.xyaxis.line")
            }
        }
        .background(AppTheme.Colors.background.ignoresSafeArea())
        .navigationTitle(symbol)
        .navigationBarTitleDisplayMode(.inline)
    }
}
