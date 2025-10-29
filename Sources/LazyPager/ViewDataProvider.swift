//
//  ViewDataProvider.swift
//  
//
//  Created by Brian Floersch on 7/8/23.
//

import Foundation
import SwiftUI
import UIKit

public class ViewDataProvider<Content: View, DataCollecton: RandomAccessCollection, Element>: UIViewController, ViewLoader where DataCollecton.Index == Int, DataCollecton.Element == Element {
    
    var viewLoader: (Element) -> Content
    var data: DataCollecton
    var config: Config
    var pagerView: PagerView<Element, ViewDataProvider, Content>
    
    var dataCount: Int {
        return data.count
    }
    
    
    init(data: DataCollecton,
         page: Binding<Int>,
         config: Config,
         viewLoader: @escaping (Element) -> Content) {
        
        LazyPagerLogger.log("ViewDataProvider.init start - initialPage=\(page.wrappedValue) initialDataCount=\(data.count)")
        self.data = data
        self.viewLoader = viewLoader
        self.config = config
        self.pagerView = PagerView(page: page, config: config)
        
        super.init(nibName: nil, bundle: nil)
        self.pagerView.viewLoader = self
        
        LazyPagerLogger.log("ViewDataProvider.init end - pagerCurrentIndex=\(self.pagerView.currentIndex)")
        pagerView.computeViewState()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func goToPage(_ page: Int) {
        LazyPagerLogger.log("ViewDataProvider.goToPage - targetPage=\(page)")
        pagerView.goToPage(page)
    }
    
    func reloadViews() {
        LazyPagerLogger.log("ViewDataProvider.reloadViews - loadedViewCount=\(pagerView.loadedViews.count)")
        pagerView.reloadViews()
        pagerView.computeViewState()
    }

    // MARK: ViewLoader
    
    func loadView(at index: Int) -> ZoomableView<Element, Content>? {
        guard let dta = data[safe: index] else {
            LazyPagerLogger.log("ViewDataProvider.loadView miss - index=\(index) dataCount=\(data.count)")
            return nil
        }
        
        LazyPagerLogger.log("ViewDataProvider.loadView success - index=\(index)")
        let hostingController = UIHostingController(rootView: viewLoader(dta))
        return ZoomableView(hostingController: hostingController, index: index, data: dta, config: config)
    }
    
    func updateHostedView(for zoomableView: ZoomableView<Element, Content>) {
        guard let dta = data[safe: zoomableView.index] else {
            LazyPagerLogger.log("ViewDataProvider.updateHostedView miss - index=\(zoomableView.index)")
            return
        }
        
        LazyPagerLogger.log("ViewDataProvider.updateHostedView success - index=\(zoomableView.index)")
        zoomableView.hostingController.rootView = viewLoader(dta)
    }
    
    // MARK: UIViewController
    
    public override func loadView() {
        LazyPagerLogger.log("ViewDataProvider.loadView (UIViewController) - attachingPagerView")
        self.view = pagerView
    }
    
    public override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        LazyPagerLogger.log("ViewDataProvider.viewWillTransition start - targetSize=\(size)")
        pagerView.isRotating = true
        coordinator.animate(alongsideTransition: { context in }, completion: { context in
            self.pagerView.isRotating = false
            DispatchQueue.main.async {
                LazyPagerLogger.log("ViewDataProvider.viewWillTransition completion - restoringPage=\(self.pagerView.currentIndex)")
                self.pagerView.goToPage(self.pagerView.currentIndex)
            }
        })
    }
}
