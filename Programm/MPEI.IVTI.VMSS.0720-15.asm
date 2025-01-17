;======================================================================================================================;
; МПС 
; Программа: "MPS_A-07-20_BY_SAFFOX"
; Автор: Saffox, MPEI, А-07-20                                                                                         ;
;======================================================================================================================;

;----------------------------------------------------------------------------------------------------------------------;
;                                                      КОНСТАНТЫ                                                       ;
;----------------------------------------------------------------------------------------------------------------------;

G 			EQU 7 		
M 			EQU 15 		

; СИГНАЛЫ
Y1 			EQU P3.4
Y3 			EQU P3.5
UART_TX 	EQU P3.1 
LED			EQU P1.3
WR_MEM		EQU P3.6
RD_MEM		EQU	P3.7
	
FULL_BUF	EQU	P1.4
SBL0		EQU P1.5
SBL1		EQU P1.6
SBL2		EQU P1.7
	
; АДРЕСНЫЕ СИГНАЛЫ
RG1			EQU 0D00h
RG2			EQU 0E00h
KBRD		EQU 0B00h
CE_MEM		EQU 70h

;ВРЕМЕННЫЕ ИНТЕРВАЛЫ
TimerT0STROB	EQU 8AD0h	; ДЛИТЕЛЬНОСТЬ СТРОБА Y1 ---> 2*M = 2*15 = 30 [МС] = 30000 [МКС] => 65536 - 30000 = 35536 = 8AD0h
TimerT1			EQU	92A0h 	; ДЛИТЕЛЬНОСТЬ СПАДА ПЕРИОДИЧЕСКОГО СИГНАЛА Y3 ---> Т-tи = (20+М)-G = 20+15-7 = 28 [МС] = 28000 [МКС] =>
							; 65536 - 28000 = 37536 = 92A0h
TimerT1ti 		EQU 0E4A8h	; ДЛИТЕЛЬНОСТЬ ИМПУЛЬСА ПЕРИОДИЧЕСКОГО СИГНАЛА Y3 ---> tи = G = 7 [МС] => 65536 - 7000 = 58536	
		
; НАЗНАЧЕНИЯ РЕГИСТРОВ:
;	R0 - ИСПОЛЬЗУЕТСЯ "СИТУАТИВНО"
;	R1 - ФЛАГ ОШИБКИ ОПЕРАТОРА
;	R2 - ЦИФРА В ЗНАКОМЕСТЕ МЛАДШЕГО РАЗРЯДА СДИ
;	R3 - ЦИФРА В ЗНАКОМЕСТЕ СТАРШЕГО РАЗРЯДА СДИ
;	R4 - ДАННЫЕ ОТ UART
;	R5 - ВЫЧИСЛЕННОЕ УПРАВЛЯЮЩЕЕ ВОЗДЕЙСТВИЕ Y2
;	R6 - "ХВОСТ" КОЛЬЦЕВОГО БУФЕРА (МЛ.  ЧАСТЬ)
;	R7 - "ХВОСТ" КОЛЬЦЕВОГО БУФЕРА (СТ. ЧАСТЬ)

ORG 0000h
	JMP START


ORG 0003h		; АДРЕС ОБРАБОТЧИКА ПРЕРЫВАНИЯ ОТ КЛАВИАТУРЫ (ПО ВНЕШНЕМУ ВХОДУ INT0)
	JMP 	EXT0_KBRD

ORG 000Bh		; АДРЕС ОБРАБОТЧИКА ПРЕРЫВАНИЯ ОТ ТАЙМЕРА Т0
	JMP		GEN_Y1

ORG 0013h		; АДРЕС ОБРАБОТЧИКА ПРЕРЫВАНИЯ ОТ КОЛЬЦЕВОГО БУФЕРА (ПО ВНЕШНЕМУ ВХОДУ INT1)
	JMP 	EXT1_BUSY

ORG 001Bh		; АДРЕС ОБРАБОТЧИКА ПРЕРЫВАНИЯ ОТ ТАЙМЕРА Т1
	JMP		GEN_Y3

ORG 0023H		; АДРЕС ОБРАБОТЧИКА ПРЕРЫВАНИЯ ОТ ПОСЛЕДОВАТЕЛЬНОГО ПОРТА (UART)
	JMP 	SERIAL


DSEG AT 0030h
	    	Q: 				ds	0		; ИНИЦИАЛИЗИРУЕМ КАК "СЛОВО" (2 БАЙТА), ОДНАКО РЕАЛЬНО ИСПОЛЬЗОВАТЬСЯ БУДЕТ ТОЛЬКО 1-Й ЬАЙТ
	 HEAD_MEM:				ds	0		; "ГОЛОВА" КОЛЬЦЕВОГО БУФЕРА (МЛ. И СТ. ЧАСТИ СООТВЕВСТВЕННО)

CSEG AT 0100h
START:	
	CALL INI
	NOP
	
	JMP $ 		

;======================================================================================================================;
;||                                           БЛОК ОБРАБОТЧИКОВ ПРЕРЫВАНИЙ                                           ||;
;||																													 ||;

; -------------------------------------- 1. ОБРАБОТКА ПРЕРЫВАНИЙ ОТ КЛАВИАТУРЫ ----------------------------------------;

