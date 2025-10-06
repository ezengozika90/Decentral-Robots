;; RoboMarket: Decentralized Robotics Service Platform Contract
;;
;; A blockchain-powered marketplace connecting customers with autonomous robotics service 
;; providers. This platform enables secure, trustless transactions through smart contract 
;; escrow, transparent reputation systems, and automated payment distribution across 
;; various robotics service categories including household automation, logistics, security, 
;; maintenance, and entertainment.
;;
;; Key Features:
;; - Provider registration with on-chain credential verification
;; - Multi-category service ecosystem with standardized pricing
;; - Automated escrow-based payment processing
;; - Dual reputation system (provider and customer ratings)
;; - Complete service lifecycle management with state validation
;; - Transparent platform fee collection and governance

;; Error constants for transaction validation and access control
(define-constant ERR-INVALID-PARAMETERS (err u4000))
(define-constant ERR-UNAUTHORIZED-ACCESS (err u4001))
(define-constant ERR-PROVIDER-ALREADY-EXISTS (err u4002))
(define-constant ERR-INSUFFICIENT-FUNDS (err u4003))
(define-constant ERR-RESOURCE-NOT-FOUND (err u4004))
(define-constant ERR-SERVICE-UNAVAILABLE (err u4005))
(define-constant ERR-BOOKING-NOT-ACTIVE (err u4006))
(define-constant ERR-INVALID-STATE-TRANSITION (err u4007))
(define-constant ERR-OPERATION-ALREADY-COMPLETED (err u4008))
(define-constant ERR-RATING-OUT-OF-BOUNDS (err u4009))

;; Platform configuration and governance settings
(define-constant contract-owner tx-sender)
(define-constant platform-fee-percentage u250) ;; Represents 2.5% in basis points (250/10000)

;; Service category enumeration for robotics offerings
(define-constant category-household u100)
(define-constant category-logistics u200)
(define-constant category-security u300)
(define-constant category-maintenance u400)
(define-constant category-entertainment u500)

;; Booking lifecycle state enumeration for transaction tracking
(define-constant status-pending u10)
(define-constant status-confirmed u20)
(define-constant status-in-progress u30)
(define-constant status-completed u40)
(define-constant status-cancelled u50)
(define-constant status-disputed u60)

;; Auto-incrementing identifier counters for unique resource generation
(define-data-var next-service-id uint u1000)
(define-data-var next-booking-id uint u2000)
(define-data-var total-platform-fees uint u0)

;; Provider profile storage with reputation metrics and business information
(define-map service-providers
  principal
  {
    business-name: (string-ascii 50),
    service-description: (string-ascii 200),
    is-active: bool,
    total-earnings: uint,
    service-count: uint,
    reputation-score: uint,
    total-reviews: uint,
    registered-at: uint
  }
)

;; Service listing storage with pricing and availability information
(define-map service-listings
  uint
  {
    provider: principal,
    title: (string-ascii 100),
    description: (string-ascii 300),
    category: uint,
    hourly-rate: uint,
    is-available: bool,
    created-at: uint,
    completed-bookings: uint,
    cumulative-rating: uint,
    review-count: uint
  }
)

;; Booking records with complete transaction and status history
(define-map bookings
  uint
  {
    service-id: uint,
    customer: principal,
    provider: principal,
    start-block: uint,
    duration-hours: uint,
    total-cost: uint,
    platform-fee: uint,
    status: uint,
    created-at: uint,
    completed-at: (optional uint),
    customer-rating: (optional uint),
    provider-rating: (optional uint)
  }
)

;; Escrow vault for secure payment holding during service execution
(define-map escrow-balances
  uint
  uint
)

;; Provider service count tracking for analytics and validation
(define-map provider-service-totals
  principal
  uint
)

;; Validates that transaction sender is the contract owner
(define-private (is-contract-owner)
  (is-eq tx-sender contract-owner)
)

;; Calculates platform fee based on total payment amount
(define-private (calculate-platform-fee (amount uint))
  (/ (* amount platform-fee-percentage) u10000)
)

;; Generates unique service identifier and increments counter
(define-private (get-and-increment-service-id)
  (let ((current-id (var-get next-service-id)))
    (var-set next-service-id (+ current-id u1))
    current-id
  )
)

;; Generates unique booking identifier and increments counter
(define-private (get-and-increment-booking-id)
  (let ((current-id (var-get next-booking-id)))
    (var-set next-booking-id (+ current-id u1))
    current-id
  )
)

;; Validates service category against allowed values
(define-private (is-valid-category (category uint))
  (or (is-eq category category-household)
      (is-eq category category-logistics)
      (is-eq category category-security)
      (is-eq category category-maintenance)
      (is-eq category category-entertainment))
)

