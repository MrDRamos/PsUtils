{***************************************************************}
{                                                               }
{       DeployMaster Sample Support DLL                         }
{                                                               }
{       BDE Installation and Alias Creation                     }
{                                                               }
{       Design & implementation, by Jan Goyvaerts, 2000         }
{                                                               }
{***************************************************************}

library DeployBDE;

uses
  Windows,
  SysUtils,
  BDE;

{$R *.RES}

type
  THResultFunc = function: HResult;

function StrToOem(const AnsiStr: string): string;
begin
  // Convert string from Windows ANSI to DOS ASCII
  SetLength(Result, Length(AnsiStr));
  if Length(Result) > 0 then CharToOem(PChar(AnsiStr), PChar(Result));
end;

procedure CreateBDEAlias(Alias, Folder, Driver: string);
var
  Parameters: string;
begin
  // Try to delete existing alias first
  try
    DbiDeleteAlias(nil, PChar(Alias));
  except
    // Suppress errors
  end;
  // Set parameters for the new alias: NAME:VALUE pairs separated with semicolons (;)
  // Use the BDE Administration utility to see which parameters you can set.
  // This sample sets all the parameters the PARADOX driver needs.
  Parameters := Format('%s:"%s"',  [szCFGDBPATH, Folder]) +
                Format(';%s:"%s"', [szCFGDBDEFAULTDRIVER, szPARADOX]) +
                Format(';%s:"%s"', [szCFGDBENABLEBCD, szCFGFALSE]);
  // Set the driver name
  if CompareText(Driver, szCFGDBSTANDARD) = 0 then Driver := szPARADOX;
  // Create new alias and save the new configuration
  try
    DbiAddAlias(nil, PChar(StrToOem(Alias)),
                     PChar(StrToOem(Driver)),
                     PChar(Parameters), True);
    DbiCfgSave(nil, nil, True);
  except
    // Suppress errors
  end;
end;

// FinishDeployment() is called after DeployMaster has finished its job.
procedure FinishDeployment(Log: PChar); stdcall;
var
  BDEInstFile: string;
  BDEInst: THandle;
  DllRegisterServer: THResultFunc;
begin
  // ****** BDE INSTALLATION ******
  // Load BDEInst.dll
  // This DLL is supposed to be installed into %APPFOLDER%, the same folder where the deployment log is copied into
  BDEInstFile := ExtractFilePath(AnsiString(Log)) + 'BDEInst.dll';
  BDEInst := LoadLibrary(PChar(BDEInstFile));
  // Quit if we can't load the DLL
  if BDEInst = 0 then Exit;
  try
    // Load the installation routine
    DllRegisterServer := GetProcAddress(BDEInst, 'DllRegisterServer');
    if @DllRegisterServer = nil then raise Exception.Create('Unable to load BDEInst.dll::DllRegisterServer');
    // Install the BDE.  Easy, isn't it?
    DllRegisterServer;
  finally
    // Clean up
    FreeLibrary(BDEInst);
  end;
  // Since the installation DLL has served its purpose, we can get rid of it now
  DeleteFile(BDEInstFile);
  // ****** ALIAS CREATION ******
  DbiInit(nil);
  try
    // Sample: Create the alias DeployTest using the Folder %APPFOLDER% with the PARADOX driver
    CreateBDEAlias('DeployTest', ExtractFilePath(AnsiString(Log)), 'PARADOX');
    // Create more aliases here...
  finally
    DbiExit;
  end;
end;

exports
  // Make our support routines visible to the world
  FinishDeployment;

end.
