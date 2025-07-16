# Token Time Lock System - Phase 2

A comprehensive token time-locking system built on the Stacks blockchain with enhanced security features, bug fixes, and additional functionality.

## 🚀 Features

### Core Functionality
- **Time-locked token storage**: Lock STX tokens for specified periods
- **Admin role management**: Secure admin role transfer with time delays
- **Emergency controls**: Pause/unpause functionality for security
- **Batch operations**: Claim multiple token locks simultaneously
- **Token factory**: Create and manage custom tokens

### Security Enhancements
- Emergency pause mechanism
- Proper ownership validation
- Time-based access controls
- Comprehensive error handling
- Protection against common vulnerabilities

## 📋 Phase 2 Improvements

### Bug Fixes
1. **Admin Role Transfer**: Fixed incomplete admin role claiming logic
2. **Ownership Validation**: Added proper contract owner verification
3. **Time Validation**: Added checks for future unlock times
4. **Balance Verification**: Enhanced token balance validation

### New Contracts
- **Token Factory Contract**: Creates and manages custom tokens that can be time-locked

### Enhanced Security
- Emergency pause/unpause functionality
- Improved access control mechanisms
- Comprehensive input validation
- Protection against reentrancy attacks

## 🏗️ Contract Architecture

### Main Contract: `token-time-lock.clar`
- **Purpose**: Core time-locking functionality
- **Key Features**: 
  - Lock STX tokens with time delays
  - Claim tokens after unlock period
  - Emergency pause controls
  - Batch token claiming

### Auxiliary Contract: `token-factory.clar`
- **Purpose**: Custom token creation and management
- **Key Features**:
  - Create custom tokens with metadata
  - Transfer and approve token spending
  - Mint additional tokens (creator only)
  - Full SIP-010 compatibility

## 🛠️ Installation & Setup

```bash
# Clone the repository
git clone <repository-url>
cd token-time-lock

# Install Clarinet (if not already installed)
curl -L https://github.com/hirosystems/clarinet/releases/latest/download/clarinet-linux-x64.tar.gz | tar -xz
sudo mv clarinet /usr/local/bin/

# Initialize project
clarinet new token-time-lock
cd token-time-lock

# Copy contracts to contracts/ directory
# Copy the enhanced contracts to your contracts folder

# Check contract syntax
clarinet check

# Run tests
clarinet test
```

## 📖 Usage Guide

### Basic Token Locking

```clarity
;; Lock 1000 STX tokens for 100 blocks
(contract-call? .token-time-lock lock-tokens u1000 u100)

;; Check if tokens can be claimed
(contract-call? .token-time-lock can-claim-tokens tx-sender u1)

;; Claim tokens after unlock period
(contract-call? .token-time-lock claim-tokens u1)
```

### Admin Role Management

```clarity
;; Set admin (owner only)
(contract-call? .token-time-lock set-admin 'SP1ABC...DEF u1000)

;; Claim admin role (after unlock period)
(contract-call? .token-time-lock claim-admin-role)
```

### Emergency Controls

```clarity
;; Emergency pause (owner only)
(contract-call? .token-time-lock emergency-pause)

;; Resume operations (owner only)
(contract-call? .token-time-lock emergency-unpause)
```

### Custom Token Creation

```clarity
;; Create a new token
(contract-call? .token-factory create-token 
    "My Token" 
    "MTK" 
    u1000000 
    u6)

;; Transfer tokens
(contract-call? .token-factory transfer-token u1 u100 'SP1ABC...DEF)
```

## 🔧 Configuration

### Network Settings
- **Devnet**: Local development environment
- **Testnet**: Stacks testnet for testing
- **Mainnet**: Production deployment

### Key Parameters
- **Lock Duration**: Minimum 1 block, no maximum limit
- **Token Amount**: Must be greater than 0
- **Admin Unlock**: Must be set to future block height

## 🧪 Testing

```bash
# Run all tests
clarinet test

# Run specific test file
clarinet test tests/token-time-lock-test.ts

# Check contract syntax
clarinet check

# Generate coverage report
clarinet test --coverage
```

## �� Contract Functions

### Public Functions

| Function | Description | Parameters |
|----------|-------------|------------|
| `lock-tokens` | Lock STX tokens with time delay | `amount`, `unlock-block` |
| `claim-tokens` | Claim unlocked tokens | `lock-id` |
| `set-admin` | Set admin principal with time lock | `who`, `unlock-block` |
| `claim-admin-role` | Claim admin role after unlock | None |
| `emergency-pause` | Pause contract operations | None |
| `emergency-unpause` | Resume contract operations | None |
| `batch-claim-tokens` | Claim multiple token locks | `lock-ids` |

### Read-Only Functions

| Function | Description | Returns |
|----------|-------------|---------|
| `get-lock-info` | Get token lock details | Lock information |
| `get-user-lock-count` | Get user's total locks | Lock count |
| `get-total-locked` | Get total locked amount | Total amount |
| `get-contract-owner` | Get contract owner | Principal |
| `is-paused` | Check if contract is paused | Boolean |
| `can-claim-tokens` | Check if tokens can be claimed | Boolean |

## 🔐 Security Features

### Access Control
- Owner-only administrative functions
- Time-based permission validation
- Emergency pause mechanism

### Input Validation
- Amount validation (must be > 0)
- Time validation (unlock must be in future)
- Balance verification before locking

### Error Handling
- Comprehensive error constants
- Proper error propagation
- Informative error messages

## 📈 Gas Optimization

- Efficient data structures
- Minimal storage operations
- Optimized function calls
- Reduced computational complexity

## 🛡️ Common Vulnerabilities Addressed

1. **Reentrancy**: Protected through state updates before external calls
2. **Integer Overflow**: Using safe arithmetic operations
3. **Access Control**: Proper permission validation
4. **Time Manipulation**: Block height validation
5. **Emergency Response**: Pause mechanism for critical issues

## 🔮 Future Enhancements

- Multi-token support
- Governance mechanisms
- Yield farming integration
- Cross-chain compatibility
- Advanced analytics dashboard

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make changes with proper testing
4. Submit a pull request
5. Ensure all tests pass

## �� Support

For issues, questions, or contributions:
- Create an issue in the repository
- Contact: midorichie@example.com
- Documentation: See inline code comments

---

**Version**: 2.0.0  
**Last Updated**: July 2025  
**Blockchain**: Stacks  
**Language**: Clarity
