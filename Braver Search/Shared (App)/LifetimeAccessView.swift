import SwiftUI

private enum AccessPalette {
    static let orange = Color(red: 1, green: 0.60, blue: 0.18)
    static let gold = Color(red: 0.96, green: 0.81, blue: 0.47)
    static let goldEnd = Color(red: 0.83, green: 0.60, blue: 0.17)
    static let ink = Color(red: 0.19, green: 0.10, blue: 0)
}

/// Trial introduction and lifetime pricing are separate pages in the same sheet.
struct LifetimeAccessView: View {
    private enum Page { case trial, lifetime, status }
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var monetization = MonetizationManager.shared
    @ObservedObject private var store = StoreManager.shared
    @State private var selection = Double(MonetizationConfig.suggestedLifetimeIndex)
    @State private var choseLifetime = false
    private var maximumTier: Double { Double(MonetizationConfig.lifetimeOptions.count - 1) }
    private var index: Int { min(Int(maximumTier), max(0, Int(selection.rounded()))) }
    private var option: DonationOption { MonetizationConfig.lifetimeOptions[index] }
    private var access: AccessDecision { monetization.access }
    private var busy: Bool { store.activePurchaseProductID != nil || store.isRestoring }
    private var page: Page {
        switch access.state {
        case .eligible: return choseLifetime ? .lifetime : .trial
        case .trial, .expired: return .lifetime
        default: return .status
        }
    }
    private var price: String {
        if let product = store.productsByID[option.id] { return product.displayPrice }
        #if DEBUG
        if AccessStore.previewRecord() != nil { return option.fallbackPrice }
        #endif
        return "—"
    }

    var body: some View {
        ZStack {
            backdrop
            ScrollView {
                VStack(spacing: page == .lifetime ? 16 : 24) {
                    if page == .trial {
                        lion("TipCheers", size: 156)
                        heading("Try it in Safari", detail: "14 days of Safari search redirects.")
                        Label("No automatic charge", systemImage: "checkmark.circle")
                            .font(.subheadline).foregroundStyle(AccessPalette.gold)
                    } else if page == .lifetime {
                        if access.state == .expired {
                            Text("Your free trial has ended.").font(.caption).foregroundStyle(.white.opacity(0.65))
                        } else if let expires = access.expiresAt, access.state == .trial {
                            Text("Your trial is free until \(expires.formatted(date: .abbreviated, time: .omitted))")
                                .font(.caption).foregroundStyle(AccessPalette.gold)
                        }
                        pricePicker
                    } else {
                        lion(access.state == .unknown ? "TipCheers" : "TipMax", size: 156)
                        heading(access.title, detail: access.message)
                    }
                }
                .padding(24).padding(.top, page == .lifetime ? 0 : 28)
                .frame(maxWidth: 480).frame(maxWidth: .infinity)
            }
            .safeAreaInset(edge: .top) { navigationBar }
            .safeAreaInset(edge: .bottom) { actions }
        }
        .foregroundStyle(.white).preferredColorScheme(.dark)
        #if os(macOS)
        .frame(width: 480, height: 760)
        #endif
        .task {
            #if DEBUG
            let args = ProcessInfo.processInfo.arguments
            if let at = args.firstIndex(of: "-monetization-tier"), args.indices.contains(at + 1), let value = Double(args[at + 1]) { selection = min(maximumTier, max(0, value)) }
            #endif
            recordPageView()
            await store.loadProductsIfNeeded()
        }
        .onChange(of: page) { _ in
            // Activating a trial closes this sheet; it isn't a visit to pricing.
            if access.state != .trial || choseLifetime { recordPageView() }
        }
        .onChange(of: access.state) { state in
            // Also handles a trial approved later through Transaction.updates.
            if state == .trial && !choseLifetime { dismiss() }
        }
        .onChange(of: index) { _ in
            DurableAnalytics.shared.capture("lifetime_tier_selected", properties: ["product_id": option.id])
        }
    }

    private var backdrop: some View {
        ZStack {
            Color.black
            if page == .trial {
                LinearGradient(
                    colors: [Color(red: 0.12, green: 0.10, blue: 0.09), .black],
                    startPoint: .top, endPoint: .bottom)
                RadialGradient(
                    colors: [AccessPalette.orange.opacity(0.14), .clear],
                    center: UnitPoint(x: 0.5, y: 0.27), startRadius: 0, endRadius: 290)
            }
        }.ignoresSafeArea()
    }

