.global __idle
__idle:
    hlt
    jmp __idle