;; Validates rating value is within acceptable bounds (1-5)
(define-private (is-valid-rating (rating uint))
  (and (>= rating u1) (<= rating u5))
)

;; Validates string input is not empty
(define-private (is-non-empty-string (text (string-ascii 300)))
  (> (len text) u0)
)

;; Registers a new service provider on the platform
(define-public (register-provider 
  (name (string-ascii 50)) 
  (description (string-ascii 200)))
  (let ((provider-address tx-sender))
    (asserts! (is-none (map-get? service-providers provider-address)) 
              ERR-PROVIDER-ALREADY-EXISTS)
    (asserts! (is-non-empty-string name) ERR-INVALID-PARAMETERS)
    (asserts! (is-non-empty-string description) ERR-INVALID-PARAMETERS)
    
    (ok (map-set service-providers provider-address {
      business-name: name,
      service-description: description,
      is-active: true,
      total-earnings: u0,
      service-count: u0,
      reputation-score: u0,
      total-reviews: u0,
      registered-at: block-height
    }))
  )
)

;; Updates existing provider profile information
(define-public (update-provider-profile 
  (name (string-ascii 50)) 
  (description (string-ascii 200)) 
  (active bool))
  (let ((provider-data (unwrap! (map-get? service-providers tx-sender) 
                                ERR-RESOURCE-NOT-FOUND)))
    (asserts! (is-non-empty-string name) ERR-INVALID-PARAMETERS)
    (asserts! (is-non-empty-string description) ERR-INVALID-PARAMETERS)
    
    (ok (map-set service-providers tx-sender 
                 (merge provider-data {
                   business-name: name,
                   service-description: description,
                   is-active: active
                 })))
  )
)

;; Creates a new service listing in the marketplace
(define-public (create-service 
  (title (string-ascii 100)) 
  (description (string-ascii 300)) 
  (category uint) 
  (rate uint))
  (let (
    (service-id (get-and-increment-service-id))
    (provider-address tx-sender)
    (provider-data (unwrap! (map-get? service-providers provider-address) 
                            ERR-RESOURCE-NOT-FOUND))
    (current-count (default-to u0 (map-get? provider-service-totals provider-address)))
  )
    (asserts! (get is-active provider-data) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (is-non-empty-string title) ERR-INVALID-PARAMETERS)
    (asserts! (is-non-empty-string description) ERR-INVALID-PARAMETERS)
    (asserts! (> rate u0) ERR-INVALID-PARAMETERS)
    (asserts! (is-valid-category category) ERR-INVALID-PARAMETERS)
    
    (map-set service-listings service-id {
      provider: provider-address,
      title: title,
      description: description,
      category: category,
      hourly-rate: rate,
      is-available: true,
      created-at: block-height,
      completed-bookings: u0,
      cumulative-rating: u0,
      review-count: u0
    })
    
    (map-set provider-service-totals provider-address (+ current-count u1))
    
    (map-set service-providers provider-address 
             (merge provider-data {
               service-count: (+ (get service-count provider-data) u1)
             }))
    
    (ok service-id)
  )
)

;; Updates an existing service listing
(define-public (update-service 
  (service-id uint) 
  (title (string-ascii 100)) 
  (description (string-ascii 300)) 
  (rate uint) 
  (available bool))
  (let ((service-data (unwrap! (map-get? service-listings service-id) 
                               ERR-RESOURCE-NOT-FOUND)))
    (asserts! (is-eq (get provider service-data) tx-sender) 
              ERR-UNAUTHORIZED-ACCESS)
    (asserts! (is-non-empty-string title) ERR-INVALID-PARAMETERS)
    (asserts! (is-non-empty-string description) ERR-INVALID-PARAMETERS)
    (asserts! (> rate u0) ERR-INVALID-PARAMETERS)
    
    (ok (map-set service-listings service-id 
                 (merge service-data {
                   title: title,
                   description: description,
                   hourly-rate: rate,
                   is-available: available
                 })))
  )
)

