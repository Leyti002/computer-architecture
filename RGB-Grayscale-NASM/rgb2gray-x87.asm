section .data
filename_in:    db "Cat_test.png", 0
filename_out:   db "output_x87.png", 0

msg_load_err:   db "Erreur lors du chargement de l'image.", 0
msg_write_err:  db "Erreur lors de l'écriture de l'image.", 0

; Coefficients pour la conversion RGB -> niveaux de gris (BT.2020)
coeff_r:        dd 0.2627
coeff_g:        dd 0.6780
coeff_b:        dd 0.0593

section .bss
w:              resd 1
h:              resd 1
c:              resd 1
buf_in:         resq 1
buf_out:        resq 1   ; Buffer pour l'image en niveaux de gris

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
    mov     r8d, 3                ; Forcer 3 canaux (RGB)
    call    stbi_load

    test    rax, rax
    jz      .error_load
    mov     [buf_in], rax

    ; -----------------------------------------------------------------
    ; 2. Allouer le buffer de sortie (niveaux de gris)
    ; Taille = width * height * 1 octet par pixel
    ; -----------------------------------------------------------------
    mov     eax, [w]
    imul    eax, [h]              ; eax = width * height
    mov     rdi, rax
    call    malloc
    test    rax, rax
    jz      .error_malloc
    mov     [buf_out], rax

    ; -----------------------------------------------------------------
    ; 3. Conversion RGB -> niveaux de gris avec FPU x87
    ; -----------------------------------------------------------------
    mov     rsi, [buf_in]         ; rsi = source RGB (3 octets par pixel)
    mov     rdi, [buf_out]        ; rdi = destination gris (1 octet par pixel)
    mov     ecx, [w]
    imul    ecx, [h]              ; ecx = nombre total de pixels

.conversion_loop:
    test    ecx, ecx
    jz      .conversion_done

    ; Charger les composantes R, G, B
    movzx   eax, byte [rsi]       ; R
    movzx   ebx, byte [rsi+1]     ; G
    movzx   edx, byte [rsi+2]     ; B

    ; Initialiser le FPU
    finit

    ; Conversion R -> float et multiplication par coefficient
    mov     dword [rsp-4], eax    ; Stocker R temporairement
    fild    dword [rsp-4]         ; Charger R dans ST0
    fmul    dword [coeff_r]       ; ST0 = R * 0.2627

    ; Conversion G -> float et multiplication par coefficient
    mov     dword [rsp-4], ebx    ; Stocker G temporairement
    fild    dword [rsp-4]         ; Charger G dans ST0, ST1 = R*0.2627
    fmul    dword [coeff_g]       ; ST0 = G * 0.6780

    ; Conversion B -> float et multiplication par coefficient
    mov     dword [rsp-4], edx    ; Stocker B temporairement
    fild    dword [rsp-4]         ; Charger B dans ST0, ST1 = G*0.6780, ST2 = R*0.2627
    fmul    dword [coeff_b]       ; ST0 = B * 0.0593

    ; Additionner les trois composantes pondérées
    faddp   st1, st0              ; ST0 = (G*0.6780) + (B*0.0593), ST1 = R*0.2627
    faddp   st1, st0              ; ST0 = R*0.2627 + G*0.6780 + B*0.0593

    ; Troncature et conversion en entier (0-255)
    fistp   dword [rsp-4]         ; Convertir float -> int
    mov     eax, [rsp-4]

    ; Saturation entre 0 et 255
    cmp     eax, 255
    jle     .not_above
    mov     eax, 255
.not_above:
    cmp     eax, 0
    jge     .not_below
    mov     eax, 0
.not_below:

    ; Stocker le pixel de sortie
    mov     byte [rdi], al

    ; Avancer les pointeurs
    add     rsi, 3                ; Avancer de 3 octets (RGB)
    inc     rdi                   ; Avancer de 1 octet (niveaux de gris)
    dec     ecx
    jmp     .conversion_loop

.conversion_done:

    ; -----------------------------------------------------------------
    ; 4. Écrire l'image en niveaux de gris
    ; -----------------------------------------------------------------
    mov     rdi, filename_out
    mov     esi, [w]
    mov     edx, [h]
    mov     ecx, 1                ; 1 canal (niveaux de gris)
    mov     r8, [buf_out]
    mov     eax, [w]              ; stride = width * 1
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

    ; -----------------------------------------------------------------
    ; 6. Retour succès
    ; -----------------------------------------------------------------
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
    mov     rdi, msg_load_err     ; Réutilise le message d'erreur de chargement
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
