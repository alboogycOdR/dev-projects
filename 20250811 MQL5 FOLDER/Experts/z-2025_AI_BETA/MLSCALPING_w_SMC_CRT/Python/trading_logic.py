import pandas as pd
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import train_test_split
import numpy as np

def identify_smc_patterns(data):
    """Identifies various Smart Money Concepts (SMC) patterns."""
    # Identify Break of Structure (BOS)
    data["bos"] = (data["high"] > data["high"].shift(1)) & (data["close"] > data["open"])

    # Identify Change of Character (ChoCH)
    data["choch"] = (data["low"] < data["low"].shift(1)) & (data["bos"].shift(1) == True)

    # Identify Order Blocks (simplified)
    # A bearish candle before a strong bullish move
    data["order_block_bullish"] = (data["open"].shift(1) > data["close"].shift(1)) & (data["close"] > data["open"].shift(1))
    # A bullish candle before a strong bearish move
    data["order_block_bearish"] = (data["open"].shift(1) < data["close"].shift(1)) & (data["close"] < data["open"].shift(1))

    # Identify Fair Value Gaps (simplified)
    data["fair_value_gap_bullish"] = data["low"] > data["high"].shift(2)
    data["fair_value_gap_bearish"] = data["high"] < data["low"].shift(2)

    return data

def identify_all_crt_patterns(data):
    """Identifies various Candle Range Theory (CRT) patterns based on the provided specification.
    Returns a list of dictionaries, each representing a detected CRT event.
    """
    crt_patterns = []
    # Ensure data is timezone-aware and in 'America/New_York'
    if data.index.tz is None:
        data.index = data.index.tz_localize('UTC').tz_convert('America/New_York')
    else:
        data.index = data.index.tz_convert('America/New_York')

    for i in range(2, len(data)): # Start from index 2 for 3-candle patterns
        C_i = data.iloc[i] # Current candle
        C_i_minus_1 = data.iloc[i-1] # Previous candle
        C_i_minus_2 = data.iloc[i-2] # Two candles ago

        # 1. Classic 3-Candle CRT
        # Bullish 3-Candle CRT
        if (C_i_minus_1['low'] < C_i_minus_2['low']) and \
           (C_i_minus_1['close'] > C_i_minus_2['low']):
            crt_patterns.append({
                'timestamp': C_i.name,
                'pattern_name': 'Classic 3-Candle Bullish',
                'crt_high': C_i_minus_2['high'],
                'crt_low': C_i_minus_2['low'],
                'target_dol': C_i_minus_2['high']
            })

        # Bearish 3-Candle CRT
        if (C_i_minus_1['high'] > C_i_minus_2['high']) and \
           (C_i_minus_1['close'] < C_i_minus_2['high']):
            crt_patterns.append({
                'timestamp': C_i.name,
                'pattern_name': 'Classic 3-Candle Bearish',
                'crt_high': C_i_minus_2['high'],
                'crt_low': C_i_minus_2['low'],
                'target_dol': C_i_minus_2['low']
            })

    for i in range(1, len(data)): # Start from index 1 for 2-candle patterns
        C_i = data.iloc[i] # Current candle
        C_i_minus_1 = data.iloc[i-1] # Previous candle

        # 2. 2-Candle CRT
        # Bullish 2-Candle CRT
        if (C_i['low'] < C_i_minus_1['low']) and \
           (C_i['close'] > C_i_minus_1['high']):
            crt_patterns.append({
                'timestamp': C_i.name,
                'pattern_name': '2-Candle Bullish',
                'crt_high': C_i_minus_1['high'],
                'crt_low': C_i_minus_1['low'],
                'target_dol': C_i_minus_1['high']
            })

        # Bearish 2-Candle CRT
        if (C_i['high'] > C_i_minus_1['high']) and \
           (C_i['close'] < C_i_minus_1['low']):
            crt_patterns.append({
                'timestamp': C_i.name,
                'pattern_name': '2-Candle Bearish',
                'crt_high': C_i_minus_1['high'],
                'crt_low': C_i_minus_1['low'],
                'target_dol': C_i_minus_1['low']
            })

    # 3. Inside Bar CRT
    # This requires iterating backwards to find the Mother Bar
    for i in range(1, len(data)): # Iterate from the second candle
        C_i = data.iloc[i] # Current candle (potential Breakout Candle)
        
        mother_bar_idx = -1
        for j in range(i - 1, -1, -1): # Iterate backwards from C[i-1]
            C_j = data.iloc[j]
            if j == i - 1: # First candle to check is C[i-1]
                if not ((C_i_minus_1['high'] < C_j['high']) and (C_i_minus_1['low'] > C_j['low'])):
                    mother_bar_idx = j
                    break
            else:
                # Check if C_j is an inside bar relative to C_j+1
                if not ((data.iloc[j+1]['high'] < C_j['high']) and (data.iloc[j+1]['low'] > C_j['low'])):
                    mother_bar_idx = j
                    break
        
        if mother_bar_idx != -1:
            mother_bar = data.iloc[mother_bar_idx]
            # Check if all candles between mother_bar and C_i are inside bars relative to mother_bar
            is_inside_bar_sequence = True
            for k in range(mother_bar_idx + 1, i):
                if not ((data.iloc[k]['high'] < mother_bar['high']) and (data.iloc[k]['low'] > mother_bar['low'])):
                    is_inside_bar_sequence = False
                    break
            
            if is_inside_bar_sequence:
                # Bullish Inside Bar CRT
                if (C_i['low'] < mother_bar['low']) and (C_i['close'] > mother_bar['low']):
                    crt_patterns.append({
                        'timestamp': C_i.name,
                        'pattern_name': 'Inside Bar Bullish',
                        'crt_high': mother_bar['high'],
                        'crt_low': mother_bar['low'],
                        'target_dol': mother_bar['high']
                    })
                # Bearish Inside Bar CRT
                elif (C_i['high'] > mother_bar['high']) and (C_i['close'] < mother_bar['high']):
                    crt_patterns.append({
                        'timestamp': C_i.name,
                        'pattern_name': 'Inside Bar Bearish',
                        'crt_high': mother_bar['high'],
                        'crt_low': mother_bar['low'],
                        'target_dol': mother_bar['low']
                    })

    # 4. Multiple Candle CRT (Flagging Impulse Candle)
    # Calculate ATR (Average True Range)
    # True Range (TR) = max[(high - low), abs(high - close_prev), abs(low - close_prev)]
    data['tr1'] = data['high'] - data['low']
    data['tr2'] = abs(data['high'] - data['close'].shift(1))
    data['tr3'] = abs(data['low'] - data['close'].shift(1))
    data['tr'] = data[['tr1', 'tr2', 'tr3']].max(axis=1)
    data['atr'] = data['tr'].rolling(14).mean()

    for i in range(len(data)): # Iterate through all candles
        C_i = data.iloc[i]
        if pd.notna(C_i['atr']) and (C_i['high'] - C_i['low']) > (1.5 * C_i['atr']):
            pattern_name = 'Multiple Candle Impulse Bullish' if C_i['close'] > C_i['open'] else 'Multiple Candle Impulse Bearish'
            crt_patterns.append({
                'timestamp': C_i.name,
                'pattern_name': pattern_name,
                'crt_high': C_i['high'],
                'crt_low': C_i['low'],
                'target_dol': np.nan # Not specified for this pattern
            })

    return crt_patterns