EXT0_KBRD:
	NOP 					; ЭЛЕМЕНТ ПРОГРАММНОЙ "ЗАЩИТЫ"
	NOP						; ОТ ДРЕБЕЗГА КОНТАКТОВ
	NOP		
	
	CLR 	EX0 				; ЗАПРЕТ ПРЕРЫВАНИЙ ОТ ТАСТАТУРЫ

	CLR		SBL0		 		; ФОРМИРОВАНИЕ "БЕГУЩЕГО НУЛЯ" НА ЛИНИЯХ ОПРОСА ТАСТАТУРЫ

		MOV		DPTR, #KBRD			; ЧТЕНИЕ СОСТОЯНИЯ ЛИНИИ ТАСТАТУРЫ
		MOVX	A, @DPTR			
		ANL		A, 00001111b	; НАЛОЖЕНИЕ МАСКИ ДЛЯ ПОЛУЧЕНИЯ БИТОВ, ОТВЕТСТВЕННЫХ ТОЛЬКО ЗА ТАСТАТУРУ
	
		; БЛОК ПРОВЕРКИ БИТА ОШИБКИ - ЕСЛИ ВЗВЕДЁН (ДО ЭТОГО БЫЛА СОВЕРШЕНА ОШИБКА), ТО НУЖНО ПРОВЕРИТЬ ТОЛЬКО НАЖАТИЕ "R"
		CJNE	R3, #1, GO_NEXT
		CJNE 	A, #00000001b,	GO_TO_KBRD_END	; ЕСЛИ НАЖАТА НЕ КЛАВИША "R" - ИГНОРИРУЕМ ВСЁ ОСТАЛЬНОЕ
		
			MOV		R1, #0					; ИНАЧЕ - СНИМАЕМ БИТ ОШИБКИ
			MOV		A, #-1					; И ОЧИЩАЕМ СДИ	
			CALL	INDICATION
			MOV		A, #-1					
			CALL	INDICATION			
			JMP		KBRD_END
			
			GO_TO_KBRD_END:	
				JMP	KBRD_END
			
	GO_NEXT:
		CJNE	A, #00000010b, CHECK6		; ДАЛЕЕ ИДЁТ "МАСКИРОВАНИЕ" НАЖАТОЙ КЛАВИШИ
			MOV		A, #9					; ЕЁ ТРАНСЛИРОВАНИЕ В НЕКОТОРОЕ ЧИСЛО
			CALL	INDICATION				; И ВЫЗОВ ПРОЦЕДУРЫ ОТОБРАЖЕНИЯ
			JMP		KBRD_END
			
		CHECK6:
		CJNE	A, #00000100b, CHECK3
			MOV		A, #6
			CALL	INDICATION
			JMP		KBRD_END
			
		CHECK3:
		CJNE	A, #00001000b, LINE2
			MOV		A, #3
			CALL	INDICATION
			JMP		KBRD_END
	
	LINE2:
	SETB	SBL0
	CLR		SBL1		 		; ФОРМИРОВАНИЕ "БЕГУЩЕГО НУЛЯ" НА ЛИНИЯХ ОПРОСА ТАСТАТУРЫ

		MOV		DPTR, #KBRD			; ЧТЕНИЕ СОСТОЯНИЯ ЛИНИИ ТАСТАТУРЫ
		MOVX	A, @DPTR
		ANL		A, 00001111b	; НАЛОЖЕНИЕ МАСКИ ДЛЯ ПОЛУЧЕНИЯ БИТОВ, ОТВЕТСТВЕННЫХ ТОЛЬКО ЗА ТАСТАТУРУ
	
		CJNE	A, #00000001b, CHECK8		; ДАЛЕЕ ИДЁТ "МАСКИРОВАНИЕ" НАЖАТОЙ КЛАВИШИ
			MOV		A, #0					; ЕЁ ТРАНСЛИРОВАНИЕ В НЕКОТОРОЕ ЧИСЛО
			CALL	INDICATION				; И ВЫЗОВ ПРОЦЕДУРЫ ОТОБРАЖЕНИЯ
			JMP		KBRD_END
			
		CHECK8:
		CJNE	A, #00000010b, CHECK5				
			MOV		A, #8					
			CALL	INDICATION		
			JMP		KBRD_END

		CHECK5:
		CJNE	A, #00000100b, CHECK2
			MOV		A, #5
			CALL	INDICATION
			JMP		KBRD_END
			
		CHECK2:
		CJNE	A, #00001000b, LINE3
			MOV		A, #2
			CALL	INDICATION
			JMP		KBRD_END

	LINE3:
	SETB	SBL1
	CLR		SBL2		 		; ФОРМИРОВАНИЕ "БЕГУЩЕГО НУЛЯ" НА ЛИНИЯХ ОПРОСА ТАСТАТУРЫ
	
		MOV		DPTR, #KBRD			; ЧТЕНИЕ СОСТОЯНИЯ ЛИНИИ ТАСТАТУРЫ
		MOVX	A, @DPTR
		
		CJNE	A, #00000010b, CHECK7				; ТУТ ПРОВЕРЯЕМ НАЖАТИЕ КЛАВИШИ "Е"
			
		; БЛОК ПРОВЕРКИ КОРРЕКТНОСТИ ВВОДА
			CJNE 	R2, #-1,	FIX_Q		; ПРОВЕРКА НАЛИЧИЯ "ХОТЬ ЧЕГО-ТО" В МЛАДШЕМ РАЗРЯДЕ СДИ
				JMP		CODE_ERROR
				
		; ФИКСИРОВАНИЕ Q
			FIX_Q:
			CJNE 	R3, #-1, GO_SUMM		; ЕСЛИ СТАРШИЙ РАЗРЯД НЕ БЫЛ ЗАПИСАН, ТО ЕГО НАДО "ИНИЦИАЛИЗИРОВАТЬ" НУЛЕМ
				MOV		R3, #0
			GO_SUMM:
				MOV		A, R3				; | ВЫЧИСЛЕНИЕ ЗНАЧЕНИЯ Q
				MOV		B, #10				; |	
				MUL 	AB					; |
				ADD		A, R2 				; | R3*10+R2 = Q
				 
				MOV		R0, #Q				; НАСТРОЙКА КОСВЕННОЙ АДРЕСАЦИИ
				MOV		@R0, A				; НЕПОСРЕДСТВЕННО, ФИКСИРОВАНИЕ Q
				CALL	DATACHECK			; ВЫЗОВ ПРОЦЕДУРЫ ПРИНЯТИЯ РЕШЕНИЯ ОБ УПРАВЛЕНИИ
				JMP		KBRD_END
			
			CLR 	Y1						; СИГНАЛ Y1 ГЕНЕРИРУЕТСЯ ЕСЛИ ДЕЙСТВИТЕЛЬНО БЫЛ ПРОИЗВЕДЕН ВВОД ДАННЫХ С ТАСТАТУРЫ
			SETB	TR0						; ЗАПУСК ТАЙМЕРА Т0 ДЛЯ КОНТРОЛЯ ДЛИТЕЛЬНОСТИ СТРОБА Y1
			MOV		A, #-1					; "ОЧИСТКА" СДИ		
			CALL	INDICATION
			MOV		A, #-1					
			CALL	INDICATION			
			JMP		KBRD_END
		
		CHECK7:		
		CJNE	A, #00000010b, CHECK4			; ДАЛЕЕ ИДЁТ "МАСКИРОВАНИЕ" НАЖАТОЙ КЛАВИШИ
			MOV		A, #7					; ЕЁ ТРАНСЛИРОВАНИЕ В НЕКОТОРОЕ ЧИСЛО
			CALL	INDICATION				; И ВЫЗОВ ПРОЦЕДУРЫ ОТОБРАЖЕНИЯ
			JMP		KBRD_END
		
		CHECK4:
		CJNE	A, #00000100b, CHECK1
			MOV		A, #4
			CALL	INDICATION
			JMP		KBRD_END
		
		CHECK1:
		CJNE	A, #00001000b, KBRD_END
			MOV		A, #1
			CALL	INDICATION
			JMP		KBRD_END
	
	CODE_ERROR:
		CALL	ERROR					; ВЫЗОВ ПРОЦЕДУРЫ ОБРАБОТКИ ОШИБКИ (ВЫВОД КОДА НА СДИ)
		JMP		KBRD_END				; "БЛОКИРОВКА" ВВОДА ДАННЫХ
	
	CALL	INDICATION				; ВЫЗОВ ПРОЦЕДУРЫ ОТОБРАЖЕНИЯ ВВЕДЁННЫХ ДАННЫХ НА СДИ
	CALL	DATACHECK				; ВЫЗОВ ПРОЦЕДУРЫ ПРИНЯТИЯ РЕШЕНИЯ ОБ УПРАВЛЕНИИ		

	KBRD_END:
		SETB 	EX0			; РАЗРЕШЕНИЕ ПРЕРЫВАНИЙ ОТ ТАСТАТУРЫ
