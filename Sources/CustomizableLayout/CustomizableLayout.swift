//
//  CustomizableLayout.swift
//
//
//  Created by Dimas Agung Prabowo on 27/06/23.
//

#if canImport(UIKit)

import AsyncDisplayKit
import UIKit

/**
 A customizable layout object that allows client-side to determine every section's layout attributes.
 
 - Parameters:
    - scrollDirection: The scroll direction of the collection view.
    - margins: The margins of the layout.
 
 Here is an example on how to create a custom layout:
 ```
 let margins = UIEdgeInsets(with: 8)
 let spacing = CGFloat(8)
 
 lazy var verticalListLayout: CustomizableLayout = {
    // 1. Because we want to create a vertical list layout,
    // define CustomizableLayout with scroll direction as vertical,
    // insert your inset too if we have one.
 
    let layout = CustomizableLayout(scrollDirection: .vertical, margins: margins)
 
    // 2. Define the size of the cell in every section.
    // In this case every cell has the same size so the second argument is not used.
 
    layout.sizaCalculationBlock = { _ in
        guard let collectionView = layout.collectionView else { return .zero }
 
        let whiteSpaceFromMargins = margins.left + margins.right
 
        return CustomizableLayout.Size(
            width: .fixed(collectionView.bounds.width - whiteSpaceFromMargins),
            height: .flexible
        )
    }
 
    // 3. Define the attributes for each section.
    
    layout.preparationBlock = { [weak self] env in
        guard let self else { return [] }
        
        // 3.1. Create attribute list of all sections
        var attributes: [UICollectionViewLayoutAttributes] = []
 
        // 3.2. Keep track of current section's origin.y
        var yOffset = self.margins.top
 
        (0 ..< env.collectionView.numberofSections)
            .forEach { section in
                // 3.3. Create attribute for section N
                let attribute = UICollectionViewLayoutAttributes(section: section)
 
                // 3.4. Get section N size
                let size = env.sizeForSection(section)
 
                let xOffset = self.margins.left
 
                // 3.5. Determine the frame of the section's cell
                attribute.frame = CGRect(
                    x: xOffset,
                    y: yOffset,
                    width: size.width,
                    height: size.height
                )
 
                // 3.6. Remember to keep track of origin.y
 
                yOffset += size.height + self.spacing
 
                attributes.append(attribute)
            }
 
        return attributes
    }
 
    return layout
 }()
 
 // 4. Use the layout in your collection node.
 
 lazy var collectionNode = ASCollectionNode(collectionViewLayout: verticalListLayout)
 
 // 5. Finally, add layout inspector to your collection node.
 
 lazy var layoutInspector = CustomizableLayout.Inspector(layout: verticalListLayout)
 
 init() {
    collectionNode.layoutInspector = layoutInspector
 }
 ```
 */
public final class CustomizableLayout: UICollectionViewLayout {
    // MARK: - Helper Types
    
    /// A structure to store informations about the layout.
    public struct Environment {
        public let numberOfSections: () -> Int
        public let sizeForSection: (Int) -> CGSize
        public let layoutAttributesForSections: (Int) -> UICollectionViewLayoutAttributes?
    }
    
    /// A structure that contains width and height values of `CustomizableLayout`'s cell.
    public struct Size {
        /**
            The dimension of CustomizableLayout.Size
         
            There are two types of dimensions:
            1. Fixed dimension for static value
            2. Flexible dimension for dynamic value that is determined by the size of the content
         */
        public enum Dimension: Equatable {
            case fixed(CGFloat)
            case flexible
        }
        
        public let width: Dimension
        public let height: Dimension
        
        public init(width: Dimension, height: Dimension) {
            self.width = width
            self.height = height
        }
        
        public static let zero = Size(width: .fixed(.zero), height: .fixed(.zero))
        public static let flexible = Size(width: .flexible, height: .flexible)
    }
    
    public enum ScrollDirection {
        case vertical
        case horizontal
    }
    
    public enum StickyLayoutType {
        /// Put `leadingInset` if you want your sticky to stick with insets
        ///
        /// Example:
        /// - on `vertical` scroll, `leadingInset` will be the `top` inset
        /// - on `horizontal` scroll, `leadingInset` will be the `left` inset
        
