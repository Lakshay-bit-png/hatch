import SwiftUI
import Observation

enum GameKind: String, CaseIterable, Identifiable {
    case twenty48, minesweeper, snake, memory

    var id: String { rawValue }

    var label: String {
        switch self {
        case .twenty48: return "2048"
        case .minesweeper: return "Mines"
        case .snake: return "Snake"
        case .memory: return "Memory"
        }
    }
}

/// Which game the tab is showing. Shared so the panel's key handler knows where to
/// send the arrow keys.
@Observable
@MainActor
final class GamesState {
    static let shared = GamesState()

    private let key = "game.selected"

    var selected: GameKind {
        didSet { UserDefaults.standard.set(selected.rawValue, forKey: key) }
    }

    private init() {
        let stored = UserDefaults.standard.string(forKey: key) ?? ""
        selected = GameKind(rawValue: stored) ?? .twenty48
    }
}

struct GamesView: View {
    @Bindable var state: GamesState

    @Environment(\.palette) private var palette

    var body: some View {
        VStack(spacing: 8) {
            picker

            switch state.selected {
            case .twenty48:
                Game2048View(game: Game2048.shared)
            case .minesweeper:
                MinesweeperView(game: Minesweeper.shared)
            case .snake:
                SnakeView(game: SnakeGame.shared)
            case .memory:
                MemoryView(game: MemoryGame.shared)
            }
        }
        .padding(.top, 7)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var picker: some View {
        HStack(spacing: 2) {
            ForEach(GameKind.allCases) { kind in
                Button {
                    withAnimation(Motion.swap) { state.selected = kind }
                } label: {
                    Text(kind.label)
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(state.selected == kind ? palette.background : palette.muted)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 12)
                        .background(Capsule().fill(state.selected == kind ? palette.contrast : .clear))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(Capsule().fill(palette.fill))
    }
}