RETI

; -------------------------------------- 2. ОБРАБОТКА ПРЕРЫВАНИЙ ОТ ТАЙМЕРА Т0 ----------------------------------------;
GEN_Y1:
	SETB	Y1						; ОКОНЧАНИЕ СТРОБА НИЗКОГО УРОВНЯ СИГНАЛА Y1
	CLR		TF0						; СНЯТИЕ ФЛАГА ПЕРЕПОЛНЕНИЯ СЧЁТЧИКА Т0
	
	; ВОССТАНОВЛЕНИЕ ВРЕМЕННОГО ИНТЕРВАЛА ДЛЯ ТАЙМЕРА Т0
	CLR		TR0						; ОСТАНОВКА ТАЙМЕРА
	MOV 	TH0, #HIGH(-TimerT0STROB) 	; ЗАГРУЗКА СТ. БАЙТА ИНТЕРВАЛА ВРЕМЕНИ					
	MOV 	TL0, #LOW(-TimerT0STROB) 	; ЗАГРУЗКА МЛ. БАЙТА ИНТЕРВАЛА ВРЕМЕНИ
RETI

; ---------------------------------- 3. ОБРАБОТКА ПРЕРЫВАНИЙ ОТ КОЛЬЦЕВОГО БУФЕРА -------------------------------------;
EXT1_BUSY:
	PUSH	ACC
	
	CLR		FULL_BUF		; СНИМАЕМ СИГНАЛ ПЕРЕПОЛНЕНИИЯ БУФЕРА
	MOV		A, R6			; (МЛ. ЧАСТЬ УКАЗАТЕЛЯ "ХВОСТА")
	ADD		A, #2			; ПЕРЕСТАНОВКА УКАЗАТЕЛЯ "ХВОСТА" НА 1 ЗАПИСЬ ВПЕРЕД (2 БАЙТА)
	MOV		B, A
	MOV		A, R7			; (СТ. ЧАСТЬ УКАЗАТЕЛЯ "ХВОСТА")
	ADDC	A, #0			; УЧЕТ ВОЗМОЖНОГО ПРЕНОСА
	MOV		R7, A
	MOV		R6, B