        case sliding(leadingInset: CGFloat = 0.0)
        case stacking(leadingInset: CGFloat = 0.0)
    }
    
    public enum StickyState {
        case sliding(section: Int?)
        case stacking(sections: [Int])
    }
    
    // MARK: - Properties
    
    // An array that stores current layout attributes for every section.
    private var attributesCache: [UICollectionViewLayoutAttributes] = []
    
    // A property that provides the information about this layout.
    private var environment: Environment?
    
    internal let scrollDirection: ScrollDirection
    internal var margins: UIEdgeInsets
    
    // A block that allows client-side to determine the size of the cell in every section.
    public var sizeCalculationBlock: (Int) -> Size = { _ in
        assertionFailure("Must define sizeCalculationBlock")
        return .zero
    }
    
    // A block that allows client-side to determine every section's layout attributes.
    public var preparationBlock: (_ environment: Environment) -> [UICollectionViewLayoutAttributes] = { _ in
        assertionFailure("Must define preparationBlock")
        return []
    }
    
    // A block that allows client-side to determine the condition for layout invalidation.
    public lazy var shouldInvalidateLayoutBlock: (_ environment: Environment, _ newBounds: CGRect) -> Bool = { [weak self] _, newBounds in
        self?.collectionView?.bounds.size != newBounds.size
    }
    
    // A block that allows client-side to determine all layout attributes to be presented in current rect.
    public var presentationBlock: (_ environment: Environment, _ rect: CGRect, _ attributes: [UICollectionViewLayoutAttributes]) -> [UICollectionViewLayoutAttributes] = { _, _, attributes in
        attributes
    }
    
    // A block that allows client-side to determine at which section should a cell be sticky.
    public var stickySectionBlock: (() -> [Int])?
    
    public var stickyLayoutType: StickyLayoutType = .sliding()
    
    public var isAntiBlinkingEnabled: Bool = false
    
    public var stickyStateHandler: ((StickyState) -> Void)?
    
    private var contentWidth: CGFloat = 0.0
    
    private var contentHeight: CGFloat = 0.0
    
    // MARK: - Lifecycles
    
    public init(scrollDirection: ScrollDirection, margins: UIEdgeInsets) {
        self.scrollDirection = scrollDirection
        self.margins = margins
        super.init()
    }
    
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Overriden methods
    
    public override func prepare() {
        super.prepare()
        
        defer {
            let bounds = collectionView?.bounds ?? .zero
            
            switch scrollDirection {
            case .vertical:
                let maxY: CGFloat = attributesCache.map(\.frame.maxY).max() ?? 0.0
                contentWidth = bounds.width
                contentHeight = maxY + margins.bottom
                
            case .horizontal:
                let maxX: CGFloat = attributesCache.map(\.frame.maxX).max() ?? 0.0
                contentWidth = maxX + margins.right
                contentHeight = bounds.height - (collectionView?.adjustedContentInset.bottom ?? 0.0)
            }
        }
        
        if environment == nil, let flowLayoutDelegate = collectionView as? UICollectionViewDelegateFlowLayout {
            let sizeForSectionBlock: (UICollectionView, Int) -> CGSize = { [weak self] collectionView, section in
                guard let self = self,
                      let realSize = flowLayoutDelegate.collectionView?(collectionView, layout: self, sizeForItemAt: IndexPath(item: 0, section: section))
                else { return .zero }
                
                var newSize: CGSize = .zero
                let calculatedSize: Size = self.sizeCalculationBlock(section)
                
                switch calculatedSize.width {
                case let .fixed(width):
                    newSize.width = max(0.0, width)
                case .flexible:
                    newSize.width = max(0.0, realSize.width)
                }
                
                switch calculatedSize.height {
                case let .fixed(height):
                    newSize.height = max(0.0, height)
                case .flexible:
                    newSize.height = max(0.0, realSize.height)
                }
                
                return newSize
            }
            
            let layoutAttributesForSectionBlock: (Int) -> UICollectionViewLayoutAttributes? = { [weak self] section in
                guard let self = self else { return nil }
                return self.layoutAttributesForItem(at: IndexPath(item: 0, section: section))
            }
            
            if let uiCollectionView = collectionView {
                environment = Environment(
                    numberOfSections: { [weak uiCollectionView] in
                        uiCollectionView?.numberOfSections ?? 0
                    },
                    sizeForSection: { [weak uiCollectionView] section in
                        guard let uiCollectionView = uiCollectionView else { return .zero }
                        return sizeForSectionBlock(uiCollectionView, section)
                    },
                    layoutAttributesForSections: layoutAttributesForSectionBlock
                )
            }
        }
        
        guard let environment = environment else { return }
        
        switch scrollDirection {
        case .vertical:
            attributesCache = preparationBlock(environment).sorted { $0.frame.origin.y < $1.frame.origin.y }
        case .horizontal:
            attributesCache = preparationBlock(environment).sorted { $0.frame.origin.x < $1.frame.origin.x }
        }
    }
    
