//+------------------------------------------------------------------+
//|                                                    EA_Macros.mqh |
//|                                                      Daniel Jose |
//+------------------------------------------------------------------+
#property copyright "Daniel Jose"
//+------------------------------------------------------------------+
#ifndef EA_Macros
	#define EA_Macros

	#define macroRemoveSec(A) (A - (A % 60))
	#define macroGetDate(A) (A - (A % 86400))
	#define macroGetTime(A) (A % 86400)
	#define macroGetSec(A) 	(A - (A - (A % 60)))
	#define macroGetMin(A) 	(int)((A - (A - ((A % 3600) - (A % 60)))) / 60)
	#define macroGetHour(A)	(A - (A - ((A % 86400) - (A % 3600))))
	#define macroHourBiggerOrEqual(A, B) ((A * 3600) < (B - (B - ((B % 86400) - (B % 3600)))))
	#define macroMinusMinutes(A, B) (B - ((A * 60) + (B % 60)))
	#define macroMinusHours(A, B) (B - (A * 3600))
	#define macroAddHours(A, B) (B + (A * 3600))
	#define macroAddMin(A, B) (B + (A * 60))
	#define macroSetHours(A, B) ((A * 3600) + (B - ((B % 86400))))
	#define macroSetMin(A, B) ((A * 60) + (B - (B % 3600)))
	#define macroSetTime(A, B, C) ((A * 3600) + (B * 60) + (C - (C % 86400)))

	#define macroColorRGBA(A, B) ((uint)((B << 24) | (A & 0x00FF00) | ((A & 0xFF0000) >> 16) | ((A & 0x0000FF) << 16)))
	#define macroTransparency(A) (((A > 100 ? 100 : (A < 0 ? 0 : (100 - A))) * 2.55) / 255.0)

	#define macroFlagValid(A, B) (((A & 0x60) == 0x60) ? B : ((A & 0x20) == 0x20) || ((A & 0x40) == 0x40))

#endif
//+------------------------------------------------------------------+
