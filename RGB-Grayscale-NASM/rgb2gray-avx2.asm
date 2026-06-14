section .data
filename_in:    db "Cat_test.png", 0
filename_out:   db "output_avx2.png", 0

msg_load_err:   db "Erreur lors du chargement de l'image.", 0
msg_write_err:  db "Erreur lors de l'écriture de l'image.", 0

; Coefficients pour la conversion RGB -> niveaux de gris (BT.2020) en float32
; Répliqués 8 fois pour le traitement vectoriel AVX2
coeff_r:        dd 0.2627, 0.2627, 0.2627, 0.2627, 0.2627, 0.2627, 0.2627, 0.2627
coeff_g:        dd 0.6780, 0.6780, 0.6780, 0.6780, 0.6780, 0.6780, 0.6780, 0.6780
coeff_b:        dd 0.0593, 0.0593, 0.0593, 0.0593, 0.0593, 0.0593, 0.0593, 0.0593

; Pour la conversion et saturation
float_255:      dd 255.0, 255.0, 255.0, 255.0, 255.0, 255.0, 255.0, 255.0
float_0:        dd 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0

; Masques pour l'extraction des composantes
mask_r:         dd 0x000000FF, 0x000000FF, 0x000000FF, 0x000000FF, 0x000000FF, 0x000000FF, 0x000000FF, 0x000000FF
mask_g:         dd 0x0000FF00, 0x0000FF00, 0x0000FF00, 0x0000FF00, 0x0000FF00, 0x0000FF00, 0x0000FF00, 0x0000FF00
mask_b:         dd 0x00FF0000, 0x00FF0000, 0x00FF0000, 0x00FF0000, 0x00FF0000, 0x00FF0000, 0x00FF0000, 0x00FF0000

shift_g:        db 8, 8, 8, 8, 8, 8, 8, 8
shift_b:        db 16, 16, 16, 16, 16, 16, 16, 16

section .bss
w:              resd 1
h:              resd 1
c:              resd 1
buf_in:         resq 1
buf_out:        resq 1

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
    ; 1. Charger l'image RGBA avec stbi_load()
    ; -----------------------------------------------------------------
    mov     rdi, filename_in
    mov     rsi, w
    mov     rdx, h
    mov     rcx, c
    mov     r8d, 4                ; Forcer 4 canaux (RGBA)
    call    stbi_load

    test    rax, rax
    jz      .error_load
    mov     [buf_in], rax

    ; -----------------------------------------------------------------
    ; 2. Allouer le buffer de sortie (niveaux de gris)
    ; -----------------------------------------------------------------
    mov     eax, [w]
    imul    eax, [h]              ; eax = width * height
    mov     rdi, rax
    call    malloc
    test    rax, rax
    jz      .error_malloc
    mov     [buf_out], rax

    ; -----------------------------------------------------------------
    ; 3. Conversion RGBA -> niveaux de gris avec AVX2 vectoriel
    ; -----------------------------------------------------------------
    mov     rsi, [buf_in]         ; rsi = source RGBA (4 octets par pixel)
    mov     rdi, [buf_out]        ; rdi = destination gris (1 octet par pixel)
    mov     ecx, [w]
    imul    ecx, [h]              ; ecx = nombre total de pixels

    ; Calculer le nombre de pixels à traiter vectoriellement (multiple de 8)
    mov     eax, ecx
    and     eax, 0xFFFFFFF8       ; eax = ecx & ~7 (multiple de 8)
    mov     r8d, eax              ; r8 = nombre de pixels vectoriels
    sub     ecx, eax              ; ecx = pixels restants (scalaires)

    ; Charger les constantes AVX2 une fois pour toutes
    vmovaps ymm7, [coeff_r]       ; ymm7 = coefficients R
    vmovaps ymm8, [coeff_g]       ; ymm8 = coefficients G  
    vmovaps ymm9, [coeff_b]       ; ymm9 = coefficients B
    vmovaps ymm10, [float_255]    ; ymm10 = 255.0
    vmovaps ymm11, [float_0]      ; ymm11 = 0.0

    ; -----------------------------------------------------------------
    ; Boucle vectorielle AVX2 (8 pixels à la fois)
    ; -----------------------------------------------------------------
    test    r8d, r8d
    jz      .scalar_processing

