import SwiftUI

/// Full-screen onboarding carousel (Cursor-style: bold icon, clear headline, skimmable bullets).
struct TutorialView: View {
    let onFinish: () -> Void

    @State private var page = 0

    private struct Slide {
        let title: String
        let headline: String
        let bullets: [String]
        let icon: String
    }

    private let slides: [Slide] = [
        Slide(
            title: "Welcome",
            headline: "Juicd is built for short daily sessions.",
            bullets: [
                "Pick props on a shared board, track slips on Dashboard, and climb ranks over time.",
                "Five tabs along the bottom — each does something different; we’ll walk through all of them.",
                "You can skip anytime with Skip — come back from Profile → Replay onboarding when you want a refresher."
            ],
            icon: "bolt.heart.fill"
        ),
        Slide(
            title: "Your “day” (slate)",
            headline: "Juicd uses a slate, not midnight.",
            bullets: [
                "A new slate starts at 6:00 local time — so late-night picks stay on the same slate until then.",
                "Daily Play balance refills on each slate (prototype: up to 100 pts). That refill is wallet-only — it does not add to season score.",
                "Season score comes from wins and bonuses only (see Dashboard)."
            ],
            icon: "sun.horizon.fill"
        ),
        Slide(
            title: "Play",
            headline: "Build singles or parlays from today’s board.",
            bullets: [
                "For You shows every league ribbon that has priced props; league pills filter to one sport.",
                "Tap a tile to open the slip sheet — adjust stake, add legs (parlay), then place.",
                "Juicd boosts (when shown) multiply decimal odds on that tile only.",
                "Sync pulls the latest shared board when Supabase is configured; otherwise the app uses rich local sample odds.",
                "Ranked play uses your Play results — spend wisely; low-stake days are normalized so rank stays fair."
            ],
            icon: "sportscourt.fill"
        ),
        Slide(
            title: "Dashboard",
            headline: "Wallet, slips, and skill rank.",
            bullets: [
                "Play slips: browse today or tap past slate chips — each row shows single vs parlay, stake, combined odds, win/miss, and season pts.",
                "Last ranked match: preview of how you placed in yesterday’s 10-player skill pool (sample until your first resolve).",
                "Daily balance card: spendable points this slate.",
                "Rank tier & ladder: visual tiers from Bronze → Champion — your checkmark shows where you are today.",
                "MMR card explains grouping, fair scaling, placement, smoothing, and tier curves — tap ? on Rank ladder for the deep dive."
            ],
            icon: "rectangle.grid.2x2.fill"
        ),
        Slide(
            title: "Tourney",
            headline: "Closest-pick bracket — different from Play.",
            bullets: [
                "Pick a daily game variant, preview four rounds, then enter before the lock time.",
                "Each round you submit one number; whoever is closer to the simulated outcome advances.",
                "No stake — rewards feed season-style progression and badges.",
                "Separate from Play ranked pools — great when you want structure without spending daily balance."
            ],
            icon: "trophy.fill"
        ),
        Slide(
            title: "Friends",
            headline: "Requests, crew, leaderboard.",
            bullets: [
                "Search by display name to send a request; incoming requests appear at the top.",
                "Leaderboard ranks you against accepted friends by skill (MMR).",
                "Tap someone on the board to see their recent Play form — lightweight rivalry, no stalking."
            ],
            icon: "person.2.fill"
        ),
        Slide(
            title: "Profile",
            headline: "Season footprint & badges.",
            bullets: [
                "Season vs career cards: tap for detailed breakdown (legs, slips, ledger totals).",
                "Tier gradient reflects current ranked tier; expand Ranking details for raw MMR.",
                "Badges unlock from wins and milestones.",
                "Prototype tools (season resets, ads dev toggle, replay tutorial) live at the bottom for builds."
            ],
            icon: "person.crop.circle.fill"
        ),
        Slide(
            title: "You’re set",
            headline: "Explore any tab — help icons reopen these guides.",
            bullets: [
                "Most tabs have a blue info button with deeper tips.",
                "Questions about rank math? Dashboard → Rank ladder → ?",
                "Have fun — short sessions, clear feedback, room to improve."
            ],
            icon: "hand.thumbsup.fill"
        )
    ]

