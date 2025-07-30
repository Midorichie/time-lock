;; Token Time Lock Contract - Phase 2 Enhanced Version
;; Complete restructure with comprehensive security validations

;; Error constants
(define-constant ERR-NOT-OWNER (err u100))
(define-constant ERR-TIME-LOCKED (err u101))
(define-constant ERR-NO-TOKENS (err u102))
(define-constant ERR-INVALID-AMOUNT (err u103))
(define-constant ERR-INSUFFICIENT-BALANCE (err u104))
(define-constant ERR-ALREADY-CLAIMED (err u105))
(define-constant ERR-INVALID-UNLOCK-TIME (err u106))
(define-constant ERR-EMERGENCY-PAUSE (err u107))
(define-constant ERR-INVALID-INPUT (err u108))
(define-constant ERR-INVALID-PRINCIPAL (err u109))
(define-constant ERR-RATE-LIMIT-EXCEEDED (err u110))

;; Security constants
(define-constant MAX-LOCK-DURATION u144000) ;; ~1000 days in blocks
(define-constant MIN-LOCK-DURATION u144) ;; ~1 day in blocks
(define-constant MAX-LOCKS-PER-USER u100)
(define-constant MIN-LOCK-AMOUNT u1000000) ;; 1 STX minimum
(define-constant MAX-LOCK_AMOUNT u1000000000000) ;; 1M STX maximum
(define-constant BURN-ADDRESS 'SP000000000000000000002Q6VF78)

;; Data variables
(define-data-var admin-lock (optional uint) none)
(define-data-var admin-principal (optional principal) none)
(define-data-var contract-owner principal tx-sender)
(define-data-var emergency-pause bool false)
(define-data-var total-locked uint u0)
(define-data-var next-lock-id uint u1)

;; Maps for token locks
(define-map token-locks 
    { user: principal, lock-id: uint }
    { 
        amount: uint,
        unlock-block: uint,
        claimed: bool,
        created-at: uint
    }
)

;; Map to track user's lock count
(define-map user-lock-count principal uint)

;; Input validation functions
(define-private (is-valid-amount (amount uint))
    (and (>= amount MIN-LOCK-AMOUNT) (<= amount MAX-LOCK_AMOUNT))
)

(define-private (is-valid-unlock-time (unlock-block uint))
    (and 
        (> unlock-block block-height)
        (<= (- unlock-block block-height) MAX-LOCK-DURATION)
        (>= (- unlock-block block-height) MIN-LOCK-DURATION)
    )
)

(define-private (is-valid-admin-principal (who principal))
    (and 
        (not (is-eq who tx-sender))
        (not (is-eq who (var-get contract-owner)))
        (not (is-eq who BURN-ADDRESS))
    )
)

(define-private (is-valid-lock-id (lock-id uint))
    (and (> lock-id u0) (< lock-id (var-get next-lock-id)))
)

(define-private (check-user-lock-limit (user principal))
    (let (
        (user-locks (default-to u0 (map-get? user-lock-count user)))
    )
        (< user-locks MAX-LOCKS-PER-USER)
    )
)

(define-private (has-sufficient-balance (user principal) (amount uint))
    (>= (stx-get-balance user) amount)
)

;; Read-only functions - All isolated with no dependencies
(define-read-only (get-lock-info (user principal) (lock-id uint))
    (map-get? token-locks { user: user, lock-id: lock-id })
)

(define-read-only (get-user-lock-count (user principal))
    (default-to u0 (map-get? user-lock-count user))
)

(define-read-only (get-total-locked)
    (var-get total-locked)
)

(define-read-only (get-contract-owner)
    (var-get contract-owner)
)

(define-read-only (get-admin-info)
    {
        admin-principal: (var-get admin-principal),
        admin-lock: (var-get admin-lock)
    }
)

(define-read-only (get-pause-status)
    (var-get emergency-pause)
)

(define-read-only (get-security-limits)
    {
        max-lock-duration: MAX-LOCK-DURATION,
        min-lock-duration: MIN-LOCK-DURATION,
        max-locks-per-user: MAX-LOCKS-PER-USER,
        min-lock-amount: MIN-LOCK-AMOUNT,
        max-lock-amount: MAX-LOCK_AMOUNT
    }
)

;; Validate claim eligibility with comprehensive checks
(define-read-only (validate-claim-eligibility (user principal) (lock-id uint))
    (match (map-get? token-locks { user: user, lock-id: lock-id })
        lock-data (and 
            (is-valid-lock-id lock-id)
            (not (get claimed lock-data))
            (>= block-height (get unlock-block lock-data))
            (not (var-get emergency-pause))
            (> (get amount lock-data) u0)
        )
        false
    )
)

;; Admin functions with enhanced validation
(define-public (set-admin (who principal) (unlock-block uint))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-OWNER)
        (asserts! (is-valid-unlock-time unlock-block) ERR-INVALID-UNLOCK-TIME)
        (asserts! (is-none (var-get admin-principal)) ERR-NOT-OWNER)
        (asserts! (is-valid-admin-principal who) ERR-INVALID-PRINCIPAL)
        
        (var-set admin-principal (some who))
        (var-set admin-lock (some unlock-block))
        
        ;; Emit event
        (print {
            event: "admin-set",
            admin: who,
            unlock-block: unlock-block,
            set-by: tx-sender
        })
        
        (ok true)
    )
)

