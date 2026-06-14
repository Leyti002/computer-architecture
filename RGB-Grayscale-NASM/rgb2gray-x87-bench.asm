section .data
filename_in:    db "Cat_test.png", 0
filename_out:   db "output_x87_bench.png", 0

msg_load_err:   db "Erreur lors du chargement de l'image.", 0
msg_write_err:  db "Erreur lors de l'écriture de l'image.", 0

; Coefficients pour la conversion RGB -> niveaux de gris (BT.2020)
coeff_r:        dd 0.2627
coeff_g:        dd 0.6780
coeff_b:        dd 0.0593

; Compteur de boucle de benchmarking
bench_iters:    dd 10              ; 10 itérations seulement pour x87

section .bss
w:              resd 1
h:              resd 1
c:              resd 1
buf_in:         resq 1
buf_out:        resq 1
buf_temp:       resq 1             ; Buffer temporaire pour les itérations

section .text
global main

extern stbi_load
extern stbi_write_png
extern stbi_image_free
extern malloc
extern free
extern puts

; ---------------------------------------------------------------------
; Point d'entrée pour GCC (fonction main)
; ---------------------------------------------------------------------
main:
    push    rbx
    push    rbp
    push    r12
    push    r13
    push    r14
    push    r15
    sub     rsp, 8

    ; -----------------------------------------------------------------
    ; 1. Charger l'image RGB avec stbi_load()
    ; -----------------------------------------------------------------
    mov     rdi, filename_in
    mov     rsi, w
    mov     rdx, h
    mov     rcx, c
    mov     r8d, 3
    call    stbi_load

    test    rax, rax
    jz      .error_load
    mov     [buf_in], rax

    ; -----------------------------------------------------------------
    ; 2. Allouer les buffers de sortie - CORRIGÉ
    ; -----------------------------------------------------------------
    ; Buffer de sortie (niveaux de gris)
    mov     eax, [w]
    imul    eax, [h]              ; eax = width * height
    movsxd  rdi, eax              ; Conversion 32-bit -> 64-bit
    call    malloc
    test    rax, rax
    jz      .error_malloc
    mov     [buf_out], rax

    ; Buffer temporaire pour les itérations
    mov     eax, [w]
    imul    eax, [h]
    imul    eax, 3                ; Taille RGB = width * height * 3
    movsxd  rdi, eax              ; Conversion 32-bit -> 64-bit
    call    malloc
    test    rax, rax
    jz      .error_malloc
    mov     [buf_temp], rax

    ; -----------------------------------------------------------------
    ; 3. BOUCLE DE BENCHMARKING - 10 itérations seulement
    ; -----------------------------------------------------------------
    mov     r14d, [bench_iters]   ; r14 = compteur d'itérations

.bench_loop:
    ; Copier l'image d'entrée vers le buffer temporaire pour chaque itération
    mov     rsi, [buf_in]         ; Source
    mov     rdi, [buf_temp]       ; Destination
    mov     ecx, [w]
    imul    ecx, [h]
    imul    ecx, 3                ; Taille totale en octets (RGB)

.copy_input_loop:
    test    ecx, ecx
    jz      .copy_done
    mov     al, [rsi]
    mov     [rdi], al
    inc     rsi
    inc     rdi
    dec     ecx
    jmp     .copy_input_loop

.copy_done:
    ; Réinitialiser les pointeurs pour la conversion
    mov     rsi, [buf_temp]       ; Source = buffer temporaire
    mov     rdi, [buf_out]        ; Destination = buffer de sortie
    mov     ecx, [w]
    imul    ecx, [h]              ; ecx = nombre total de pixels

.conversion_loop:
    test    ecx, ecx
    jz      .conversion_done

    ; Charger R, G, B
    movzx   eax, byte [rsi]       ; R
    movzx   ebx, byte [rsi+1]     ; G
    movzx   edx, byte [rsi+2]     ; B

    ; Conversion x87
    finit

    ; R * 0.2627
    mov     [rsp-4], eax
    fild    dword [rsp-4]
    fmul    dword [coeff_r]

    ; G * 0.6780
    mov     [rsp-4], ebx
    fild    dword [rsp-4]
    fmul    dword [coeff_g]

    ; B * 0.0593
    mov     [rsp-4], edx
    fild    dword [rsp-4]
    fmul    dword [coeff_b]

    ; Additionner
    faddp   st1, st0
    faddp   st1, st0

    ; Troncature et saturation
    fistp   dword [rsp-4]
    mov     eax, [rsp-4]
    cmp     eax, 255
    jle     .not_above
    mov     eax, 255
.not_above:
    cmp     eax, 0
    jge     .not_below
    mov     eax, 0
.not_below:
    mov     [rdi], al

    ; Avancer les pointeurs
    add     rsi, 3
    inc     rdi
    dec     ecx
    jmp     .conversion_loop

.conversion_done:
    ; Décrémenter le compteur de benchmarking
    dec     r14d
    jnz     .bench_loop

    ; -----------------------------------------------------------------
    ; 4. Écrire l'image finale (une seule fois)
    ; -----------------------------------------------------------------
    mov     rdi, filename_out
    mov     esi, [w]
    mov     edx, [h]
    mov     ecx, 1
    mov     r8, [buf_out]
    mov     eax, [w]
    mov     r9d, eax
    call    stbi_write_png

    test    eax, eax
    jz      .error_write

    ; -----------------------------------------------------------------
    ; 5. Nettoyage mémoire
    ; -----------------------------------------------------------------
    mov     rdi, [buf_in]
    call    stbi_image_free

    mov     rdi, [buf_out]
    call    free

    mov     rdi, [buf_temp]
    call    free

    add     rsp, 8
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbp
    pop     rbx
    xor     eax, eax
    ret

; ---------------------------------------------------------------------
; Gestion des erreurs
; ---------------------------------------------------------------------
.error_load:
    mov     rdi, msg_load_err
    call    puts
    jmp     .exit_error

.error_write:
    mov     rdi, msg_write_err
    call    puts
    jmp     .exit_error

.error_malloc:
    mov     rdi, msg_load_err
    call    puts

.exit_error:
    add     rsp, 8
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbp
    pop     rbx
    mov     eax, 1
    ret