def feature_engineering(data):
    """Creates features for the ML model."""
    data = identify_smc_patterns(data)

    # Add CRT patterns as boolean features for ML model
    # Initialize all CRT columns to False
    data['classic_3_candle_bullish'] = False
    data['classic_3_candle_bearish'] = False
    data['two_candle_bullish'] = False
    data['two_candle_bearish'] = False
    data['inside_bar_bullish'] = False
    data['inside_bar_bearish'] = False
    data['multiple_candle_impulse_bullish'] = False
    data['multiple_candle_impulse_bearish'] = False

    detected_crts = identify_all_crt_patterns(data)
    for pattern in detected_crts:
        timestamp = pattern['timestamp']
        pattern_name = pattern['pattern_name']
        
        # Map pattern names to boolean columns
        if pattern_name == 'Classic 3-Candle Bullish':
            data.loc[timestamp, 'classic_3_candle_bullish'] = True
        elif pattern_name == 'Classic 3-Candle Bearish':
            data.loc[timestamp, 'classic_3_candle_bearish'] = True
        elif pattern_name == '2-Candle Bullish':
            data.loc[timestamp, 'two_candle_bullish'] = True
        elif pattern_name == '2-Candle Bearish':
            data.loc[timestamp, 'two_candle_bearish'] = True
        elif pattern_name == 'Inside Bar Bullish':
            data.loc[timestamp, 'inside_bar_bullish'] = True
        elif pattern_name == 'Inside Bar Bearish':
            data.loc[timestamp, 'inside_bar_bearish'] = True
        elif pattern_name == 'Multiple Candle Impulse Bullish':
            data.loc[timestamp, 'multiple_candle_impulse_bullish'] = True
        elif pattern_name == 'Multiple Candle Impulse Bearish':
            data.loc[timestamp, 'multiple_candle_impulse_bearish'] = True

    # Add some basic technical indicators as features
    data["rsi"] = 100 - (100 / (1 + data["close"].diff().rolling(14).apply(lambda x: x[x > 0].sum() / -x[x < 0].sum(), raw=False)))
    data["macd"] = data["close"].ewm(span=12, adjust=False).mean() - data["close"].ewm(span=26, adjust=False).mean()

    # Create a target variable (simplified for demonstration)
    # In a real scenario, this would be based on future price movement (e.g., did price go up by X% in the next N bars?)
    data["target"] = (data["close"].shift(-5) > data["close"]).astype(int) # Predict if price will be higher in 5 bars

    data = data.dropna()
    return data