(define-public (claim-admin-role)
    (let (
        (current-block block-height)
        (unlock-block (unwrap! (var-get admin-lock) ERR-NOT-OWNER))
        (who (unwrap! (var-get admin-principal) ERR-NOT-OWNER))
    )
        (begin
            (asserts! (is-eq tx-sender who) ERR-NOT-OWNER)
            (asserts! (>= current-block unlock-block) ERR-TIME-LOCKED)
            
            (var-set contract-owner who)
            (var-set admin-principal none)
            (var-set admin-lock none)
            
            ;; Emit event
            (print {
                event: "admin-claimed",
                new-owner: who,
                block-height: current-block
            })
            
            (ok "Admin role claimed")
        )
    )
)

;; Emergency pause function with validation
(define-public (set-emergency-pause (pause-state bool))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-OWNER)
        (var-set emergency-pause pause-state)
        
        ;; Emit event
        (print {
            event: "emergency-pause-changed",
            paused: pause-state,
            by: tx-sender,
            block-height: block-height
        })
        
        (ok pause-state)
    )
)

;; Core token locking functionality with comprehensive validation
(define-public (lock-tokens (amount uint) (unlock-block uint))
    (let (
        (current-lock-id (var-get next-lock-id))
        (current-user-locks (default-to u0 (map-get? user-lock-count tx-sender)))
        (is-paused (var-get emergency-pause))
    )
        (begin
            ;; Comprehensive input validation
            (asserts! (not is-paused) ERR-EMERGENCY-PAUSE)
            (asserts! (is-valid-amount amount) ERR-INVALID-AMOUNT)
            (asserts! (is-valid-unlock-time unlock-block) ERR-INVALID-UNLOCK-TIME)
            (asserts! (has-sufficient-balance tx-sender amount) ERR-INSUFFICIENT-BALANCE)
            (asserts! (check-user-lock-limit tx-sender) ERR-RATE-LIMIT-EXCEEDED)
            
            ;; Transfer tokens to contract
            (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
            
            ;; Create lock record
            (map-set token-locks
                { user: tx-sender, lock-id: current-lock-id }
                {
                    amount: amount,
                    unlock-block: unlock-block,
                    claimed: false,
                    created-at: block-height
                }
            )
            
            ;; Update counters
            (map-set user-lock-count tx-sender (+ current-user-locks u1))
            (var-set next-lock-id (+ current-lock-id u1))
            (var-set total-locked (+ (var-get total-locked) amount))
            
            ;; Emit event
            (print {
                event: "tokens-locked",
                user: tx-sender,
                lock-id: current-lock-id,
                amount: amount,
                unlock-block: unlock-block,
                created-at: block-height
            })
            
            (ok current-lock-id)
        )
    )
)

;; Public claim function with enhanced validation
(define-public (claim-tokens (lock-id uint))
    (let (
        (lock-data (unwrap! (map-get? token-locks { user: tx-sender, lock-id: lock-id }) ERR-NO-TOKENS))
        (amount (get amount lock-data))
        (unlock-block (get unlock-block lock-data))
        (claimed (get claimed lock-data))
        (is-paused (var-get emergency-pause))
    )
        (begin
            ;; Comprehensive validation
            (asserts! (is-valid-lock-id lock-id) ERR-INVALID-INPUT)
            (asserts! (not is-paused) ERR-EMERGENCY-PAUSE)
            (asserts! (not claimed) ERR-ALREADY-CLAIMED)
            (asserts! (>= block-height unlock-block) ERR-TIME-LOCKED)
            (asserts! (> amount u0) ERR-INVALID-AMOUNT)
            
            ;; Update lock status
            (map-set token-locks
                { user: tx-sender, lock-id: lock-id }
                (merge lock-data { claimed: true })
            )
            
            ;; Transfer tokens back to user
            (try! (as-contract (stx-transfer? amount tx-sender tx-sender)))
            
            ;; Update total locked
            (var-set total-locked (- (var-get total-locked) amount))
            
            ;; Emit event
            (print {
                event: "tokens-claimed",
                user: tx-sender,
                lock-id: lock-id,
                amount: amount,
                claimed-at: block-height
            })
            
            (ok amount)
        )
    )
)

;; Enhanced batch claim function with validation
(define-public (batch-claim-tokens (lock-ids (list 10 uint)))
    (let (
        (is-paused (var-get emergency-pause))
        (total-claimed u0)
    )
        (begin
            (asserts! (not is-paused) ERR-EMERGENCY-PAUSE)
            (asserts! (> (len lock-ids) u0) ERR-INVALID-INPUT)
            
            ;; Process first lock ID (simplified for demonstration)
            (if (> (len lock-ids) u0)
                (let (
                    (lock-id (unwrap-panic (element-at lock-ids u0)))
                    (lock-data (unwrap! (map-get? token-locks { user: tx-sender, lock-id: lock-id }) ERR-NO-TOKENS))
                    (amount (get amount lock-data))
                    (unlock-block (get unlock-block lock-data))
                    (claimed (get claimed lock-data))
                )
                    (begin
                        ;; Validation
                        (asserts! (is-valid-lock-id lock-id) ERR-INVALID-INPUT)
                        (asserts! (not claimed) ERR-ALREADY-CLAIMED)
                        (asserts! (>= block-height unlock-block) ERR-TIME-LOCKED)
                        (asserts! (> amount u0) ERR-INVALID-AMOUNT)
                        
                        ;; Update lock status
                        (map-set token-locks
                            { user: tx-sender, lock-id: lock-id }
                            (merge lock-data { claimed: true })
                        )
                        
                        ;; Transfer tokens
                        (try! (as-contract (stx-transfer? amount tx-sender tx-sender)))
                        
                        ;; Update total locked
                        (var-set total-locked (- (var-get total-locked) amount))
                        
                        ;; Emit event
                        (print {
                            event: "batch-claim",
                            user: tx-sender,
                            lock-ids: lock-ids,
                            amount: amount,
                            claimed-at: block-height
                        })
                        
                        (ok (list amount))
                    )
                )
                (ok (list))
            )
        )
    )
)

;; Emergency withdraw function (owner only) - new security feature
(define-public (emergency-withdraw (user principal) (lock-id uint))
    (let (
        (lock-data (unwrap! (map-get? token-locks { user: user, lock-id: lock-id }) ERR-NO-TOKENS))
        (amount (get amount lock-data))
        (claimed (get claimed lock-data))
    )
        (begin
            ;; Only owner can call this during emergency
            (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-OWNER)
            (asserts! (var-get emergency-pause) ERR-EMERGENCY-PAUSE)
            (asserts! (not claimed) ERR-ALREADY-CLAIMED)
            (asserts! (is-valid-lock-id lock-id) ERR-INVALID-INPUT)
            
            ;; Update lock status
            (map-set token-locks
                { user: user, lock-id: lock-id }
                (merge lock-data { claimed: true })
            )
            
            ;; Transfer tokens back to original user
            (try! (as-contract (stx-transfer? amount tx-sender user)))
            
            ;; Update total locked
            (var-set total-locked (- (var-get total-locked) amount))
            
            ;; Emit event
            (print {
                event: "emergency-withdraw",
                user: user,
                lock-id: lock-id,
                amount: amount,
                withdrawn-by: tx-sender,
                block-height: block-height
            })
            
            (ok amount)
        )
    )
)
