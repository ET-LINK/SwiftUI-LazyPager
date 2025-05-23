//
//  ContentView.swift
//  LazyPager
//
//  Created by Brian Floersch on 7/2/23.
//

import SwiftUI
import LazyPager

struct Foo: Identifiable {
    let id = UUID()
    var img: String
    let idx: Int
}

struct FullTestView: View {
    var direction: Direction
    @State private var data = [
        Foo(img: "nora1", idx: 0),
        Foo(img: "nora2", idx: 1),
        Foo(img: "nora3", idx: 2),
        Foo(img: "nora4", idx: 3),
        Foo(img: "nora5", idx: 4),
        Foo(img: "nora6", idx: 5),
        Foo(img: "nora1", idx: 6),
        Foo(img: "nora2", idx: 7),
        Foo(img: "nora3", idx: 8),
        Foo(img: "nora4", idx: 9),
        Foo(img: "nora5", idx: 10),
        Foo(img: "nora6", idx: 11),
    ]
    
    @State private var show = false
    @State private var isPresenting = false
    
    var body: some View {
        Button("Open") {
            if !isPresenting {
                isPresenting = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    show = true
                    isPresenting = false
                }
            }
        }
        .fullScreenCover(isPresented: $show) {
            FullScreenContentView(data: $data, show: $show, direction: direction)
        }
    }
}

struct FullScreenContentView: View {
    @Binding var data: [Foo]
    @Binding var show: Bool
    var direction: Direction
    
    @State private var opacity: CGFloat = 1
    @State private var index = 0
    
    var body: some View {
        VStack {
            LazyPager(data: data, page: $index, direction: direction) { element in
                ZStack {
                    Image(element.img)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                    VStack {
                        Text("\(index) \(element.idx) \(data.count - 1)")
                            .foregroundColor(.black)
                            .background(.white)
                    }
                }
            }
            .zoomable(min: 1, max: 5)
            .onDismiss(backgroundOpacity: $opacity) {
                show = false
            }
            .onTap {
                print("tap")
            }
            .shouldLoadMore(on: .lastElement(minus: 2)) {
                data.append(Foo(img: "nora4", idx: data.count))
            }
            .background(.black.opacity(opacity))
            .background(ClearFullScreenBackground())
            .ignoresSafeArea()
            
            VStack {
                HStack(spacing: 30) {
                    Button("-") {
                        index = max(0, index - 1)
                    }
                    VStack(spacing: 10) {
                        Button("append") {
                            data.append(Foo(img: "nora4", idx: data.count))
                        }
                        Button("replace") {
                            if !data.isEmpty {
                                data[0] = Foo(img: "nora4", idx: data.count)
                            }
                        }
                        Button("update") {
                            if !data.isEmpty {
                                data[0].img = "nora5"
                            }
                        }
                    }
                    VStack(spacing: 10) {
                        Button("del first") {
                            if !data.isEmpty {
                                data.removeFirst()
                                index = max(0, index - 1)
                            }
                        }
                        Button("del last") {
                            if !data.isEmpty {
                                data.removeLast()
                            }
                        }
                        Button("jmp") {
                            index = min(10, data.count - 1)
                        }
                    }
                    Button("+") {
                        index = min(data.count - 1, index + 1)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .background(.white)
        }
    }
}

struct FullTestView_Previews: PreviewProvider {
    static var previews: some View {
        FullTestView(direction: .horizontal)
    }
}
