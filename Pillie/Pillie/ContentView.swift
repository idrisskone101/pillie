//
//  ContentView.swift
//  Pillie
//
//  Created by Idriss Kone on 2026-02-17.
//

import SwiftUI

struct ContentView: View {
    @AppStorage("onboardingStep") private var onboardingStep = 0
    @Environment(PillStore.self) private var store
    @State private var isLoading = true
    @State private var iconScale: CGFloat = 0.9

    var body: some View {
        ZStack {
            // Main content
            ZStack {
                switch onboardingStep {
            case 0:
                WelcomeView {
                    withAnimation(.easeInOut(duration: 0.4)) {
                        onboardingStep = 1
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .leading),
                    removal: .move(edge: .leading)
                ))

            case 1:
                PainPointPickerView(
                    onBack: {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            onboardingStep = 0
                        }
                    },
                    onContinue: { points in
                        store.painPoints = points
                        withAnimation(.easeInOut(duration: 0.4)) {
                            onboardingStep = 2
                        }
                    }
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing),
                    removal: .move(edge: .trailing)
                ))

            case 2:
                FreePlanView(
                    onBack: {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            onboardingStep = 1
                        }
                    },
                    onContinue: {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            onboardingStep = 3
                        }
                    }
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing),
                    removal: .move(edge: .trailing)
                ))

            case 3:
                PremiumChallengePreviewView(
                    onBack: {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            onboardingStep = 2
                        }
                    },
                    onContinue: {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            onboardingStep = 4
                        }
                    }
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing),
                    removal: .move(edge: .trailing)
                ))

            case 4:
                PremiumPaywallView(
                    onBack: {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            onboardingStep = 3
                        }
                    },
                    onContinue: {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            onboardingStep = 5
                        }
                    },
                    onSkip: {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            onboardingStep = 5
                        }
                    }
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing),
                    removal: .move(edge: .trailing)
                ))

            case 5:
                MethodPickerView(
                    onBack: {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            onboardingStep = 4
                        }
                    },
                    onContinue: { method in
                        store.contraceptiveMethod = method
                        withAnimation(.easeInOut(duration: 0.4)) {
                            onboardingStep = 6
                        }
                    }
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing),
                    removal: .move(edge: .trailing)
                ))

            case 6:
                MethodDetailsView(
                    onBack: {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            onboardingStep = 5
                        }
                    },
                    onContinue: { regimen, customActive, customBreak, cycleDay in
                        store.startNewProtocol(
                            method: store.contraceptiveMethod,
                            regimen: regimen,
                            customActiveDays: customActive,
                            customBreakDays: customBreak,
                            cycleDay: cycleDay,
                            preserveHistory: false
                        )
                        if store.appActivatedDate == nil {
                            store.appActivatedDate = store.today
                        }
                        withAnimation(.easeInOut(duration: 0.4)) {
                            onboardingStep = 7
                        }
                    }
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing),
                    removal: .move(edge: .trailing)
                ))

            case 7:
                TimeSetupView(
                    onBack: {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            onboardingStep = 6
                        }
                    },
                    onContinue: {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            onboardingStep = 8
                        }
                    }
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing),
                    removal: .move(edge: .trailing)
                ))

            case 8:
                AppBlockingSetupView(
                    onBack: {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            onboardingStep = 7
                        }
                    },
                    onContinue: {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            onboardingStep = 9
                        }
                    },
                    onSkip: {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            onboardingStep = 9
                        }
                    }
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing),
                    removal: .move(edge: .trailing)
                ))

            default:
                MainTabView()
                    .transition(.opacity)
            }
            }
            .font(.pillieBody())

            // Splash screen overlay
            if isLoading {
                ZStack {
                    PillieTheme.coral
                        .ignoresSafeArea()

                    Image("SplashIcon")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 120, height: 120)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.6), lineWidth: 3)
                        )
                        .shadow(color: Color.black.opacity(0.15), radius: 20, y: 8)
                        .scaleEffect(iconScale)
                }
                .transition(.opacity)
                .zIndex(1)
            }
        }
        .task {
            withAnimation(.easeOut(duration: 0.5)) {
                iconScale = 1.0
            }
            try? await Task.sleep(for: .seconds(1.5))
            withAnimation(.easeInOut(duration: 0.4)) {
                isLoading = false
            }
        }
    }
}

#Preview {
    ContentView()
        .environment(PillStore.previewStore())
}
