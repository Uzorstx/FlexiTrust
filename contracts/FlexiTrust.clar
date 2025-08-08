;; FlexiTrust - Decentralized Freelance Escrow Platform
;; A secure escrow system for freelance work payments with multi-milestone support

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-invalid-amount (err u103))
(define-constant err-invalid-status (err u104))
(define-constant err-already-exists (err u105))
(define-constant err-insufficient-funds (err u106))
(define-constant err-invalid-milestone (err u107))
(define-constant err-milestone-limit (err u108))
(define-constant err-invalid-description (err u109))

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
    description: (string-ascii 500),
    is-milestone-project: bool,
    milestone-count: uint,
    completed-milestones: uint
  }
)

(define-map project-funds
  uint
  {
    escrow-balance: uint,
    fee-collected: uint
  }
)

(define-map milestones
  { project-id: uint, milestone-id: uint }
  {
    description: (string-ascii 500),
    amount: uint,
    status: (string-ascii 20),
    created-at: uint,
    deadline: uint
  }
)

;; Read-only functions
(define-read-only (get-project (project-id uint))
  (map-get? projects project-id)
)

(define-read-only (get-project-funds (project-id uint))
  (map-get? project-funds project-id)
)

(define-read-only (get-milestone (project-id uint) (milestone-id uint))
  (map-get? milestones { project-id: project-id, milestone-id: milestone-id })
)

