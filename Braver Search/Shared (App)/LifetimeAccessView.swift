import SwiftUI

private enum AccessPalette {
    static let orange = Color(red: 1, green: 0.60, blue: 0.18)
    static let gold = Color(red: 0.96, green: 0.81, blue: 0.47)
    static let goldEnd = Color(red: 0.83, green: 0.60, blue: 0.17)
    static let ink = Color(red: 0.19, green: 0.10, blue: 0)
}

/// Shared native price picker on iPhone, iPad, and Mac. The artwork and gold CTA match Give Thanks.
struct LifetimeAccessView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var monetization = MonetizationManager.shared
    @ObservedObject private var store = StoreManager.shared
    @State private var selection = 1.0
    private var index: Int { min(4, max(0, Int(selection.rounded()))) }
    private var option: DonationOption { MonetizationConfig.lifetimeOptions[index] }
    private var access: AccessDecision { monetization.access }
    private var unlocked: Bool { [.grandfathered, .lifetime, .free].contains(access.state) }
    private var busy: Bool { store.activePurchaseProductID != nil || store.isRestoring }
    private var price: String {
        if let product = store.productsByID[option.id] { return product.displayPrice }
        #if DEBUG
        if AccessStore.previewRecord() != nil { return option.fallbackPrice }
        #endif
        return "—"
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 18) {
                    VStack(spacing: 10) {
                        Text(access.title).font(.system(.largeTitle, design: .rounded, weight: .bold))
                        Text(access.message).font(.body).foregroundStyle(.white.opacity(0.7))
                            .fixedSize(horizontal: false, vertical: true)
                    }.multilineTextAlignment(.center)

                    VStack(spacing: 10) {
                        if access.state == .eligible {
                            primaryButton("Start my 14 free days", id: "start-free-trial", disabled: !store.isAvailable(AccessConfiguration.trialID)) {
                                await store.purchase(id: AccessConfiguration.trialID)
                            }
                            Text("Free trial. No charge or hold. No automatic renewal.\nAfter 14 days, redirects pause until you choose a one-time purchase.")
                                .font(.caption).foregroundStyle(.white.opacity(0.6)).multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    VStack(spacing: 14) {
                        Image(unlocked ? "TipMax" : option.assetName)
                            .resizable().scaledToFit().frame(width: 112, height: 112)
                            .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
                            .shadow(color: AccessPalette.orange.opacity(0.12), radius: 28, y: 8)
                            .id(unlocked ? "unlocked" : option.id)
                            .transition(.opacity)
                            .accessibilityHidden(true)
                        if unlocked {
                            Label(access.state == .grandfathered ? "Early supporter · Free forever" : "Lifetime access", systemImage: "checkmark.seal.fill")
                                .font(.headline).foregroundStyle(AccessPalette.gold)
                        } else {
                            VStack(spacing: 6) {
                                Text(option.displayName).font(.title3.bold())
                                Text(option.description).font(.subheadline).foregroundStyle(.white.opacity(0.65))
                                    .fixedSize(horizontal: false, vertical: true)
                            }.multilineTextAlignment(.center)
                            VStack(spacing: 3) {
                                Text(price).font(.system(size: 36, weight: .bold, design: .rounded)).contentTransition(.numericText())
                                Text(index == 1 ? "Suggested · One time" : "One time · Same full app")
                                    .font(.caption.weight(.medium)).foregroundStyle(AccessPalette.gold)
                            }.accessibilityElement(children: .combine)
                            VStack(spacing: 8) {
                                Slider(value: $selection, in: 0...4, step: 1)
                                    .tint(AccessPalette.gold)
                                    .accessibilityLabel("Choose your lifetime price")
                                    .accessibilityValue("\(option.displayName), \(price), one time")
                                    .accessibilityIdentifier("lifetime-price-slider")
                                HStack {
                                    Text("A little love")
                                    Spacer()
                                    Text("A lot of love")
                                }.font(.caption).foregroundStyle(.white.opacity(0.55))
                            }
                            Text("Every price unlocks every redirect.")
                                .font(.subheadline.weight(.medium)).foregroundStyle(.white.opacity(0.85))
                        }
                    }
                    .padding(20).frame(maxWidth: .infinity)
                    .background(LinearGradient(colors: [Color(red: 0.20, green: 0.13, blue: 0.11), Color(red: 0.105, green: 0.095, blue: 0.12)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 28))
                    .overlay(RoundedRectangle(cornerRadius: 28).stroke(AccessPalette.gold.opacity(0.20), lineWidth: 1))
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: index)

                    VStack(spacing: 12) {
                        if !unlocked && access.state != .unknown {
                            if access.state == .eligible {
                                Button("Or unlock now · \(price)") { Task { await store.purchase(id: option.id) } }
                                    .buttonStyle(.plain).foregroundStyle(AccessPalette.gold).padding(8)
                                    .disabled(busy || !store.isAvailable(option.id))
                            } else {
                                primaryButton("Unlock forever · \(price)", id: "lifetime-purchase", disabled: !store.isAvailable(option.id)) {
                                    await store.purchase(id: option.id)
                                }
                            }
                            if (!store.isAvailable(option.id) || (access.state == .eligible && !store.isAvailable(AccessConfiguration.trialID))) && !store.isLoadingProducts {
                                Text("The App Store hasn’t made this option available yet.")
                                    .font(.caption).foregroundStyle(.white.opacity(0.55)).multilineTextAlignment(.center)
                                Button("Retry App Store") { Task { await store.loadProductsIfNeeded() } }
                                    .buttonStyle(.plain).font(.caption).foregroundStyle(AccessPalette.gold)
                            }
                        }
                        if let expires = access.expiresAt, access.state == .trial {
                            Text("Free until \(expires.formatted(date: .abbreviated, time: .omitted))")
                                .font(.caption).foregroundStyle(AccessPalette.gold)
                        }
                        if let message = store.purchaseMessage {
                            Text(message).font(.callout).multilineTextAlignment(.center)
                                .foregroundStyle(AccessPalette.gold).accessibilityIdentifier("purchase-result")
                        }
                        Button(store.isRestoring ? "Checking purchases…" : "Restore purchases") { Task { await store.restore() } }
                            .buttonStyle(.plain).font(.subheadline).foregroundStyle(.white.opacity(0.7)).padding(8).disabled(busy)
                        Text(access.state == .grandfathered ? "Your existing access stays free.\nTips are always optional." : "One purchase for your iPhone, iPad & Mac.\nSetup help is always here.")
                            .font(.caption).foregroundStyle(.white.opacity(0.45)).multilineTextAlignment(.center)
                    }
                }.padding(24).frame(maxWidth: 480).frame(maxWidth: .infinity)
            }
            .safeAreaInset(edge: .top) {
                HStack {
                    Text("✦  BRAVER SEARCH")
                        .font(.system(size: 11, weight: .bold, design: .rounded)).tracking(2)
                        .foregroundStyle(AccessPalette.gold)
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.7)).frame(width: 44, height: 44)
                            .background(.white.opacity(0.08), in: Circle())
                    }.buttonStyle(.plain).accessibilityLabel("Close")
                }.padding(.horizontal, 24).padding(.top, 12).padding(.bottom, 4).background(.black)
            }
        }
        .foregroundStyle(.white).preferredColorScheme(.dark)
        #if os(macOS)
        .frame(width: 480, height: 760)
        #endif
        .task {
            #if DEBUG
            let args = ProcessInfo.processInfo.arguments
            if let at = args.firstIndex(of: "-monetization-tier"), args.indices.contains(at + 1), let value = Double(args[at + 1]) { selection = min(4, max(0, value)) }
            #endif
            await store.loadProductsIfNeeded()
            DurableAnalytics.shared.capture("lifetime_screen_viewed", properties: ["access_state": access.state.rawValue])
        }
        .onChange(of: index) { _ in
            DurableAnalytics.shared.capture("lifetime_tier_selected", properties: ["product_id": option.id])
        }
    }

    private func primaryButton(_ title: String, id: String, disabled: Bool, action: @escaping () async -> Void) -> some View {
        Button { Task { await action() } } label: {
            HStack {
                Spacer()
                if store.activePurchaseProductID != nil { ProgressView().tint(AccessPalette.ink) }
                Text(title).font(.headline)
                Spacer()
            }.padding(.vertical, 16).foregroundStyle(AccessPalette.ink)
                .background(LinearGradient(colors: [AccessPalette.gold, AccessPalette.goldEnd], startPoint: .top, endPoint: .bottom), in: RoundedRectangle(cornerRadius: 18))
        }.buttonStyle(.plain).disabled(busy || disabled).opacity(busy || disabled ? 0.75 : 1)
            .accessibilityIdentifier(id)
    }
}

struct AccessSummaryButton: View {
    @ObservedObject private var monetization = MonetizationManager.shared
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: monetization.access.allowsRedirects ? "sparkles" : "heart.fill")
                    .foregroundStyle(AccessPalette.gold)
                VStack(alignment: .leading, spacing: 3) {
                    Text(monetization.access.title).font(.subheadline.bold()).foregroundStyle(.white)
                    Text(subtitle).font(.caption).foregroundStyle(.white.opacity(0.6))
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(.white.opacity(0.4))
            }.padding(16).background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 18))
        }.buttonStyle(.plain).accessibilityIdentifier("access-summary")
    }
    private var subtitle: String {
        if let expires = monetization.access.expiresAt, monetization.access.state == .trial {
            return "Free until \(expires.formatted(date: .abbreviated, time: .omitted))"
        }
        switch monetization.access.state {
        case .grandfathered: return "Early supporter. Free forever."
        case .lifetime: return "Lifetime access. Thank you."
        case .expired: return "Trial complete. Choose your lifetime price."
        case .unknown: return "Restore purchases to check your access."
        default: return "14 free days. Then choose your price."
        }
    }
}