.vector_loop:
    ; Charger 8 pixels RGBA (32 octets = 8 pixels * 4 octets)
    vmovdqu ymm0, [rsi]           ; ymm0 = [A3B3G3R3|A2B2G2R2|A1B1G1R1|...] (8 pixels)

    ; Extraire la composante R (octets 0, 4, 8, 12, 16, 20, 24, 28)
    vpxor   ymm1, ymm1, ymm1      ; ymm1 = 0
    vpunpcklbw ymm2, ymm0, ymm1   ; Déballer les octets bas en mots
    vpunpcklwd ymm3, ymm2, ymm1   ; Déballer les mots bas en double mots
    vpunpckhbw ymm4, ymm0, ymm1   ; Déballer les octets hauts en mots  
    vpunpcklwd ymm5, ymm4, ymm1   ; Déballer les mots hauts en double mots

    ; Combiner les parties basses et hautes pour R
    vinsertf128 ymm1, ymm3, xmm5, 1  ; ymm1 = composantes R sur 32 bits

    ; Extraire la composante G (octets 1, 5, 9, 13, 17, 21, 25, 29)
    vpsrldq ymm2, ymm0, 1         ; Décaler d'1 octet pour aligner G
    vpxor   ymm3, ymm3, ymm3
    vpunpcklbw ymm4, ymm2, ymm3
    vpunpcklwd ymm5, ymm4, ymm3
    vpunpckhbw ymm6, ymm2, ymm3
    vpunpcklwd ymm2, ymm6, ymm3
    vinsertf128 ymm2, ymm5, xmm2, 1  ; ymm2 = composantes G sur 32 bits

    ; Extraire la composante B (octets 2, 6, 10, 14, 18, 22, 26, 30)
    vpsrldq ymm3, ymm0, 2         ; Décaler de 2 octets pour aligner B
    vpxor   ymm4, ymm4, ymm4
    vpunpcklbw ymm5, ymm3, ymm4
    vpunpcklwd ymm6, ymm5, ymm4
    vpunpckhbw ymm0, ymm3, ymm4
    vpunpcklwd ymm3, ymm0, ymm4
    vinsertf128 ymm3, ymm6, xmm3, 1  ; ymm3 = composantes B sur 32 bits

    ; Convertir les composantes en float32
    vcvtdq2ps ymm1, ymm1          ; ymm1 = R (float32)
    vcvtdq2ps ymm2, ymm2          ; ymm2 = G (float32) 
    vcvtdq2ps ymm3, ymm3          ; ymm3 = B (float32)

    ; Appliquer les coefficients
    vmulps  ymm1, ymm1, ymm7      ; ymm1 = R * 0.2627
    vmulps  ymm2, ymm2, ymm8      ; ymm2 = G * 0.6780
    vmulps  ymm3, ymm3, ymm9      ; ymm3 = B * 0.0593

    ; Additionner les composantes pondérées
    vaddps  ymm1, ymm1, ymm2      ; ymm1 += ymm2
    vaddps  ymm1, ymm1, ymm3      ; ymm1 += ymm3 (ymm1 = Gray)

    ; Saturation entre 0 et 255
    vmaxps  ymm1, ymm1, ymm11     ; Saturer à 0
    vminps  ymm1, ymm1, ymm10     ; Saturer à 255

    ; Convertir float32 -> int32
    vcvtps2dq ymm1, ymm1          ; ymm1 = Gray (int32)

    ; Convertir int32 -> int16 -> int8 (pack pour 8 pixels)
    vpackssdw ymm1, ymm1, ymm1    ; int32 -> int16 (saturé)
    vpermq   ymm1, ymm1, 0x08     ; Réorganiser les lanes
    vpacksswb xmm1, xmm1, xmm1    ; int16 -> int8 (saturé)

    ; Stocker les 8 pixels de sortie
    vmovq   qword [rdi], xmm1

    ; Avancer les pointeurs
    add     rsi, 32               ; 8 pixels * 4 octets = 32 octets
    add     rdi, 8                ; 8 pixels * 1 octet = 8 octets
    sub     r8d, 8
    jnz     .vector_loop

    ; -----------------------------------------------------------------
    ; Traitement scalaire SSE2 pour les pixels restants
    ; -----------------------------------------------------------------
.scalar_processing:
    test    ecx, ecx
    jz      .conversion_done

.scalar_loop:
    ; Charger les composantes R, G, B (ignorer A)
    movzx   eax, byte [rsi]       ; R
    movzx   ebx, byte [rsi+1]     ; G
    movzx   edx, byte [rsi+2]     ; B

    ; Conversion avec SSE2 scalaire
    cvtsi2ss xmm0, eax            ; xmm0 = R (float)
    mulss   xmm0, [coeff_r]       ; xmm0 = R * 0.2627

    cvtsi2ss xmm1, ebx            ; xmm1 = G (float)
    mulss   xmm1, [coeff_g]       ; xmm1 = G * 0.6780

    cvtsi2ss xmm2, edx            ; xmm2 = B (float)
    mulss   xmm2, [coeff_b]       ; xmm2 = B * 0.0593

    addss   xmm0, xmm1            ; xmm0 += xmm1
    addss   xmm0, xmm2            ; xmm0 += xmm2

    ; Saturation
    maxss   xmm0, [float_0]
    minss   xmm0, [float_255]

    ; Conversion float -> int
    cvtss2si eax, xmm0

    ; Stocker le pixel de sortie
    mov     byte [rdi], al

    ; Avancer les pointeurs
    add     rsi, 4                ; RGBA = 4 octets
    inc     rdi                   ; Gris = 1 octet
    dec     ecx
    jnz     .scalar_loop

.conversion_done:
    ; Réinitialiser AVX
    vzeroupper

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
