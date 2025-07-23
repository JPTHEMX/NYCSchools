I have tested this scenario with two different users: User A (qc2) and User B (PROD).
* For User A (qc2): An error message appears when attempting to change the nickname. (See attached screenshot).
* For User B (PROD): I was able to change the nickname successfully, but I could not reproduce the irregular behavior described in the ticket. (See attached video).
Questions & Next Steps:
1. Could you please test again with the latest code to confirm if the issue still persists?
2. If the issue is still reproducible, could you please provide a specific user account where this behavior can be consistently replicated?
3. Could you also confirm which app version was originally tested on?
Additional Context:
I'm asking because a related fix was implemented in ticket 75852. The original issue was that fetchOffers was being called when the accountIds array was empty. This has since been fixed by adding a check to ensure the accountIds array is not empty before processing the network request. It's possible this fix has resolved the behavior described in this ticket.
