//
//  MainView.swift
//  Braver Search
//
//  Created by Brenden Bishop on 1/19/25.
//

import SwiftUI
import Combine
import os.log

struct MainView: View {
    @State private var isEnabled: Bool
    @State private var isShowingSupportSheet = false
    @State private var selectedDonationIndex = 0
    @StateObject private var monetization = MonetizationManager.shared
    @StateObject private var store = StoreManager.shared
    private let userDefaults: UserDefaults

    init() {
        let defaults = UserDefaults(suiteName: MonetizationConfig.appGroupIdentifier)!
        self.userDefaults = defaults

        if defaults.object(forKey: "enabled") == nil {
            defaults.set(true, forKey: "enabled")
            defaults.synchronize()
            self._isEnabled = State(initialValue: true)
        } else {
            self._isEnabled = State(initialValue: defaults.bool(forKey: "enabled"))
        }

        os_log(.debug, "Braver Search: Initialized with enabled = %{public}@", String(describing: self._isEnabled.wrappedValue))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        heroCard
                        installationCard
                        reviewCard

                        if monetization.canShowSupport {
                            supportSection
                        }

                        utilityLinks
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 14)
                    .padding(.bottom, 28)
                }
            }
            .navigationTitle("Braver Search")
            .navigationBarTitleDisplayMode(.large)
        }
        .preferredColorScheme(.dark)
        .task {
            MonetizationManager.shared.configureIfNeeded()
            await MonetizationManager.shared.resolveUserState()
            await StoreManager.shared.loadProductsIfNeeded()
        }
        .onReceive(NotificationCenter.default.publisher(for: .openSupportFlow)) { _ in
            guard monetization.canShowSupport else {
                return
            }
            isShowingSupportSheet = true
        }
        .sheet(isPresented: $isShowingSupportSheet) {
            SupportSheetView()
        }
    }

    private var heroCard: some View {
        IOSSurfaceCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center, spacing: 16) {
                    Text("Redirect Search")
                        .font(.system(size: 22, weight: .bold, design: .default))
                        .foregroundStyle(.white)

                    Spacer(minLength: 16)

                    Toggle("", isOn: $isEnabled)
                        .labelsHidden()
                        .tint(IOSTheme.activeGreen)
                        .onChange(of: isEnabled) { newValue in
                            os_log(.debug, "Braver Search: Toggle changed to %{public}@", String(describing: newValue))
                            userDefaults.set(newValue, forKey: "enabled")
                            userDefaults.synchronize()
                            IOSAppAnalytics.track(
                                "redirect_setting_changed",
                                properties: [
                                    "enabled": newValue,
                                    "surface": "ios_app",
                                ]
                            )
                        }
                }

                Text("When enabled, searches from Safari with Google, DuckDuckGo, or Bing will be redirected to Brave Search.")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(IOSTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var installationCard: some View {
        NavigationLink(destination: InstallationGuideView()) {
            IOSSurfaceCard {
                HStack(alignment: .center, spacing: 12) {
                    Text("How to Install")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)

                    Spacer(minLength: 12)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(IOSTheme.chevron)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var reviewCard: some View {
        Link(destination: MonetizationConfig.reviewURL) {
            IOSSurfaceCard {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Rate & Review")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)

                    HStack(alignment: .center, spacing: 14) {
                        Image("RateReview")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 72, height: 72)
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                        Text("Leaving a review motivates me to keep building, and it shows other people that Braver Search works and is worth trying.")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.white)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    IOSOutlineActionLabel(title: "Write a Review")
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var supportSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Give Thanks")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.white)

            Text("If Braver Search has been useful, you can leave an optional tip to help support ongoing maintenance.")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)

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
        }
    }

    private var utilityLinks: some View {
        VStack(alignment: .leading, spacing: 16) {

            Text("Visit the Github page for help, bug reports, source code, and updates.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(IOSTheme.tertiaryText)

            Link(destination: URL(string: "https://github.com/bbishdotdev/braver-search")!) {
                IOSCompactActionCard(title: "Help & Support")
            }
            .buttonStyle(.plain)

            Text(.init("Not affiliated with Brave Software Inc. [About Brave Search](https://search.brave.com)"))
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(IOSTheme.tertiaryText)
                .tint(IOSTheme.accentOrange)
                .padding(.top, 8)
        }
    }
}

enum IOSTheme {
    static let surface = Color(red: 0.12, green: 0.12, blue: 0.15)
    static let surfaceBorder = Color.white.opacity(0.08)
    static let supportStart = Color(red: 0.06, green: 0.12, blue: 0.24)
    static let supportEnd = Color(red: 0.06, green: 0.16, blue: 0.32)
    static let supportBorder = Color(red: 0.93, green: 0.35, blue: 0.16).opacity(0.34)
    static let activeGreen = Color(red: 0.20, green: 0.78, blue: 0.35)
    static let accentOrange = Color(red: 1.0, green: 0.60, blue: 0.18)
    static let secondaryText = Color.white.opacity(0.78)
    static let tertiaryText = Color.white.opacity(0.58)
    static let chevron = Color.white.opacity(0.45)
    static let goldStart = Color(red: 0.96, green: 0.81, blue: 0.47)
    static let goldEnd = Color(red: 0.83, green: 0.60, blue: 0.17)
    static let goldText = Color(red: 0.19, green: 0.10, blue: 0.00)
}

struct IOSSurfaceCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(IOSTheme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(IOSTheme.surfaceBorder, lineWidth: 1)
        )
    }
}

struct IOSCompactActionCard: View {
    let title: String
    var foreground: Color = .white

    var body: some View {
        IOSSurfaceCard {
            Text(title)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(foreground)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 4)
        }
    }
}