; СРАВНЕНИЕ С АДРЕСОМ ЗАПИСИ, СЛЕДУЮЩЕЙ ЗА ПОСЛЕДНЕЙ (1792-Й) ЗАПИСЬЮ (АДРЕС: 1792*2 -1 = 3583 + 2 = 3585 = 0E01h)
												
		CJNE	R7, #0Eh, END_CHECK_TAIL		; ЕСЛИ СТАРШАЯ ЧАСТЬ "ХВОСТА" ЕЩЁ "НЕ ДОРОСЛА" - ВЫХОДИМ
		CJNE	R6, #01h, END_CHECK_TAIL		; ЕСЛИ МЛАДШАЯ ЧАСТЬ "ХВОСТА" ЕЩЁ "НЕ ДОРОСЛА" - ВЫХОДИМ
		
	; "ХВОСТ" ВЫШЕЛ ЗА ГРАНИЦУ ЗАПИСЕЙ - ПЕРЕСТАВИТЬ ЕГО НА 1-Ю ЗАПИСЬ
	MOV		R6, #04h		
	MOV		R7, #00h
	
	END_CHECK_TAIL:
	; ТУТ ПРОВЕРКА НЕ ДОШЕЛ ЛИ "ХВОСТ" К "ГОЛОВЕ"
		MOV		R0,	#HEAD_MEM	; "НАСТРОЙКА" НА АДРЕС ЗНАЧЕНИЯ ГОЛОВЫ
	
		INC		R0
		MOV		A, @R0			; ЗАГРУЗКА МЛ. БАЙТА ЗНАЧЕНИЯ ГОЛОВЫ
	
		MOV		B, R6
		CJNE	A, B, INCORRECT		; ЕСЛИ БУФЕР НЕ "ПУСТ" - ИДЁМ ДАЛЬШЕ
	
		DEC		R0
		MOV		A, @R0			; ЗАГРУЗКА СТАРШЕГО БАЙТА ЗНАЧЕНИЯ ГОЛОВЫ
	
		MOV		B, R7
		CJNE	A, B, INCORRECT		; ЕСЛИ БУФЕР НЕ "ПУСТ" - ИДЁМ ДАЛЬШЕ 
		JMP		OK
	
	INCORRECT:
		SETB	FULL_BUF			; СООБЩАЕМ ВНЕШНЕМУ УСТРОЙСТВУ, ЧТО БУФЕР ПУСТ
	
	OK:
	; ЗАПИСЫВАЕМ ТЕУЩИЙ УКАЗАТЕЛЬ "ХВОСТА" В "НАЧАЛО" КОЛЬЦЕВОГО БУФЕРА
		MOV		A, #CE_MEM		; "ВЫБОР" МИКРОСХЕМЫ КОЛЬЦЕВОГО БУФЕРА [CS]
		ANL		A, #11110000b	; ОБНУЛЕНИЕ СТАРШИХ БИТОВ АДРЕСА
		MOV		DPH, A
		ORL		A, #02h			; "НАСТРОЙКА" НА АДРЕС ХРАНЕНИЯ УКАЗАТЕЛЕЙ (00h..01h - "ГОЛОВА" / 02h..03h - "ХВОСТ")
		MOV		DPL, A
		
		MOV		A, R7		; ЗАГРУЗКА СТ. ЧАСТИ УКАЗАТЕЛЯ НА "ХВОСТ"
		MOVX	@DPTR, A		; В "НАЧАЛО" КОЛЬЦЕВОГО БУФЕРА

		INC		DPTR
		
		MOV		A, R6		; ЗАГРУЗКА МЛ. ЧАСТИ УКАЗАТЕЛЯ НА "ХВОСТ"
		MOVX	@DPTR, A		; В "НАЧАЛО" КОЛЬЦЕВОГО БУФЕРА

	POP		ACC
	
RETI

; -------------------------------------- 4. ОБРАБОТКА ПРЕРЫВАНИЙ ОТ ТАЙМЕРА Т1 ----------------------------------------;
GEN_Y3:
	CLR		TF1						; СНЯТИЕ ФЛАГА ПЕРЕПОЛНЕНИЯ СЧЁТЧИКА Т1
	CJNE	R5, #0, GO_TO_HI		; ЕСЛИ В R5 НАХОДИТСЯ "0" - ЗНАЧИТ НЕОБХОДИМО АКТИВИЗИРОВАТЬ СИГНАЛ НА tи
						
		; ИНАЧЕ СБРАСЫВАЕМ СИГНАЛ НА Т-tи
		CLR		Y3 
		MOV		TH1, #HIGH(TimerT1)	       		; ЗАГРУЗКА СТ. БАЙТА ВРЕМЕНИ СПАДА (В ТЕНЕВОЙ РЕГИСТР)
		MOV		TL1, #LOW(TimerT1)           	; ЗАГРУЗКА МЛ. БАЙТА ВРЕМЕНИ СПАДА
		SETB	TR1								; ВКЛЮЧЕНИЕ Т1
		MOV		R5, #1							; ИЗМЕНЕНИЕ ЗНАЧЕНИЯ В РЕГИСТРЕ НА ПРОТИВОПОЛОЖНОЕ
		JMP		GEN_Y3_END
		
	 GO_TO_HI:
		SETB	Y3
		MOV		TH1, #HIGH(TimerT1ti)	       	; ЗАГРУЗКА СТ. БАЙТА ВРЕМЕНИ ИМПУЛЬСА (В ТЕНЕВОЙ РЕГИСТР)
		MOV		TL1, #LOW(TimerT1ti)           	; ЗАГРУЗКА МЛ. БАЙТА ВРЕМЕНИ ИМПУЛЬСА
		SETB	TR1								; ВКЛЮЧЕНИЕ Т1
		MOV		R5, #0							; ИЗМЕНЕНИЕ ЗНАЧЕНИЯ В РЕГИСТРЕ НА ПРОТИВОПОЛОЖНОЕ
		
	GEN_Y3_END:
RETI

; -------------------------------- 5. ОБРАБОТКА ПРЕРЫВАНИЙ ОТ ПОСЛЕДОВАТЕЛЬНОГО ПОРТА ---------------------------------;
SERIAL:
	MOV 	A, SBUF		; ЗАБИРАЕМ ПРИШЕДШИЕ ДАННЫЕ ИЗ БУФЕРА (8 БИТ) 
	MOV		R4, A		; СОХРАНЕНИЕ ПРИШЕДНЕГО ПАКЕТА
	
	CALL	DATACHECK	; ВЫЗОВ ПРОЦЕДУРЫ ПРИНЯТИЯ РЕШЕНИЯ ОБ УПРАВЛЕНИИ
	CALL	WRITEMEM	; ЗАПИСЬ ПОЛУЧЕННОГО ПАКЕТА В КОЛЬЦЕВОЙ БУФЕР
	
	CLR 	RI			; СНЯТИЕ ФЛАГА ЗАПОЛНЕНИЯ БУФЕРА UART
