//
//  PagerView.swift
//  
//
//  Created by Brian Floersch on 7/8/23.
//

import Foundation
import UIKit
import SwiftUI

protocol ViewLoader: AnyObject {
    
    associatedtype Element
    associatedtype Content: View
    
    var dataCount: Int { get }
    
    func loadView(at: Int) -> ZoomableView<Element, Content>?
    func updateHostedView(for zoomableView: ZoomableView<Element, Content>)
}

class PagerView<Element, Loader: ViewLoader, Content: View>: UIScrollView, UIScrollViewDelegate where Loader.Element == Element, Loader.Content == Content {
    
    var isFirstLoad = false
    var loadedViews = [ZoomableView<Element, Content>]()
    var config: Config
    weak var viewLoader: Loader?
    
    var isRotating = false
    var page: Binding<Int>
    
    var currentIndex: Int = 0 {
        didSet {
            LazyPagerLogger.log("PagerView.currentIndex didSet - oldValue=\(oldValue) newValue=\(currentIndex)")
            computeViewState()
            loadMoreIfNeeded()
        }
    }
    
    init(page: Binding<Int>, config: Config) {
        self.currentIndex = page.wrappedValue
        self.page = page
        self.config = config
        super.init(frame: .zero)
        LazyPagerLogger.log("PagerView.init - initialIndex=\(currentIndex) direction=\(config.direction) preloadAmount=\(config.preloadAmount)")
        
        showsVerticalScrollIndicator = false
        showsHorizontalScrollIndicator = false
        backgroundColor = .clear
        isPagingEnabled = true
        delegate = self
        contentInsetAdjustmentBehavior = .never
    }
    
    
    required init?(coder: NSCoder) {
        fatalError("Not implemented")
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        if !isFirstLoad {
            LazyPagerLogger.log("PagerView.layoutSubviews firstLoad - frame=\(frame.size)")
            ensureCurrentPage()
            isFirstLoad = true
        } else if isRotating {
            LazyPagerLogger.log("PagerView.layoutSubviews rotating - frame=\(frame.size)")
            ensureCurrentPage()
        }
    }
    
    func computeViewState() {
        LazyPagerLogger.log("PagerView.computeViewState start - currentIndex=\(currentIndex) loadedCount=\(loadedViews.count)")
        delegate = nil
        DispatchQueue.main.async {
            self.delegate = self
        }
        
        // 获取数据总数并做空集防御
        let total = viewLoader?.dataCount ?? 0
        guard total > 0 else {
            // 数据为空时清空所有视图，避免非法区间与无效子视图
            loadedViews.forEach { $0.removeFromSuperview() }
            loadedViews.removeAll()
            LazyPagerLogger.log("PagerView.computeViewState cleared - dataEmpty")
            return
        }
        
        // 将 currentIndex clamp 到有效范围，避免区间越界
        let safeCurrent = max(0, min(currentIndex, total - 1))
        
        if subviews.isEmpty {
            LazyPagerLogger.log("PagerView.computeViewState preparingInitialLoad - safeCurrent=\(safeCurrent) total=\(total)")
            // 计算预加载范围（修正 endIndex 为 total - 1）
            let startIndex = max(0, safeCurrent - config.preloadAmount)
            let endIndex = min(total - 1, safeCurrent + config.preloadAmount)
            
            // 向前加载指定数量（仅在区间有序时）
            if startIndex < safeCurrent {
                for i in (startIndex..<safeCurrent).reversed() {
                    prependView(at: i)
                }
            }
            
            // 向后加载指定数量（仅在区间有序时）
            if safeCurrent <= endIndex {
                for i in safeCurrent...endIndex {
                    appendView(at: i)
                }
            }
        }
        
        // 处理后续加载...剩余代码保持不变
        if let lastView = loadedViews.last {
            let diff = lastView.index - currentIndex
            if diff < (config.preloadAmount) {
                for i in lastView.index..<(lastView.index + (config.preloadAmount - diff)) {
                    appendView(at: i + 1)
                }
            }
        }
        
        if let firstView = loadedViews.first {
            let diff = currentIndex - firstView.index
            if diff < (config.preloadAmount) {
                for i in (firstView.index - (config.preloadAmount - diff)..<firstView.index).reversed() {
                    prependView(at: i)
                }
            }
        }
        
        self.removeOutOfFrameViews()
        
        // Debug
        LazyPagerLogger.log("PagerView.computeViewState end - loadedIndexes=\(self.loadedViews.map { $0.index })")
    }
    
    
    func addSubview(_ zoomView: ZoomableView<Element, Content>) {
        super.addSubview(zoomView)
        NSLayoutConstraint.activate([
            zoomView.widthAnchor.constraint(equalTo: frameLayoutGuide.widthAnchor),
            zoomView.heightAnchor.constraint(equalTo: frameLayoutGuide.heightAnchor),
        ])
    }
    
