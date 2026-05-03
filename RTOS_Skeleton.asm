;*******************************************************************************
;*                    EEE8087 REAL-TIME OPERATING SYSTEM                       *
;*******************************************************************************
;*    Group Members:            -       Student ID                                            *
;*    1. Timothy Diete-Spiff    -       250524738                                             *
;*    2. UWA UWA AGBAI          -       250606089                                             *
;*******************************************************************************

; System Call Numbers (used in D0 when calling TRAP #0)
syscr       equ     1           ; Create task
sysdel      equ     2           ; Delete task
syswmtx    equ     3           ; Wait on mutex
syssmtx    equ     4           ; Signal mutex
sysimtx    equ     5           ; Initialize mutex
syswttm    equ     6           ; Wait for time intervals

; Trap number for system calls
sys         equ     0           ; All system calls use TRAP #0

; Number of TCBs (maximum concurrent tasks)
numtcbs     equ     8           ; Support up to 8 tasks

; TCB Field Offsets
; These define where each piece of data is stored within a TCB
tcbuse      equ     0           ; In-use flag: 0=free, 1=used (2 bytes)
tcbstat     equ     2           ; Task state: 0=ready, 1=waiting (2 bytes)
tcbnext     equ     4           ; Pointer to next TCB in list (4 bytes)
tcbwait     equ     8           ; Wait counter for wait_time (4 bytes)
tcbwmtx     equ     12          ; Waiting on mutex flag (2 bytes)
; Saved registers start here
tcbd0       equ     14          ; Saved D0 (4 bytes)
tcbd1       equ     18          ; Saved D1
tcbd2       equ     22          ; Saved D2
tcbd3       equ     26          ; Saved D3
tcbd4       equ     30          ; Saved D4
tcbd5       equ     34          ; Saved D5
tcbd6       equ     38          ; Saved D6
tcbd7       equ     42          ; Saved D7
tcba0       equ     46          ; Saved A0 (4 bytes)
tcba1       equ     50          ; Saved A1
tcba2       equ     54          ; Saved A2
tcba3       equ     58          ; Saved A3
tcba4       equ     62          ; Saved A4
tcba5       equ     66          ; Saved A5
tcba6       equ     70          ; Saved A6
tcba7       equ     74          ; Saved A7 (Stack Pointer)
tcbpc       equ     78          ; Saved Program Counter (4 bytes)
tcbsr       equ     82          ; Saved Status Register (2 bytes)
tcblen      equ     84          ; Total length of one TCB

; Task States
stready     equ     0           ; Task is ready to run
stwaittm    equ     1           ; Task is waiting on timer
stwaitmtx   equ     2           ; Task is waiting on mutex

; Hardware Addresses (Memory-Mapped I/O)
sevseg      equ     $E0000E     ; 7-segment display
led         equ     $E00010     ; LEDs (active low typically)
sw          equ     $E00014     ; Switches/pushbuttons

; Memory Layout
usrcode     equ     $2000       ; Where user task code starts
t0stack     equ     $3000       ; Task 0 stack top
t1stack     equ     $4000       ; Task 1 stack top
t2stack     equ     $5000       ; Task 2 stack top

            org     $0          ; Origin at address 0
            
; Initial Stack Pointer and Program Counter (loaded on reset)
            dc.l    $8000       ; Initial SP (stack pointer at reset)
            dc.l    reset       ; Initial PC (where to start on reset)

; Hardware Interrupt Vectors
; The processor has 7 hardware interrupt levels (1-7)
; Level 1 is used for the timer
            org     $64         ; Hardware interrupt vectors start at $64
hivec1      dc.l    timer_isr   ; Level 1 interrupt -> timer ISR
hivec2      dc.l    dummy_isr   ; Level 2 (not used)
hivec3      dc.l    dummy_isr   ; Level 3 (not used)
hivec4      dc.l    dummy_isr   ; Level 4 (not used)
hivec5      dc.l    dummy_isr   ; Level 5 (not used)
hivec6      dc.l    dummy_isr   ; Level 6 (not used)
hivec7      dc.l    dummy_isr   ; Level 7 (not used)

; Software Interrupt Vectors (TRAP instructions)
; TRAP #0 through TRAP #15 have vectors starting at $80
            org     $80         ; Software interrupt vectors start at $80
sivec0      dc.l    syscall_handler  ; TRAP #0 -> system call handler
sivec1      dc.l    dummy_isr   ; TRAP #1 (not used)
; ... remaining TRAP vectors not used ...

            org     $1000       ; RTOS code starts at $1000

;-------------------------------------------------------------------------------
; DUMMY ISR - For unused interrupts
;-------------------------------------------------------------------------------
dummy_isr:
            rte                 ; Just return, do nothing


;-------------------------------------------------------------------------------
; FIRST LEVEL INTERRUPT HANDLER (FLIH)
;-------------------------------------------------------------------------------
flih:
            move.l  d0,temp1        
            move.l  a0,temp2        
            move.l  rdytcb,a0       
            move.l  temp1,d0        
            move.l  d0,tcbd0(a0)    
            move.l  d1,tcbd1(a0)
            move.l  d2,tcbd2(a0)
            move.l  d3,tcbd3(a0)
            move.l  d4,tcbd4(a0)
            move.l  d5,tcbd5(a0)
            move.l  d6,tcbd6(a0)
            move.l  d7,tcbd7(a0)
            move.l  temp2,d0        
            move.l  d0,tcba0(a0)    
            move.l  a1,tcba1(a0)
            move.l  a2,tcba2(a0)
            move.l  a3,tcba3(a0)
            move.l  a4,tcba4(a0)
            move.l  a5,tcba5(a0)
            move.l  a6,tcba6(a0)
            move.l  sp,d0           
            add.l   #10,d0           
            move.l  d0,tcba7(a0)    
            move.w  4(sp),d0         
            move.w  d0,tcbsr(a0)    
            move.l  6(sp),d0        
            move.l  d0,tcbpc(a0)    
            rts


;-------------------------------------------------------------------------------
; DISPATCHER
;-------------------------------------------------------------------------------
disp:
            move.l  rdytcb,a0
            move.l  tcbd1(a0),d1
            move.l  tcbd2(a0),d2
            move.l  tcbd3(a0),d3
            move.l  tcbd4(a0),d4
            move.l  tcbd5(a0),d5
            move.l  tcbd6(a0),d6
            move.l  tcbd7(a0),d7
            move.l  tcba1(a0),a1
            move.l  tcba2(a0),a2
            move.l  tcba3(a0),a3
            move.l  tcba4(a0),a4
            move.l  tcba5(a0),a5
            move.l  tcba6(a0),a6
            move.l  tcba7(a0),sp
            sub.l   #6,sp
            move.l  tcbpc(a0),d0
            move.l  d0,2(sp)
            move.w  tcbsr(a0),d0
            move.w  d0,(sp)
            move.l  tcbd0(a0),d0
            move.l  tcba0(a0),a0
            rte


;-------------------------------------------------------------------------------
; TIMER INTERRUPT SERVICE ROUTINE
;-------------------------------------------------------------------------------
timer_isr:
            jsr     flih
            jsr     update_waiters
            jsr     scheduler
            jmp     disp

;-------------------------------------------------------------------------------
; UPDATE WAITERS (Helper for Timer ISR)
;-------------------------------------------------------------------------------
update_waiters:
            move.l  #tcbs,a0
            move.l  #numtcbs,d1

uw_loop:
            cmp.w   #1,tcbuse(a0)
            bne     uw_next
            cmp.w   #stwaittm,tcbstat(a0)
            bne     uw_next
            move.l  tcbwait(a0),d0
            sub.l   #1,d0
            move.l  d0,tcbwait(a0)
            bne     uw_next  
            move.w  #stready,tcbstat(a0)
            move.l  a0,-(sp)
            move.l  d1,-(sp)
            jsr     add_to_ready
            move.l  (sp)+,d1
            move.l  (sp)+,a0
uw_next:
            add.l   #tcblen,a0
            sub.l   #1,d1
            bne     uw_loop
            rts

;-------------------------------------------------------------------------------
; RESET HANDLER
;-------------------------------------------------------------------------------

reset:
            ; Initialize stack pointer
            move.l  #$8000,sp           ; Top of memory for system stack

            ; Initialize all TCBs to unused
            move.l  #tcbs,a0            ; Load start of TCB array
            move.l  #numtcbs,d0         ; Loop counter (8 tasks)
            sub.l   #1,d0               ; Adjust for dbra (7 to 0)

init_loop:
            move.w  #0,tcbuse(a0)       ; Mark as unused
            add.l   #tcblen,a0          ; Move to next TCB
            dbra    d0,init_loop        ; Repeat until all done

            ; Initialize global pointers
            move.l  #0,rdytcb           ; Empty ready list
            move.l  #0,wttcb            ; Empty waiting list
            move.l  #1,mutex            ; Mutex available (1)

            ; Manually Create Task 0
            move.l  #tcbs,a0            ; Get first TCB (TCB 0)
            
            ; Mark as used and ready
            move.w  #1,tcbuse(a0)       ; Used
            move.w  #stready, tcbstat(a0) ; Ready state
            
            ; Set up registers for Task 0
            move.l  #usrcode,tcbpc(a0)  ; PC = Start of user code
            move.l  #t0stack,tcba7(a0)  ; SP = Task 0 Stack
            move.w  #$2000,tcbsr(a0)    ; SR = Interrupts enabled (Supervisor)
            

            move.l  a0,tcbnext(a0)      
            move.l  a0,rdytcb           ; This is the running task
            jmp     disp

;-------------------------------------------------------------------------------
; SYSTEM CALL HANDLER
;-------------------------------------------------------------------------------

syscall_handler:
            or.w #$0700,sr
            
            cmp.l   #syscr,d0           
            beq     sys_create  
            
            cmp.l   #sysdel,d0       
            beq     sys_delete
            
            cmp.l   #syswttm,d0         
            beq     sys_wait_time
            
            cmp.l   #sysimtx,d0        
            beq     sys_init_mutex
            
            cmp.l   #syswmtx,d0        
            beq     sys_wait_mutex
            
            cmp.l   #syssmtx,d0         
            beq     sys_signal_mutex
            
            rte                         ; Unknown call, just return


;-------------------------------------------------------------------------------
; SYSTEM CALL: CREATE TASK (with error handling)
;-------------------------------------------------------------------------------
sys_create:
            ; ERROR CHECK: Validate task address (must be in user space)
            cmp.l   #$2000,d1           ; Below user code?
            blt     create_error        ; Yes, invalid
            cmp.l   #$8000,d1           ; Above valid range?
            bge     create_error        ; Yes, invalid
            
            ; ERROR CHECK: Validate stack pointer
            cmp.l   #$2000,d2           ; Below user space?
            blt     create_error        ; Yes, invalid
            cmp.l   #$8000,d2           ; Above valid range?
            bgt     create_error        ; Yes, invalid
            
            ; Find a free TCB
            move.l  #tcbs,a0            ; Start of array
            move.l  #numtcbs,d3         ; Counter
            
find_free:
            tst.w   tcbuse(a0)          ; Check if used
            beq     found_free          ; If 0, we found one
            add.l   #tcblen,a0          ; Next TCB
            sub.l   #1,d3
            bne     find_free           ; Loop
            ; No free TCB found
            
create_error:            
            move.l  #-1,d0              ; Return error code
            rte

found_free:
            ; Initialize the new TCB
            move.w  #1,tcbuse(a0)       ; Mark used
            move.w  #stready,tcbstat(a0) ; Mark ready
            move.l  d1,tcbpc(a0)        ; Set PC (from parameter D1)
            move.l  d2,tcba7(a0)        ; Set SP (from parameter D2)
            move.w  #$2000,tcbsr(a0)    ; Set SR (Interrupts enabled)
            
            ; Add TCB to ready list
            move.l  a0,-(sp)            ; Save A0 (new TCB)
            jsr     add_to_ready
            move.l  (sp)+,a0            ; Restore A0
            
            ; Return success
            move.l  #0,d0               ; Return 0
            rte

;-------------------------------------------------------------------------------
; SYSTEM CALL: DELETE TASK (with cleanup)
;-------------------------------------------------------------------------------
sys_delete:
            move.l  rdytcb,a0           ; A0 = Current Task
            
            ; CLEANUP: If this task was holding mutex, release it
            tst.l   mutex               ; Is mutex locked (0)?
            bne     del_no_mutex        ; No, skip cleanup
            
            ; Mutex is locked - release it before deleting
            move.l  #1,mutex            ; Free the mutex
            
del_no_mutex:
            jsr     remove_from_ready   ; Fix links
            move.w  #0,tcbuse(a0)       ; Free the block
            jsr     scheduler           ; Pick next task (updates rdytcb)
            jmp     disp                ; Run it (DO NOT RTE)


;-------------------------------------------------------------------------------
; SYSTEM CALL: WAIT TIME (with error handling)
;-------------------------------------------------------------------------------
sys_wait_time:
            ; ERROR CHECK: If wait time is 0 or less, return immediately
            tst.l   d1                  ; Is D1 <= 0?
            ble     wait_time_done      ; Yes, don't block, just return
            
            or.w    #$0700,sr           
            jsr     flih                ; Save registers to current TCB
            
            move.l  rdytcb,a0           ; A0 = Current Task
            
            move.l  d1,tcbwait(a0)      ; Set wait duration
            move.w  #stwaittm, tcbstat(a0) ; Set status to waiting
            
            jsr     remove_from_ready   ; Take off ready list
            jsr     add_to_waiting      ; Put on waiting list
            
            jsr     scheduler           ; Pick new task
            jmp     disp                ; Go run it (DO NOT RTE)

wait_time_done:
            rte                         ; Return immediately if invalid time
;-------------------------------------------------------------------------------
; HELPER: ADD TO READY LIST
;-------------------------------------------------------------------------------
add_to_ready:
            move.l  rdytcb,d0           ; Check if list empty
            bne     list_not_empty
            
            ; Case 1: List is empty
            move.l  a0,rdytcb           ; Head 
            move.l  a0,tcbnext(a0)      ; Next
            rts

list_not_empty:
            move.l  rdytcb,a1           ; Start search at head
            
find_tail:
            move.l  tcbnext(a1),d0      ; Get next
            cmp.l   rdytcb,d0           ; Is next == Head?
            beq     found_tail
            move.l  d0,a1               ; Advance
            bra     find_tail
            
found_tail:
            ; A1 is now the tail
            move.l  a0,tcbnext(a1)      ;
            move.l  rdytcb,tcbnext(a0)  ;
            rts

;-------------------------------------------------------------------------------
; HELPER: REMOVE FROM READY LIST (Circular Remove)
; Entry: A0 = pointer to TCB to remove
;-------------------------------------------------------------------------------
remove_from_ready:
            move.l  tcbnext(a0),d0      
            cmp.l   a0,d0               ; Is next == self?
            bne     more_than_one
            
            ; Case 1: Only one item in list
            move.l  #0,rdytcb           ; List is now empty
            rts

more_than_one:
            ; Case 2: Multiple items. Find predecessor (A1)
            ; Predecessor is the node where tcbnext == A0
            move.l  a0,a1               ; Start search at target
            
find_pred:
            move.l  tcbnext(a1),d0      ; Get next
            cmp.l   a0,d0               ; Is next == Target?
            beq     found_pred
            move.l  d0,a1               ; Advance
            bra     find_pred
            
found_pred:
            ; A1 is predecessor. A0 is target.
            move.l  tcbnext(a0),tcbnext(a1) ; Pred -> Target's Next
            
            ; If we removed the head (rdytcb), move head pointer
            cmp.l   rdytcb,a0
            bne     rm_done
            move.l  tcbnext(a0),rdytcb  ; Head = Next
            
rm_done:
            rts

;-------------------------------------------------------------------------------
; HELPER: ADD TO WAITING LIST (Linear Insert at Head)
; Entry: A0 = pointer to TCB to add
;-------------------------------------------------------------------------------
add_to_waiting:
            move.l  wttcb,tcbnext(a0)   ; New -> Old Head
            move.l  a0,wttcb            ; Head -> New
            rts
            
;-------------------------------------------------------------------------------
; SCHEDULER
;-------------------------------------------------------------------------------
scheduler:
            move.l  rdytcb,a0
            cmp.l   #0,a0               
            beq     sched_done
            move.l  tcbnext(a0),a0      ; Get next into A0
            move.l  a0,rdytcb           ; Store to rdytcb
sched_done:
            rts            
;-------------------------------------------------------------------------------
; SYSTEM CALL: INITIALIZE MUTEXs
;-------------------------------------------------------------------------------
sys_init_mutex:
            move.l  d1,mutex            ; Set mutex value (0 or 1)
            rte

;-------------------------------------------------------------------------------
; SYSTEM CALL: WAIT MUTEX
;-------------------------------------------------------------------------------
sys_wait_mutex:
            tst.l   mutex               ; Is mutex available (1)?
            bne     mutex_free          ; Yes, grab it

            ; --- Mutex is LOCKED (0) ---
            ; We must block the current task
            
            or.w    #$0700,sr           ; Disable interrupts for safety
            jsr     flih                ; Save current task state
            
            move.l  rdytcb,a0           ; Get current TCB
            move.w  #stwaitmtx,tcbstat(a0) ; Status = Waiting on Mutex
            move.w  #1,tcbwmtx(a0)      ; Mark specific wait flag
            
            jsr     remove_from_ready   ; Remove from ready loop
            jsr     add_to_waiting      ; Add to linear wait list
            
            jsr     scheduler           ; Pick next task
            jmp     disp                ; Run next task (Context Switch)

mutex_free:
            ; --- Mutex is FREE (1) ---
            move.l  #0,mutex            ; Lock it (set to 0)
            rte                         ; Continue running

;-------------------------------------------------------------------------------
; SYSTEM CALL: SIGNAL MUTEX (with error handling)
;-------------------------------------------------------------------------------
sys_signal_mutex:
            ; ERROR CHECK: If mutex already free, do nothing (prevent double signal)
            tst.l   mutex               ; Is mutex already 1 (free)?
            bne     signal_already_free ; Yes, ignore this signal
            
            jsr     find_mutex_waiter   ; Look for a task waiting on mutex
            cmp.l   #0,a0               ; Did we find one?
            beq     no_waiters

            ; --- Found a waiting task (in A0) ---            
            jsr     remove_from_waiting ; Remove TCB in A0 from wait list
            move.w  #stready,tcbstat(a0) ; Status = Ready
            move.w  #0,tcbwmtx(a0)      ; Clear wait flag
            jsr     add_to_ready        ; Add to ready loop
            ; Note: Mutex remains 0 (locked) because we passed ownership 
            ; directly to the waking task.
            rte

no_waiters:
            ; --- No one waiting ---
            move.l  #1,mutex            ; Unlock mutex (set to 1)
            
signal_already_free:
            rte

;-------------------------------------------------------------------------------
; HELPER: FIND MUTEX WAITER
; Returns: A0 = Pointer to waiting TCB, or 0 if none found
;-------------------------------------------------------------------------------
find_mutex_waiter:
            move.l  wttcb,a0            ; Start at head of waiting list
            
fm_loop:
            cmp.l   #0,a0               ; End of list?
            beq     fm_done             ; Return 0
            
            tst.w   tcbwmtx(a0)         ; Is this task waiting on mutex?
            bne     fm_done             ; Yes, found it! Return A0
            
            move.l  tcbnext(a0),a0      ; Next TCB
            bra     fm_loop
            
fm_done:
            rts

;-------------------------------------------------------------------------------
; HELPER: REMOVE FROM WAITING LIST
; Entry: A0 = Pointer to TCB to remove
;-------------------------------------------------------------------------------
remove_from_waiting:
            move.l  a0,d0               ; 
            move.l  wttcb,a1            ; 
            
            cmp.l   a0,a1               ; 
            beq     rm_w_head
            
rm_w_loop:
            move.l  tcbnext(a1),d1      ; 
            cmp.l   d0,d1               ; 
            beq     rm_w_found
            move.l  d1,a1               ; 
            bra     rm_w_loop

rm_w_found:
            move.l  tcbnext(a0),tcbnext(a1) ; Unlink target
            rts

rm_w_head:
            move.l  tcbnext(a0),wttcb   ;
            rts

            org     $1800       ; Data section

; Global Pointers
rdytcb      ds.l    1           ; Pointer to first TCB in ready list (current task)
wttcb       ds.l    1           ; Pointer to first TCB in waiting list
mutex       ds.l    1           ; Mutex variable (0=locked, 1=available)

; TCB Array - 8 Task Control Blocks
tcbs        ds.b    tcblen*numtcbs    ; 84 bytes * 8 = 672 bytes

; Temporary storage (if needed)
temp1       ds.l    1
temp2       ds.l    1

            org     usrcode     ; User code starts at $2000

; Uncomment ONE of these to select which test program runs:
               bra     prog1       ; Run stopwatch test
;              bra     prog2       ; Run radiation monitor test
;             bra     prog3       ; Test Error Handling

;-------------------------------------------------------------------------------
; 7-SEGMENT DISPLAY PATTERNS
;-------------------------------------------------------------------------------
; Used by both test programs
kseg:
            dc.b    $3F         ; 0
            dc.b    $06         ; 1
            dc.b    $5B         ; 2
            dc.b    $4F         ; 3
            dc.b    $66         ; 4
            dc.b    $6D         ; 5
            dc.b    $7D         ; 6
            dc.b    $07         ; 7
            dc.b    $7F         ; 8
            dc.b    $67         ; 9
            dc.b    $77         ; A
            dc.b    $7C         ; b
            dc.b    $39         ; C
            dc.b    $5E         ; d
            dc.b    $79         ; E
            dc.b    $71         ; F


;*******************************************************************************
; TEST PROGRAM 1: STOPWATCH
;*******************************************************************************
prog1:
;-------------------------------------------------------------------------------
; PROG1 - TASK 0: Display and increment counter
;-------------------------------------------------------------------------------
p1t0:
            move.b  #0,$E00000          ; Clear Digit 7 (Leftmost)
            move.b  #0,$E00002          ; Clear Digit 6
            move.b  #0,$E00004          ; Clear Digit 5
            move.b  #0,$E00006          ; Clear Digit 4
            move.b  #0,$E00008          ; Clear Digit 3
            move.b  #0,$E0000A          ; Clear Digit 2
            move.b  #0,$E0000C          ; Clear Digit 1
            
            ; Initialize
            move.l  #0,p1count          ; Counter = 0
            move.l  #0,p1running        ; Stopped
            
            ; Display initial value (0)

            move.l  #kseg,a0
            move.b  (a0),d0             ; Get pattern for 0
            move.l  #sevseg,a2
            move.b  d0,(a2)             ; Display it
            
            ; Create Task 1
            move.l  #syscr,d0           ; System call: create task
            move.l  #p1t1,d1            ; Task 1 address
            move.l  #t1stack,d2         ; Task 1 stack
            trap    #0                  ; Make the call
            
            ; Main loop
p1t0loop:
            ; Display p1count on 7-segment (units digit only)
            move.l  p1count,d0
            divu    #10,d0              ; D0.W = tens, upper word = units
            swap    d0                  ; D0.W = units
            and.l   #$FFFF,d0           ; Clean up
            
            ; Look up 7-segment pattern
            move.l  #kseg,a0
            add.l   d0,a0
            move.b  (a0),d0
            move.l  #sevseg,a2
            move.b  d0,(a2)             ; Display it
            
            ; Check if running
            move.l  p1running,d0
            tst.l   d0
            beq     p1t0wait            ; Not running, just wait
            
            ; Running - increment counter
            move.l  p1count,d0
            add.l   #1,d0
            cmp.l   #100,d0
            blt     p1t0noroll
            move.l  #0,d0               ; Reset to 0 at 100
p1t0noroll:
            move.l  d0,p1count
            
            ; Wait 1 second (10 x 100ms)
            move.l  #syswttm,d0
            move.l  #10,d1
            trap    #0
            bra     p1t0loop
            
p1t0wait:
            ; Not running - small wait
            move.l  #syswttm,d0
            move.l  #1,d1
            trap    #0
            bra     p1t0loop

;-------------------------------------------------------------------------------
; PROG1 - TASK 1: Button monitor
;-------------------------------------------------------------------------------
p1t1:
p1t1loop:
            ; Read switches
            move.l  #sw,a2
            move.b  (a2),d0
            and.l   #1,d0               ; Check bit 0
            beq     p1t1loop            ; Not pressed, keep checking
            
            ; Button pressed - toggle running
            move.l  p1running,d0
            eor.l   #1,d0               ; Toggle
            move.l  d0,p1running
            
            ; Wait for release
p1t1release:
            move.l  #sw,a2
            move.b  (a2),d0
            and.l   #1,d0
            bne     p1t1release         ; Still pressed
            
            ; Debounce delay
            move.l  #syswttm,d0
            move.l  #2,d1
            trap    #0
            
            bra     p1t1loop

; PROG1 Data
p1count     ds.l    1
p1running   ds.l    1

;*******************************************************************************
; TEST PROGRAM 2: RADIATION MONITOR
;*******************************************************************************
prog2:


p27seg      equ     $E00000     ; 7-seg Start
p27sege     equ     $E0000E     ; 7-seg End (Digit 0)
p2led       equ     $E00010     ; LEDs
p2sw        equ     $E00014     ; Switch

;-------------------------------------------------------------------------------
; PROG2 - TASK 0: Initialization and Counter A
;-------------------------------------------------------------------------------
p2t0:
            ; 1. Initialize Variables
            move.l  #0,p2a
            move.l  #0,p2b
            move.l  #0,p2c
            
            ; 2. Initialize LEDs (Off)
            move.l  #0,d0
            move.b  d0,p2led
            
            ; 3. Initialize Mutex
            move.l  #sysimtx,d0
            move.l  #1,d1               ; 1 = Available
            trap    #sys

            ; 4. Initialize 7-Segment Display 
            move.l  #0,d0               ; Index for '0' pattern
            lea     kseg,a0
            move.b  (a0,d0),d0          ; Load '0' pattern
            
            move.l  #p27seg,a0          ; Start address ($E00000)

p2loop:     
            move.b  d0,(a0)             ; Write '0' to current digit
            add.l   #2,a0               ; Move to next digit
            cmp.l   #$E00010,a0         ; Check bounds
            blt     p2loop              ; Loop until all 8 are cleared

            ; 5. Create Task 1
            move.l  #syscr,d0
            move.l  #p2t1,d1            ; Address
            move.l  #t1stack,d2         ; Stack
            trap    #sys

p2t00:      ; --- Task 0 Main Loop ---
            ; Increment A
            move.l  p2a,d0
            add.l   #1,d0
            move.l  d0,p2a

            ; Wait Mutex
            move.l  #syswmtx,d0         ; (Matches your kernel definition)
            trap    #sys

            ; Increment C (Critical Section)
            move.l  p2c,d0
            add.l   #1,d0
            move.l  d0,p2c

            ; Signal Mutex
            move.l  #syssmtx,d0         ; (Matches your kernel definition)
            trap    #sys

            bra     p2t00               ; Repeat

;-------------------------------------------------------------------------------
; PROG2 - TASK 1: Counter B and Danger Check
;-------------------------------------------------------------------------------
p2t1:
            ; 1. Create Task 2
            move.l  #syscr,d0
            move.l  #p2t2,d1            ; Address
            move.l  #t2stack,d2         ; Stack
            trap    #sys

p2t10:      ; --- Task 1 Main Loop ---
            ; Increment B
            move.l  p2b,d0
            add.l   #1,d0
            move.l  d0,p2b

            ; Wait Mutex
            move.l  #syswmtx,d0
            trap    #sys        

            ; Increment C (Critical Section)
            move.l  p2c,d0
            add.l   #1,d0
            move.l  d0,p2c

            ; Signal Mutex
            move.l  #syssmtx,d0
            trap    #sys
            
            ; Danger Check: Check if C > 400,000 (0x61A80)
            move.l  p2c,d0
            cmp.l   #400000,d0
            bgt     p2ledon1

            bra     p2t10               ; Repeat

p2ledon1:
            move.l  #$01,d0
            or.b    d0,p2led            ; Turn on RH LED (Bit 0)
            bra     p2t10               ; Return to loop

;-------------------------------------------------------------------------------
; PROG2 - TASK 2: Wait, Display, and Verify
;-------------------------------------------------------------------------------
p2t2:   
            ; 1. Wait for 80 ticks (8 seconds)
            move.l  #syswttm,d0
            move.l  #80,d1              
            trap    #sys

            ; 2. Calculate C / 8
            move.l  p2c,d0
            lsr.l   #3,d0               ; Divide by 8

            ; 3. Display Logic (Adapted from your example)
            ; Displays the Hex value of C/8 on all 8 digits
            
            lea     kseg,a0             ; A0 = Pattern Table
            move.l  #p27sege,a1         ; A1 = Rightmost Digit ($E0000E)
            move.l  #0,d1               ; D1 = Shift Counter (0, 4, 8...)
            
p2t200: 
            move.l  #$0F,d2             ; 
            lsl.l   d1,d2               ; Shift mask left to correct position
            and.l   d0,d2               ; Extract the hex digit bits
            lsr.l   d1,d2               ; Shift bits back to LSB (0-15)
            
            move.b  (a0,d2),d2          ; Get 7-seg pattern from table
            move.b  d2,(a1)             ; Write to display
            
            add.l   #4,d1               ; Increase shift counter by 4
            sub.l   #2,a1               ; Move to previous digit (Left)
            
            cmp.l   #32,d1              ; Have we done 32 bits (8 digits)?
            bne     p2t200              ; If not, repeat loop
            

            ; 4. Verify Mutex: (a + b) - c > 2?
            move.l  p2a,d0
            add.l   p2b,d0
            sub.l   p2c,d0
            
            cmp.l   #2,d0
            bgt     p2ledon2

            bra     p2t2                

p2ledon2:
            move.l  #$02,d0
            or.b    d0,p2led            ; Turn on LH LED (Error)
            bra     p2t2               

; Variable Data
p2a         ds.l    1
p2b         ds.l    1
p2c         ds.l    1

;*******************************************************************************
; TEST PROGRAM 3: ERROR HANDLING VERIFICATION
;*******************************************************************************
prog3:
;-------------------------------------------------------------------------------
; Test 1: Invalid Address Detection
;-------------------------------------------------------------------------------
            ; Try to create task below user space
            move.l  #syscr,d0
            move.l  #$1000,d1       ; Invalid: below $2000
            move.l  #t1stack,d2
            trap    #0
            
            ; Check return value
            cmp.l   #-1,d0
            bne     test_failed     ; Should return -1
            
            ; Success - show "E" on 7-segment
            move.l  #sevseg,a2
            move.b  #$79,(a2)       ; "E" pattern
            
test_done:  bra     test_done

test_failed:
            ; Failed - light both LEDs
            move.l  #led,a2
            move.b  #$03,(a2)
            bra     test_done
            
;===============================================================================
;  END OF PROGRAM
;===============================================================================
            end     reset



*~Font name~Courier New~
*~Font size~10~
*~Tab type~1~
*~Tab size~4~