    private var progress: CGFloat {
        guard !slides.isEmpty else { return 0 }
        return CGFloat(page + 1) / CGFloat(slides.count)
    }

    var body: some View {
        ZStack {
            JuicdTheme.canvasDeep.ignoresSafeArea()
            RadialGradient(
                colors: [JuicdTheme.brand.opacity(0.12), Color.clear],
                center: UnitPoint(x: 0.5, y: 0.15),
                startRadius: 10,
                endRadius: 320
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(JuicdTheme.strokeSubtle)
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [JuicdTheme.brand, JuicdTheme.brand2],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: max(8, geo.size.width * progress))
                            }
                        }
                        .frame(height: 5)

                        Text("\(page + 1)/\(slides.count)")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(JuicdTheme.textTertiary)
                            .monospacedDigit()
                            .frame(width: 52, alignment: .trailing)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)

                    HStack {
                        Spacer()
                        Button("Skip") {
                            onFinish()
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(JuicdTheme.textSecondary)
                    }
                    .padding(.horizontal, 20)
                }

                TabView(selection: $page) {
                    ForEach(slides.indices, id: \.self) { i in
                        ScrollView {
                            VStack(spacing: 28) {
                                Text(slides[i].title.uppercased())
                                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                                    .tracking(1.4)
                                    .foregroundStyle(JuicdTheme.textTertiary)

                                ZStack {
                                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                                        .fill(JuicdTheme.cardElevated)
                                        .frame(width: 132, height: 132)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 32, style: .continuous)
                                                .stroke(
                                                    LinearGradient(
                                                        colors: [
                                                            JuicdTheme.brand.opacity(0.95),
                                                            JuicdTheme.brand2.opacity(0.5),
                                                            Color.white.opacity(0.25)
                                                        ],
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    ),
                                                    lineWidth: 2
                                                )
                                        )
                                        .shadow(color: JuicdTheme.brand.opacity(0.2), radius: 24, y: 12)

                                    Image(systemName: slides[i].icon)
                                        .font(.system(size: 56, weight: .bold))
                                        .foregroundStyle(
                                            LinearGradient(
                                                colors: [.white, JuicdTheme.brand.opacity(0.85)],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            )
                                        )
                                }
                                .padding(.top, 8)

                                Text(slides[i].headline)
                                    .font(.system(size: 24, weight: .bold, design: .rounded))
                                    .multilineTextAlignment(.center)
                                    .foregroundStyle(JuicdTheme.textPrimary)
                                    .padding(.horizontal, 8)

                                VStack(alignment: .leading, spacing: 14) {
                                    ForEach(Array(slides[i].bullets.enumerated()), id: \.offset) { _, line in
                                        HStack(alignment: .top, spacing: 12) {
                                            Image(systemName: "circle.fill")
                                                .font(.system(size: 6))
                                                .foregroundStyle(JuicdTheme.brand)
                                                .padding(.top, 7)
                                            Text(line)
                                                .font(.system(size: 16, weight: .medium))
                                                .foregroundStyle(JuicdTheme.textSecondary)
                                                .lineSpacing(5)
                                                .fixedSize(horizontal: false, vertical: true)
                                        }
                                    }
                                }
                                .padding(.horizontal, 24)
                                .padding(.bottom, 24)
                            }
                            .frame(maxWidth: 560)
                            .frame(maxWidth: .infinity)
                        }
                        .tag(i)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))

                VStack(spacing: 12) {
                    if page < slides.count - 1 {
                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                page += 1
                            }
                        } label: {
                            Text("Next")
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(JuicdTheme.brand)
                    } else {
                        Button {
                            onFinish()
                        } label: {
                            Text("Get started")
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(JuicdTheme.brand)
                    }
                }
                .padding(.horizontal, 22)
                .padding(.top, 8)
                .padding(.bottom, 28)
                .background(JuicdTheme.canvasDeep.opacity(0.92))
            }
        }
    }
}
