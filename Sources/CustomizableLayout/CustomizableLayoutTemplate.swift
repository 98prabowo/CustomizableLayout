//
//  CustomizableLayoutTemplate.swift
//  
//
//  Created by Dimas Agung Prabowo on 27/06/23.
//

#if canImport(UIKit)

import AsyncDisplayKit
import UIKit

extension CustomizableLayout {
    public struct Template {
        // MARK: Vertical Layouts
        
        /// Create a vertical grid layout with each row may have different height where the height of the row is determined by the tallest cell.
        ///
        /// - Parameters:
        ///     - numberOfColumns : number of columns for this layout.
        ///     - interItemSpacing : space between the items in same line (Horizontally).
        ///     - lineSpacing : space between the lines (Vertically).
        ///     - margins : space between the most start / end item with the border of collection depends on the margin position (e.g left: most left item to the border of collection)
        public static func gridDynamicRowLayout(
            numberOfColumns: Int,
            interItemSpacing: CGFloat = 8.0,
            lineSpacing: CGFloat = 8.0,
            margins: UIEdgeInsets
        ) -> CustomizableLayout {
            return verticalStaggeredListLayout(numberOfColumns: numberOfColumns) { _ in
                    .gridDynamicRow(
                        margins: margins,
                        interItemSpacing: interItemSpacing,
                        lineSpacing: lineSpacing
                    )
            }
        }
        
        /// Create a vertical list layout with each item will fill full width of the collection (UITableView Style).
        ///
        /// - Parameters:
        ///     - spacing : space between the lines (Vertically).
        ///     - margins : space between the most start / end item with the border of collection depends on the margin position (e.g left: most left item to the border of collection)
        public static func verticalListLayout(
            spacing: CGFloat,
            margins: UIEdgeInsets
        ) -> CustomizableLayout {
            return verticalStaggeredListLayout(numberOfColumns: 1) { _ in
                    .fullWidth(
                        margins: margins,
                        lineSpacing: spacing
                    )
            }
        }
        
        /// Create a vertical stagger layout (Pinterest Style).
        ///
        /// - Parameters:
        ///     - numberOfColumns : number of columns for this layout.
        ///     - interItemSpacing : space between the items in same line (Horizontally).
        ///     - lineSpacing : space between the lines (Vertically).
        ///     - margins : space between the most start / end item with the border of collection depends on the margin position (e.g left: most left item to the border of collection)
        ///     - shouldFillGapFirst:  if set to false, cells will be filled from left to right. if set to true, cells will be filled to the column with most gap.
        public static func verticalStaggeredLayout(
            numberOfColumns: Int,
            interItemSpacing: CGFloat,
            lineSpacing: CGFloat,
            margins: UIEdgeInsets,
            shouldFillGapFirst: Bool = false
        ) -> CustomizableLayout {
            return verticalStaggeredListLayout(
                numberOfColumns: numberOfColumns,
                shouldFillGapFirst: shouldFillGapFirst) { _ in
                        .staggered(
                            margins: margins,
                            interItemSpacing: interItemSpacing,
                            lineSpacing: lineSpacing
                        )
                }
        }
        