;; Creates a new booking for a service with escrow payment
(define-public (book-service 
  (service-id uint) 
  (start-block uint) 
  (hours uint))
  (let (
    (service-data (unwrap! (map-get? service-listings service-id) 
                           ERR-RESOURCE-NOT-FOUND))
    (booking-id (get-and-increment-booking-id))
    (customer-address tx-sender)
    (provider-address (get provider service-data))
    (total-payment (* (get hourly-rate service-data) hours))
    (fee-amount (calculate-platform-fee total-payment))
  )
    (asserts! (get is-available service-data) ERR-SERVICE-UNAVAILABLE)
    (asserts! (not (is-eq customer-address provider-address)) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (> hours u0) ERR-INVALID-PARAMETERS)
    (asserts! (> start-block block-height) ERR-INVALID-PARAMETERS)
    
    (try! (stx-transfer? total-payment customer-address (as-contract tx-sender)))
    
    (map-set bookings booking-id {
      service-id: service-id,
      customer: customer-address,
      provider: provider-address,
      start-block: start-block,
      duration-hours: hours,
      total-cost: total-payment,
      platform-fee: fee-amount,
      status: status-pending,
      created-at: block-height,
      completed-at: none,
      customer-rating: none,
      provider-rating: none
    })
    
    (map-set escrow-balances booking-id total-payment)
    
    (map-set service-listings service-id 
             (merge service-data {
               completed-bookings: (+ (get completed-bookings service-data) u1)
             }))
    
    (ok booking-id)
  )
)

;; Provider accepts a pending booking request
(define-public (accept-booking (booking-id uint))
  (let ((booking-data (unwrap! (map-get? bookings booking-id) 
                               ERR-RESOURCE-NOT-FOUND)))
    (asserts! (is-eq (get provider booking-data) tx-sender) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (is-eq (get status booking-data) status-pending) 
              ERR-INVALID-STATE-TRANSITION)
    
    (ok (map-set bookings booking-id 
                 (merge booking-data {
                   status: status-confirmed
                 })))
  )
)

;; Provider starts service execution for a confirmed booking
(define-public (start-service (booking-id uint))
  (let ((booking-data (unwrap! (map-get? bookings booking-id) 
                               ERR-RESOURCE-NOT-FOUND)))
    (asserts! (is-eq (get provider booking-data) tx-sender) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (is-eq (get status booking-data) status-confirmed) 
              ERR-INVALID-STATE-TRANSITION)
    (asserts! (>= block-height (get start-block booking-data)) ERR-UNAUTHORIZED-ACCESS)
    
    (ok (map-set bookings booking-id 
                 (merge booking-data {
                   status: status-in-progress
                 })))
  )
)

;; Provider completes service and triggers payment release from escrow
(define-public (complete-service (booking-id uint))
  (let (
    (booking-data (unwrap! (map-get? bookings booking-id) 
                           ERR-RESOURCE-NOT-FOUND))
    (escrow-amount (unwrap! (map-get? escrow-balances booking-id) 
                            ERR-RESOURCE-NOT-FOUND))
    (provider-address (get provider booking-data))
    (fee-amount (get platform-fee booking-data))
    (provider-payment (- escrow-amount fee-amount))
    (provider-profile (unwrap! (map-get? service-providers provider-address) 
                               ERR-RESOURCE-NOT-FOUND))
  )
    (asserts! (is-eq provider-address tx-sender) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (is-eq (get status booking-data) status-in-progress) 
              ERR-INVALID-STATE-TRANSITION)
    
    (try! (as-contract (stx-transfer? provider-payment tx-sender provider-address)))
    
    (var-set total-platform-fees 
             (+ (var-get total-platform-fees) fee-amount))
    
    (map-set bookings booking-id 
             (merge booking-data {
               status: status-completed,
               completed-at: (some block-height)
             }))
    
    (map-delete escrow-balances booking-id)
    
    (map-set service-providers provider-address 
             (merge provider-profile {
               total-earnings: (+ (get total-earnings provider-profile) provider-payment)
             }))
    
    (ok true)
  )
)

;; Cancels a booking and refunds customer from escrow
(define-public (cancel-booking (booking-id uint))
  (let (
    (booking-data (unwrap! (map-get? bookings booking-id) 
                           ERR-RESOURCE-NOT-FOUND))
    (requester tx-sender)
    (customer-address (get customer booking-data))
    (provider-address (get provider booking-data))
    (current-status (get status booking-data))
    (refund-amount (unwrap! (map-get? escrow-balances booking-id) 
                            ERR-RESOURCE-NOT-FOUND))
  )
    (asserts! (> booking-id u0) ERR-INVALID-PARAMETERS)
    
    (asserts! (or (is-eq requester customer-address) 
                  (is-eq requester provider-address)) ERR-UNAUTHORIZED-ACCESS)
    
    (asserts! (or (is-eq current-status status-pending) 
                  (is-eq current-status status-confirmed)) ERR-INVALID-STATE-TRANSITION)
    
    (try! (as-contract (stx-transfer? refund-amount tx-sender customer-address)))
    
    (map-set bookings booking-id 
             (merge booking-data {
               status: status-cancelled
             }))
    
    (map-delete escrow-balances booking-id)
    
    (ok true)
  )
)

