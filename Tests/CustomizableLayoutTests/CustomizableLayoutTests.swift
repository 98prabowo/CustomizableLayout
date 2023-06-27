import XCTest
@testable import CustomizableLayout

internal final class CustomizableLayoutTests: XCTestCase {
    internal func testVerticalListLayout_creation() throws {
        let sut = CustomizableLayout.Template.verticalListLayout(
            spacing: 8.0,
            margins: .zero
        )
        
        XCTAssertEqual(sut.scrollDirection, .vertical)
        XCTAssertEqual(sut.margins, .zero)
    }
    
    internal func testVerticalStaggeredLayout_creation() throws {
        let sut = CustomizableLayout.Template.verticalStaggeredLayout(
            numberOfColumns: 2,
            interItemSpacing: 8,
            lineSpacing: 10,
            margins: .zero
        )
        
        XCTAssertEqual(sut.scrollDirection, .vertical)
        XCTAssertEqual(sut.margins, .zero)
    }
    
    internal func testHorizontalListLayout_creation() throws {
        let sut = CustomizableLayout.Template.horizontalListLayout(
            spacing: 8.0,
            margins: .zero
        )
        
        XCTAssertEqual(sut.scrollDirection, .horizontal)
        XCTAssertEqual(sut.margins, .zero)
    }
    
    internal func testHorizontalListFullWidthLayout_creation() throws {
        let sut = CustomizableLayout.Template.horizontalListFullWidthLayout(margins: .zero)
        
        XCTAssertEqual(sut.scrollDirection, .horizontal)
        XCTAssertEqual(sut.margins, .zero)
    }
    
    internal func testHorizontalStaggeredLayout_creation() throws {
        let sut = CustomizableLayout.Template.horizontalStaggeredLayout(
            numberOfRows: 2,
            interItemSpacing: 8.0,
            lineSpacing: 10,
            margins: .zero
        )
        
        XCTAssertEqual(sut.scrollDirection, .horizontal)
        XCTAssertEqual(sut.margins, .zero)
    }
}