    private var navigationBar: some View {
        HStack {
            if page == .lifetime && access.state == .eligible {
                Button { choseLifetime = false } label: {
                    Label("Back", systemImage: "chevron.left").font(.subheadline)
                        .frame(minHeight: 44)
                }.buttonStyle(.plain).foregroundStyle(AccessPalette.gold).disabled(busy)
                    .accessibilityIdentifier("back-to-trial")
            } else {
                Text("✦  BRAVER SEARCH")
                    .font(.system(size: 11, weight: .bold, design: .rounded)).tracking(2)
                    .foregroundStyle(AccessPalette.gold)
            }
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark").font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7)).frame(width: 44, height: 44)
                    .background(.white.opacity(0.08), in: Circle())
            }.buttonStyle(.plain).accessibilityLabel("Close")
        }.padding(.horizontal, 24).padding(.top, 12).padding(.bottom, 4).background(page == .trial ? Color.clear : Color.black)
    }

    private var actions: some View {
        VStack(spacing: 8) {
            if let message = store.purchaseMessage, page != .status {
                Text(message).font(.callout).multilineTextAlignment(.center)
                    .foregroundStyle(AccessPalette.gold).accessibilityIdentifier("purchase-result")
            }
            if page == .trial {
                availabilityMessage(for: AccessConfiguration.trialID)
                primaryButton("Start free trial", id: "start-free-trial", disabled: !store.isAvailable(AccessConfiguration.trialID)) {
                    await store.purchase(id: AccessConfiguration.trialID)
                    if monetization.access.state == .trial { dismiss() }
                }
                Text("Buy once to continue after the trial.")
                    .font(.caption).foregroundStyle(.white.opacity(0.6)).multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Button { choseLifetime = true } label: {
                    HStack(spacing: 6) {
                        Text("See lifetime prices").underline()
                        Image(systemName: "arrow.right").font(.caption)
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.85)).frame(minHeight: 44)
                }
                    .buttonStyle(.plain)
                    .disabled(busy).accessibilityIdentifier("see-lifetime-prices")
            } else if page == .lifetime {
                availabilityMessage(for: option.id)
                Text("Every price unlocks the full app.")
                    .font(.caption).foregroundStyle(.white.opacity(0.65))
                primaryButton("Unlock forever · \(price)", id: "lifetime-purchase", disabled: !store.isAvailable(option.id)) {
                    await store.purchase(id: option.id)
                }
                Text("One purchase for iPhone, iPad & Mac.")
                    .font(.caption).foregroundStyle(.white.opacity(0.6))
            } else if access.state == .unknown {
                if let message = store.purchaseMessage {
                    Text(message).font(.callout).foregroundStyle(AccessPalette.gold).multilineTextAlignment(.center)
                }
                primaryButton("Check my access", id: "check-access", disabled: false) { await store.restore() }
            } else {
                primaryButton("Done", id: "access-done", disabled: false) { dismiss() }
            }
            if access.state != .unknown {
                Divider().overlay(.white.opacity(0.08)).padding(.bottom, 4)
                Button { Task { await store.restore() } } label: {
                    HStack(spacing: 8) {
                        if store.isRestoring {
                            ProgressView().tint(.white.opacity(0.7))
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                        Text(store.isRestoring ? "Checking purchases…" : "Restore purchases")
                    }
                    .font(.subheadline.weight(.medium)).foregroundStyle(.white.opacity(0.7))
                    .padding(.horizontal, 16).frame(minHeight: 44)
                    .background(.white.opacity(0.04), in: Capsule())
                    .overlay(Capsule().stroke(.white.opacity(0.18), lineWidth: 1))
                }
                .buttonStyle(.plain).disabled(busy).opacity(busy ? 0.6 : 1)
                .accessibilityIdentifier("restore-purchases")
            }
            #if DEBUG
            if let test = AccessStore.localTest() {
                Text("Sandbox · \(test.cohort.rawValue) user" + (test.elapsedDays == 0 ? "" : " · +\(test.elapsedDays) days"))
                    .font(.caption2).foregroundStyle(.white.opacity(0.5))
            }
            #endif
        }
        .padding(.horizontal, 24).padding(.top, 12).padding(.bottom, 12)
        .frame(maxWidth: 480).frame(maxWidth: .infinity).background(.black)
    }

    private var pricePicker: some View {
        VStack(spacing: 14) {
            lion(option.assetName, size: 120)
                .id(option.id).transition(.opacity)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: index)
            // All tier labels participate in sizing, even with larger text settings.
            ZStack(alignment: .top) {
                ForEach(MonetizationConfig.lifetimeOptions) { tier in
                    VStack(spacing: 6) {
                        Text(tier.displayName).font(.title3.bold())
                        Text(tier.description).font(.subheadline).foregroundStyle(.white.opacity(0.65))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .opacity(tier.id == option.id ? 1 : 0)
                    .accessibilityHidden(tier.id != option.id)
                }
            }.multilineTextAlignment(.center)
            VStack(spacing: 3) {
                Text(price).font(.system(size: 32, weight: .bold, design: .rounded))
                    .monospacedDigit().lineLimit(1).minimumScaleFactor(0.65)
                Text("Suggested price").font(.caption.weight(.medium)).foregroundStyle(AccessPalette.gold)
                    .opacity(option.id == AccessConfiguration.suggestedLifetimeID ? 1 : 0)
                    .accessibilityHidden(option.id != AccessConfiguration.suggestedLifetimeID)
            }.accessibilityElement(children: .combine)
            VStack(spacing: 8) {
                Group {
                    #if os(iOS)
                    QuietPriceSlider(value: $selection, maximum: maximumTier)
                    #else
                    Slider(value: $selection, in: 0...maximumTier, step: 1).tint(AccessPalette.gold)
                    #endif
                }
                .accessibilityLabel("Choose your lifetime price")
                .accessibilityValue("\(option.displayName), \(price), one time")
                .accessibilityIdentifier("lifetime-price-slider").disabled(busy)
                HStack {
                    Text("A little love")
                    Spacer()
                    Text("A lot of love")
                }.font(.caption).foregroundStyle(.white.opacity(0.55))
            }
        }
        .padding(20).frame(maxWidth: .infinity)
        .background(LinearGradient(colors: [Color(red: 0.20, green: 0.13, blue: 0.11), Color(red: 0.105, green: 0.095, blue: 0.12)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 28))
        .overlay(RoundedRectangle(cornerRadius: 28).stroke(AccessPalette.gold.opacity(0.20), lineWidth: 1))
    }

    @ViewBuilder private func availabilityMessage(for id: String) -> some View {
        if !store.isAvailable(id) && !store.isLoadingProducts {
            Text("This option isn’t available from the App Store yet.")
                .font(.caption).foregroundStyle(.white.opacity(0.6)).multilineTextAlignment(.center)
            Button("Retry App Store") { Task { await store.loadProductsIfNeeded() } }
                .buttonStyle(.plain).font(.caption).foregroundStyle(AccessPalette.gold).disabled(busy)
        }
    }

    private func heading(_ title: String, detail: String) -> some View {
        VStack(spacing: 10) {
            Text(title).font(.system(page == .lifetime ? .title : .largeTitle, design: .rounded, weight: .bold))
            Text(detail).font(.body).foregroundStyle(.white.opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)
        }.multilineTextAlignment(.center)
    }

    private func lion(_ asset: String, size: CGFloat) -> some View {
        Image(asset).resizable().scaledToFit().frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
            .shadow(color: AccessPalette.orange.opacity(0.12), radius: 28, y: 8)
            .accessibilityHidden(true)
    }

    private func recordPageView() {
        let event = page == .trial ? "trial_offer_viewed" : page == .lifetime ? "lifetime_screen_viewed" : "access_status_viewed"
        DurableAnalytics.shared.capture(event, properties: ["access_state": access.state.rawValue])
    }

    private func primaryButton(_ title: String, id: String, disabled: Bool, action: @escaping () async -> Void) -> some View {
        Button { Task { await action() } } label: {
            HStack {
                Spacer()
                if busy { ProgressView().tint(AccessPalette.ink) }
                Text(title).font(.headline)
                Spacer()
            }.padding(.vertical, 16).foregroundStyle(AccessPalette.ink)
                .background(LinearGradient(colors: [AccessPalette.gold, AccessPalette.goldEnd], startPoint: .top, endPoint: .bottom), in: RoundedRectangle(cornerRadius: 18))
        }.buttonStyle(.plain).disabled(busy || disabled).opacity(busy || disabled ? 0.75 : 1)
            .accessibilityIdentifier(id)
    }
}

