# RoboMarket: Decentralized Robotics Service Platform

## Overview

RoboMarket is a blockchain-powered marketplace that connects customers with autonomous robotics service providers through smart contract technology. The platform enables secure, trustless transactions using escrow-based payment processing, transparent reputation systems, and automated payment distribution across various robotics service categories.

## Key Features

- **Provider Registration**: On-chain credential verification and profile management
- **Multi-Category Service Ecosystem**: Support for household automation, logistics, security, maintenance, and entertainment services
- **Automated Escrow**: Secure payment holding during service execution
- **Dual Reputation System**: Separate rating systems for both providers and customers
- **Complete Service Lifecycle Management**: State validation from booking to completion
- **Transparent Fee Collection**: Platform fee tracking and governance

## Service Categories

The platform supports five main service categories:

- **Household** (ID: 100): Home automation and domestic robotics services
- **Logistics** (ID: 200): Delivery, transport, and warehouse automation
- **Security** (ID: 300): Surveillance and protection services
- **Maintenance** (ID: 400): Repair and upkeep services
- **Entertainment** (ID: 500): Recreational and event robotics

## Booking Lifecycle States

Each booking progresses through defined states:

- **Pending** (ID: 10): Initial booking created, awaiting provider acceptance
- **Confirmed** (ID: 20): Provider has accepted the booking
- **In Progress** (ID: 30): Service execution has started
- **Completed** (ID: 40): Service finished, payment released
- **Cancelled** (ID: 50): Booking cancelled, refund processed
- **Disputed** (ID: 60): Booking under dispute resolution

## Platform Economics

- **Platform Fee**: 2.5% of total transaction value (250 basis points)
- **Payment Flow**: Customer pays into escrow → Service completion → Provider receives 97.5% → Platform retains 2.5%

## Core Functions

### Provider Management

#### register-provider
Registers a new service provider on the platform.

**Parameters:**
- `name` (string-ascii 50): Business name
- `description` (string-ascii 200): Service description

**Returns:** `(response bool uint)`

**Errors:**
- ERR-PROVIDER-ALREADY-EXISTS: Provider already registered
- ERR-INVALID-PARAMETERS: Empty or invalid input strings

#### update-provider-profile
Updates existing provider profile information.

**Parameters:**
- `name` (string-ascii 50): Updated business name
- `description` (string-ascii 200): Updated service description
- `active` (bool): Availability status

**Returns:** `(response bool uint)`

### Service Listings

#### create-service
Creates a new service listing in the marketplace.

**Parameters:**
- `title` (string-ascii 100): Service title
- `description` (string-ascii 300): Detailed service description
- `category` (uint): Service category ID (100-500)
- `rate` (uint): Hourly rate in microSTX

**Returns:** `(response uint uint)` - Returns the new service ID

**Errors:**
- ERR-RESOURCE-NOT-FOUND: Provider not registered
- ERR-UNAUTHORIZED-ACCESS: Provider account inactive
- ERR-INVALID-PARAMETERS: Invalid inputs or category

#### update-service
Updates an existing service listing.

**Parameters:**
- `service-id` (uint): ID of service to update
- `title` (string-ascii 100): Updated title
- `description` (string-ascii 300): Updated description
- `rate` (uint): Updated hourly rate
- `available` (bool): Availability status

**Returns:** `(response bool uint)`

### Booking Management

#### book-service
Creates a new booking for a service with escrow payment.

**Parameters:**
- `service-id` (uint): ID of service to book
- `start-block` (uint): Block height when service should start
- `hours` (uint): Duration in hours

**Returns:** `(response uint uint)` - Returns the new booking ID

**Process:**
1. Validates service availability
2. Calculates total cost and platform fee
3. Transfers payment to escrow
4. Creates booking record

**Errors:**
- ERR-SERVICE-UNAVAILABLE: Service not available
- ERR-UNAUTHORIZED-ACCESS: Customer cannot be provider
- ERR-INVALID-PARAMETERS: Invalid duration or start time

#### accept-booking
Provider accepts a pending booking request.

**Parameters:**
- `booking-id` (uint): ID of booking to accept

**Returns:** `(response bool uint)`

**Authorization:** Only the service provider

#### start-service
Marks a confirmed booking as in-progress.

**Parameters:**
- `booking-id` (uint): ID of booking to start

**Returns:** `(response bool uint)`

**Requirements:**
- Current block height must be at or after scheduled start
- Booking must be in confirmed state

#### complete-service
Completes service and releases payment from escrow.

**Parameters:**
- `booking-id` (uint): ID of booking to complete

**Returns:** `(response bool uint)`

**Process:**
1. Validates booking is in-progress
2. Calculates provider payment (total - platform fee)
3. Transfers funds to provider
4. Updates platform fee balance
5. Updates provider earnings
6. Marks booking as completed

#### cancel-booking
Cancels a booking and refunds customer from escrow.

**Parameters:**
- `booking-id` (uint): ID of booking to cancel

