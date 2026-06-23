import SwiftUI

struct AddTickerView: View {
    @EnvironmentObject var vm: WatchlistViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var query: String = ""
    @State private var debounceTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search by ticker or company name…", text: $query)
                    .textFieldStyle(.plain)
                    .font(.body)
                    .onChange(of: query) { newValue in
                        debounceSearch(query: newValue)
                    }
                if vm.isSearching {
                    ProgressView().scaleEffect(0.75)
                } else if !query.isEmpty {
                    Button {
                        query = ""
                        vm.searchResults = []
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(12)
            .background(.regularMaterial)

            Divider()

            // Results
            Group {
                if !query.isEmpty && vm.searchResults.isEmpty && !vm.isSearching {
                    noResultsView
                } else {
                    resultsList
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            // Footer
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding(12)
        }
        .frame(width: 500, height: 440)
    }

    // MARK: - Sub-views

    private var noResultsView: some View {
        VStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("No results for \"\(query)\"")
                .foregroundStyle(.secondary)
        }
    }

    private var resultsList: some View {
        List(vm.searchResults, id: \.symbol) { result in
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(result.displaySymbol)
                        .font(.headline)
                    Text(result.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                let alreadyAdded = vm.tickers.contains { $0.symbol == result.symbol }
                Button {
                    vm.addTicker(symbol: result.symbol, name: result.description)
                    dismiss()
                } label: {
                    Label(alreadyAdded ? "Added" : "Add", systemImage: alreadyAdded ? "checkmark" : "plus")
                }
                .disabled(alreadyAdded)
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            .padding(.vertical, 3)
        }
        .listStyle(.plain)
    }

    // MARK: - Debounce

    private func debounceSearch(query: String) {
        debounceTask?.cancel()
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            vm.searchResults = []
            return
        }
        debounceTask = Task {
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            vm.searchSymbols(query: query)
        }
    }
}
