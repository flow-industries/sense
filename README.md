# Sense Protocol

## Setup

### 1. Clone the Repository

```
git clone git@github.com:orb-club/flow-sense.git
```

or

```
git clone https://github.com/orb-club/flow-sense.git
```

### 2. Install dependencies

```
yarn
```

### 3. Compile

To compile the project, run:

```
npx hardhat compile
```

or

```
forge b
```

### 4. Test

```
yarn coverage:report:filtered -vvv
```

### 5. Deploy

Fill the .env with your private key, your .env should look like this:

```
WALLET_PRIVATE_KEY=0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef
```

Run the following command, which deploys the full protocol with all present Rules & Actions, and also the Global Feed, Graph, and Username primitives.

```
yarn run deploy
```

### Primitives

## Project Structure

The `contracts/` folder is divided into several main folders: `actions/`, `core/`, `extensions/`, `migration/` and `rules/`.

### Core

Contains the main contracts that make up the base Sense Protocol. These contracts are envisioned as non-opinionated and flexible, allowing for a wide range of use cases.
We expect developers to build upon them, inherit from them, extend the functionality, and be creative with them.

### Migration

Contains modified versions of the Feed and Graph primitives, which do not do any checks and just fill up the storage during the initial migration.

### Extensions

Contains the bespoke implementations of contracts for the Sense Social Protocol.
These contracts are opinionated and are designed to achieve the best experience.
These also serve as examples of how developers could build on top of the Core contracts.

### Rules

Contains contracts implementing Sense Rules. These also serve as examples of how developers could build their own Rules.

### Actions

Contains contracts implementing Sense Actions. These also serve as examples of how developers could build their own Actions.

## Acknowledgements

Sense contracts are based on [Lens V3](https://github.com/lens-protocol/lens-v3), licensed under GPL-3.0.