#if os(iOS)
/// A continuous thumb with discrete prices, without the system slider's endpoint feedback.
/// VoiceOver can still move between the available tiers with its adjustable-control gesture.
private struct QuietPriceSlider: View {
    @Binding var value: Double
    let maximum: Double
    @Environment(\.layoutDirection) private var layoutDirection
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        GeometryReader { geometry in
            let width = max(1, geometry.size.width - 28)
            let progress = min(1, max(0, value / max(1, maximum)))
            let position = layoutDirection == .rightToLeft ? 1 - progress : progress
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.18)).frame(height: 5)
                Capsule().fill(AccessPalette.gold)
                    .frame(width: width * progress, height: 5)
                    .offset(x: layoutDirection == .rightToLeft ? width * (1 - progress) : 0)
                Circle().fill(AccessPalette.gold)
                    .frame(width: 28, height: 28)
                    .shadow(color: .black.opacity(0.25), radius: 3, y: 2)
                    .offset(x: width * position - 14)
            }
            .frame(width: width, height: 44)
            .padding(.horizontal, 14)
            // Track math uses physical coordinates; explicitly handle RTL above.
            .environment(\.layoutDirection, .leftToRight)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { drag in
                    guard isEnabled else { return }
                    let position = min(1, max(0, (drag.location.x - 14) / width))
                    value = maximum * (layoutDirection == .rightToLeft ? 1 - position : position)
                }
                .onEnded { _ in if isEnabled { value = value.rounded() } })
        }
        .frame(height: 44)
        .accessibilityElement(children: .ignore)
        .accessibilityAdjustableAction { direction in
            guard isEnabled else { return }
            switch direction {
            case .increment: value = min(maximum, value.rounded() + 1)
            case .decrement: value = max(0, value.rounded() - 1)
            @unknown default: break
            }
        }
    }
}
#endif

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
