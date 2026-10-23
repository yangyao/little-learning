import SwiftUI
#if canImport(LearningCore)
import LearningCore
#endif

struct FruitGameView: View {
    @EnvironmentObject private var library: CollectionStore
    private var session: FruitSession { library.progress.fruits }
    var body: some View {
        ChallengeHeading(subtitle:library.positionLabel(.sorting),title:"四颗同款，装进同一罐")
        Text("点果罐，移动顶端水果；只能放同款或空罐。")
            .woodText(Wood.Typography.support).foregroundStyle(Wood.Palette.textSecondary)
        LazyVGrid(columns:[GridItem(.adaptive(minimum:72),spacing:12)],spacing:16) {
            ForEach(session.jars.indices,id:\.self) { jar in
                Button { library.progress.fruits.tap(jar) } label: {
                    VStack(spacing:8) {
                        Text("\(jar+1)").woodText(Wood.Typography.support)
                        VStack(spacing:4) {
                            ForEach(Array((0..<4).reversed()),id:\.self) { depth in
                                Text(depth < session.jars[jar].count ? FruitSession.fruits[session.jars[jar][depth]] : "·")
                                    .font(.system(size:30)).frame(height:36).frame(maxWidth:.infinity)
                                    .foregroundStyle(Wood.Palette.textSecondary)
                            }
                        }.padding(.vertical,12).padding(.horizontal,8)
                            .background(session.selected == jar ? Wood.Palette.successBackground : Wood.Palette.surface,in:UnevenRoundedRectangle(topLeadingRadius:8,bottomLeadingRadius:24,bottomTrailingRadius:24,topTrailingRadius:8))
                            .overlay {
                                UnevenRoundedRectangle(topLeadingRadius:8,bottomLeadingRadius:24,bottomTrailingRadius:24,topTrailingRadius:8)
                                    .strokeBorder(session.selected == jar ? Wood.Palette.slotStroke : Wood.Palette.borderDecorative,lineWidth:session.selected == jar ? 3 : 2)
                            }
                    }
                }.buttonStyle(IllustrationButtonStyle()).disabled(session.isSolved)
                    .accessibilityLabel("果罐 \(jar+1)，\(session.jars[jar].isEmpty ? "空罐" : session.jars[jar].reversed().map{FruitSession.names[$0]}.joined(separator:"、"))\(session.selected == jar ? "，已选取" : "")")
                    .accessibilityIdentifier("sorting.jar.\(jar)")
            }
        }
    }
}
