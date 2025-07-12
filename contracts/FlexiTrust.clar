;; FlexiTrust - Decentralized Freelance Escrow Platform
;; A secure escrow system for freelance work payments

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-invalid-amount (err u103))
(define-constant err-invalid-status (err u104))
(define-constant err-already-exists (err u105))
(define-constant err-insufficient-funds (err u106))

;; Data Variables
(define-data-var contract-enabled bool true)
(define-data-var platform-fee-percentage uint u250) ;; 2.5% (250 basis points)
(define-data-var next-project-id uint u1)

;; Data Maps
(define-map projects
  uint
  {
    client: principal,
    freelancer: principal,
    amount: uint,
    status: (string-ascii 20),
    created-at: uint,
    deadline: uint,
    description: (string-ascii 500)
  }
)

(define-map project-funds
  uint
  {
    escrow-balance: uint,
    fee-collected: uint
  }
)

;; Read-only functions
(define-read-only (get-project (project-id uint))
  (map-get? projects project-id)
)

(define-read-only (get-project-funds (project-id uint))
  (map-get? project-funds project-id)
)

(define-read-only (get-contract-enabled)
  (var-get contract-enabled)
)

(define-read-only (get-platform-fee-percentage)
  (var-get platform-fee-percentage)
)

(define-read-only (get-next-project-id)
  (var-get next-project-id)
)

(define-read-only (calculate-platform-fee (amount uint))
  (begin
    (asserts! (> amount u0) err-invalid-amount)
    (asserts! (< amount u1000000000000) err-invalid-amount)
    (ok (/ (* amount (var-get platform-fee-percentage)) u10000))
  )
)

;; Private functions
(define-private (is-valid-status (status (string-ascii 20)))
  (or (is-eq status "active")
      (or (is-eq status "completed")
          (or (is-eq status "disputed")
              (is-eq status "cancelled"))))
)

(define-private (is-project-participant (project-id uint) (user principal))
  (match (map-get? projects project-id)
    project-data
    (begin
      (asserts! (> project-id u0) false)
      (or (is-eq user (get client project-data))
          (is-eq user (get freelancer project-data)))
    )
    false
  )
)

;; Public functions
(define-public (create-project 
  (freelancer principal)
  (amount uint)
  (deadline uint)
  (description (string-ascii 500))
)
  (let (
    (project-id (var-get next-project-id))
    (platform-fee (unwrap! (calculate-platform-fee amount) err-invalid-amount))
    (total-required (+ amount platform-fee))
    (current-balance (stx-get-balance tx-sender))
  )
    (asserts! (var-get contract-enabled) err-invalid-status)
    (asserts! (> amount u0) err-invalid-amount)
    (asserts! (< amount u1000000000000) err-invalid-amount) ;; Max amount check
    (asserts! (> deadline stacks-block-height) err-invalid-amount)
    (asserts! (< deadline (+ stacks-block-height u52560)) err-invalid-amount) ;; Max 1 year deadline
    (asserts! (not (is-eq tx-sender freelancer)) err-unauthorized)
    (asserts! (>= current-balance total-required) err-insufficient-funds)
    (asserts! (> (len description) u0) err-invalid-amount)
    
    ;; Transfer funds to contract
    (try! (stx-transfer? total-required tx-sender (as-contract tx-sender)))
    
    ;; Create project record
    (map-set projects project-id {
      client: tx-sender,
      freelancer: freelancer,
      amount: amount,
      status: "active",
      created-at: stacks-block-height,
      deadline: deadline,
      description: description
    })
    
    ;; Set project funds
    (map-set project-funds project-id {
      escrow-balance: amount,
      fee-collected: platform-fee
    })
    
    ;; Increment project ID
    (var-set next-project-id (+ project-id u1))
    
    (ok project-id)
  )
)

