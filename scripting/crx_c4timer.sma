#include <amxmodx>
#include <amxmisc>
#include <csx>

#if AMXX_VERSION_NUM < 183
	#include <dhudmessage>
#endif

#define PLUGIN_VERSION "2.1"
#define SYM_NEWLINE "%n%"

enum
{
	RED = 0,
	GREEN,
	BLUE
}

enum
{
	HUD = 0,
	DHUD,
	CENTER
}

enum _:RegisteredCvars
{
	CVAR_STYLE,
	CVAR_RANDOM,
	CVAR_YELLOW,
	CVAR_RED,
	CVAR_XPOS,
	CVAR_YPOS,
	CVAR_TYPE,
	CVAR_ORIGINAL
}

enum _:CvarValues
{
	CV_STYLE,
	bool:CV_RANDOM,
	CV_YELLOW,
	CV_RED,
	Float:CV_XPOS,
	Float:CV_YPOS,
	CV_TYPE,
	CV_ORIGINAL
}

enum _:Styles
{
	Begin[64],
	Add[20],
	End[20],
	ReplaceSymbol[20],
	ReplaceWith[20],
	bool:DoReplace
}

new g_eRegisteredCvars[RegisteredCvars]
new g_eCvarValues[CvarValues]
new g_eTimer[Styles]
new Array:g_aStyles
 
new g_szTimer[128], g_iCurrentTimer, g_iMessage
new bool:g_bPlanted
new g_iStyles
 
public plugin_init()
{
	register_plugin("Style C4 Timer", PLUGIN_VERSION, "OciXCrom")
	register_cvar("StyleC4Timer", PLUGIN_VERSION, FCVAR_SERVER|FCVAR_SPONLY|FCVAR_UNLOGGED)
	register_logevent("RemoveTimer", 2, "1=Round_Start")
	register_logevent("RemoveTimer", 2, "1=Round_End")
	register_logevent("RemoveTimer", 2, "1&Restart_Round_")
	g_aStyles = ArrayCreate(Styles)
	
	g_eRegisteredCvars[CVAR_STYLE] 			= 		register_cvar("c4timer_style", "1")
	g_eRegisteredCvars[CVAR_RANDOM]			= 		register_cvar("c4timer_random", "0")
	g_eRegisteredCvars[CVAR_YELLOW] 		= 		register_cvar("c4timer_yellow", "10")
	g_eRegisteredCvars[CVAR_RED] 			= 		register_cvar("c4timer_red", "5")
	g_eRegisteredCvars[CVAR_XPOS] 			= 		register_cvar("c4timer_xpos", "-1.0")
	g_eRegisteredCvars[CVAR_YPOS] 			= 		register_cvar("c4timer_ypos", "0.80")
	g_eRegisteredCvars[CVAR_TYPE] 			= 		register_cvar("c4timer_type", "0")
	g_eRegisteredCvars[CVAR_ORIGINAL]		= 		get_cvar_pointer("mp_c4timer")
	
	g_iMessage = CreateHudSyncObj()
	ReadFile()
}

public plugin_end()
	ArrayDestroy(g_aStyles)

ReadFile()
{
	new szConfigsName[256], szFilename[256]
	get_configsdir(szConfigsName, charsmax(szConfigsName))
	formatex(szFilename, charsmax(szFilename), "%s/C4Styles.ini", szConfigsName)
	new iFilePointer = fopen(szFilename, "rt")
	
	if(iFilePointer)
	{
		new szData[96], szKey[32], szValue[64]
		new eStyle[Styles]
		
		while(!feof(iFilePointer))
		{
			fgets(iFilePointer, szData, charsmax(szData))
			trim(szData)
			
			switch(szData[0])
			{
				case EOS, ';': continue
				case '{': g_iStyles++
				case '}':
				{
					eStyle[DoReplace] = !is_blank(eStyle[Add])
					ArrayPushArray(g_aStyles, eStyle)
					
					eStyle[Begin][0] = EOS
					eStyle[Add][0] = EOS
					eStyle[End][0] = EOS
					eStyle[ReplaceSymbol][0] = EOS
					eStyle[ReplaceWith][0] = EOS
				}
				default:
				{
					replace_all(szData, charsmax(szData), SYM_NEWLINE, "^n")
					strtok(szData, szKey, charsmax(szKey), szValue, charsmax(szValue), ':')
					trim(szKey); trim(szValue); remove_quotes(szValue)
					
					if(equali(szKey, "begin"))
						copy(eStyle[Begin], charsmax(eStyle[Begin]), szValue)
					else if(equali(szKey, "add"))
						copy(eStyle[Add], charsmax(eStyle[Add]), szValue)
					else if(equali(szKey, "end"))
						copy(eStyle[End], charsmax(eStyle[End]), szValue)
					else if(equali(szKey, "replace symbol"))
						copy(eStyle[ReplaceSymbol], charsmax(eStyle[ReplaceSymbol]), szValue)
					else if(equali(szKey, "replace with"))
						copy(eStyle[ReplaceWith], charsmax(eStyle[ReplaceWith]), szValue)
				}
			}
		}
		
		fclose(iFilePointer)
	}
}
 
