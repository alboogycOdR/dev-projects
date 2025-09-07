# LongTail Trading Strategy

An Expert Advisor that implements the LongTail trading strategy, designed to capitalize on trends while surviving ranging markets.

## Overview

LongTail is a modified version of the Remora strategy that uses a 1:R reward system (where R > 1). The current implementation focuses on a 1:3 reward ratio.

### Key Features

- Dynamic grid-based trading system
- Automated recovery mechanism for ranging markets
- Daily session management capability 
- Progression sequence for position sizing
- Advanced delay management for price gaps

## Strategy Components

The EA is organized into several key components:

- **Core Management**
  - Daily session control
  - Position monitoring
  - Strategy rule enforcement

- **Grid Management**
  - Exit position handling
  - Recovery position placement
  - Continuation order management

- **Risk Management**
  - Dynamic position sizing
  - Progressive lot sequence
  - Multiple validation checks

## Configuration

Key parameters that can be configured:

```
input bool   use_daily_session = false;  // Enable/disable daily sessions
input int    multiplier = 3;             // Reward multiplier
input int    sequenceLength = 50;        // Length of progression sequence
```

Default session times (when daily sessions enabled):
- Start: 08:30
- End: 18:30

## Requirements

- MetaTrader 5 Platform
- Account with appropriate broker permissions
- Sufficient margin for progression sequence

## Project Structure

```
LongTail-Strategy/
├── Main/
│   └── LongTailsScalperV1.mq5       # Main EA entry point
├── Modules/
│   ├── ControlInterface/            # Core business logic
│   │   ├── SequenceHandler/         # Progression sequence management
│   │   ├── ProgressionCycleHandler/ # Trading cycle management  
│   │   ├── GridStopsHandler/        # Stop orders management
│   │   ├── GridShiftHandler/        # Grid movement logic
│   │   └── ErrorCorrectionHandler/  # Error handling and rules
│   └── AuditInterface/             # Logging and monitoring
├── Abstract/                       # Documentation and planning
└── Documentation.md               
```

## Installation

1. Clone the repository to your local MetaEditor project directory
2. Compile the main EA file (`LongTailsScalperV1.mq5`)
3. Attach the EA to your desired chart in MetaTrader 5

## Usage Guidelines

- Primary focus is on XAU/USD with a grid spread of 40 points
- Can potentially be used with Volatility 75 and 75(1s)
- Requires careful monitoring during initial deployment
- Recommended to test thoroughly on a demo account first

## Known Limitations

- Slippage can affect order placement
- Spread variations may impact strategy performance
- Maximum range survival threshold is still under study

## Development Status

Current version: 1.73

Status: Under active development and testing

## License

Copyright © 2025 Anyim Ossi

Contact: anyimossi.dev@gmail.com
