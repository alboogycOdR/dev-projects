import random
'''
MUST HAVE INFO
avg_swing_size:int = "swing size of a particular pair, 7:30am,london session"
'''

minimum_stake: int = 1
# bankroll = minimum_stake * 1000
bankroll = 1000 if minimum_stake == 1 else None
bankroll = 50000 if minimum_stake == 50 else bankroll
minimum_profit = minimum_stake * 2
reward_multiplier = 3


current_stake = minimum_stake
previous_losses = []


def increase_stake(current_stake, minimum_outcome) -> int:
    while current_stake*reward_multiplier < minimum_outcome:
        current_stake += minimum_stake
    return current_stake


# Simulate 30 rounds of losses
num_rounds = 0
# for i in range(num_rounds):
while bankroll:
    # print(f"Round {i+1}")
    minimum_outcome = sum(previous_losses) + minimum_profit
    potential_outcome = current_stake * reward_multiplier

    # determine the stake
    if potential_outcome < minimum_outcome:
        current_stake = increase_stake(current_stake, minimum_outcome)

    # print(f"Current stake: {current_stake}")

    bankroll -= current_stake
    if bankroll < 0:
        break

    previous_losses.append(current_stake)
    num_rounds += 1

if num_rounds == 0:
    print(f"No activity to record, record is empty.\nBankroll: {bankroll}")
print(f"{reward_multiplier}X Progression:\n {previous_losses}\n")
print(f"Total losses: {sum(previous_losses)} over {num_rounds}rounds")
# print("\n")
# num = 0
# for i in range(1000):
#     num = num+1 if random.random() > 0.99 else num

# print(num)