    func addFirstView(_ zoomView: ZoomableView<Element, Content>) {
        if config.direction == .horizontal {
            zoomView.leadingConstraint = zoomView.leadingAnchor.constraint(equalTo: leadingAnchor)
            zoomView.trailingConstraint = zoomView.trailingAnchor.constraint(equalTo: trailingAnchor)
            zoomView.leadingConstraint?.isActive = true
            zoomView.trailingConstraint?.isActive = true
        } else {
            zoomView.topConstraint = zoomView.topAnchor.constraint(equalTo: topAnchor)
            zoomView.bottomConstraint = zoomView.bottomAnchor.constraint(equalTo: bottomAnchor)
            zoomView.topConstraint?.isActive = true
            zoomView.bottomConstraint?.isActive = true

        }
        
    }
    
    func appendView(at index: Int) {
        guard let zoomView = viewLoader?.loadView(at: index) else { return }
        LazyPagerLogger.log("PagerView.appendView - index=\(index)")
        
        addSubview(zoomView)
        
        if let lastView = loadedViews.last {
            if config.direction == .horizontal {
                lastView.trailingConstraint?.isActive = false
                lastView.trailingConstraint = nil
                
                zoomView.leadingConstraint = zoomView.leadingAnchor.constraint(equalTo: lastView.trailingAnchor)
                zoomView.trailingConstraint = zoomView.trailingAnchor.constraint(equalTo: trailingAnchor)
                zoomView.leadingConstraint?.isActive = true
                zoomView.trailingConstraint?.isActive = true
            } else {
                lastView.bottomConstraint?.isActive = false
                lastView.bottomConstraint = nil
                
                zoomView.topConstraint = zoomView.topAnchor.constraint(equalTo: lastView.bottomAnchor)
                zoomView.bottomConstraint = zoomView.bottomAnchor.constraint(equalTo: bottomAnchor)
                zoomView.topConstraint?.isActive = true
                zoomView.bottomConstraint?.isActive = true
            }
            
        } else {
            addFirstView(zoomView)
        }
        loadedViews.append(zoomView)
        layoutSubviews()
    }
    
    func prependView(at index: Int) {
        guard let zoomView = viewLoader?.loadView(at: index) else { return }
        LazyPagerLogger.log("PagerView.prependView - index=\(index)")
        
        addSubview(zoomView)
        
        if let firstView = loadedViews.first {
            if config.direction == .horizontal {
                firstView.leadingConstraint?.isActive = false
                firstView.leadingConstraint = nil
                
                zoomView.leadingConstraint = zoomView.leadingAnchor.constraint(equalTo: leadingAnchor)
                zoomView.trailingConstraint = zoomView.trailingAnchor.constraint(equalTo: firstView.leadingAnchor)
                zoomView.leadingConstraint?.isActive = true
                zoomView.trailingConstraint?.isActive = true
            } else {
                firstView.topConstraint?.isActive = false
                firstView.topConstraint = nil
                
                zoomView.topConstraint = zoomView.topAnchor.constraint(equalTo: topAnchor)
                zoomView.bottomConstraint = zoomView.bottomAnchor.constraint(equalTo: firstView.topAnchor)
                zoomView.topConstraint?.isActive = true
                zoomView.bottomConstraint?.isActive = true
            }
            
        } else {
            addFirstView(zoomView)
        }
        
        layoutSubviews()
        
        loadedViews.insert(zoomView, at: 0)
        if config.direction == .horizontal {
            contentOffset.x += frame.size.width
        } else {
            contentOffset.y += frame.size.height
        }
    }
    
    func reloadViews() {
        LazyPagerLogger.log("PagerView.reloadViews - loadedViewCount=\(loadedViews.count)")
        for view in loadedViews {
            viewLoader?.updateHostedView(for: view)
        }
    }
    
