import SwiftUI

struct SupportSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var monetization = MonetizationManager.shared
    @ObservedObject private var store = StoreManager.shared

    var body: some View {
        NavigationView {
            List {
                Section {
                    Text("If Braver Search has been useful, you can support ongoing maintenance with an optional tip.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if monetization.canShowSupport {
                    donationButtons
                }
            }
            .navigationTitle("Support Braver Search")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var donationButtons: some View {
        Section {
            ForEach(MonetizationConfig.donationOptions) { option in
                Button {
                    Task {
                        await store.purchase(option: option)
                    }
                } label: {
                    HStack(spacing: 12) {
                        Image(option.assetName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 56, height: 56)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                        VStack(alignment: .leading, spacing: 4) {
                            Text(option.displayName)
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Text(option.description)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.leading)
                            Text(store.priceText(for: option))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
                .disabled(store.activePurchaseProductID != nil)
            }

            if monetization.hasDonated {
                Text("Thanks again for supporting Braver Search.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let purchaseMessage = store.purchaseMessage {
                Text(purchaseMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
