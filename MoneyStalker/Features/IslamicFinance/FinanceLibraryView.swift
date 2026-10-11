import SwiftData
import SwiftUI

struct FinanceLibraryView: View {
    @Query(sort: \LibraryBookmark.savedAt, order: .reverse) private var bookmarks: [LibraryBookmark]
    @Query(sort: \LibraryVisit.viewedAt, order: .reverse) private var visits: [LibraryVisit]
    @State private var query = ""
    @State private var topic = "All"

    private var filtered: [FinanceArticle] {
        FinanceLibrary.articles.filter { article in
            (topic == "All" || article.topic == topic) &&
            (query.isEmpty || article.title.localizedCaseInsensitiveContains(query) || article.summary.localizedCaseInsensitiveContains(query))
        }
    }

    var body: some View {
        List {
            if !recent.isEmpty {
                Section("Recently viewed") {
                    ForEach(recent) { article in
                        NavigationLink(article.title, value: AppRoute.libraryArticle(article.id))
                    }
                }
            }
            Section {
                Picker("Topic", selection: $topic) {
                    Text("All").tag("All")
                    ForEach(FinanceLibrary.topics, id: \.self) { Text($0).tag($0) }
                }
                ForEach(filtered) { article in
                    NavigationLink(value: AppRoute.libraryArticle(article.id)) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(article.title).font(.body.weight(.semibold))
                            Text(article.summary)
                                .font(.caption)
                                .foregroundStyle(Color.moneyStalkerSlate)
                            Text(article.verified ? article.sourceName : "Not a verified article")
                                .font(.caption2)
                                .foregroundStyle(Color.moneyStalkerSlate)
                        }
                    }
                }
            }
        }
        .searchable(text: $query, prompt: "Search articles")
        .navigationTitle("Finance library")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var recent: [FinanceArticle] {
        var seen = Set<String>()
        return visits.compactMap { visit -> FinanceArticle? in
            guard seen.insert(visit.articleID).inserted, let article = FinanceLibrary.article(visit.articleID) else { return nil }
            return article
        }
        .prefix(3)
        .map { $0 }
    }
}

struct FinanceArticleView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.openURL) private var openURL
    @Query private var bookmarks: [LibraryBookmark]
    var articleID: String

    private var article: FinanceArticle? { FinanceLibrary.article(articleID) }
    private var saved: LibraryBookmark? { bookmarks.first { $0.articleID == articleID } }

    var body: some View {
        Group {
            if let article {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text(article.summary)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Color.moneyStalkerSecondary)
                        ForEach(article.body, id: \.self) { paragraph in
                            Text(paragraph)
                                .font(.body)
                                .foregroundStyle(Color.moneyStalkerSecondary)
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            Text(article.verified ? "Source" : "Source status")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.moneyStalkerSlate)
                            Text(article.sourceName)
                            Text(article.perspective)
                                .font(.footnote)
                                .foregroundStyle(Color.moneyStalkerSlate)
                            Text("Publication date: not stored. This copy was written for Money Stalker and is not a quotation.")
                                .font(.footnote)
                                .foregroundStyle(Color.moneyStalkerSlate)
                            if let url = article.sourceURL, let link = URL(string: url) {
                                Button("Open source") { openURL(link) }
                            }
                        }
                        .padding(14)
                        .moneyStalkerCard()
                    }
                    .padding(16)
                }
                .navigationTitle(article.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    Button(saved == nil ? "Save" : "Saved") { toggle() }
                }
                .onAppear { remember() }
            } else {
                Text("This article is not in the library.")
            }
        }
        .moneyStalkerScreen()
    }

    private func toggle() {
        if let saved {
            context.delete(saved)
        } else {
            context.insert(LibraryBookmark(articleID: articleID))
        }
        try? context.save()
    }

    private func remember() {
        context.insert(LibraryVisit(articleID: articleID))
        try? context.save()
    }
}