    func remove(view: ZoomableView<Element, Content>) {
        LazyPagerLogger.log("PagerView.removeView - index=\(view.index)")
        let index = view.index
        loadedViews.removeAll { $0.index == view.index }
        view.removeFromSuperview()
        
        if let firstView = loadedViews.first {
            
            if config.direction == .horizontal {
                firstView.leadingConstraint?.isActive = false
                firstView.leadingConstraint = nil
                firstView.leadingConstraint = firstView.leadingAnchor.constraint(equalTo: leadingAnchor)
                firstView.leadingConstraint?.isActive = true
                
                if firstView.index > index {
                    contentOffset.x -= frame.size.width
                }
            } else {
                firstView.topConstraint?.isActive = false
                firstView.topConstraint = nil
                firstView.topConstraint = firstView.topAnchor.constraint(equalTo: topAnchor)
                firstView.topConstraint?.isActive = true
                
                if firstView.index > index {
                    contentOffset.y -= frame.size.height
                }
            }
        }
        
        if let lastView = loadedViews.last {
            if config.direction == .horizontal {
                lastView.trailingConstraint?.isActive = false
                lastView.trailingConstraint = nil
                lastView.trailingConstraint = lastView.trailingAnchor.constraint(equalTo: trailingAnchor)
                lastView.trailingConstraint?.isActive = true
            } else {
                lastView.bottomConstraint?.isActive = false
                lastView.bottomConstraint = nil
                lastView.bottomConstraint = lastView.bottomAnchor.constraint(equalTo: bottomAnchor)
                lastView.bottomConstraint?.isActive = true
            }
        }
    }
    
    
    func removeOutOfFrameViews() {
        guard let viewLoader = viewLoader else { return }
        
        let total = viewLoader.dataCount
        // 数据为空时清空所有视图
        guard total > 0 else {
            loadedViews.forEach { $0.removeFromSuperview() }
            loadedViews.removeAll()
            LazyPagerLogger.log("PagerView.removeOutOfFrameViews cleared - dataEmpty")
            return
        }
        
        // 使用 clamp 后的索引进行距离判断，避免边界抖动
        let safeCurrent = max(0, min(currentIndex, total - 1))
        
        for view in loadedViews {
            if abs(safeCurrent - view.index) > config.preloadAmount || view.index >= total {
                LazyPagerLogger.log("PagerView.removeOutOfFrameViews - removingIndex=\(view.index) safeCurrent=\(safeCurrent)")
                remove(view: view)
            }
        }
    }
    
    func resizeOutOfBoundsViews() {
        for v in loadedViews {
            if v.index != currentIndex {
                v.zoomScale = 1
            }
        }
    }
    
    func goToPage(_ page: Int) {
        LazyPagerLogger.log("PagerView.goToPage - targetPage=\(page)")
        currentIndex = page
        ensureCurrentPage()
    }
    
    func ensureCurrentPage() {
        guard let index = loadedViews.firstIndex(where: { $0.index == currentIndex }) else { return }
        if config.direction == .horizontal {
            contentOffset.x = CGFloat(index) * frame.size.width
        } else {
            contentOffset.y = CGFloat(index) * frame.size.height
        }
        LazyPagerLogger.log("PagerView.ensureCurrentPage - resolvedIndex=\(index) contentOffset=\(config.direction == .horizontal ? contentOffset.x : contentOffset.y)")
    }
    
    func loadMoreIfNeeded() {
        guard let loadMoreCallback = config.loadMoreCallback else { return }
        guard case let .lastElement(offset) = config.loadMoreOn else { return }
        guard let viewLoader = viewLoader else { return }
        
        if currentIndex + offset >= viewLoader.dataCount - 1 {
            DispatchQueue.main.async {
                loadMoreCallback()
            }
            LazyPagerLogger.log("PagerView.loadMoreIfNeeded triggered - currentIndex=\(currentIndex) dataCount=\(viewLoader.dataCount) offset=\(offset)")
        }
    }
    
    // MARK: UISCrollVieDelegate methods
    
    var lastPos: CGFloat = 0
    
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if !scrollView.isTracking, !isRotating  {
            // 防御空数组访问
            guard !loadedViews.isEmpty else { return }
            
            var relativeIndex: Int
            if config.direction == .horizontal {
                relativeIndex = Int(round(scrollView.contentOffset.x / scrollView.frame.width))
            } else {
                relativeIndex = Int(round(scrollView.contentOffset.y / scrollView.frame.height))
            }
            relativeIndex = relativeIndex < 0 ? 0 : relativeIndex
            relativeIndex = relativeIndex >= loadedViews.count ? loadedViews.count-1 : relativeIndex
            currentIndex = loadedViews[relativeIndex].index
            page.wrappedValue = currentIndex
            LazyPagerLogger.log("PagerView.scrollViewDidScroll - relativeIndex=\(relativeIndex) mappedIndex=\(currentIndex)")
        }
        
        
        // Horribly janky way to detect when scrolling (both touching and animation) is finnished.
        let caputred: CGFloat
        
        if config.direction == .horizontal {
            caputred = scrollView.contentOffset.x
        } else {
            caputred = scrollView.contentOffset.y
        }
        
        lastPos = caputred
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(100)) {
            if self.lastPos == caputred, !scrollView.isTracking {
                self.resizeOutOfBoundsViews()
                LazyPagerLogger.log("PagerView.scrollViewDidScroll settled - currentIndex=\(self.currentIndex)")
            }
        }
    }
}