    public override var collectionViewContentSize: CGSize {
        return CGSize(width: contentWidth, height: contentHeight)
    }
    
    public override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        if let stickySections = stickySectionBlock?(), !stickySections.isEmpty {
            return true
        }
        
        guard let environment = environment else { return false }
        return shouldInvalidateLayoutBlock(environment, newBounds)
    }
    
    public override func initialLayoutAttributesForAppearingItem(at itemIndexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        if isAntiBlinkingEnabled {
            return nil
        } else {
            return super.initialLayoutAttributesForAppearingItem(at: itemIndexPath)
        }
    }
    
    public override func finalLayoutAttributesForDisappearingItem(at itemIndexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        if isAntiBlinkingEnabled {
            let attributes = super.finalLayoutAttributesForDisappearingItem(at: itemIndexPath)
            attributes?.alpha = 1
            return attributes
        } else {
            return super.finalLayoutAttributesForDisappearingItem(at: itemIndexPath)
        }
    }
    
    public override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        var attributes = [UICollectionViewLayoutAttributes]()
        
        guard let lastIndex = attributesCache.indices.last,
              let firstMatchIndex = searchFirstIndex(rect, layoutCache: attributesCache, start: 0, end: lastIndex)
        else { return attributes }
        
        switch scrollDirection {
        case .vertical:
            for attribute in attributesCache[..<firstMatchIndex].reversed() {
                guard attribute.frame.maxY >= rect.minY else { break }
                attributes.append(attribute)
            }
            
            for attribute in attributesCache[firstMatchIndex...] {
                guard attribute.frame.minY <= rect.maxY else { break }
                attributes.append(attribute)
            }
            
        case .horizontal:
            for attribute in attributesCache[..<firstMatchIndex].reversed() {
                guard attribute.frame.maxX >= rect.minX else { break }
                attributes.append(attribute)
            }
            
            for attribute in attributesCache[firstMatchIndex...] {
                guard attribute.frame.minX <= rect.maxX else { break }
                attributes.append(attribute)
            }
        }
        
        guard let environment = environment else { return attributes }
        
        attributes = presentationBlock(environment, rect, attributes)
        
        guard let stickySections = stickySectionBlock?(), !stickySections.isEmpty else { return attributes }
        
        var stickyAttributes = makeStickyAttributes(
            stickySections.compactMap { section -> UICollectionViewLayoutAttributes? in
                attributesCache.first { $0.indexPath.section == section }
            }
        )
        
        // Remove sticky attributes that is not inside rect bounds
        stickyAttributes.removeAll { !rect.intersects($0.frame) }
        
        // Remove attributes to be replaced by sticky attributes to avoid multiple attributes with same indexPath
        attributes.removeAll { stickySections.contains($0.indexPath.section) }
        
        attributes.append(contentsOf: stickyAttributes)
        
        return attributes
    }
    
    public override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        return attributesCache.first { $0.indexPath.section == indexPath.section }
    }
    
    // MARK: - Private Implementations
    
    private func makeStickyAttributes(_ attributes: [UICollectionViewLayoutAttributes]) -> [UICollectionViewLayoutAttributes] {
        switch stickyLayoutType {
        case let .sliding(inset):
            switch scrollDirection {
            case .vertical:
                return getVerticalSlidingAttributes(
                    with: getSortedAttributesVertical(attributes),
                    topOfContentView: getTopOfContentView(),
                    inset: inset
                )
            case .horizontal:
                return getHorizontalSlidingAttributes(
                    with: getSortedAttributesHorizontal(attributes),
                    mostLeftOfContentView: getMostLeftOfContentView(),
                    inset: inset
                )
            }
            
        case let .stacking(inset):
            switch scrollDirection {
            case .vertical:
                return getVerticalStackingAttributes(
                    with: getSortedAttributesVertical(attributes),
                    topOfContentView: getTopOfContentView(),
                    inset: inset
                )
            case .horizontal:
                return getHorizontalStackingAttributes(
                    with: getSortedAttributesHorizontal(attributes),
                    mostLeftOfContentView: getMostLeftOfContentView(),
                    inset: inset
                )
            }
        }
    }
    
    private func getVerticalSlidingAttributes(
        with verticalAttributes: [UICollectionViewLayoutAttributes],
        topOfContentView: CGFloat,
        inset: CGFloat
    ) -> [UICollectionViewLayoutAttributes] {
        let finalTopContentView: CGFloat = topOfContentView + inset
        var stickySection: Int?
        
        let attributes = verticalAttributes
            .enumerated()
            .map { index, attribute -> UICollectionViewLayoutAttributes in
                // If has next attribute which has touched the bottom edge of the current attribute, make it sliding
                // else if top edge of the current attribute has touched the top of content view, make it sticky
                if let nextAttribute = verticalAttributes[safe: index + 1],
                   finalTopContentView + attribute.frame.height >= nextAttribute.frame.origin.y {
                    attribute.makeSlidingAttributeForVerticalScroll(on: nextAttribute.frame.origin.y)
                } else if attribute.frame.origin.y <= finalTopContentView {
                    attribute.makeStickyAttributeForVerticalScroll(on: finalTopContentView)
                    stickySection = attribute.indexPath.section
                }
                
                return attribute
            }
        
        stickyStateHandler?(.sliding(section: stickySection))
        
        return attributes
    }
    
    private func getHorizontalSlidingAttributes(
        with horizontalAttributes: [UICollectionViewLayoutAttributes],
        mostLeftOfContentView: CGFloat,
        inset: CGFloat
    ) -> [UICollectionViewLayoutAttributes] {
        let finalMostLeftContentView: CGFloat = mostLeftOfContentView + inset
        var stickySection: Int?
        
        let attributes = horizontalAttributes
            .enumerated()
            .map { index, attribute -> UICollectionViewLayoutAttributes in
                // If has next attribute which has touched the most right edge of the current attribute, make it sliding
                // else if most left edge of the current attribute has touched the most left of content view, make it sticky
                if let nextAttribute = horizontalAttributes[safe: index + 1],
                   finalMostLeftContentView + attribute.frame.width >= nextAttribute.frame.origin.x {
                    attribute.makeSlidingAttributeForHorizontalScroll(on: nextAttribute.frame.origin.y)
                } else if attribute.frame.origin.x <= finalMostLeftContentView {
                    attribute.makeStickyAttributeForHorizontalScroll(on: finalMostLeftContentView)
                    stickySection = attribute.indexPath.section
                }
                
                return attribute
            }
        
        stickyStateHandler?(.sliding(section: stickySection))
        
        return attributes
    }
    
    private func getVerticalStackingAttributes(
        with verticalAttributes: [UICollectionViewLayoutAttributes],
        topOfContentView: CGFloat,
        inset: CGFloat
    ) -> [UICollectionViewLayoutAttributes] {
        var bottomStackPosition: CGFloat = topOfContentView + inset
        var stickySections: [Int] = []
        
        let stickyAttributes = verticalAttributes
            .map { attribute -> UICollectionViewLayoutAttributes in
                if attribute.frame.origin.y < bottomStackPosition {
                    attribute.makeStickyAttributeForVerticalScroll(on: bottomStackPosition)
                    bottomStackPosition += attribute.frame.height
                    stickySections.append(attribute.indexPath.section)
                }
                
                return attribute
            }
        
        stickyStateHandler?(.stacking(sections: stickySections))
        
        return stickyAttributes
    }
    
    private func getHorizontalStackingAttributes(
        with horizontalAttributes: [UICollectionViewLayoutAttributes],
        mostLeftOfContentView: CGFloat,
        inset: CGFloat
    ) -> [UICollectionViewLayoutAttributes] {
        var rightStackPosition: CGFloat = mostLeftOfContentView + inset
        var stickySections: [Int] = []
        
        let stickyAttributes = horizontalAttributes
            .map { attribute -> UICollectionViewLayoutAttributes in
                if attribute.frame.origin.x < rightStackPosition {
                    attribute.makeStickyAttributeForHorizontalScroll(on: rightStackPosition)
                    rightStackPosition += attribute.frame.width
                    stickySections.append(attribute.indexPath.section)
                }
                
                return attribute
            }
        
        stickyStateHandler?(.stacking(sections: stickySections))
        
        return stickyAttributes
    }
    
    private func getSortedAttributesVertical(_ attributes: [UICollectionViewLayoutAttributes]) -> [UICollectionViewLayoutAttributes] {
        return attributes.sorted { $0.frame.origin.y < $1.frame.origin.y }
    }
    
    private func getSortedAttributesHorizontal(_ attributes: [UICollectionViewLayoutAttributes]) -> [UICollectionViewLayoutAttributes] {
        return attributes.sorted { $0.frame.origin.x < $1.frame.origin.x }
    }
    
    private func searchFirstIndex(_ rect: CGRect, layoutCache: [UICollectionViewLayoutAttributes], start: Int, end: Int) -> Int? {
        return binarySearch(rect, layoutCache: layoutCache, start: start, end: end)
    }
    
    private func binarySearch(_ rect: CGRect, layoutCache: [UICollectionViewLayoutAttributes], start: Int, end: Int) -> Int? {
        guard end >= start else { return nil }
        
        let mid = (start + end) / 2
        let attr = layoutCache[mid]
        
        if attr.frame.intersects(rect) {
            return mid
        } else {
            /// Check if `mid` frame is located before or after the viewport rect
            let isBeforeViewPort: Bool
            switch scrollDirection {
            case .vertical:
                isBeforeViewPort = attr.frame.maxY < rect.minY
            case .horizontal:
                isBeforeViewPort = attr.frame.maxX < rect.minX
            }
            
            if isBeforeViewPort {
                return binarySearch(rect, layoutCache: layoutCache, start: mid + 1, end: end)
            } else {
                return binarySearch(rect, layoutCache: layoutCache, start: start, end: mid - 1)
            }
        }
    }
    
    private func getTopOfContentView() -> CGFloat {
        guard let collectionView = collectionView else { return .zero }
        
        let currentTopOfContentView = collectionView.contentOffset.y
        
        let realContentSizeHeight = collectionView.contentSize.height + collectionView.adjustedContentInset.bottom
        let maxTopOfContentView = realContentSizeHeight - collectionView.frame.height
        
        return min(maxTopOfContentView, currentTopOfContentView)
    }
    
    private func getMostLeftOfContentView() -> CGFloat {
        guard let collectionView = collectionView else { return .zero }
        
        let currentMostLeftOfContentView = collectionView.contentOffset.x
        
        let realContentSizeWidth = collectionView.contentSize.width + collectionView.adjustedContentInset.right
        let maxLeftOfContentView = realContentSizeWidth - collectionView.frame.width
        
        return min(maxLeftOfContentView, currentMostLeftOfContentView)
    }
}

// MARK: - UICollectionViewLayoutAttributes Extension

extension UICollectionViewLayoutAttributes {
    public convenience init(section: Int) {
        self.init(forCellWith: IndexPath(item: 0, section: section))
    }
}

extension UICollectionViewLayoutAttributes {
    internal func makeStickyAttributeForVerticalScroll(on position: CGFloat) {
        frame.origin.y = position
        zIndex = 1
    }
    
    internal func makeSlidingAttributeForVerticalScroll(on topOfNextCell: CGFloat) {
        let cellHeight = frame.height
        
        frame.origin.y = topOfNextCell - cellHeight
        zIndex = 1
    }
    
    internal func makeStickyAttributeForHorizontalScroll(on position: CGFloat) {
        frame.origin.x = position
        zIndex = 1
    }
    
    internal func makeSlidingAttributeForHorizontalScroll(on mostLeftOfNextCell: CGFloat) {
        let cellWidth = frame.width
        
        frame.origin.x = mostLeftOfNextCell - cellWidth
        zIndex = 1
    }
}

#endif