(define-public (complete-project (project-id uint))
  (let (
    (project-data (unwrap! (map-get? projects project-id) err-not-found))
    (funds-data (unwrap! (map-get? project-funds project-id) err-not-found))
    (client (get client project-data))
    (freelancer (get freelancer project-data))
    (amount (get amount project-data))
    (escrow-balance (get escrow-balance funds-data))
  )
    (asserts! (var-get contract-enabled) err-invalid-status)
    (asserts! (is-eq tx-sender client) err-unauthorized)
    (asserts! (is-eq (get status project-data) "active") err-invalid-status)
    (asserts! (> escrow-balance u0) err-insufficient-funds)
    (asserts! (is-eq amount escrow-balance) err-invalid-amount)
    
    ;; Transfer funds to freelancer
    (try! (as-contract (stx-transfer? amount tx-sender freelancer)))
    
    ;; Update project status
    (map-set projects project-id (merge project-data {status: "completed"}))
    
    ;; Clear escrow balance
    (map-set project-funds project-id (merge funds-data {escrow-balance: u0}))
    
    (ok true)
  )
)

(define-public (cancel-project (project-id uint))
  (let (
    (project-data (unwrap! (map-get? projects project-id) err-not-found))
    (funds-data (unwrap! (map-get? project-funds project-id) err-not-found))
    (client (get client project-data))
    (amount (get amount project-data))
    (escrow-balance (get escrow-balance funds-data))
    (platform-fee (get fee-collected funds-data))
  )
    (asserts! (var-get contract-enabled) err-invalid-status)
    (asserts! (is-eq tx-sender client) err-unauthorized)
    (asserts! (is-eq (get status project-data) "active") err-invalid-status)
    (asserts! (> escrow-balance u0) err-insufficient-funds)
    (asserts! (is-eq amount escrow-balance) err-invalid-amount)
    
    ;; Refund client (minus platform fee for cancellation)
    (try! (as-contract (stx-transfer? amount tx-sender client)))
    
    ;; Update project status
    (map-set projects project-id (merge project-data {status: "cancelled"}))
    
    ;; Clear escrow balance
    (map-set project-funds project-id (merge funds-data {escrow-balance: u0}))
    
    (ok true)
  )
)

(define-public (dispute-project (project-id uint))
  (let (
    (project-data (unwrap! (map-get? projects project-id) err-not-found))
  )
    (asserts! (var-get contract-enabled) err-invalid-status)
    (asserts! (> project-id u0) err-invalid-amount)
    (asserts! (is-project-participant project-id tx-sender) err-unauthorized)
    (asserts! (is-eq (get status project-data) "active") err-invalid-status)
    
    ;; Update project status to disputed
    (map-set projects project-id (merge project-data {status: "disputed"}))
    
    (ok true)
  )
)

;; Admin functions
(define-public (set-contract-enabled (enabled bool))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (var-set contract-enabled enabled)
    (ok true)
  )
)

(define-public (set-platform-fee-percentage (new-fee uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (<= new-fee u1000) err-invalid-amount) ;; Max 10%
    (var-set platform-fee-percentage new-fee)
    (ok true)
  )
)

(define-public (resolve-dispute (project-id uint) (winner-is-freelancer bool))
  (let (
    (project-data (unwrap! (map-get? projects project-id) err-not-found))
    (funds-data (unwrap! (map-get? project-funds project-id) err-not-found))
    (client (get client project-data))
    (freelancer (get freelancer project-data))
    (amount (get amount project-data))
    (escrow-balance (get escrow-balance funds-data))
  )
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (is-eq (get status project-data) "disputed") err-invalid-status)
    (asserts! (> escrow-balance u0) err-insufficient-funds)
    (asserts! (is-eq amount escrow-balance) err-invalid-amount)
    
    ;; Transfer funds to winner
    (if winner-is-freelancer
      (try! (as-contract (stx-transfer? amount tx-sender freelancer)))
      (try! (as-contract (stx-transfer? amount tx-sender client)))
    )
    
    ;; Update project status
    (map-set projects project-id (merge project-data {status: "completed"}))
    
    ;; Clear escrow balance
    (map-set project-funds project-id (merge funds-data {escrow-balance: u0}))
    
    (ok true)
  )
)

(define-public (withdraw-fees)
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (let (
      (contract-balance (stx-get-balance (as-contract tx-sender)))
    )
      (asserts! (> contract-balance u0) err-insufficient-funds)
      (try! (as-contract (stx-transfer? contract-balance tx-sender contract-owner)))
      (ok contract-balance)
    )
  )
)