        /// Create a vertical stagger layout (Pinterest Style) whose cells client can configure wheter to return staggered or full width based on client implementation.
        ///
        /// - Parameters:
        ///     - numberOfColumn: Number of columns for this layout, only works for staggered.
        ///     - shouldFillGapFirst:  if set to false, cells will be filled from left to right. if set to true, cells will be filled to the column with most gap.
        ///     - createCell: callback with the current iteration parameter of the cell part (`Int`) which you can configure to return a cell of type` StaggerCellLayout`.
        public static func verticalStaggeredListLayout(
            numberOfColumns: @escaping @autoclosure () -> Int,
            shouldFillGapFirst: Bool = false,
            createCell: @escaping (_ section: Int) -> StaggerLayoutType
        ) -> CustomizableLayout {
            let layout = CustomizableLayout(scrollDirection: .vertical, margins: .zero)
            
            layout.sizeCalculationBlock = { [weak layout] section in
                let item = createCell(section)
                let numberOfColumns = numberOfColumns()
                guard let collectionView = layout?.collectionView,
                      item != .skip else { return .zero }
                
                switch item {
                case let .fullWidth(margins, _):
                    let reduceWidthFromMargins: CGFloat = margins.left + margins.right
                    
                    return CustomizableLayout.Size(
                        width: .fixed(collectionView.bounds.width - reduceWidthFromMargins),
                        height: .flexible)
                    
                case
                    let .gridDynamicRow(margins, interItemSpacing, _),
                    let .staggered(margins, interItemSpacing, _):
                    
                    let reduceWidthFromMargins: CGFloat = margins.left + margins.right
                    let reduceWidthFromSpacing: CGFloat = interItemSpacing + CGFloat(numberOfColumns - 1)
                    let contentWidth: CGFloat = collectionView.bounds.width - reduceWidthFromMargins - reduceWidthFromSpacing
                    
                    return CustomizableLayout.Size(
                        width: .fixed(contentWidth / CGFloat(numberOfColumns)),
                        height: .flexible
                    )
                    
                case .skip:
                    assertSkip()
                    return .zero
                }
            }
            
            layout.preparationBlock = { [weak layout] env in
                guard let layout = layout else { return [] }
                var attributes: [UICollectionViewLayoutAttributes] = []
                var currentColumn: Int = 0
                var yOffsets: [CGFloat] = []
                var lastMarginBottom: CGFloat = .zero
                
                var maxHeightInRow: CGFloat = .zero
                var previousType: CustomizableLayout.StaggerLayoutType.Identifier = .skip
                
                let numberOfSection: Int = env.numberOfSections()
                let numberOfColumns: Int = numberOfColumns()
                
                for section in 0 ..< numberOfSection {
                    /// Intended to store previous item but need to ignore `.skip` type it is used for reset currentColumn counter if cell layout type changed.
                    /// If we didn't ignore .skip type case like `[.staggered, .skip, .staggered]` will messed up the currenColumn by reseting to 0.
                    if section != 0 {
                        let previousItem: StaggerLayoutType = createCell(section - 1)
                        if previousItem != .skip {
                            previousType = previousItem.identifier
                        }
                    }
                    
                    let item: CustomizableLayout.StaggerLayoutType = createCell(section)
                    guard item != .skip else { continue }
                    
                    let attribute = UICollectionViewLayoutAttributes(section: section)
                    let size: CGSize = env.sizeForSection(section)
                    
                    /// Reset column counter if cell layout type changed.
                    if item.identifier != previousType {
                        currentColumn = 0
                    }
                    
                    /// Calculate the top margin when the yOffsets is still empty.
                    if yOffsets.isEmpty {
                        switch item {
                        /// If the first section is `staggered` or `gridDynamicRow`, we calculate the layout on the first row and take the max margin top.
                        /// ex: in 1 row we have 3 staggered with different margin, so our layout will be painted on the max margin in that row.
                        case .staggered, .gridDynamicRow:
                            /// To guard if `numberOfColumns` is higher than `numberOfSection`.
                            let maxColumnInSingleLine: Int = min(numberOfColumns, numberOfSection)
                            let marginTop: CGFloat = (0 ..< maxColumnInSingleLine)
                                .map(createCell)
                                .map { layout in
                                    switch layout {
                                    case
                                        let .gridDynamicRow(margins, _, _),
                                        let .staggered(margins, _, _):
                                        return margins.top
                                        
                                    default:
                                        return 0
                                    }
                                }
                                .max() ?? 0
                            
                            yOffsets = Array(repeating: marginTop, count: numberOfColumns)
                        
                        /// If the first section is fullWidth.
                        case let .fullWidth(margins, _):
                            yOffsets = Array(repeating: margins.top, count: numberOfColumns)
                            
                        case .skip:
                            assertSkip()
                        }
                    }
                    
                    switch item {
                    case let .staggered(margins, interItemSpacing, lineSpacing):
                        defer {
                            /// If `shouldFillGapFirst` we don't need to look up to column positioning since it will fill with the shortest column first.
                            if !shouldFillGapFirst {
                                /// Reset `currentColumn` for next row.
                                if currentColumn == numberOfColumns - 1 {
                                    currentColumn = 0
                                } else {
                                    currentColumn += 1
                                }
                            }
                        }
                        
                        /// Get the shortest column (column with most gap) to fill.
                        let shortestColumn: Int = yOffsets.enumerated()
                            .min { $0.element < $1.element }
                            .map { $0.offset } ?? 0
                        
                        let column: Int = shouldFillGapFirst ? shortestColumn : currentColumn
                        let xOffset: CGFloat = margins.left + (size.width + interItemSpacing)  * CGFloat(column)
                        
                        attribute.frame = CGRect(
                            x: xOffset,
                            y: yOffsets[column],
                            width: size.width,
                            height: size.height
                        )
                        attributes.append(attribute)
                        yOffsets[column] += size.height + lineSpacing
                        
                        /// Calculate the bottom margin if it's the last section.
                        if section == numberOfSection - 1, numberOfSection > numberOfColumns {
                            /// Get the tallest column.
                            let yOffsetWithoutSpacing: [CGFloat] = yOffsets.map { $0 - lineSpacing }
                            guard let maxOffset = yOffsetWithoutSpacing.max(),
                                  let highestColumn = yOffsetWithoutSpacing.firstIndex(where: { $0 == maxOffset })
                            else { break }
                            
                            /// Get the tallest section.
                            let tallestSection: Int = numberOfSection - numberOfColumns + highestColumn
                            let cell: StaggerLayoutType = createCell(tallestSection)
                            
                            /// Get the bottom margin.
                            if case .staggered(margins, _, _) = cell {
                                lastMarginBottom = margins.bottom
                            }
                        }
                        
                    case let .fullWidth(margins, lineSpacing):
                        let maxHeight: CGFloat = yOffsets.max() ?? 0.0
                        attribute.frame = CGRect(
                            x: margins.left,
                            y: maxHeight,
                            width: size.width,
                            height: size.height
                        )
                        attributes.append(attribute)
                        yOffsets = yOffsets.map { _ in
                            maxHeight + size.height + lineSpacing
                        }
                        lastMarginBottom = margins.bottom
                        
                    case let .gridDynamicRow(margins, interItemSpacing, lineSpacing):
                        let xOffset: CGFloat = margins.left + (size.width + interItemSpacing) * CGFloat(currentColumn)
                        
                        /// Do calculation for the highest cell in that row and will reset for every new row.
                        if currentColumn == 0 {
                            for column in section ..< section + numberOfColumns {
                                guard column < numberOfSection else { break }
                                
                                let item = createCell(column)
                                guard case .gridDynamicRow = item else { break }

                                let size = env.sizeForSection(column)
                                maxHeightInRow = max(maxHeightInRow, size.height)
                            }
                        }
                        
                        attribute.frame = CGRect(
                            x: xOffset,
                            y: yOffsets[currentColumn],
                            width: size.width,
                            height: maxHeightInRow
                        )
                        attributes.append(attribute)
                        yOffsets[currentColumn] += maxHeightInRow + lineSpacing
                        lastMarginBottom = margins.bottom
                        
                        /// Reset `currentColumn` for next row
                        if currentColumn == numberOfColumns - 1 {
                            currentColumn = 0
                            maxHeightInRow = 0
                        } else {
                            currentColumn += 1
                        }
                        
                    case .skip:
                        assertSkip()
                    }
                }
                
                /// Apply the latest margin bottom
                var mutableMargins = layout.margins
                mutableMargins.bottom = lastMarginBottom
                layout.margins = mutableMargins
                
                return attributes
            }
            
            return layout
        }
        