**Returns:** `(response bool uint)`

**Authorization:** Customer or provider

**Restrictions:** Only pending or confirmed bookings can be cancelled

### Reputation System

#### submit-rating
Submits a rating for a completed service.

**Parameters:**
- `booking-id` (uint): ID of completed booking
- `rating` (uint): Rating value (1-5)
- `is-customer-rating` (bool): True for customer rating provider, false for provider rating customer

**Returns:** `(response bool uint)`

**Effects:**
- Customer ratings update both service and provider reputation scores
- Provider ratings are stored with the booking
- Ratings can only be submitted once per party

**Errors:**
- ERR-RATING-OUT-OF-BOUNDS: Rating not between 1 and 5
- ERR-OPERATION-ALREADY-COMPLETED: Rating already submitted
- ERR-INVALID-STATE-TRANSITION: Booking not completed

### Platform Administration

#### withdraw-fees
Allows contract owner to withdraw accumulated platform fees.

**Parameters:**
- `amount` (uint): Amount to withdraw in microSTX

**Returns:** `(response bool uint)`

**Authorization:** Contract owner only

## Read-Only Functions

### get-provider
Retrieves complete provider profile information.

**Parameters:** `provider` (principal)

**Returns:** `(optional provider-data)`

### get-service
Retrieves complete service listing information.

**Parameters:** `service-id` (uint)

**Returns:** `(optional service-data)`

### get-booking
Retrieves complete booking information.

**Parameters:** `booking-id` (uint)

**Returns:** `(optional booking-data)`

### get-provider-rating
Calculates provider's average reputation score.

**Parameters:** `provider` (principal)

**Returns:** `(optional uint)` - Average rating or none if no reviews

### get-service-rating
Calculates service's average customer rating.

**Parameters:** `service-id` (uint)

**Returns:** `(optional uint)` - Average rating or none if no reviews

### get-platform-fees
Returns current accumulated platform fee balance.

**Returns:** `uint`

### get-escrow-balance
Returns escrow balance for a specific booking.

**Parameters:** `booking-id` (uint)

**Returns:** `(optional uint)`

### get-provider-service-count
Returns total number of services created by provider.

**Parameters:** `provider` (principal)

**Returns:** `uint`

### is-registered-provider
Checks if a provider is registered.

**Parameters:** `provider` (principal)

**Returns:** `bool`

### get-platform-stats
Returns comprehensive platform statistics.

**Returns:** Object containing:
- `total-fees`: Accumulated platform fees
- `next-service-id`: Next available service ID
- `next-booking-id`: Next available booking ID
- `fee-percentage`: Platform fee percentage in basis points

## Error Codes

- **ERR-INVALID-PARAMETERS** (4000): Invalid input parameters
- **ERR-UNAUTHORIZED-ACCESS** (4001): Unauthorized operation attempt
- **ERR-PROVIDER-ALREADY-EXISTS** (4002): Provider already registered
- **ERR-INSUFFICIENT-FUNDS** (4003): Insufficient balance
- **ERR-RESOURCE-NOT-FOUND** (4004): Requested resource not found
- **ERR-SERVICE-UNAVAILABLE** (4005): Service not available for booking
- **ERR-BOOKING-NOT-ACTIVE** (4006): Booking not in active state
- **ERR-INVALID-STATE-TRANSITION** (4007): Invalid state change attempted
- **ERR-OPERATION-ALREADY-COMPLETED** (4008): Operation already performed
- **ERR-RATING-OUT-OF-BOUNDS** (4009): Rating value outside valid range

## Usage Example

### Provider Registration and Service Creation

```clarity
;; Register as a provider
(contract-call? .robomarket register-provider 
  "RoboClean Services" 
  "Professional household cleaning robots")

;; Create a service listing
(contract-call? .robomarket create-service 
  "Automated Home Cleaning"
  "Full-service home cleaning with autonomous navigation and eco-friendly supplies"
  u100  ;; household category
  u50000)  ;; 0.05 STX per hour
```

### Customer Booking Flow

```clarity
;; Book a service
(contract-call? .robomarket book-service 
  u1000  ;; service-id
  u1000000  ;; start-block
  u4)  ;; 4 hours duration

;; Provider accepts booking
(contract-call? .robomarket accept-booking u2000)

;; Provider starts service
(contract-call? .robomarket start-service u2000)

;; Provider completes service
(contract-call? .robomarket complete-service u2000)

;; Customer rates service
(contract-call? .robomarket submit-rating u2000 u5 true)
```

## Security Considerations

1. **Escrow Protection**: All payments are held in escrow until service completion
2. **State Validation**: Strict state machine prevents invalid transitions
3. **Access Control**: Function-level authorization checks prevent unauthorized actions
4. **Refund Mechanism**: Customers can cancel and receive refunds before service starts
5. **Rating Integrity**: One-time rating submission prevents manipulation

## Development and Deployment

### Prerequisites
- Stacks blockchain node or testnet access
- Clarity CLI tools
- STX tokens for transactions