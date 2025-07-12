# FlexiTrust

A decentralized freelance escrow platform built on Stacks blockchain, enabling secure payments between clients and freelancers with automated dispute resolution.

## Overview

FlexiTrust provides a trustless escrow system where clients can securely pay freelancers for completed work. The platform holds funds in escrow until project completion and includes dispute resolution mechanisms to protect both parties.

## Features

- **Secure Escrow**: Funds are held in smart contract until work completion
- **Automated Payments**: Instant payment release upon client approval
- **Dispute Resolution**: Built-in mechanism for handling disagreements
- **Platform Fees**: Transparent fee structure (2.5% default)
- **Project Management**: Track project status and deadlines
- **Cancellation Protection**: Refund mechanism for cancelled projects

## Smart Contract Functions

### Public Functions

- `create-project`: Create a new freelance project with escrow
- `complete-project`: Mark project as completed and release funds
- `cancel-project`: Cancel active project and refund client
- `dispute-project`: Initiate dispute resolution process

### Read-Only Functions

- `get-project`: Retrieve project details
- `get-project-funds`: View escrow balance and fees
- `calculate-platform-fee`: Calculate fees for given amount

### Admin Functions

- `resolve-dispute`: Resolve disputes and distribute funds
- `set-platform-fee-percentage`: Adjust platform fee rates
- `withdraw-fees`: Withdraw accumulated platform fees

## Usage

1. **Create Project**: Client creates project with freelancer address, amount, and deadline
2. **Work Progress**: Freelancer completes work according to project requirements
3. **Completion**: Client approves work and releases escrowed funds
4. **Dispute**: Either party can initiate dispute if needed

## Technical Details

- **Blockchain**: Stacks
- **Smart Contract Language**: Clarity
- **Token**: STX (Stacks)
- **Fee Structure**: Basis points (250 = 2.5%)

## Security Features

- Input validation for all parameters
- Access control for sensitive operations
- Overflow protection for arithmetic operations
- Proper error handling throughout

## Getting Started

### Prerequisites

- Clarinet CLI tool
- Stacks wallet
- STX tokens for transactions

### Installation

1. Clone the repository
2. Run `clarinet check` to verify contract
3. Deploy to testnet for testing
4. Deploy to mainnet for production

## Testing

Run the test suite with:
```bash
clarinet test
```

## Contributing

Contributions are welcome! Please read our contributing guidelines and submit pull requests for any improvements.

## License

MIT License - see LICENSE file for details

## Support

For support and questions, please open an issue in the GitHub repository.