public bomb_planted()
{
	CheckCvars()
	g_bPlanted = true
	g_iCurrentTimer = g_eCvarValues[CV_ORIGINAL]
	FormTimer()
	DisplayTimer()
}
 
public bomb_defused()
	RemoveTimer()
 
public bomb_explode()
	RemoveTimer()

CheckCvars()
{
	g_eCvarValues[CV_STYLE] 		= 		clamp(get_pcvar_num(g_eRegisteredCvars[CVAR_STYLE]), 0, g_iStyles)
	g_eCvarValues[CV_RANDOM] 		=	 	bool:get_pcvar_num(g_eRegisteredCvars[CVAR_RANDOM])
	g_eCvarValues[CV_YELLOW] 		= 		get_pcvar_num(g_eRegisteredCvars[CVAR_YELLOW])
	g_eCvarValues[CV_RED] 			= 		get_pcvar_num(g_eRegisteredCvars[CVAR_RED])
	g_eCvarValues[CV_XPOS] 			=		_:get_pcvar_float(g_eRegisteredCvars[CVAR_XPOS])
	g_eCvarValues[CV_YPOS] 			= 		_:get_pcvar_float(g_eRegisteredCvars[CVAR_YPOS])
	g_eCvarValues[CV_TYPE] 			= 		get_pcvar_num(g_eRegisteredCvars[CVAR_TYPE])
	g_eCvarValues[CV_ORIGINAL] 		= 		get_pcvar_num(g_eRegisteredCvars[CVAR_ORIGINAL])
	
	ArrayGetArray(g_aStyles, g_eCvarValues[CV_STYLE], g_eTimer)
}

FormTimer()
{
	ClearTimer()
	
	if(g_eTimer[DoReplace])
	{
		AddToTimer(g_eTimer[Begin])
		
		for(new i; i < g_iCurrentTimer; i++)
			AddToTimer(g_eTimer[Add])
			
		AddToTimer(g_eTimer[End])
	}
	else
		formatex(g_szTimer, charsmax(g_szTimer), g_eTimer[Begin], g_iCurrentTimer)
}

UpdateTimer()
{
	if(g_eTimer[DoReplace])
		ReplaceInTimer(g_eTimer[ReplaceSymbol], g_eTimer[ReplaceWith])
	else
		formatex(g_szTimer, charsmax(g_szTimer), g_eTimer[Begin], g_iCurrentTimer)
}

ClearTimer()
	g_szTimer[0] = EOS
	
AddToTimer(const szString[])
	add(g_szTimer, charsmax(g_szTimer), szString)
	
ReplaceInTimer(const szString[], const szString2[])
	replace(g_szTimer, charsmax(g_szTimer), szString, szString2)
	
public DisplayTimer()
{   
	if(g_bPlanted)
	{	
		if(g_iCurrentTimer >= 0)
		{			
			switch(g_eCvarValues[CV_TYPE])
			{
				case HUD:
				{
					new iColor[3]; GetColors(iColor)
					set_hudmessage(iColor[0], iColor[1], iColor[2], g_eCvarValues[CV_XPOS], g_eCvarValues[CV_YPOS], 0, 1.0, 1.0, 0.01, 0.01)
					ShowSyncHudMsg(0, g_iMessage, g_szTimer, g_iCurrentTimer)
				}
				case DHUD:
				{
					new iColor[3]; GetColors(iColor)
					set_dhudmessage(iColor[0], iColor[1], iColor[2], g_eCvarValues[CV_XPOS], g_eCvarValues[CV_YPOS], 0, 1.0, 1.0, 0.01, 0.01)
					show_dhudmessage(0, g_szTimer, g_iCurrentTimer)
				}
				case CENTER: client_print(0, print_center, g_szTimer, g_iCurrentTimer)
			}
			
			g_iCurrentTimer--
			
			UpdateTimer()
			set_task(1.0, "DisplayTimer")
		}
	}
}

public RemoveTimer()
{
	if(g_bPlanted)
	{
		g_bPlanted = false
		g_iCurrentTimer = -1
	}
}

GetColors(iColor[3])
{
	if(g_eCvarValues[CV_RANDOM])
	{
		for(new i; i < BLUE; i++)
			iColor[i] = random(256)
	}
	else
	{
		if(g_iCurrentTimer > g_eCvarValues[CV_YELLOW]) iColor[GREEN] = 100
		else if(g_iCurrentTimer > g_eCvarValues[CV_RED])
		{
			iColor[RED] = 255
			iColor[GREEN] = 255
		}
		else iColor[RED] = 255
	}
}

bool:is_blank(szString[])
	return szString[0] == EOS