RETI
;||																													 ||;
;||																													 ||;
;======================================================================================================================;


;======================================================================================================================;
;||                                        		  БЛОК ПРОЦЕДУР 		                                             ||;
;||																													 ||;

; ------------------------------------------------ ИНИЦИАЛИЗАЦИЯ МПС --------------------------------------------------;
INI:	
	CLR		EA				; ЗАПРЕТ АППАРАТНЫХ ПРЕРЫВАНИЙ ОТ ЛЮБЫХ ИСТОЧНИКОВ НА ВРЕМЯ ИНИЦИАЛИЗАЦИИ

	MOV		A, #11110000b
	MOV		P2, A				; "ИНИЦИАЛИЗАЦИЯ" АДРЕСНОЙ ШИНЫ

; ИНИЦИАЛИЗАЦИЯ ВНЕШНИХ СИГНАЛОВ И БУФЕРА
	SETB	Y1
	CLR		Y3
	
	CLR		FULL_BUF		; СБРОС СИГНАЛА ПЕРЕПОЛНЕНИЯ КОЛЬЦЕВОГО БУФЕРА (ДЛЯ ВНЕШНЕГО УСТРОЙСТВА)
	SETB	WR_MEM			; ИНИЦИАЛИЗАЦИЯ СИГНАЛОВ ДЛЯ БУФЕРА
	SETB	RD_MEM
	
; ИНИЦИАЛИЗАЦЦИЯ ТАСТАТУРЫ
	MOV 	A, #11111111b		; ИНИЦИАЛИЗАЦИЯ ЛИНИЙ ТАСТАТУРЫ (СВЕТОДИОД ЗАЖЖЕТСЯ ПОЗЖЕ)
	MOV 	P0, A
	
; ИНИЦИАЛИЗАЦИЯ СДИ
	MOV		DPTR, #RG1		; ИНИЦИАЛИЗАЦИЯ СТАРШЕГО ЗНАКОМЕСТА СДИ
	MOV		A, #00000000b	; ЗАПИСЬ "ПУСТОЙ" КОМБИНАЦИИ НАПРЯМУЮ В СДИ 
	MOVX 	@DPTR, A		

	MOV		DPTR, #RG2		; ИНИЦИАЛИЗАЦИЯ МЛАДШЕГО ЗНАКОМЕСТА СДИ
	MOV		A, #00000000b	; ЗАПИСЬ "ПУСТОЙ" КОМБИНАЦИИ НАПРЯМУЮ В СДИ 
	MOVX 	@DPTR, A			
	
; ИНИЦИАЛИЗАЦИЯ ТАЙМЕРОВ И ПРИЕМОПЕРЕДАТЧИКА ПОСЛЕДОВАТЕЛЬНОГО ПОРТА	
	;T0	 - КОНТРОЛИРУЕТ ГЕНЕАРЦИЮ Y1
	;T1  - КОНТРОЛИРУЕТ ГЕНЕРАЦИЮ Y3
	;T2	 - ВЫКЛЮЧЕН (НЕ ИСПОЛЬЗУЕТСЯ - ОТСУТСТВУЕТ В i8051)
	
	MOV		WCON, #11100000b		; НАСТРОЙКА СТОРОЖЕВОГО ТАЙМЕРА С ПЕРИОДОМ СРАБАТЫВАНИЯ 2048 МС (ПО 1 БАНКУ УКАЗАТЕЛЕЙ ДАННЫХ)
	SETB	WDTEN
	
	CLR 	TR0 					; ОСТАНАВЛИВАЕМ ТАЙМЕРЫ Т0-Т2
	CLR 	TR1
	;CLR 	T2OE						
	
	MOV		SCON, #10110100b		; УСТАНОВКА 2 РЕЖИМА РАБОТЫ UART (АСИНХР. С ФИКС. СКОРОСТЬЮ Fclk/64)
    ANL		PCON, #01111111b		; ЯВНАЯ НАСТРОЙКА СКОРОСТИ ПЕРЕДАЧИ
	
	MOV		TMOD, #00010001b 		; УСТАНОВКА РЕЖИМОВ ТАЙМЕРОВ (Т1 И Т0 - 16 БИТ)
	
	MOV		TH0, #HIGH(TimerT0STROB)  	    ; ЗАГРУЗКА СТ. БАЙТА Т0
	MOV		TL0, #LOW(TimerT0STROB)        	; ЗАГРУЗКА МЛ. БАЙТА Т0
	MOV		TH1, #HIGH(TimerT1ti)	       	; ЗАГРУЗКА СТ. БАЙТА Т1 ВРЕМЕНИ ИМПУЛЬСА
	MOV		TL1, #LOW(TimerT1ti)           	; ЗАГРУЗКА МЛ. БАЙТА Т1 ВРЕМЕНИ ИМПУЛЬСА
	
; ИНИЦИАЛИЗАЦИЯ ДЕСЯТИЧНОЙ ВЕЛИЧИНЫ (Q = G)
	MOV		R0, #Q
	MOV		@R0, #G