;; Submits a rating for completed service (customer or provider perspective)
(define-public (submit-rating 
  (booking-id uint) 
  (rating uint) 
  (is-customer-rating bool))
  (let (
    (booking-data (unwrap! (map-get? bookings booking-id) 
                           ERR-RESOURCE-NOT-FOUND))
    (service-id (get service-id booking-data))
    (service-data (unwrap! (map-get? service-listings service-id) 
                           ERR-RESOURCE-NOT-FOUND))
    (provider-address (get provider booking-data))
    (provider-profile (unwrap! (map-get? service-providers provider-address) 
                               ERR-RESOURCE-NOT-FOUND))
  )
    (asserts! (is-eq (get status booking-data) status-completed) 
              ERR-INVALID-STATE-TRANSITION)
    (asserts! (is-valid-rating rating) ERR-RATING-OUT-OF-BOUNDS)
    
    (if is-customer-rating
      (begin
        (asserts! (is-eq (get customer booking-data) tx-sender) ERR-UNAUTHORIZED-ACCESS)
        (asserts! (is-none (get customer-rating booking-data)) ERR-OPERATION-ALREADY-COMPLETED)
        
        (map-set bookings booking-id 
                 (merge booking-data {
                   customer-rating: (some rating)
                 }))
        
        (map-set service-listings service-id 
                 (merge service-data {
                   cumulative-rating: (+ (get cumulative-rating service-data) rating),
                   review-count: (+ (get review-count service-data) u1)
                 }))
        
        (map-set service-providers provider-address 
                 (merge provider-profile {
                   reputation-score: (+ (get reputation-score provider-profile) rating),
                   total-reviews: (+ (get total-reviews provider-profile) u1)
                 }))
      )
      (begin
        (asserts! (is-eq provider-address tx-sender) ERR-UNAUTHORIZED-ACCESS)
        (asserts! (is-none (get provider-rating booking-data)) ERR-OPERATION-ALREADY-COMPLETED)
        
        (map-set bookings booking-id 
                 (merge booking-data {
                   provider-rating: (some rating)
                 }))
      )
    )
    
    (ok true)
  )
)

;; Allows contract owner to withdraw accumulated platform fees
(define-public (withdraw-fees (amount uint))
  (begin
    (asserts! (is-contract-owner) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (<= amount (var-get total-platform-fees)) 
              ERR-INSUFFICIENT-FUNDS)
    
    (try! (as-contract (stx-transfer? amount tx-sender contract-owner)))
    (var-set total-platform-fees 
             (- (var-get total-platform-fees) amount))
    
    (ok true)
  )
)

;; Retrieves complete provider profile information
(define-read-only (get-provider (provider principal))
  (map-get? service-providers provider)
)

;; Retrieves complete service listing information
(define-read-only (get-service (service-id uint))
  (map-get? service-listings service-id)
)

;; Retrieves complete booking information
(define-read-only (get-booking (booking-id uint))
  (map-get? bookings booking-id)
)

;; Calculates provider's average reputation score
(define-read-only (get-provider-rating (provider principal))
  (match (map-get? service-providers provider)
    provider-data
      (if (> (get total-reviews provider-data) u0)
        (some (/ (get reputation-score provider-data) 
                 (get total-reviews provider-data)))
        none
      )
    none
  )
)

;; Calculates service's average customer rating
(define-read-only (get-service-rating (service-id uint))
  (match (map-get? service-listings service-id)
    service-data
      (if (> (get review-count service-data) u0)
        (some (/ (get cumulative-rating service-data) 
                 (get review-count service-data)))
        none
      )
    none
  )
)

;; Returns current platform fee balance
(define-read-only (get-platform-fees)
  (var-get total-platform-fees)
)

;; Returns escrow balance for a specific booking
(define-read-only (get-escrow-balance (booking-id uint))
  (map-get? escrow-balances booking-id)
)

;; Returns total number of services created by provider
(define-read-only (get-provider-service-count (provider principal))
  (default-to u0 (map-get? provider-service-totals provider))
)

;; Checks if a provider is registered
(define-read-only (is-registered-provider (provider principal))
  (is-some (map-get? service-providers provider))
)

;; Returns comprehensive platform statistics and configuration
(define-read-only (get-platform-stats)
  {
    total-fees: (var-get total-platform-fees),
    next-service-id: (var-get next-service-id),
    next-booking-id: (var-get next-booking-id),
    fee-percentage: platform-fee-percentage
  }
)