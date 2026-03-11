import SwiftUI

struct SupportSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedDonationIndex = 0
    @ObservedObject private var monetization = MonetizationManager.shared
    @ObservedObject private var store = StoreManager.shared

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Give Thanks")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(.white)

                        Text("If Braver Search has been useful, you can leave an optional tip to help support ongoing maintenance.")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(IOSTheme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)

                        if monetization.canShowSupport {
                            IOSDonationCarousel(
                                selectedIndex: $selectedDonationIndex,
                                height: 380,
                                isDisabled: store.activePurchaseProductID != nil,
                                priceText: { option in
                                    store.priceText(for: option)
                                },
                                action: { option in
                                    Task {
                                        await store.purchase(option: option)
                                    }
                                }
                            )
                        }

                        if monetization.hasDonated {
                            Text("Thanks again for supporting Braver Search.")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(IOSTheme.secondaryText)
                        }

                        if let purchaseMessage = store.purchaseMessage {
                            Text(purchaseMessage)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(IOSTheme.secondaryText)
                        }

                        Text("Optional tips are available only for users who downloaded Braver Search before it became a paid app.")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(IOSTheme.tertiaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 28)
                }
            }
            .navigationTitle("Support Braver Search")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
