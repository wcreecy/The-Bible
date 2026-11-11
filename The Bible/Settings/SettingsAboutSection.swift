import SwiftUI

struct SettingsAboutSection: View {
    var body: some View {
        Section {
            NavigationLink {
                FeedbackView()
            } label: {
                SettingsNavigationRow(
                    title: "Share Feedback",
                    subtitle: "Send comments, suggestions, or report a problem",
                    systemImage: "envelope"
                )
            }
            .accessibilityIdentifier("shareFeedbackLink")

            if let url = URL(string: "https://apps.apple.com/app/id6756133350?action=write-review") {
                SettingsExternalLinkRow(
                    url: url,
                    title: "Rate the App",
                    subtitle: "Leave a rating or review on the App Store",
                    systemImage: "star"
                )
                .accessibilityIdentifier("rateAppLink")
            }

            if let url = URL(string: "https://medium.com/@williamcreecy/privacy-policy-a46d78662bb7") {
                SettingsExternalLinkRow(
                    url: url,
                    title: "Privacy Policy",
                    subtitle: "How the app handles your data",
                    systemImage: "lock.shield"
                )
                .accessibilityIdentifier("privacyPolicyLink")
            }

            NavigationLink {
                AcknowledgementsView()
            } label: {
                SettingsNavigationRow(
                    title: "Acknowledgements",
                    subtitle: "Sources and credits",
                    systemImage: "heart.text.square"
                )
            }
            .accessibilityIdentifier("acknowledgementsLink")
        } header: {
            Text("About")
        } footer: {
            Text("Version \(appVersion)", comment: "App version shown below the About section; the value is the version and build, e.g. 1.2 (45).")
                .accessibilityIdentifier("appVersionLabel")
        }
    }

    /// Marketing version and build number, e.g. "1.2 (45)".
    private var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "—"
        guard let build = info?["CFBundleVersion"] as? String else { return version }
        return "\(version) (\(build))"
    }
}

/// Credits for data the app includes, as their licenses require.
struct AcknowledgementsView: View {
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text("OpenBible.info")
                        .font(.headline)
                    Text("Scripture connections in Chapter Insights are selected from the OpenBible.info cross-reference dataset, used under the Creative Commons Attribution license.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 2)

                if let url = URL(string: "https://www.openbible.info") {
                    Link(destination: url) {
                        Label("openbible.info", systemImage: "safari")
                    }
                }
            } header: {
                Text("Scripture Connections")
            }

            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text("STEPBible and Tyndale House, Cambridge")
                        .font(.headline)
                    Text("The Hebrew and Greek words, Strong’s numbers, dictionary entries, grammar, and names of people and places in Word Study come from STEPBible-Data by STEPBible.org and Tyndale House, Cambridge, used under the Creative Commons Attribution 4.0 license. The data was reformatted for this app: punctuation was removed from word endings, most dictionary definitions and many short meanings were rewritten in plain language and some corrected, long dictionary entries were shortened, grammar codes were rewritten as plain English, and name records were trimmed to who each is, how they are related, and the verses they appear in.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 2)

                if let url = URL(string: "https://STEPBible.github.io/STEPBible-Data") {
                    Link(destination: url) {
                        Label("STEPBible-Data", systemImage: "safari")
                    }
                }
            } header: {
                Text("Hebrew and Greek Words")
            }

            Section {
                ForEach(BibleTranslation.available) { translation in
                    VStack(alignment: .leading, spacing: 6) {
                        Text("\(translation.name) (\(translation.abbreviation))")
                            .font(.headline)
                        Text(translation.notice)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                    .accessibilityElement(children: .combine)
                }
            } header: {
                Text("Bible Translations")
            } footer: {
                Text("Study content, such as key verses and quotations in chapter insights, quotes the King James Version.")
            }
        }
        .navigationTitle("Acknowledgements")
        .navigationBarTitleDisplayMode(.inline)
    }
}
