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
            stockContent
        }
        .background(AppTheme.Colors.background.ignoresSafeArea())
        .navigationTitle(symbol)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Stock Detail View Components -

private extension StockDetailView {
    @ViewBuilder
    var stockContent: some View {
        if let stock = viewModel.stock {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.section) {
                stockIdentitySection(stock)
                stockPriceCard(stock)
                stockAboutSection(stock)
            }
            .foregroundStyle(AppTheme.Colors.primaryText)
            .appScreenStyle()
            .padding(.vertical, AppTheme.Spacing.screenPadding)
        } else {
            ContentUnavailableView("stock.unavailable.title", systemImage: "chart.xyaxis.line")
        }
    }

    func stockIdentitySection(_ stock: Stock) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.item) {
            Text(stock.symbol)
                .font(AppTheme.Typography.screenTitle)
                .accessibilityIdentifier("stockDetailSymbol")
            Text(stock.name)
                .font(AppTheme.Typography.body)
                .foregroundStyle(AppTheme.Colors.secondaryText)
                .accessibilityIdentifier("stockDetailName")
        }
    }

    func stockPriceCard(_ stock: Stock) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.card) {
            Text(LocaleFormatting.currency(stock.price))
                .font(.largeTitle.weight(.bold))
                .contentTransition(.numericText())
            ChangeLabel(change: stock.change)
                .accessibilityIdentifier("stockDetailPercentageChange")
            StockDetailValueRow(
                title: "stock.change.absolute",
                titleAccessibilityIdentifier: "stockDetailAbsoluteChangeLabel",
                value: {
                    Text(LocaleFormatting.currency(stock.absoluteChange))
                        .accessibilityIdentifier("stockDetailAbsoluteChange")
                }
            )
            StockDetailValueRow(
                title: "stock.lastUpdated",
                value: { Text(stock.lastUpdated, style: .time) }
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(AppTheme.Colors.surface, in: RoundedRectangle(cornerRadius: AppTheme.Radius.card))
    }

    func stockAboutSection(_ stock: Stock) -> some View {
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
}

// MARK: - Stock Detail Value Row -

private struct StockDetailValueRow<Value: View>: View {
    let title: LocalizedStringKey
    let titleAccessibilityIdentifier: String?
    let value: Value

    init(
        title: LocalizedStringKey,
        titleAccessibilityIdentifier: String? = nil,
        @ViewBuilder value: () -> Value
    ) {
        self.title = title
        self.titleAccessibilityIdentifier = titleAccessibilityIdentifier
        self.value = value()
    }

    var body: some View {
        HStack(spacing: AppTheme.Spacing.compact) {
            titleLabel
            value
        }
        .font(AppTheme.Typography.caption)
        .foregroundStyle(AppTheme.Colors.secondaryText)
    }

    @ViewBuilder
    private var titleLabel: some View {
        if let titleAccessibilityIdentifier {
            Text(title)
                .accessibilityIdentifier(titleAccessibilityIdentifier)
        } else {
            Text(title)
        }
    }
}
