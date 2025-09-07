
def build_sequence(reward_multiplier: int, sequence_length: int):
  '''
  Computes the progression sequence used in determining the lot sizes
  Args:
    reward_multiplier: Potential reward for each risk
    sequence_length : Length of progression sequence
  Returns: an array of 50 integers
  '''

  minimum_stake: int = 1
  minimum_profit = minimum_stake * 2
  current_stake = minimum_stake
  progression_sequence = []

  for i in range(sequence_length):
    minimum_outcome = sum(progression_sequence) + minimum_profit
    while current_stake * reward_multiplier < minimum_outcome:
        current_stake += minimum_stake   
    progression_sequence.append(current_stake)

  return progression_sequence 
  
def build_lot_sequence(account_balance=10000):
  '''
  Builds an array of lot size progression relative the users account balance
  '''
  # the minimum stake depends on the pip value of the pair, and the account balance
  # for now we'll build with XAU/USD in mind
  # ====================================================================== +
  # Build the base lot sequence
  # ideally, the first term of the lot sequence should be the lot 
  # that produces the first term of the progression sequence at grid size pips
  # but we would use assumptions for speed sake
  # for speed we develop with symbol minimal volume 0.01 (1/100) - XAU/USD our grid is 200 points(2usd)
  # for volatility 75-1s minimum lot is 0.05 and our grid is 2000 points(1usd)
  # ====================================================================== +
  progression_sequence = build_sequence(3, 20)
  print(progression_sequence)
  print(f'\n total= {sum(progression_sequence)}')

  minimum_lot = 0.005
  sequence_factor = progression_sequence[0]/minimum_lot
  base_lot_sequence = [term/sequence_factor for term in progression_sequence if term > 0]
  print(base_lot_sequence)
  print(sum(base_lot_sequence))
  # print(sum([ 0.005, 0.005, 0.010, 0.010, 0.015, 0.020, 0.025, 0.035, 0.045, 0.065, 0.085, 0.110, 0.150, 0.200, 0.265, 0.355, 0.470, 0.630, 0.840, 1.120 ]))


build_lot_sequence(10000)

