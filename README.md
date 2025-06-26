I noticed an intention to hold a direct reference to the CardCollectionViewCell within the UIViewController. I'd like to propose an alternative approach: instead of directly manipulating the cell from the ViewController, we should leverage delegates (or closures/combine publishers) to update our underlying data model, and then instruct the UICollectionView to reload or reconfigure the relevant cell(s) to reflect that data change.

This is a crucial architectural point in iOS for several fundamental reasons, and avoiding direct cell references from the ViewController helps prevent common issues:

Risk of Crashing with Non-Visible Cells:
If you hold a reference to a cell and try to update it after it has been scrolled off-screen and potentially deallocated (due to cell reuse), this will lead to a crash. The UICollectionView manages the lifecycle of its cells.
UI Bugs due to Cell Reuse:
UICollectionView reuses cells for performance. If you update a specific cell instance you're holding onto, that change might incorrectly appear on a different item when the cell is reused, or an old state might reappear. The cell should always be configured based on the current data for its indexPath.
Violation of Single Source of Truth (SSOT):
The data model should be the single source of truth for the state of your UI. Updating the cell directly creates a discrepancy: the cell's visual state might change, but the underlying data model doesn't, leading to inconsistencies and making state management difficult.
Strong Coupling:
Holding direct references creates strong coupling between the UIViewController and the concrete CardCollectionViewCell implementation. This makes the ViewController less flexible, harder to test, and more difficult to refactor if the cell's implementation changes. Using a data-driven approach with delegates/data source methods decouples these components.

Suggested Approach:
When an action happens that needs to change a cell's state:
The cell (or an interaction within it) informs the ViewController via a delegate method (or closure/publisher).
The ViewController updates the corresponding data in its model.
The ViewController then tells the UICollectionView to reloadData(), reloadItems(at:), or reconfigureItems(at:) for the affected indexPaths.
The UICollectionViewDataSource method (cellForItemAt) will then be called, and the cell will be configured with the fresh data from the updated model.