; ИНИЦИАЛИЗАЦИЯ УКАЗАТЕЛЯ "ГОЛОВЫ" В ПАМЯТИ И "НА БОРТУ"
	MOV		R0, #HEAD_MEM		
	MOV		A, #CE_MEM			; "ВЫБОР" МКРОСХЕМЫ КОЛЬЦЕВОГО БУФЕРА [CS]
	ANL		A, #11110000b		; ОБНУЛЕНИЕ СТАРШИХ БИТОВ АДРЕСА
	MOV		DPH, A
	MOV		DPL, #0				; АДРЕС "ГОЛОВЫ" - 0000h
	
	MOV		A, #0
	MOVX	@DPTR, A			; ИНИЦИАЛИЗАЦИЯ СТ. ЧАСТИ АДРЕСА "ГОЛОВЫ" БУФЕРА (В БУФЕРЕ)
	MOV		@R0, A				; ИНИЦИАЛИЗАЦИЯ СТ. ЧАСТИ АДРЕСА "ГОЛОВЫ" БУФЕРА ("НА БОРТУ")
				
	INC		R0
	INC		DPTR
	
	MOV		A, #04h				 
	MOVX	@DPTR, A			; ИНИЦИАЛИЗАЦИЯ МЛ. ЧАСТИ АДРЕСА "ГОЛОВЫ" БУФЕРА (В БУФЕРЕ)
	MOV		@R0, A				; ИНИЦИАЛИЗАЦИЯ МЛ. ЧАСТИ АДРЕСА "ГОЛОВЫ" БУФЕРА ("НА БОРТУ")
	
; ИНИЦИАЛИЗАЦИЯ РЕГИСТРОВ R0-R7 (1 БАНКА)	
	MOV		R1, #0 			; ФЛАГ ОШИБКИ ОПЕРАТОРА (0 - ОШИБКА ОТСУТСТВУЕТ)
	MOV		R2, #-1			; ЦИФРА В ЗНАКОМЕСТЕ МЛАДШЕГО РАЗРЯДА СДИ
	MOV		R3, #-1			; ЦИФРА В ЗНАКОМЕСТЕ СТАРШЕГО РАЗРЯДА СДИ
	MOV		R4, #0			; ДАННЫЕ ОТ UART (ИЗНАЧАЛЬНО "ПУСТОЙ" ПАКЕТ)
	MOV		R5, #0			; УПРАВЛЯЮЩЕЕ ВОЗДЕЙСТВИЕ Y3 (0 - НАДО ПЕРЕКЛЮЧИТЬ НА ВЫСОКИЙ УРОВЕНЬ / 1 - НА НИЗКИЙ)
	MOV		R6, #04h		; МЛ. ЧАСТЬ "ХВОСТА" КОЛЬЦЕВОГО БУФЕРА (ИЗНАЧАЛЬНО УСТАНОВКА НА 1-Й АДРЕС: 0004h)
	MOV		R7, #0			; СТ. ЧАСТЬ "ХВОСТА" КОЛЬЦЕВОГО БУФЕРА (ИЗНАЧАЛЬНО УСТАНОВКА НА 1-Й АДРЕС: 0004h)

; ВКЛЮЧЕНИЕ СВЕТОДИОДА (КАК ПРИЗНАК ГОТОВНОСТИ МПС К РАБОТЕ ПОСЛЕ СТАРТА)
	CLR		LED

; НАСТРОЙКА РЕГИСТРОВ ПРИОРИТЕТА И РАЗРЕШЕНИЕ ПРЕРЫВАНИЙ
	ORL		IP, #00001000b			; НАИВЫСШ. ПРИОРИТЕТ У ТАЙМРА Т1 (ГЕНЕРАТОР ПРЯМОУГ. ИПУЛЬСОВ)
	MOV 	IE, #10011111b 			; УСТАНОВКА РАЗРЕШЕНИЯ ВНЕШНИХ ПРЕРЫВАНИЙ, ОТ ТАЙМЕРОВ Т0/Т1 И UART 

RET

