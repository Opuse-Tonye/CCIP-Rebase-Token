# Cross-Chain Rebase Token

1. A protocol that allows useers to deposit into a vault and in return, receives rebase token that represents their underlying balance
2. Rebase Token -> balanceOf cunction is dynamic to show the changing balance with time.
 - Balance increases linearly with time 
 - mint tokens with our users every time they perform an action (minting, burning, transfering and bridging)

3. Interest Rate
    - Individually set an interest rate to each user based on global interest rate of the protocol at the time the user deposits into the vault.
    - This global interest rate can only decrease to incentivise/ reward early adopters.
    - Increase token adoption