        // MARK: Horizontal Layouts
            
        /// Create a horizontal list layout (Carousel Style)
        ///
        /// - Parameters:
        ///     - spacing : space between the items in same line (Horizontally).
        ///     - margins : space between the most start / end item with the border of collection depends on the margin position (e.g left: most left item to the border of collection)
        ///     - heightType : collection height type used for determine wether user want to used fixed height or flexible based on it's content height.
        public static func horizontalListLayout(
            spacing: CGFloat,
            margins: UIEdgeInsets,
            heightType: CustomizableLayout.CollectionHeightType = .fixed
        ) -> CustomizableLayout {
            let layout = CustomizableLayout(scrollDirection: .horizontal, margins: margins)

            layout.sizeCalculationBlock = { [weak layout] _ in
                guard let collectionView = layout?.collectionView else { return .zero }

                let whitespaceFromMargins: CGFloat = margins.top + margins.bottom

                return CustomizableLayout.Size(
                    width: .flexible,
                    height: heightType == .flexible ? .flexible : .fixed(collectionView.bounds.height - whitespaceFromMargins)
                )
            }

            layout.preparationBlock = { [weak layout] env in
                guard let collectionView = layout?.collectionView else { return [] }

                var attributes: [UICollectionViewLayoutAttributes] = []
                var xOffset = margins.left
                var maxHeight: CGFloat = 0

                /// This is intended for horizontal collection node to readjust their height based on heighest content cell
                /// It will be only invoked when using horizontal layout template and if the user use `.flexible` heightType
                if heightType == .flexible {
                    (0 ..< env.numberOfSections())
                        .forEach { section in
                            let size = env.sizeForSection(section)
                            maxHeight = max(maxHeight, size.height)
                        }

                    if let node = collectionView as? ASCollectionView, let collectionNode = node.collectionNode {
                        collectionNode.style.height = ASDimensionMake(maxHeight + margins.top + margins.bottom)
                        collectionNode.setNeedsLayout()
                    } else {
                        collectionView.frame.size.height = maxHeight + margins.top + margins.bottom
                        collectionView.collectionViewLayout.invalidateLayout()
                    }
                }

                (0 ..< env.numberOfSections())
                    .forEach { section in
                        let attribute = UICollectionViewLayoutAttributes(section: section)
                        let size = env.sizeForSection(section)
                        let yOffset = margins.top

                        attribute.frame = CGRect(
                            x: xOffset,
                            y: yOffset,
                            width: size.width,
                            height: heightType == .flexible ? maxHeight : size.height
                        )

                        xOffset += size.width + spacing

                        attributes.append(attribute)
                    }

                return attributes
            }

            return layout
        }
        