(define-read-only (get-milestone-count (project-id uint))
  (match (map-get? projects project-id)
    project-data (ok (get milestone-count project-data))
    err-not-found
  )
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

(define-private (is-valid-milestone-status (status (string-ascii 20)))
  (or (is-eq status "active")
      (or (is-eq status "completed")
          (is-eq status "disputed")))
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

(define-private (validate-project-id (project-id uint))
  (begin
    (asserts! (> project-id u0) false)
    (asserts! (< project-id (var-get next-project-id)) false)
    true
  )
)

(define-private (validate-milestone-id (project-id uint) (milestone-id uint))
  (match (map-get? projects project-id)
    project-data
    (begin
      (asserts! (> milestone-id u0) false)
      (asserts! (<= milestone-id (get milestone-count project-data)) false)
      true
    )
    false
  )
)

(define-private (validate-amount (amount uint))
  (begin
    (asserts! (> amount u0) false)
    (asserts! (< amount u1000000000000) false)
    true
  )
)

(define-private (validate-description (description (string-ascii 500)))
  (begin
    (asserts! (> (len description) u0) false)
    (asserts! (<= (len description) u500) false)
    true
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
    (asserts! (validate-amount amount) err-invalid-amount)
    (asserts! (> deadline stacks-block-height) err-invalid-amount)
    (asserts! (< deadline (+ stacks-block-height u52560)) err-invalid-amount)
    (asserts! (not (is-eq tx-sender freelancer)) err-unauthorized)
    (asserts! (>= current-balance total-required) err-insufficient-funds)
    (asserts! (validate-description description) err-invalid-description)
    
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
      description: description,
      is-milestone-project: false,
      milestone-count: u0,
      completed-milestones: u0
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

(define-public (create-milestone-project
  (freelancer principal)
  (total-amount uint)
  (deadline uint)
  (description (string-ascii 500))
  (milestone-descriptions (list 10 (string-ascii 500)))
  (milestone-amounts (list 10 uint))
  (milestone-deadlines (list 10 uint))
)
  (let (
    (project-id (var-get next-project-id))
    (platform-fee (unwrap! (calculate-platform-fee total-amount) err-invalid-amount))
    (total-required (+ total-amount platform-fee))
    (current-balance (stx-get-balance tx-sender))
    (milestone-count (len milestone-descriptions))
  )
    (asserts! (var-get contract-enabled) err-invalid-status)
    (asserts! (validate-amount total-amount) err-invalid-amount)
    (asserts! (> deadline stacks-block-height) err-invalid-amount)
    (asserts! (< deadline (+ stacks-block-height u52560)) err-invalid-amount)
    (asserts! (not (is-eq tx-sender freelancer)) err-unauthorized)
    (asserts! (>= current-balance total-required) err-insufficient-funds)
    (asserts! (validate-description description) err-invalid-description)
    (asserts! (> milestone-count u0) err-invalid-milestone)
    (asserts! (<= milestone-count u50) err-milestone-limit)
    (asserts! (is-eq milestone-count (len milestone-amounts)) err-invalid-milestone)
    (asserts! (is-eq milestone-count (len milestone-deadlines)) err-invalid-milestone)
    
    ;; Validate milestone amounts sum to total
    (asserts! (is-eq total-amount (fold + milestone-amounts u0)) err-invalid-amount)
    
    ;; Transfer funds to contract
    (try! (stx-transfer? total-required tx-sender (as-contract tx-sender)))
    
    ;; Create project record
    (map-set projects project-id {
      client: tx-sender,
      freelancer: freelancer,
      amount: total-amount,
      status: "active",
      created-at: stacks-block-height,
      deadline: deadline,
      description: description,
      is-milestone-project: true,
      milestone-count: milestone-count,
      completed-milestones: u0
    })
    
    ;; Set project funds
    (map-set project-funds project-id {
      escrow-balance: total-amount,
      fee-collected: platform-fee
    })
    
    ;; Create milestones
    (try! (create-milestones-batch 
      project-id 
      milestone-descriptions 
      milestone-amounts 
      milestone-deadlines 
      u1
    ))
    
    ;; Increment project ID
    (var-set next-project-id (+ project-id u1))
    
    (ok project-id)
  )
)

(define-private (create-milestones-batch
  (project-id uint)
  (descriptions (list 10 (string-ascii 500)))
  (amounts (list 10 uint))
  (deadlines (list 10 uint))
  (current-id uint)
)
  (begin
    (try! (create-milestone-at-index project-id descriptions amounts deadlines u0 u1))
    (try! (create-milestone-at-index project-id descriptions amounts deadlines u1 u2))
    (try! (create-milestone-at-index project-id descriptions amounts deadlines u2 u3))
    (try! (create-milestone-at-index project-id descriptions amounts deadlines u3 u4))
    (try! (create-milestone-at-index project-id descriptions amounts deadlines u4 u5))
    (try! (create-milestone-at-index project-id descriptions amounts deadlines u5 u6))
    (try! (create-milestone-at-index project-id descriptions amounts deadlines u6 u7))
    (try! (create-milestone-at-index project-id descriptions amounts deadlines u7 u8))
    (try! (create-milestone-at-index project-id descriptions amounts deadlines u8 u9))
    (try! (create-milestone-at-index project-id descriptions amounts deadlines u9 u10))
    (ok true)
  )
)

(define-private (create-milestone-at-index
  (project-id uint)
  (descriptions (list 10 (string-ascii 500)))
  (amounts (list 10 uint))
  (deadlines (list 10 uint))
  (index uint)
  (milestone-id uint)
)
  (match (element-at descriptions index)
    desc
    (match (element-at amounts index)
      amt
      (match (element-at deadlines index)
        deadline
        (begin
          (asserts! (validate-description desc) err-invalid-description)
          (asserts! (validate-amount amt) err-invalid-amount)
          (asserts! (> deadline stacks-block-height) err-invalid-amount)
          
          (map-set milestones 
            { project-id: project-id, milestone-id: milestone-id }
            {
              description: desc,
              amount: amt,
              status: "active",
              created-at: stacks-block-height,
              deadline: deadline
            }
          )
          (ok true)
        )
        (ok true) ;; No more elements, success
      )
      (ok true) ;; No more elements, success
    )
    (ok true) ;; No more elements, success
  )
)

(define-public (add-milestone
  (project-id uint)
  (description (string-ascii 500))
  (amount uint)
  (deadline uint)
)
  (let (
    (project-data (unwrap! (map-get? projects project-id) err-not-found))
    (current-milestone-count (get milestone-count project-data))
    (new-milestone-id (+ current-milestone-count u1))
  )
    (asserts! (var-get contract-enabled) err-invalid-status)
    (asserts! (validate-project-id project-id) err-not-found)
    (asserts! (is-eq tx-sender (get client project-data)) err-unauthorized)
    (asserts! (get is-milestone-project project-data) err-invalid-status)
    (asserts! (is-eq (get status project-data) "active") err-invalid-status)
    (asserts! (< current-milestone-count u50) err-milestone-limit)
    (asserts! (validate-amount amount) err-invalid-amount)
    (asserts! (> deadline stacks-block-height) err-invalid-amount)
    (asserts! (validate-description description) err-invalid-description)
    
    ;; Update project milestone count
    (map-set projects project-id 
      (merge project-data { milestone-count: new-milestone-id })
    )
    
    ;; Create milestone
    (map-set milestones 
      { project-id: project-id, milestone-id: new-milestone-id }
      {
        description: description,
        amount: amount,
        status: "active",
        created-at: stacks-block-height,
        deadline: deadline
      }
    )
    
    (ok new-milestone-id)
  )
)

(define-public (complete-milestone (project-id uint) (milestone-id uint))
  (let (
    (project-data (unwrap! (map-get? projects project-id) err-not-found))
    (milestone-data (unwrap! (map-get? milestones { project-id: project-id, milestone-id: milestone-id }) err-not-found))
    (funds-data (unwrap! (map-get? project-funds project-id) err-not-found))
    (client (get client project-data))
    (freelancer (get freelancer project-data))
    (milestone-amount (get amount milestone-data))
    (escrow-balance (get escrow-balance funds-data))
    (current-completed (get completed-milestones project-data))
    (total-milestones (get milestone-count project-data))
    (new-completed (+ current-completed u1))
  )
    (asserts! (var-get contract-enabled) err-invalid-status)
    (asserts! (validate-project-id project-id) err-not-found)
    (asserts! (validate-milestone-id project-id milestone-id) err-invalid-milestone)
    (asserts! (is-eq tx-sender client) err-unauthorized)
    (asserts! (get is-milestone-project project-data) err-invalid-status)
    (asserts! (is-eq (get status project-data) "active") err-invalid-status)
    (asserts! (is-eq (get status milestone-data) "active") err-invalid-status)
    (asserts! (>= escrow-balance milestone-amount) err-insufficient-funds)
    
    ;; Transfer milestone payment to freelancer
    (try! (as-contract (stx-transfer? milestone-amount tx-sender freelancer)))
    
    ;; Update milestone status
    (map-set milestones 
      { project-id: project-id, milestone-id: milestone-id }
      (merge milestone-data { status: "completed" })
    )
    
    ;; Update project completed milestones
    (map-set projects project-id 
      (merge project-data { completed-milestones: new-completed })
    )
    
    ;; Update escrow balance
    (map-set project-funds project-id 
      (merge funds-data { escrow-balance: (- escrow-balance milestone-amount) })
    )
    
    ;; Check if all milestones are completed
    (if (is-eq new-completed total-milestones)
      (map-set projects project-id 
        (merge project-data { 
          status: "completed",
          completed-milestones: new-completed
        })
      )
      true
    )
    
    (ok true)
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
    (asserts! (validate-project-id project-id) err-not-found)
    (asserts! (is-eq tx-sender client) err-unauthorized)
    (asserts! (is-eq (get status project-data) "active") err-invalid-status)
    (asserts! (not (get is-milestone-project project-data)) err-invalid-status)
    (asserts! (> escrow-balance u0) err-insufficient-funds)
    (asserts! (is-eq amount escrow-balance) err-invalid-amount)
    
    ;; Transfer funds to freelancer
    (try! (as-contract (stx-transfer? amount tx-sender freelancer)))
    
    ;; Update project status
    (map-set projects project-id (merge project-data { status: "completed" }))
    
    ;; Clear escrow balance
    (map-set project-funds project-id (merge funds-data { escrow-balance: u0 }))
    
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
  )
    (asserts! (var-get contract-enabled) err-invalid-status)
    (asserts! (validate-project-id project-id) err-not-found)
    (asserts! (is-eq tx-sender client) err-unauthorized)
    (asserts! (is-eq (get status project-data) "active") err-invalid-status)
    (asserts! (> escrow-balance u0) err-insufficient-funds)
    
    ;; Refund client
    (try! (as-contract (stx-transfer? escrow-balance tx-sender client)))
    
    ;; Update project status
    (map-set projects project-id (merge project-data { status: "cancelled" }))
    
    ;; Clear escrow balance
    (map-set project-funds project-id (merge funds-data { escrow-balance: u0 }))
    
    (ok true)
  )
)

(define-public (dispute-project (project-id uint))
  (let (
    (project-data (unwrap! (map-get? projects project-id) err-not-found))
  )
    (asserts! (var-get contract-enabled) err-invalid-status)
    (asserts! (validate-project-id project-id) err-not-found)
    (asserts! (is-project-participant project-id tx-sender) err-unauthorized)
    (asserts! (is-eq (get status project-data) "active") err-invalid-status)
    
    ;; Update project status to disputed
    (map-set projects project-id (merge project-data { status: "disputed" }))
    
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
    (asserts! (<= new-fee u1000) err-invalid-amount)
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
    (escrow-balance (get escrow-balance funds-data))
  )
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (validate-project-id project-id) err-not-found)
    (asserts! (is-eq (get status project-data) "disputed") err-invalid-status)
    (asserts! (> escrow-balance u0) err-insufficient-funds)
    
    ;; Transfer funds to winner
    (if winner-is-freelancer
      (try! (as-contract (stx-transfer? escrow-balance tx-sender freelancer)))
      (try! (as-contract (stx-transfer? escrow-balance tx-sender client)))
    )
    
    ;; Update project status
    (map-set projects project-id (merge project-data { status: "completed" }))
    
    ;; Clear escrow balance
    (map-set project-funds project-id (merge funds-data { escrow-balance: u0 }))
    
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