; ------------------------------ ВЫЧИСЛЕНИЕ УПРАВЛЯЮЩЕГО ВОЗДЕЙСТВИЯ И ЗАПИСЬ В БУФЕР ---------------------------------;
WRITEMEM:	
		MOV		A, #CE_MEM			; "ВЫБОР" МИКРОСХЕМЫ КОЛЬЦЕВОГО БУФЕРА (ОЗУ) [CS]
		MOV		R0, #HEAD_MEM		; ПОЛУЧЕНИЕ И ВЫСТАВЛЕНИЕ СТ. ЧАСТИ АДРЕСА "ГОЛОВЫ" КОЛЬЦЕВОГО БУФЕРА			
		ORL		A, @R0			
		MOV 	DPH, A
		
		INC		R0
		MOV		DPL, @R0			; ПОЛУЧЕНИЕ И ВЫСТАВЛЕНИЕ МЛ. ЧАСТИ АДРЕСА "ГОЛОВЫ" КОЛЬЦЕВОГО БУФЕРА
		
		MOV		A, #0
		MOVX 	@DPTR, A			; ЗАПИСЬ "0" В СТ. ЧАСТЬ (ПРИ НЕОБХОДИМОСТИ - НИЖЕ ПРОИСХОДИТ ПЕРЕЗАПИСЬ)
		
		MOV		A, #20				; РАСЧЁТ УПРАВЛЯЮЩЕГО ВОЗДЕЙСТВИЯ Y2 = M+Xd2, 
		ADD		A, R4				; ГДЕ Xd2 - ДАННЫЕ ПОЛУЧЕННЫЕ ПО UART
		MOV		B, A				; (ВРЕМЕННОЕ ХРАНЕНИЕ РЕЗУЛЬТАТА)
	
		JNC		GO_TO_WRITE			; ЕСЛИ НЕ ВОЗНИКЛО ПЕРЕПОЛНЕНИЯ, ТО ПЕРЕХОДИМ К ЗАПИСИ Y2 В КОЛЬЦЕВОЙ БУФЕР
		
		MOV		A, #1				; ИНАЧЕ В СТ. ЧАСТЬ ПИШЕМ "1"
		MOVX 	@DPTR, A			; ПО ВЫСТАВЛЕННОМУ АДРЕСУ
	GO_TO_WRITE:	
		INC		DPTR				; УВЕЛИЧЕНИЕ АДРЕСА НА "+1" (ПРЕХОД К ЗАПИСИ МЛ. ЧАСТИ)
		
		MOV		A, B				; ЗАПИСЬ ЗНАЧЕНИЯ Y2 В КОЛЬЦЕВОЙ БУФЕР
		MOVX 	@DPTR, A			; ПО ВЫСТАВЛЕННОМУ АДРЕСУ
		
		INC		DPTR				; ПЕРЕХОД НА СЛЕДУЮЩУЮ ЗАПИСЬ
	
	; ПРОВЕРКА НА ДОПУСТИМОСТЬ АРЕСА (НЕ ВЫШЛИ ЛИ ЗА 1792-ю запись) 4096 = 1000h
		MOV		A, DPH						; ИМЕЕТ СМЫСЛ ПРОВЕРЯТЬ СТАРШУЮ ЧАСТЬ АДРЕСА
		CJNE	A, #10h, WRITE_NEW_POS
	
		; ЕСЛИ ОСТАЛИСЬ ТУТ - ЗНАЧИТ НЕОБХОДИМО ПЕРЕДВИНУТЬ "ГОЛОВУ" НА САМУЮ 1-Ю ЗАПИСЬ В КОЛЬЦЕВОМ БУФЕРЕ
			MOV		R0, #HEAD_MEM		; СОХРАНЕНИЕ НОВОГО АДРЕСА "ГОЛОВЫ" КОЛЬЦЕВОГО БУФЕРА
			MOV		A, #0			; СТ. ЧАСТЬ АДРЕСА
			MOV		@R0, A
			INC		R0
			MOV		A, #04h			; МЛ. ЧАСТЬ АДРЕСА
			MOV		@R0, A
			JMP		WRITEMEM_END
		
	WRITE_NEW_POS:
		MOV		R0, #HEAD_MEM		; СОХРАНЕНИЕ НОВОГО АДРЕСА "ГОЛОВЫ" КОЛЬЦЕВОГО БУФЕРА "У СЕБЯ"
		MOV		@R0, DPH
		INC		R0
		MOV		@R0, DPL
		
	WRITEMEM_END:
		MOV		R0, #HEAD_MEM
		MOV		A, @R0
		MOV		DPTR, #0000h		; ОБРАЩЕНИЕ В КОЛЬЦЕВОЙ БУФЕР ПО АДРЕСУ "ГОЛОВЫ" (0000h..0002h)
		MOVX	@DPTR, A			; СОХР. СТ. ЧАСТИ АДРЕСА "ГОЛОВЫ"
		
		INC		DPTR
		INC 	R0
		MOV		A, @R0
		MOVX	@DPTR, A			; СОХР. МЛ. ЧАСТИ АДРЕСА "ГОЛОВЫ"
		
		CLR		FULL_BUF			; СНЯЛИ СИГНАЛ ЗАПОЛНЕНИЯ (Т.К. ТОЛЬКО ЧТО ПОЯВИЛАСЬ НОВАЯ ЗАПИСЬ)
RET

; ------------------------------------- ПРИНЯТИЕ РЕШЕНИЯ ОБ УПРАВЛЕНИИ ------------------------------------------------;
DATACHECK:
	MOV		A, #Q
	ANL		A, R4				; СРАВНЕНИЕ ДАННЫХ, ПОЛУЧЕННЫХ ПО UART (R4) И ДАННЫХ ОПЕРАТОРА (Q)
	JC		GEN_OFF				; ВЫКЛЮЧЕНИЕ ГЕНЕРАТОРА, ЕСЛИ Q < Xd2 												
	
	MOV		A, P1						; РЕШЕНИЕ О НЕОБХОДИМОСТИ ВКЛЮЧЕНИЯ ГЕНЕРАТОРА ПРИНИМАЕТСЯ НА ОСНОВЕ
										; АНАЛИЗА СОСТОЯНИЯ СВЕТОДИОДА (ВНАЧАЛЕ ЧИТАЕМ ВЕСЬ ПОРТ)
										
	ANL		A, #00001000b				; ОСТАВЛЯЕМ ТОЛЬКО БИТ СОСТОЯНИЯ СВЕТОДИОДА					
	CJNE	A, #00001000b, ENDCHECK		; ВЫХОД, ЕСЛИ СВЕТОДИОД ВЫКЛЮЧЕН 
	
		SETB	TR1 					; ВКЛЮЧЕНИЕ ГЕНЕРАТОРА ПРЯМОУГОЛЬНЫХ ИМПУЛЬСОВ Y3
		SETB	LED						; ВЫКЛЮЧЕНИЕ СВЕТОДИОДА
		MOV		R5, #1					; Т.Е. ИДЁТ 1-Я ПОЛОВИНА ПЕРИОДА
		JMP		ENDCHECK
		
	GEN_OFF:
		CJNE	R5, #0, GO_GEN_OFF		; ЕСЛИ В R5 НАХОДИТСЯ "0" - ЗНАЧИТ ИДЁТ ВТОРАЯ ПОЛОВИНА ПЕРИОДА СИГНАЛА Y3
		JMP		GEN_OFF					; ЕСЛИ ИДЁТ ТОЛЬКО ПЕРВАЯ ПОЛОВИНА - ЖДЁМ
		
	GO_GEN_OFF:
		CLR		ET1						; ЗАПРЕТ ПРЕРЫВАНИЙ ПО ТАЙМЕРУ Т1
		MOV		A, TCON					; ПОЛУЧЕНИЕ ИНФОРМАЦИИ О СОСТОЯНИИ Т1 (TF1 БУДЕТ ВЗВЕДЁН КОГДА ТАЙМЕР ДОСЧИТАЕТ)
		ANL		A, #10000000b
		CJNE	A, #0, GO_GEN_OFF		; ОЖИДАНИЕ ОКОНЧАНИЯ ПЕРИОДА ПРЯМОУГОЛЬНОГО ИМПУЛЬСА Y3
		
	; ЕСЛИ ДОШЛИ СЮДА - ЗНАЧИТ TH1 И TL1 ПУСТЫ
		CLR		TR1						; ОСТАНОВКА ГЕНЕРАТОРА ПРЯМОУГОЛЬНЫХ ИМПУЛЬСОВ Y3
		CLR		Y3						; ОСТАНОВКА ПРЯМОУГОЛЬНОГО ИМПУЛЬСОВ Y3
		
		MOV		TH1, #HIGH(TimerT1ti)	       	; ЗАГРУЗКА СТ. БАЙТА Т1 ВРЕМЕНИ ИМПУЛЬСА
		MOV		TL1, #LOW(TimerT1ti)           	; ЗАГРУЗКА МЛ. БАЙТА Т1 ВРЕМЕНИ ИМПУЛЬСА
		
		SETB	ET1						; РАЗРЕШЕНИЕ ПРЕРЫВАНИЙ ПО ТАЙМЕРУ Т1
		
		CLR		LED						; ВКЛЮЧЕНИЕ СВЕТОДИОДА			
	
	ENDCHECK:	
