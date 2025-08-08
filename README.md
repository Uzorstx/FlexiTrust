# FlexiTrust

A decentralized freelance escrow platform built on Stacks blockchain, enabling secure payments between clients and freelancers with automated dispute resolution and multi-milestone project support.

## Overview

FlexiTrust provides a trustless escrow system where clients can securely pay freelancers for completed work. The platform holds funds in escrow until project completion and includes dispute resolution mechanisms to protect both parties. Projects can be structured as single payments or broken down into multiple milestones for better progress tracking and risk management.

## Features

- **Secure Escrow**: Funds are held in smart contract until work completion
- **Multi-Milestone Projects**: Break large projects into smaller milestones with partial payments
- **Automated Payments**: Instant payment release upon client approval
- **Dispute Resolution**: Built-in mechanism for handling disagreements
- **Platform Fees**: Transparent fee structure (2.5% default)
- **Project Management**: Track project status and deadlines
- **Cancellation Protection**: Refund mechanism for cancelled projects
- **Milestone Tracking**: Individual milestone status and payment tracking

## Smart Contract Functions

### Public Functions

- `create-project`: Create a new freelance project with escrow
- `create-milestone-project`: Create a project with multiple milestones
- `add-milestone`: Add a new milestone to an existing project
- `complete-milestone`: Complete and release payment for a specific milestone
- `complete-project`: Mark project as completed and release funds
- `cancel-project`: Cancel active project and refund client
- `dispute-project`: Initiate dispute resolution process

### Read-Only Functions

- `get-project`: Retrieve project details
- `get-project-funds`: View escrow balance and fees
- `get-milestone`: Get details of a specific milestone
- `get-project-milestones`: Get all milestones for a project
- `get-milestone-count`: Get total number of milestones for a project
- `calculate-platform-fee`: Calculate fees for given amount

### Admin Functions

- `resolve-dispute`: Resolve disputes and distribute funds
- `set-platform-fee-percentage`: Adjust platform fee rates
- `withdraw-fees`: Withdraw accumulated platform fees

## Usage

### Single Payment Projects

1. **Create Project**: Client creates project with freelancer address, amount, and deadline
2. **Work Progress**: Freelancer completes work according to project requirements
3. **Completion**: Client approves work and releases escrowed funds
4. **Dispute**: Either party can initiate dispute if needed

### Multi-Milestone Projects

1. **Create Milestone Project**: Client creates project and defines initial milestones
2. **Add Milestones**: Additional milestones can be added during project lifecycle
3. **Complete Milestones**: Client approves and releases payment for each completed milestone
4. **Project Completion**: Project is automatically marked complete when all milestones are finished

## Technical Details

- **Blockchain**: Stacks
- **Smart Contract Language**: Clarity
- **Token**: STX (Stacks)
- **Fee Structure**: Basis points (250 = 2.5%)
- **Milestone Support**: Up to 50 milestones per project

## Security Features

- Input validation for all parameters
- Access control for sensitive operations
- Overflow protection for arithmetic operations
- Proper error handling throughout
- Milestone-specific dispute resolution
- Automatic project completion tracking

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

## Roadmap

### ✅ Completed Features
- **Multi-Milestone Projects**: Break large projects into smaller milestones with partial payments

### 🚧 In Development
- **Reputation System**: Track and display freelancer/client ratings and completion history
- **Token Integration**: Support for custom project tokens and multi-currency payments

### 📋 Planned Features
- **Automated Deadlines**: Implement automatic dispute initiation for overdue projects
- **Skill-Based Matching**: Add freelancer skill tags and client requirement matching
- **Time Tracking**: Integrate work time tracking with hourly payment calculations
- **Team Projects**: Support for multi-freelancer collaborative projects
- **Insurance Integration**: Optional project insurance for high-value contracts
- **Review System**: Detailed project reviews and feedback mechanisms
- **API Integration**: External API connections for project management tools and notifications

### 🔮 Future Enhancements
- Advanced analytics and reporting dashboard
- Mobile application for iOS and Android
- Integration with popular freelance platforms
- Smart contract templates for different project types
- Decentralized governance for platform decisions

## Contributing

Contributions are welcome! Please read our contributing guidelines and submit pull requests for any improvements.