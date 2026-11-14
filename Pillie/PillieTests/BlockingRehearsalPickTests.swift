import FamilyControls
import Testing

@testable import Pillie

struct BlockingRehearsalPickTests {
    private func grid(_ count: Int) -> BlockingRehearsalPickGrid {
        BlockingRehearsalPickGrid(picks: BlockingRehearsalSamplePick.tiles(count: count))
    }

    private func names(_ row: [BlockingRehearsalPickGrid.Tile]) -> [String] {
        row.map { tile in
            switch tile {
            case .pick(.sample(let sample)): sample.name
            case .more(let count): "+\(count)"
            case .pick: "token"
            }
        }
    }

    @Test func `An empty selection draws nothing`() {
        #expect(BlockingRehearsalPick.picks(in: FamilyActivitySelection()).isEmpty)
        #expect(grid(0).rows.isEmpty)
    }

    @Test func `Four picks are one row, categories first, then apps, then sites`() {
        #expect(grid(4).rows.map(names) == [["Social", "Games", "YouTube", "reddit.com"]])
    }

    @Test func `Five picks start a second row`() {
        #expect(grid(5).rows.map(names) == [["Social", "Games", "YouTube", "TikTok"], ["reddit.com"]])
    }

    @Test func `Eight picks fill two rows with no counter`() {
        #expect(grid(8).rows.map(names) == [
            ["Social", "Games", "YouTube", "TikTok"],
            ["Instagram", "Messages", "reddit.com", "news.example.com"],
        ])
    }

    @Test func `More than eight picks end on a tile that counts the rest`() {
        #expect(grid(9).rows.map(names) == [
            ["Social", "Games", "Social 2", "YouTube"],
            ["TikTok", "Instagram", "Messages", "+2"],
        ])
        #expect(grid(20).rows.last?.last == .more(13))
    }
}
