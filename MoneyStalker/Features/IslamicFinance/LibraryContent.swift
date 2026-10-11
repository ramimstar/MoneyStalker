import Foundation

struct FinanceArticle: Identifiable, Hashable {
    var id: String
    var title: String
    var summary: String
    var body: [String]
    var topic: String
    var sourceName: String
    var sourceURL: String?
    var verified: Bool
    var perspective: String
}

enum FinanceLibrary {
    static let topics = ["Zakat", "Charity", "Money habits", "Unverified notes"]

    static let articles: [FinanceArticle] = [
        FinanceArticle(
            id: "zakat-basics",
            title: "Zakat fundamentals",
            summary: "Zakat is a required charity on qualifying wealth, separate from voluntary giving.",
            body: [
                "Money Stalker treats zakat as an estimate you review, not as a personal religious ruling. A qualified advisor can apply details this app does not know.",
                "In the personal method used here, zakat is considered only after net eligible wealth reaches the nisab you select and you confirm that the hawl condition is met. The rate used in that case is 2.5% of that net wealth, not 2.5% of every asset you own.",
                "A house you live in, a personal car, and household goods bought to use are not entered as zakatable assets in this method. Gold, silver, cash, trade goods, and certain receivables are entered only when you decide they belong in the calculation."
            ],
            topic: "Zakat",
            sourceName: "Islamic Relief Zakat FAQ",
            sourceURL: "https://islamic-relief.org/zakat-faq/",
            verified: true,
            perspective: "Personal charity guidance summarized from Islamic Relief's public FAQ. Not a fatwa."
        ),
        FinanceArticle(
            id: "nisab-hawl",
            title: "Nisab and hawl",
            summary: "Nisab is the wealth threshold. Hawl is the period used by the method you select.",
            body: [
                "Islamic Relief describes nisab with two measures: 87.48 grams of gold or 612.36 grams of silver. The metal prices move, so this app never stores a fixed nisab amount. You enter the price per gram, and the app multiplies it by the selected weight.",
                "Islamic Relief says the silver nisab is lower, so it brings more people into zakat, while some scholars prefer the gold nisab. If someone's wealth is only gold, that FAQ says the gold nisab is the one to use, and the same for silver. This app lets you choose and shows which weight it used.",
                "The same FAQ says the zakat year starts when wealth first stays above nisab, and that a later dip below nisab does not by itself move that date unless the person loses their wealth. Other opinions restart the year after a dip. Money Stalker states that assumption on the result and still requires you to confirm hawl before it estimates an amount due."
            ],
            topic: "Zakat",
            sourceName: "Islamic Relief Zakat FAQ",
            sourceURL: "https://islamic-relief.org/zakat-faq/",
            verified: true,
            perspective: "Hawl description follows Islamic Relief's seed-date explanation. It is not presented as the only opinion."
        ),
        FinanceArticle(
            id: "gold-silver",
            title: "Gold and silver nisab",
            summary: "The calculator converts the weight you enter into a money threshold with your price.",
            body: [
                "Gold nisab in this method is 87.48 grams of pure gold. Silver nisab is 612.36 grams of pure silver. These are the weights published on Islamic Relief's Zakat FAQ. Some other references use about 85 grams of gold or 595 grams of silver. Those alternatives are not hidden: they are simply not the default weights in this version.",
                "If your gold is not 24 karat, the app converts it toward pure gold using karat divided by 24. Silver uses the fineness you enter. Jewelry is not added for you. Islamic Relief's Hanafi note treats gold and silver jewelry as zakatable, while other schools may excuse ordinary personal jewelry. Enter jewelry only if that is the ruling you are following.",
                "Prices are manual. The screen shows the currency, the unit (one gram), the source name you type, and the date you enter. Nothing is labeled as a live market price."
            ],
            topic: "Zakat",
            sourceName: "Islamic Relief Zakat FAQ",
            sourceURL: "https://islamic-relief.org/zakat-faq/",
            verified: true,
            perspective: "Weights match Islamic Relief's published FAQ figures. Jewelry remains a user choice because schools differ."
        ),
        FinanceArticle(
            id: "cash",
            title: "Zakat on cash and savings",
            summary: "Cash at home and in bank accounts is included when you enter it.",
            body: [
                "Islamic Relief's FAQ lists cash at home, bank balances, and savings among wealth taken into account. Money saved for hajj is also described there as zakatable when total wealth meets nisab.",
                "Enter the balances you still hold on the date you are calculating. Do not add money you have already spent. This app does not read your bank."
            ],
            topic: "Zakat",
            sourceName: "Islamic Relief Zakat FAQ",
            sourceURL: "https://islamic-relief.org/zakat-faq/",
            verified: true,
            perspective: "Cash treatment follows the public Islamic Relief FAQ."
        ),
        FinanceArticle(
            id: "investments",
            title: "Zakat on investments",
            summary: "Shares are not all treated the same way in the source used here.",
            body: [
                "Islamic Relief distinguishes shares bought to trade from shares bought to hold for dividends. For shares bought to resell, that FAQ says the market value is included. For shares held as an investment, it says to include only the portion of the company that is itself zakatable, such as cash, stock, and raw materials, and not buildings or machinery needed to run the business.",
                "This calculator does not read company accounts. Enter the figure you have already decided is eligible. Zakat Foundation of America's calculator asks for the total value of stocks, shares, and bonds, which is a broader entry than Islamic Relief's investment-share method. The difference is left in your hands."
            ],
            topic: "Zakat",
            sourceName: "Islamic Relief Zakat FAQ",
            sourceURL: "https://islamic-relief.org/zakat-faq/",
            verified: true,
            perspective: "Compared with Zakat Foundation of America's calculator, which asks for total stock and bond value."
        ),
        FinanceArticle(
            id: "business",
            title: "Inventory and receivables",
            summary: "Trade stock is included. Unreceived wages are not automatically included.",
            body: [
                "Islamic Relief says stock bought to sell is zakatable, including land bought for resale, raw materials, and goods produced for sale. Buildings, machinery, and vehicles needed to operate are described as exempt.",
                "The same FAQ says zakat is not due on money owed to you for work until you receive it, and it is not due on an inheritance or dowry you have not received. A loan you made can be included, either year by year or when it is repaid, and an insecure loan can wait until you actually receive it.",
                "Zakat Foundation's calculator also lists business cash, inventory, and receivables due by the zakat date. Use the receivables field only for amounts you have decided are already eligible."
            ],
            topic: "Zakat",
            sourceName: "Islamic Relief Zakat FAQ",
            sourceURL: "https://islamic-relief.org/zakat-faq/",
            verified: true,
            perspective: "Business items follow Islamic Relief. Receivables stay optional because unpaid wages are treated differently from loans."
        ),
        FinanceArticle(
            id: "debts",
            title: "Debts and liabilities",
            summary: "Only the short-term amounts you enter are deducted.",
            body: [
                "Islamic Relief says debts are deducted, and if the remainder is still over nisab, zakat remains due. For a large debt paid in installments, such as a mortgage or a large card balance, that FAQ says to deduct the current installment rather than the whole balance.",
                "Living costs that must be paid can also be deducted in that explanation. This app has one field for eligible short-term liabilities. It does not subtract your home loan, your rent, or next year's bills unless you type the portion you are deducting.",
                "ZATCA publishes Saudi regulatory guidance for zakat on business activity. That system is not applied to this personal calculation."
            ],
            topic: "Zakat",
            sourceName: "Islamic Relief Zakat FAQ",
            sourceURL: "https://islamic-relief.org/zakat-faq/",
            verified: true,
            perspective: "Personal debts follow Islamic Relief. ZATCA business zakat is intentionally excluded."
        ),
        FinanceArticle(
            id: "sadaqah",
            title: "Sadaqah and zakat",
            summary: "A donation is not zakat unless you record it as zakat.",
            body: [
                "Zakat is the required payment on qualifying wealth under the method you select. Sadaqah is voluntary charity. Money Stalker stores them as different record types so a general donation is not added to the zakat you still owe.",
                "Linking a donation to an expense you already saved does not create a second expense. Reports keep using the original transaction once.",
                "The app does not send money to a charity. You record a payment you made elsewhere."
            ],
            topic: "Charity",
            sourceName: "Islamic Relief Zakat FAQ",
            sourceURL: "https://islamic-relief.org/zakat-faq/",
            verified: true,
            perspective: "The distinction is an app rule plus the general zakat-versus-voluntary-charity difference. No payment processor is included."
        ),
        FinanceArticle(
            id: "riba-note",
            title: "Interest is not given a ruling here",
            summary: "This topic is listed so it is not mistaken for a verified article.",
            body: [
                "Questions about interest, bank products, and repayment are sensitive and differ by contract. Money Stalker does not have a reviewed source article for those questions in this version, so it does not state what is permitted.",
                "You can still track debts and payments in the rest of the app. That record is bookkeeping, not a ruling."
            ],
            topic: "Unverified notes",
            sourceName: "No verified source stored",
            sourceURL: nil,
            verified: false,
            perspective: "Unverified. No quotation and no ruling."
        ),
        FinanceArticle(
            id: "habits-note",
            title: "Spending and inheritance notes are not rulings",
            summary: "Halal income, borrowing, and inheritance need a verified source before this app will teach them.",
            body: [
                "A personal finance app can show what you spent and what you owe. It cannot decide whether income, a loan, or an estate division meets a religious standard unless a reviewed source is stored with the article.",
                "No Quranic passage, hadith, or fatwa is quoted here, because this version does not include a checked citation for those topics."
            ],
            topic: "Unverified notes",
            sourceName: "No verified source stored",
            sourceURL: nil,
            verified: false,
            perspective: "Unverified placeholder so the topic is not presented as settled."
        )
    ]

    static func article(_ id: String) -> FinanceArticle? {
        articles.first { $0.id == id }
    }
}
