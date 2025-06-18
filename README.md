Regarding automatic cell/header sizing:
In iOS 15 and 16, Apple's provided automatic calculation can be fragile and prone to crashes. This exposes us to OS-level bugs that are difficult to debug and control.
We also explored another feasible automatic calculation solution, which is possible but computationally expensive, especially during scrolling. It would require caching, which seems like an unnecessary overhead, though it is functional.
I've reviewed this, and I believe I can make changes in the ViewModel to calculate the header height there. I'm still testing this approach, but it appears to be feasible."
