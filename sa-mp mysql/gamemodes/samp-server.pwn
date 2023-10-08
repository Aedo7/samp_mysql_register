#pragma warning disable 239

#include <a_samp>
#include <a_mysql>
#include <samp_bcrypt>

#define MYSQL_HOST "127.0.0.1"
#define MYSQL_USER "root"
#define MYSQL_PASSWORD ""
#define MYSQL_DATABASE "samp-server"

#define callback%0(%1) forward %0(%1); public %0(%1)

#define COLOR_WHITE 0xFFFFFFFFF

main() 
{
	print("\bCargando...\n");
}

new MySQL: MySQL;

new g_MysqlRaceCheck[MAX_PLAYERS];

new bool: Logueado[MAX_PLAYERS], bool: PrimerSpawn[MAX_PLAYERS];


enum
{
	DIALOGO_INVALIDO = -1,
	DIALOGO_GENERAL,
	DIALOGO_LOGIN,
	DIALOGO_REGISTRO
}

enum E_PLAYER_INFO
{
	pi_ID,
	pi_USERNAME[MAX_PLAYER_NAME],
	pi_PASSWORD[BCRYPT_HASH_LENGTH],
	pi_ADMIN,
	pi_SCORE,
	pi_MONEY,
	pi_KILLS,
	pi_DEATHS,
	pi_SKIN
}
new PLAYER_INFO[MAX_PLAYERS][E_PLAYER_INFO];

#define GetUsername(%0) PLAYER_INFO[%0][pi_USERNAME]

/******************************************************* PUBLICS *******************************************************/

public OnGameModeInit()
{
	new MySQLOpt: option_id = mysql_init_options();

	mysql_set_option(option_id, AUTO_RECONNECT, true); 

	MySQL = mysql_connect(MYSQL_HOST, MYSQL_USER, MYSQL_PASSWORD, MYSQL_DATABASE, option_id);

	if (MySQL == MYSQL_INVALID_HANDLE || mysql_errno(MySQL) != 0)
	{
		printf("MySQL Error: no se ha conectado a la base de datos > %s <.", MYSQL_DATABASE);
		SendRconCommand("exit"); 
		return 1;
	}
	return 1;
}
public OnGameModeExit()
{
	mysql_close(MySQL);
	return 1;
}
public OnPlayerConnect(playerid)
{
	ResetPlayerVars(playerid);
	return 1;
}
public OnPlayerDisconnect(playerid, reason)
{
	g_MysqlRaceCheck[playerid] ++;

	OnSavePlayerAccount(playerid);

	return 1;
}
public OnPlayerRequestClass(playerid, classid)
{
	if (PrimerSpawn[playerid])
	{
		new query[190];
		ClearChat(playerid, COLOR_WHITE, 50);
		mysql_format(MySQL, query, sizeof query, "SELECT * FROM players WHERE username = '%e' LIMIT 1", GetUsername(playerid));
		mysql_tquery(MySQL, query, "OnPlayerDataLoaded", "ii", playerid, g_MysqlRaceCheck[playerid]);
		TogglePlayerSpectating(playerid, true);
	}
	return 1;
}
public OnPlayerRequestSpawn(playerid)
{
	return 0;
}
public OnPlayerSpawn(playerid)
{
	if (PrimerSpawn[playerid])
	{
		SetPlayerName(playerid, GetUsername(playerid));

		PrimerSpawn[playerid] = false;
	}
	return 1;
}
public OnDialogResponse(playerid, dialogid, response, listitem, inputtext[])
{
	switch (dialogid)
	{
		case DIALOGO_LOGIN:
		{
			if (response)
			{
				if(!strlen(inputtext)) 
				{
					SendClientMessage(playerid, COLOR_WHITE, "Por favor ingresa una contraseña válida.");
					ShowPlayerDialog(playerid, DIALOGO_LOGIN, DIALOG_STYLE_PASSWORD, "Iniciar Sesion", "Escribe tu contraseña para ingresar.", "Ingresar", "Salir");
					return 1;
				}
				bcrypt_verify(playerid, "OnPassswordVerify", inputtext, PLAYER_INFO[playerid][pi_PASSWORD]);
			}
		}
		case DIALOGO_REGISTRO:
		{
			if (response)
			{
				if (!strlen(inputtext) || strlen(inputtext) < 6) 
				{
					SendClientMessage(playerid, COLOR_WHITE, "La contraseña debe tener como mínimo 6 caracteres.");
					ShowPlayerDialog(playerid, DIALOGO_REGISTRO, DIALOG_STYLE_INPUT, "Registrarse", "Escribe una contraseña para registrarte.", "Registrarse", "Salir");
					return 1;
				}
				bcrypt_hash(playerid, "OnPassswordHash", inputtext, BCRYPT_COST);
			}
		}
	}
	return 1;
}

/******************************************************* CALLBACKS *******************************************************/