struct IOSOutlineActionLabel: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
    }
}

struct IOSDonationCard: View {
    let option: DonationOption
    let priceText: String
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        VStack(alignment: .center, spacing: 18) {
            Text(option.displayName)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

            Image(option.assetName)
                .resizable()
                .scaledToFit()
                .frame(width: 124, height: 124)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))

            Text(option.description)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(IOSTheme.secondaryText)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            Button(action: action) {
                Text("Tip \(priceText)")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(IOSTheme.goldText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [IOSTheme.goldStart, IOSTheme.goldEnd],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    )
                    .shadow(color: IOSTheme.goldEnd.opacity(0.25), radius: 12, y: 8)
            }
            .buttonStyle(.plain)
            .disabled(isDisabled)
            .opacity(isDisabled ? 0.7 : 1)
        }
        .padding(.horizontal, 22)
        .padding(.top, 22)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [IOSTheme.supportStart, IOSTheme.supportEnd],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(IOSTheme.supportBorder, lineWidth: 1)
        )
        .shadow(color: IOSTheme.supportBorder.opacity(0.24), radius: 14)
    }
}

struct IOSDonationCarousel: View {
    @Binding var selectedIndex: Int
    let height: CGFloat
    let isDisabled: Bool
    let priceText: (DonationOption) -> String
    let action: (DonationOption) -> Void

    @State private var isInteracting = false
    @State private var nextAutoAdvanceAt = Date().addingTimeInterval(3)
    @State private var resumeWorkItem: DispatchWorkItem?

    private let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Group {
                    if selectedIndex > 0 {
                        IOSCarouselEdgeIndicator(systemName: "chevron.left")
                    } else {
                        Color.clear
                            .frame(width: 28, height: 28)
                    }
                }

                TabView(selection: $selectedIndex) {
                    ForEach(Array(MonetizationConfig.donationOptions.enumerated()), id: \.element.id) { index, option in
                        IOSDonationCard(
                            option: option,
                            priceText: priceText(option),
                            isDisabled: isDisabled,
                            action: { action(option) }
                        )
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .tag(index)
                    }
                }
                .frame(height: height)
                .tabViewStyle(.page(indexDisplayMode: .never))
                .simultaneousGesture(
                    DragGesture(minimumDistance: 4)
                        .onChanged { _ in
                            beginInteraction()
                        }
                        .onEnded { _ in
                            endInteraction()
                        }
                )
                .onTapGesture {
                    beginInteraction()
                    endInteraction()
                }

                Group {
                    if selectedIndex < MonetizationConfig.donationOptions.count - 1 {
                        IOSCarouselEdgeIndicator(systemName: "chevron.right")
                    } else {
                        Color.clear
                            .frame(width: 28, height: 28)
                    }
                }
            }
            .onReceive(timer) { now in
                guard !isInteracting, now >= nextAutoAdvanceAt, !MonetizationConfig.donationOptions.isEmpty else {
                    return
                }

                withAnimation(.easeInOut(duration: 0.28)) {
                    selectedIndex = (selectedIndex + 1) % MonetizationConfig.donationOptions.count
                }
                nextAutoAdvanceAt = now.addingTimeInterval(3)
            }
            .onChange(of: selectedIndex) { _ in
                guard !isInteracting else {
                    return
                }
                nextAutoAdvanceAt = Date().addingTimeInterval(3)
            }

            HStack(spacing: 10) {
                ForEach(Array(MonetizationConfig.donationOptions.indices), id: \.self) { index in
                    Circle()
                        .fill(index == selectedIndex ? Color.white.opacity(0.92) : Color.white.opacity(0.28))
                        .frame(width: 10, height: 10)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .onDisappear {
            resumeWorkItem?.cancel()
        }
    }

    private func beginInteraction() {
        isInteracting = true
        resumeWorkItem?.cancel()
    }

    private func endInteraction() {
        resumeWorkItem?.cancel()
        let workItem = DispatchWorkItem {
            isInteracting = false
            nextAutoAdvanceAt = Date().addingTimeInterval(3)
        }
        resumeWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: workItem)
    }
}

struct IOSCarouselEdgeIndicator: View {
    let systemName: String

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(Color.white.opacity(0.55))
            .frame(width: 28, height: 28)
            .background(Color.black.opacity(0.18))
            .clipShape(Circle())
    }
}

#Preview {
    MainView()
}
