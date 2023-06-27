//
//  CustomizableLayoutInspector.swift
//  
//
//  Created by Dimas Agung Prabowo on 27/06/23.
//

import AsyncDisplayKit

extension CustomizableLayout {
    public final class Inspector: NSObject, ASCollectionViewLayoutInspecting {
        private let layout: CustomizableLayout
        
        public init(layout: CustomizableLayout) {
            self.layout = layout
        }
        
        public func collectionView(_ collectionView: ASCollectionView, constrainedSizeForNodeAt indexPath: IndexPath) -> ASSizeRange {
            let size: Size = layout.sizeCalculationBlock(indexPath.section)
            
            if case let .fixed(width) = size.width,
               case let .fixed(height) = size.height {
                return ASSizeRangeMake(
                    CGSize(
                        width: .maximum(width, 0.0),
                        height: .maximum(height, 0.0)
                    )
                )
            } else if case let .fixed(width) = size.width,
                      case .flexible = size.height {
                return ASSizeRangeMake(
                    CGSize(width: .maximum(width, 0.0), height: .zero),
                    CGSize(width: .maximum(width, 0.0), height: .infinity)
                )
            } else if case .flexible = size.width,
                      case let .fixed(height) = size.height {
                return ASSizeRangeMake(
                    CGSize(width: .zero, height: .maximum(height, 0.0)),
                    CGSize(width: .infinity, height: .maximum(height, 0.0))
                )
            } else {
                return ASSizeRangeMake(
                    CGSize(width: CGFloat.zero, height: CGFloat.zero),
                    CGSize(width: CGFloat.infinity, height: CGFloat.infinity)
                )
            }
        }
        
        public func scrollableDirections() -> ASScrollDirection {
            switch layout.scrollDirection {
            case .vertical:
                return ASScrollDirectionVerticalDirections
            case .horizontal:
                return ASScrollDirectionHorizontalDirections
            }
        }
    }
}