        /// Create a horizontal stagger layout .
        ///
        /// - Parameters:
        ///     - numberOfRows: Number of rows for this layout, only works for staggered.
        ///     - interItemSpacing:  A space between item vertically.
        ///     - lineSpacing: space between the items in same line (Horizontally).
        ///     - margins: space between the most start / end item with the border of collection depends on the margin position (e.g left: most left item to the border of collection).
        public static func horizontalStaggeredLayout(
            numberOfRows: Int,
            interItemSpacing: CGFloat,
            lineSpacing: CGFloat,
            margins: UIEdgeInsets
        ) -> CustomizableLayout {
            let layout = CustomizableLayout(scrollDirection: .horizontal, margins: margins)
            
            layout.sizeCalculationBlock = { [weak layout] _ in
                guard let collectionView = layout?.collectionView else { return .zero }
                
                let whitespaceFromInteritemSpacing = interItemSpacing * CGFloat(numberOfRows - 1)
                let whitespaceFromMargins = margins.top + margins.bottom
                let contentHeight = collectionView.bounds.height - whitespaceFromInteritemSpacing - whitespaceFromMargins
                
                return CustomizableLayout.Size(
                    width: .flexible,
                    height: .fixed(contentHeight / CGFloat(numberOfRows))
                )
            }
            
            layout.preparationBlock = { env in
                var attributes: [UICollectionViewLayoutAttributes] = []
                var xOffsets = Array(repeating: margins.left, count: numberOfRows)
                var row = 0
                
                (0 ..< env.numberOfSections())
                    .forEach { section in
                        let attribute = UICollectionViewLayoutAttributes(section: section)
                        let size = env.sizeForSection(section)
                        let yOffset = margins.top + (size.height + interItemSpacing) * CGFloat(row)
                        
                        attribute.frame = CGRect(
                            x: xOffsets[row],
                            y: yOffset,
                            width: size.width,
                            height: size.height
                        )
                        
                        xOffsets[row] += size.width + lineSpacing
                        
                        if row == numberOfRows - 1 {
                            row = 0
                        } else {
                            row += 1
                        }
                        
                        attributes.append(attribute)
                    }
                
                return attributes
            }
            
            return layout
        }
    }
    