callback OnPlayerDataLoaded(playerid, race_check)
{

	new hashed_username[15];
	HashedName(hashed_username, sizeof hashed_username);
	SetPlayerName(playerid, hashed_username);

	if (race_check != g_MysqlRaceCheck[playerid]) 
	{
		printf(">>> KICK race_check: %s raceid %d", GetUsername(playerid), race_check);
		return Kick(playerid);
	}
	if (cache_num_rows())
	{
		cache_get_value_int(0, "ID", PLAYER_INFO[playerid][pi_ID]);
		cache_get_value(0, "PASSWORD", PLAYER_INFO[playerid][pi_PASSWORD], BCRYPT_HASH_LENGTH);

		ShowPlayerDialog(playerid, DIALOGO_LOGIN, DIALOG_STYLE_PASSWORD, "Iniciar Sesion", "Escribe tu contraseña para ingresar.", "Ingresar", "Salir");
	}
	else ShowPlayerDialog(playerid, DIALOGO_REGISTRO, DIALOG_STYLE_INPUT, "Registrarse", "Escribe una contraseña para registrarte.", "Registrarse", "Salir");
	return 1;
}
callback OnPassswordVerify(playerid, bool: success)
{
	if (success)
	{
		new query[590];
		mysql_format(MySQL, query, sizeof query, "SELECT * FROM players WHERE username = '%e' LIMIT 1", GetUsername(playerid));
		mysql_tquery(MySQL, query, "OnPlayerLoadAccount", "i", playerid);
	}
	else
	{
		SendClientMessage(playerid, COLOR_WHITE, "La contraseña ingresada es incorrecta, por favor ingresa al servidor e intenta nuevamente.");
		KickEx(playerid, "Contraseña incorrecta.");
		return 1;
	}
	return 1;
}
callback OnPassswordHash(playerid)
{
	new query[290];
	bcrypt_get_hash(PLAYER_INFO[playerid][pi_PASSWORD]);
	mysql_format(MySQL, query, sizeof query, "INSERT INTO players (`username`, `password`) VALUES ('%e', '%e')", GetUsername(playerid), PLAYER_INFO[playerid][pi_PASSWORD]);
	mysql_tquery(MySQL, query, "OnPlayerRegister", "i", playerid);
	return 1;
}
callback OnPlayerRegister(playerid)
{
	PLAYER_INFO[playerid][pi_ID] = cache_insert_id();
	SetSpawnInfo(playerid, NO_TEAM, 250, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0);
	TogglePlayerSpectating(playerid, false);

	Logueado[playerid] = true;
	return 1;
}
callback OnPlayerLoadAccount(playerid)
{
	cache_get_value_name_int(0, "ADMIN", PLAYER_INFO[playerid][pi_ADMIN] );
	cache_get_value_name_int(0, "SCORE", PLAYER_INFO[playerid][pi_SCORE] );
	cache_get_value_name_int(0, "MONEY", PLAYER_INFO[playerid][pi_MONEY] );
	cache_get_value_name_int(0, "KILLS", PLAYER_INFO[playerid][pi_KILLS] );
	cache_get_value_name_int(0, "DEATHS", PLAYER_INFO[playerid][pi_DEATHS] );
	cache_get_value_name_int(0, "SKIN", PLAYER_INFO[playerid][pi_SKIN] );

	SetSpawnInfo(playerid, NO_TEAM, 250, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0);
	TogglePlayerSpectating(playerid, false);

	Logueado[playerid] = true;
	return 1;
}
callback KickEnd(playerid) return Kick(playerid);

/******************************************************* FUNCS *******************************************************/

HashedName(strDest[], strLen = 10)
{
	while(strLen--)
	strDest[strLen] = random(2) ? (random(26) + (random(2) ? 'a' : 'A')) : (random(10) + '0');
}

ClearChat(playerid, color, lineas)
{
	for(new line = 0; line < lineas; line ++) {
		SendClientMessage(playerid, color, "");
	}
}


KickEx(playerid, const string[], time = 500)
{
	print(string);
	return SetTimerEx("KickEnd", time, false, "i", playerid);
}

OnSavePlayerAccount(playerid)
{
	if (!Logueado[playerid]) return 1;

	new query[590];
	mysql_format(MySQL, query, sizeof query, "UPDATE players SET ADMIN = '%d', SCORE = '%d', MONEY = '%d', KILLS = '%d', DEATHS = '%d', SKIN = '%d' WHERE ID = '%d'",
	PLAYER_INFO[playerid][pi_ADMIN],
	PLAYER_INFO[playerid][pi_SCORE],
	PLAYER_INFO[playerid][pi_MONEY],
	PLAYER_INFO[playerid][pi_KILLS],
	PLAYER_INFO[playerid][pi_DEATHS],
	PLAYER_INFO[playerid][pi_SKIN],
	PLAYER_INFO[playerid][pi_ID]);
	mysql_tquery(MySQL, query);
	return 1;
}

ResetPlayerVars(playerid)
{
	GetPlayerName(playerid, PLAYER_INFO[playerid][pi_USERNAME], MAX_PLAYER_NAME);

	g_MysqlRaceCheck[playerid] ++;

	PrimerSpawn[playerid] = true;
	Logueado[playerid] = false;
}