def train_ml_model(data):
    """Trains the machine learning model."""
    features = ["bos", "choch", "order_block_bullish", "order_block_bearish", 
                "fair_value_gap_bullish", "fair_value_gap_bearish", 
                'classic_3_candle_bullish', 'classic_3_candle_bearish',
                'two_candle_bullish', 'two_candle_bearish',
                'inside_bar_bullish', 'inside_bar_bearish',
                'multiple_candle_impulse_bullish', 'multiple_candle_impulse_bearish',
                "rsi", "macd"]
    X = data[features]
    y = data["target"]

    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)

    model = RandomForestClassifier(n_estimators=100, random_state=42)
    model.fit(X_train, y_train)

    print(f"Model Accuracy: {model.score(X_test, y_test)}")

    return model

def get_trading_signal(data, model):
    """Generates a trading signal based on the latest data and the ML model."""
    last_data_point = data.iloc[-1:]

    features = ["bos", "choch", "order_block_bullish", "order_block_bearish", 
                "fair_value_gap_bullish", "fair_value_gap_bearish", 
                'classic_3_candle_bullish', 'classic_3_candle_bearish',
                'two_candle_bullish', 'two_candle_bearish',
                'inside_bar_bullish', 'inside_bar_bearish',
                'multiple_candle_impulse_bullish', 'multiple_candle_impulse_bearish',
                "rsi", "macd"]
    X_last = last_data_point[features]

    prediction = model.predict(X_last)[0]
    probability = model.predict_proba(X_last)[0]

    if prediction == 1 and probability[1] > 0.7: # High confidence buy
        return "BUY"
    elif prediction == 0 and probability[0] > 0.7: # High confidence sell
        return "SELL"
    else:
        return "HOLD"

if __name__ == "__main__":
    # This is a placeholder for where we'll get the data from MQ5
    # For now, we'll create some dummy data for demonstration
    dummy_data = {
        'time': pd.to_datetime(pd.date_range(start='2023-01-01', periods=200, freq='min')),
        'open': np.random.rand(200) * 10 + 100,
        'high': np.random.rand(200) * 10 + 105,
        'low': np.random.rand(200) * 10 + 95,
        'close': np.random.rand(200) * 10 + 100,
        'tick_volume': np.random.randint(100, 1000, 200)
    }
    data = pd.DataFrame(dummy_data)
    data = data.set_index('time')

    # Feature Engineering
    data = feature_engineering(data)

    # Train the model
    model = train_ml_model(data)

    # Get a trading signal for the latest data
    signal = get_trading_signal(data, model)

    print(f"\nTrading Signal: {signal}")
    print("\nLatest Data with Identified Patterns:")
    print(data.tail())

    # Test CRT pattern identification separately
    print("\nDetected CRT Patterns (separate test):")
    test_data = pd.DataFrame({
        'time': pd.to_datetime(['2023-01-01 09:00:00', '2023-01-01 09:01:00', '2023-01-01 09:02:00', '2023-01-01 09:03:00', '2023-01-01 09:04:00', '2023-01-01 09:05:00'], tz='America/New_York'),
        'open': [100, 101, 99, 102, 100, 103],
        'high': [102, 103, 101, 104, 102, 105],
        'low': [98, 99, 97, 100, 98, 101],
        'close': [101, 100, 100, 103, 101, 104]
    }).set_index('time')
    
    detected_patterns = identify_all_crt_patterns(test_data)
    for p in detected_patterns:
        print(p)