    /// Create a horizontal list with full width layout.
    ///
    /// - Parameters:
    ///     - spacing: A space between cell horizontally.
    ///     - margins: The amount of how large the cell will be shrink.
    public static func horizontalListFullWidthLayout(
        spacing: CGFloat = 0.0,
        margins: UIEdgeInsets
    ) -> CustomizableLayout {
        let layout = CustomizableLayout(scrollDirection: .horizontal, margins: margins)
        
        layout.sizeCalculationBlock = { [weak layout] _ in
            guard let collectionView = layout?.collectionView else { return .zero }
            
            let verticalWhiteSpaceFromMargins: CGFloat = margins.top + margins.bottom
            let horizontalWhiteSpaceFromMargins: CGFloat = margins.left + margins.right
            
            return CustomizableLayout.Size(
                width: .fixed(collectionView.bounds.width - horizontalWhiteSpaceFromMargins),
                height: .fixed(collectionView.bounds.height - verticalWhiteSpaceFromMargins)
            )
        }
        
        layout.preparationBlock = { env in
            var attributes: [UICollectionViewLayoutAttributes] = []
            var xOffset = margins.left
            (0 ..< env.numberOfSections())
                .forEach { section in
                    let attribute = UICollectionViewLayoutAttributes(section: section)
                    let size = env.sizeForSection(section)
                    let yOffset = margins.top
                    
                    attribute.frame = CGRect(
                        x: xOffset,
                        y: yOffset,
                        width: size.width,
                        height: size.height
                    )
                    
                    xOffset += size.width + spacing
                    attributes.append(attribute)
                }
            return attributes
        }
        
        return layout
    }
    
    // MARK: - Layout Types
    
    /// Types of collection item's height.
    public enum CollectionHeightType {
        /// Collection height be fixed based on client-side definition.
        case fixed
        
        /// Collection height will be adjusted based of it's highest content.
        case flexible
    }
    
    /// Types of stagger layout.
    public enum StaggerLayoutType: Equatable {
        /// Stagger cell with dynamic height (Pinterest Style).
        ///
        /// - Parameters:
        ///     - margins: Space between the most start / end item with the border of collection depends on the margin position (e.g left: most left item to the border of the collection).
        ///     - interItemSpacing: Space between the items in the same line (Horizontally).
        ///     - lineSpacing: Space between the lines (Vertically).
        case staggered(
            margins: UIEdgeInsets = .zero,
            interItemSpacing: CGFloat = 8.0,
            lineSpacing: CGFloat = 8.0
        )
        
        /// Cell with full width of the collection.
        ///
        /// - Parameters:
        ///     - margins: The amount of how large the cell will shrink.
        ///     - lineSpacing: Space between the lines (Vertically).
        case fullWidth(
            margins: UIEdgeInsets = .zero,
            lineSpacing: CGFloat = 8.0
        )
        
        /// Grid cell with each row may have different height where the height of the row is determined by the tallest column.
        ///
        /// - Parameters:
        ///     - margins: Space between the most start / end item with the border of collection depends on the margin position (e.g left: most left item to the border of the collection).
        ///     - interItemSpacing: Space between the items in the same line (Horizontally).
        ///     - lineSpacing: Space between the lines (Vertically).
        case gridDynamicRow(
            margins: UIEdgeInsets = .zero,
            interItemSpacing: CGFloat = 8.0,
            lineSpacing: CGFloat = 8.0
        )
        
        /// Use this for the edge case where you don't need to do any layouting.
        case skip
        
        internal enum Identifier: Equatable {
            case staggered
            case fullWidth
            case gridDynamicRow
            case skip
        }
        
        /// This is used to identified current cell type, instead to compare without having to care about the associated value.
        fileprivate var identifier: Identifier {
            switch self {
            case .staggered:
                return .staggered
            case .fullWidth:
                return .fullWidth
            case .gridDynamicRow:
                return .gridDynamicRow
            case .skip:
                return .skip
            }
        }
    }
    
    // MARK: - Helpers
    
    private static func assertSkip() {
        assertionFailure("Must be skipped at the top of the code block")
    }
}

#endif