RET

; ------------------------------------------------- ИНДИКАЦИЯ ---------------------------------------------------------;
INDICATION:	
	
; ПОИСК КОДА (НА СДИ) ДЛЯ ВВЕДЁННОЙ ЦИФРЫ
	TRANSLATE:
		MOV		B, A
		ANL		A, #-1
			JZ		NODIG
		MOV		A, B
		ANL 	A, #9
			JZ		DIG9
		MOV		A, B
		ANL 	A, #8
			JZ		DIG8
		MOV		A, B
		ANL 	A, #7
			JZ		DIG7
		MOV		A, B
		ANL 	A, #6
			JZ 		DIG6
		MOV		A, B
		ANL 	A, #5
			JZ		DIG5
		MOV		A, B
		ANL 	A, #4
			JZ		DIG4
		MOV		A, B
		ANL		A, #3
			JZ		DIG3
		MOV		A, B
		ANL		A, #2
			JZ 		DIG2
		MOV		A, B
		ANL		A, #1
			JZ 		DIG1
		MOV		A, B
		ANL		A, #0
			JZ 		DIG0
		; В ПРОТИВНОМ СЛУЧАЕ ЭТО СИМВОЛ ОШИБКИ "Е" - ПЕРЕХОД СРАЗУ К ЕГО ФОРМИРОВАНИЮ
	
; ЗАПИСЬ КОДА АКТИВАЦИИ НЕОБХОДИМЫХ СЕМЕНТОВ НА СДИ
		MOV 	A, #01111001b
			JMP		WRITE_DIGITS
	NODIG:
		MOV 	A, #00000000b
			JMP		WRITE_DIGITS	
	DIG0:
		MOV 	A, #00111111b
			JMP		WRITE_DIGITS		
	DIG1:
		MOV 	A, #00000110b
			JMP		WRITE_DIGITS		
	DIG2:
		MOV 	A, #01011011b
			JMP		WRITE_DIGITS		
	DIG3:
		MOV 	A, #01001111b
			JMP		WRITE_DIGITS		
	DIG4:
		MOV 	A, #01100110b
			JMP		WRITE_DIGITS		
	DIG5:
		MOV 	A, #01101101b
			JMP		WRITE_DIGITS		
	DIG6:
		MOV 	A, #01111101b
			JMP		WRITE_DIGITS
	DIG7:
		MOV 	A, #00000111b
			JMP		WRITE_DIGITS		
	DIG8:
		MOV 	A, #01111111b
			JMP		WRITE_DIGITS
	DIG9:
		MOV 	A, #01100111b
			JMP		WRITE_DIGITS
	
	WRITE_DIGITS:	
		MOV		B, A
		MOV		A, R2
		MOV		R3, A				; ПЕРЕНОС ЦИФРЫ ИЗ МЛАДШЕГО ЗНАКОМЕСТА В СТАРШЕЕ
		MOV		DPTR, #RG1			; | ПОДАЧА ЗНАЧЕНИЯ 
		MOVX		@DPTR, A			; | В РЕГИСТР-ЗАЩЁЛКУ
		
		MOV		A, B
		MOV		R2, A				; ЗАГРУЗКА НОВОГОЙ ЦИФРЫ НА МЛАДШЕЕ ЗНАКОМЕСТО
		MOV		DPTR, #RG2			; | ПОДАЧА ЗНАЧЕНИЯ 
		MOVX	@DPTR, A			; | В РЕГИСТР-ЗАЩЁЛКУ		
RET


; -------------------------------------- ОБРАБОТКА ОШИБОЧНОГО ВОЗДЕЙСТВИЯ ---------------------------------------------;
ERROR:
	MOV 	A, #10
	CALL 	INDICATION		; ВЫВОД НА СДИ СИМВОЛА "Е" (В МЛАДШЕЕ ЗНАКОМЕСТО)
	MOV 	A, #1
	CALL 	INDICATION		; ВЫВОД НА СДИ ЦИФРЫ 1 (В МЛАДШЕЕ ЗНАКОМЕСТО -> "E" БУДЕТ СДВИНУТО В СТАРШЕЕ)
	MOV		R1, #1
RET
;======================================================================================================================;

END