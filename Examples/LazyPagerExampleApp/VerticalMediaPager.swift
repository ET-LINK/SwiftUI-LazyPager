import SwiftUI
import LazyPager

struct VerticalMediaPager: View {
    
    @State private var data = [
        "nora1", "nora2", "nora3", "nora4", "nora5", "nora6",
    ]
    @State private var show = false
    
    var body: some View {
        Button("Open") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                show = true
            }
        }
        .fullScreenCover(isPresented: $show) {
            MediaPagerView(data: $data, show: $show)
        }
    }
}

struct MediaPagerView: View {
    @Binding var data: [String]
    @Binding var show: Bool
    
    var body: some View {
        ZStack {
            LazyPager(data: data, direction: .vertical) { element in
                Image(element)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            }
            .ignoresSafeArea()
            
            VStack(alignment: .leading) {
                Button(action: {
                    show = false
                }) {
                    imgButton("x.circle.fill")
                }
                .padding(.leading)
                HStack {
                    Spacer()
                    VStack(spacing: 30) {
                        Spacer()
                        imgButton("heart.fill")
                        imgButton("text.bubble.fill")
                        imgButton("bookmark.fill")
                        imgButton("arrow.turn.up.right")
                    }
                    .padding(.bottom, 20)
                }
                .padding()
                Spacer()
                HStack {
                    VStack {
                        Text("CatTok")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .font(.title2)
                        Text("Nora is an adorable cat")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    Spacer()
                    Text("😸")
                        .font(.title)
                        .padding(5)
                        .background(.pink.opacity(0.8))
                        .clipShape(Circle())
                }
                .padding()
                .foregroundColor(.white)
                .background(.black.opacity(0.5))
            }
        }
    }
    
    @ViewBuilder
    func imgButton(_ name: String) -> some View {
        Image(systemName: name)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 40, height: 40)
            .foregroundColor(.white.opacity(0.9))
    }
}

#Preview {
    VerticalMediaPager()
}
