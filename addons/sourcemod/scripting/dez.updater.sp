#pragma semicolon 1

// ====[ INCLUDES ]============================================================
#include <sourcemod>
#undef REQUIRE_EXTENSIONS
#include <socket>

#define PLUGIN_NAME "Dez Update"
#define PLUGIN_VERSION "1.0"

// ====[ PLUGIN ]==============================================================
public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	MarkNativeAsOptional("SocketCreate");
	MarkNativeAsOptional("SocketSetArg");
	MarkNativeAsOptional("SocketSetOption");
	MarkNativeAsOptional("SocketConnect");
	MarkNativeAsOptional("SocketSend");
	return APLRes_Success;
}

public Plugin:myinfo =
{
	name = "",
	author = "",
	description = "",
	version = PLUGIN_VERSION,
	url = ""
}

// ====[ EVENTS ]===========================================================
public OnPluginStart()
{
	RegAdminCmd("sm_dez_update", Command_DownloadFiles, ADMFLAG_ROOT, "Update all the files in updater.cfg");
}

public DownloadFiles()
{
	decl String:strConfig[255];
	BuildPath(Path_SM, strConfig, sizeof(strConfig), "configs/dez/updater.cfg");
	if(FileExists(strConfig, true))
	{
		new Handle:hKeyValues = CreateKeyValues("Updates");
		if(FileToKeyValues(hKeyValues, strConfig))
		{
			do
			{
				if(KvGotoFirstSubKey(hKeyValues, false))
				{
					decl String:strFileUrl[255];
					decl String:strFile[255];
					decl String:strFilePath[255];

					do
					{
						KvGetString(hKeyValues, "url", strFileUrl, sizeof(strFileUrl));
						KvGetString(hKeyValues, "path", strFile, sizeof(strFile));
						BuildPath(Path_SM, strFilePath, sizeof(strFilePath), strFile);

						Download_Socket(strFileUrl, strFilePath);

						PrintToServer("[SM] Downloading (%s) from (%s)...", strFilePath, strFileUrl);
						LogMessage("[SM] Downloading (%s) from (%s)...", strFilePath, strFileUrl);
					}
					while(KvGotoNextKey(hKeyValues, false));
					KvGoBack(hKeyValues);
				}
			}
			while(KvGotoNextKey(hKeyValues, false));
		}
		CloseHandle(hKeyValues);
	}
}

// ====[ COMMANDS ]============================================================
public Action:Command_DownloadFiles(iClient, iArgs)
{
	ReplyToCommand(iClient, "[SM] Downloading files...");
	DownloadFiles();
}

public Download_Socket(const String:strURL[], const String:strPath[])
{
	new Handle:hFile = OpenFile(strPath, "wb");
	if(hFile != INVALID_HANDLE)
	{
		decl String:strHost[64];
		decl String:strLocation[128];
		decl String:strFile[64];
		decl String:strRequest[512];
		ParseURL(strURL, strHost, sizeof(strHost), strLocation, sizeof(strLocation), strFile, sizeof(strFile));
		FormatEx(strRequest, sizeof(strRequest), "GET %s/%s HTTP/1.0\r\nHost: %s\r\nUser-agent: plugin\r\nConnection: close\r\nPragma: no-cache\r\nCache-Control: no-cache\r\n\r\n", strLocation, strFile, strHost);

		new Handle:hDLPack = CreateDataPack();
		WritePackCell(hDLPack, 0);
		WritePackCell(hDLPack, _:hFile);
		WritePackString(hDLPack, strRequest);

		new Handle:hSocket = SocketCreate(SOCKET_TCP, OnSocketError);
		SocketSetArg(hSocket, hDLPack);
		SocketSetOption(hSocket, ConcatenateCallbacks, 4096);
		SocketConnect(hSocket, OnSocketConnected, OnSocketReceive, OnSocketDisconnected, strHost, 80);
	}
}

public OnSocketConnected(Handle:hSocket, any:hDLPack)
{
	decl String:strRequest[512];
	SetPackPosition(hDLPack, 16);
	ReadPackString(hDLPack, strRequest, sizeof(strRequest));
	SocketSend(hSocket, strRequest);
}

public OnSocketReceive(Handle:socket, String:strData[], const iSize, any:hDLPack)
{
	new iIndex;
	SetPackPosition(hDLPack, 0);
	new bool:bParsedHeader = bool:ReadPackCell(hDLPack);
	if(!bParsedHeader)
	{
		if((iIndex = StrContains(strData, "\r\n\r\n")) == -1)
			iIndex = 0;
		else
			iIndex += 4;

		SetPackPosition(hDLPack, 0);
		WritePackCell(hDLPack, 1);
	}

	SetPackPosition(hDLPack, 8);
	new Handle:hFile = Handle:ReadPackCell(hDLPack);
	while(iIndex < iSize)
		WriteFileCell(hFile, strData[iIndex++], 1);
}

public OnSocketDisconnected(Handle:hSocket, any:hDLPack)
{
	SetPackPosition(hDLPack, 8);
	CloseHandle(Handle:ReadPackCell(hDLPack));
	CloseHandle(hDLPack);
	CloseHandle(hSocket);
}

public OnSocketError(Handle:hSocket, const iErrorType, const iErrorNum, any:hDLPack)
{
	SetPackPosition(hDLPack, 8);
	CloseHandle(Handle:ReadPackCell(hDLPack));
	CloseHandle(hDLPack);
	CloseHandle(hSocket);
	LogError("Socket: %d (Error code %d)", iErrorType, iErrorNum);
}

// ====[ STOCKS ]==============================================================
stock ParseURL(const String:strURL[], String:strHost[], iMaxHost, String:strLocation[], iMaxLoc, String:strFile[], iMaxName)
{
	new iIndex = StrContains(strURL, "://");
	iIndex = (iIndex != -1) ? iIndex + 3 : 0;

	decl String:strDirs[16][64];
	new iTotal = ExplodeString(strURL[iIndex], "/", strDirs, sizeof(strDirs), sizeof(strDirs[]));

	FormatEx(strHost, iMaxHost, "%s", strDirs[0]);

	strLocation[0] = '\0';
	for(new i = 1; i < iTotal - 1; i++)
		FormatEx(strLocation, iMaxLoc, "%s/%s", strLocation, strDirs[i]);

	FormatEx(strFile, iMaxName, "%s", strDirs[iTotal - 1]);
}

stock PrefixURL(String:buffer[], maxlength, const String:strURL[])
{
	if(strncmp(strURL, "http://", 7) != 0)
		FormatEx(buffer, maxlength, "http://%s", strURL);
	else
		strcopy(buffer, maxlength, strURL);
}